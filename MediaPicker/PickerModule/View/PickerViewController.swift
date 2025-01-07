//
//  PickerViewController.swift
//  MediaPicker
//
//  Created by Ayyarappan K on 02/01/25.
//

import UIKit
import Photos
import PhotosUI

protocol MediaPickerDelegate: AnyObject {
    func didSelectMediaAssets(_ mediaAssets: [PHAsset])
}

private enum ScrollDirection {
    case up, down
}

class PickerViewController: UIViewController, UIGestureRecognizerDelegate, UIScrollViewDelegate, UIAdaptivePresentationControllerDelegate {
    
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var mediaCollectionView: UICollectionView!
    @IBOutlet weak var selectionCountLabel: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var blurView: UIView!
    @IBOutlet weak var albumTableView: UITableView!
    @IBOutlet weak var albumTitleLabel: UILabel!
    @IBOutlet weak var albumSwitchButton: UIButton!
    @IBOutlet weak var dateRangeLabel: UILabel!
    
    
    var albums: [PHAssetCollection] = []
    var assets: [PHAsset] = []
    let imageManager = PHCachingImageManager()
    var selectedAssets: [PHAsset] = [] {
        didSet {
            if selectedAssets.isEmpty {
                addButton.isEnabled = false
                addButton.alpha = 0.5
            } else {
                addButton.isEnabled = true
                addButton.alpha = 1
            }
        }
    }
    
    /// Currently selected album
    var selectedAlbum: PHAssetCollection?
    
    weak var delegate: MediaPickerDelegate?
    
    private var isFetchMore: Bool = false
    private var initialSelectedIndexPath : IndexPath?
    private var currentIndexPaths: Set<IndexPath> = []
        
    ///Configurable, Default - 30
    var maxSelectionLimit: Int = 30
    
    /// Configurable, Default - 100
    /// But not recommended above 1000
    /// Used for batch limit asset fetch action
    private let batchSize: Int = 100
    
    ///Configurable, Default - 3
    private let numberOfItemsPerRow: CGFloat = 3
    private let minimumInteritemSpacing: CGFloat = 4
    private let minimumLineSpacing: CGFloat = 4
    private let sectionInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
    
    private var edgeScrollTimer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.isModalInPresentation = true
        self.presentationController?.delegate = self

        setupView()
        setupGestures()
    }
    
    deinit {
        print("\(Self.self) deinited")
        blurView.removeBlur()
    }
    
    private func setupView() {
        let collectionNib = UINib(nibName: "PickerCollectionViewCell", bundle: nil)
        mediaCollectionView.register(collectionNib, forCellWithReuseIdentifier: "PickerCollectionViewCell")
        mediaCollectionView.delegate = self
        mediaCollectionView.dataSource = self
        mediaCollectionView.contentInset = UIEdgeInsets(top: 35, left: 0, bottom: 0, right: 0)
        mediaCollectionView.scrollIndicatorInsets = mediaCollectionView.contentInset
        
        let tableNib = UINib(nibName: "AlbumTableCell", bundle: nil)
        albumTableView.register(tableNib, forCellReuseIdentifier: "AlbumTableCell")
        albumTableView.delegate = self
        albumTableView.dataSource = self
        
        addButton.isEnabled = false
        addButton.alpha = 0.5
        
        blurView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        blurView.isHidden = true
        blurView.addBlurEffect()
        albumTableView.isHidden = true
        
        // permission request
        requestPhotoLibraryAccess { [weak self] authorized in
            guard authorized, let self = self else {
                return
            }
            
            self.fetchAlbums()
            
            self.fetchAssets(for: albums.first)
        }
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(blurViewTapped))
        blurView.addGestureRecognizer(tapGesture)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanSelection(_:)))
        panGesture.delegate = self
        mediaCollectionView.addGestureRecognizer(panGesture)
    }
    
    @objc func blurViewTapped() {
        UIView.animate(withDuration: 0.3, delay: 0.01, options: .curveEaseOut) {
            self.blurView.isHidden.toggle()
            self.albumTableView.isHidden.toggle()
            self.view.layoutIfNeeded()
        }
    }

    @objc private func handlePanSelection(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: mediaCollectionView)
        let velocity = gesture.velocity(in: mediaCollectionView)
        
        switch gesture.state {
        case .began:
            initialSelectedIndexPath = mediaCollectionView.indexPathForItem(at: location)
            currentIndexPaths.removeAll()

        case .changed:
            if abs(velocity.y) > abs(velocity.x) {
                return
            }
            
            guard let currentIndexPath = mediaCollectionView.indexPathForItem(at: location) else { return }
            if let startIndexPath = initialSelectedIndexPath {
                selectAssetsBetween(start: startIndexPath, end: currentIndexPath)
            }
            
            handleEdgeScrolling(for: gesture)

        case .ended, .cancelled, .failed:
            resetGestureState()

        default:
            break
        }
    }
    
    
    private func selectAssetsBetween(start: IndexPath, end: IndexPath) {
        let startItem = min(start.item, end.item)
        let endItem = max(start.item, end.item)

        for item in startItem...endItem {
            let indexPath = IndexPath(item: item, section: start.section)
            let asset = assets[indexPath.item]

            if !currentIndexPaths.contains(indexPath) {
                currentIndexPaths.insert(indexPath)
                if let index = selectedAssets.firstIndex(of: asset) {
                    selectedAssets.remove(at: index)
                } else {
                    guard selectedAssets.count < maxSelectionLimit else {
                        showMaxSelectionAlert()
                        return
                    }
                    
                    selectedAssets.append(asset)
                }

                if let cell = mediaCollectionView.cellForItem(at: indexPath) as? PickerCollectionViewCell {
                    updateCellSelection(cell, isSelected: selectedAssets.contains(asset))
                }
            }
        }
        updateSelectedCountLabel()
    }
    
    private func handleEdgeScrolling(for gesture: UIPanGestureRecognizer) {
        guard let collectionView = mediaCollectionView else { return }

        let location = gesture.location(in: collectionView)
        let scrollBounds = collectionView.bounds
        let scrollVelocity: CGFloat = 10.0 // Adjust for smoother(10) or faster(50) edge scrolling

        if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            edgeScrollTimer?.invalidate()
            edgeScrollTimer = nil
            return
        }

        if location.y <= scrollBounds.minY + 50 {
            // Near top: Scroll up
            if collectionView.contentOffset.y > 0 {
                startEdgeScrolling(direction: .up, velocity: scrollVelocity)
            }
        } else if location.y >= scrollBounds.maxY - 50 {
            // Near bottom: Scroll down
            if collectionView.contentOffset.y < collectionView.contentSize.height - scrollBounds.height {
                startEdgeScrolling(direction: .down, velocity: scrollVelocity)
            }
        } else {
            edgeScrollTimer?.invalidate()
            edgeScrollTimer = nil
        }
    }

    private func startEdgeScrolling(direction: ScrollDirection, velocity: CGFloat) {
        guard edgeScrollTimer == nil else { return }

        edgeScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard let collectionView = self.mediaCollectionView else { return }

            let currentOffset = collectionView.contentOffset
            var newOffset = currentOffset

            switch direction {
            case .up:
                newOffset.y = max(currentOffset.y - velocity, 0)
            case .down:
                let maxOffsetY = collectionView.contentSize.height - collectionView.bounds.height
                newOffset.y = min(currentOffset.y + velocity, maxOffsetY)
            }

            collectionView.setContentOffset(newOffset, animated: false)
            updateSelectedCountLabel()
        }
    }

    private func stopEdgeScrolling() {
        edgeScrollTimer?.invalidate()
        edgeScrollTimer = nil
    }
    
    private func resetGestureState() {
        initialSelectedIndexPath = nil
        currentIndexPaths.removeAll()
        stopEdgeScrolling()
    }

    private func updateCellSelection(_ cell: PickerCollectionViewCell, isSelected: Bool) {
        cell.selectionLabel.isHidden = !isSelected
        cell.selectionLabel.text = isSelected ? "\(selectedAssets.count)" : ""
    }
    
    private func showMaxSelectionAlert() {
        showAlert(with: "Can't select more than \(maxSelectionLimit) items.") {
            //
        }
    }
    
    
    private func requestPhotoLibraryAccess(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    completion(true)
                case .denied, .restricted:
                    self.presentSettingsRedirection()
                    completion(false)
                case .notDetermined:
                    completion(false)
                @unknown default:
                    completion(false)
                }
            }
        }
    }
    
    private func fetchAlbums() {
        var allAlbums: [PHAssetCollection] = []

        // Recents
        if let recents = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumUserLibrary, options: nil).firstObject {
            allAlbums.append(recents)
        }

        // Favorites
        if let favorites = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumFavorites, options: nil).firstObject {
            allAlbums.append(favorites)
        }

        // Media Type Specific Folders
        let mediaTypeAlbums: [PHAssetCollectionSubtype] = [
            .smartAlbumVideos,
            .smartAlbumLivePhotos,
            .smartAlbumPanoramas,
            .smartAlbumScreenshots
        ]

        for subtype in mediaTypeAlbums {
            if let collection = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: subtype, options: nil).firstObject {
                allAlbums.append(collection)
            }
        }

        // User-Created Albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        userAlbums.enumerateObjects { collection, _, _ in
            allAlbums.append(collection)
        }

        self.albums = allAlbums
        DispatchQueue.main.async {
            self.albumTableView.reloadData()
        }
    }
    
    private func fetchMediaCount(for album: PHAssetCollection) -> Int {
        let assets = PHAsset.fetchAssets(in: album, options: nil)
        return assets.count
    }

    private func fetchAssets(for album: PHAssetCollection?) {
        guard let album = album else { return }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared]
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = batchSize
        
        mediaCollectionView.alpha = 0
        selectedAlbum = album
        assets = []
        let twecw = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
        fetchResult.enumerateObjects { asset, _, _ in
            self.assets.append(asset)
        }
        
        DispatchQueue.main.async {
            let text = "\(self.selectedAlbum?.localizedTitle ?? "")"
            self.albumTitleLabel.text = text
            UIView.animate(withDuration: 0.3, delay: 0.02, options: .curveEaseOut) {
                self.mediaCollectionView.reloadData()
                guard !self.assets.isEmpty else {return}
                self.mediaCollectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: false)
                self.mediaCollectionView.alpha = 1
                self.view.layoutIfNeeded()
            }
        }
    }
    
    private func fetchMoreAssets(for album: PHAssetCollection?) {
        guard let album = album else { return }
        guard !isFetchMore else { return }

        isFetchMore = true

        let fetchOptions = PHFetchOptions()
        fetchOptions.includeAssetSourceTypes = [.typeUserLibrary, .typeCloudShared]
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = self.assets.count + batchSize

        let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)

        guard fetchResult.count > self.assets.count else {
            self.isFetchMore = false
            return
        }

        let startIndex = self.assets.count

        var newAssets = [PHAsset]()
        for index in startIndex..<fetchResult.count {
            newAssets.append(fetchResult.object(at: index))
        }

        let indexPaths = (startIndex..<fetchResult.count).map { IndexPath(item: $0, section: 0) }

        self.assets.append(contentsOf: newAssets)

        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3, delay: 0.02, options: .curveEaseOut) {
                self.mediaCollectionView.performBatchUpdates {
                    self.mediaCollectionView.insertItems(at: indexPaths)
                }
                self.isFetchMore = false
                self.view.layoutIfNeeded()
            }
        }
    }
    
    private func presentSettingsRedirection() {
        let alert = UIAlertController(
            title: "Photo Library Access Denied",
            message: "To select photos, please allow access to the Photo Library in Settings.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            alert.dismiss(animated: true)
        }))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default, handler: { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(settingsURL) {
                UIApplication.shared.open(settingsURL)
            }
        }))
        self.present(alert, animated: true)
    }
    
    // old logic - not in use
//    private func fetchAllMedia(completion: @escaping ([PHAsset]) -> Void) {
//        let fetchOptions = PHFetchOptions()
//        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
//        
//        let allMedia = PHAsset.fetchAssets(with: fetchOptions)  // Fetch both images and videos
//        var assets: [PHAsset] = []
//        
//        allMedia.enumerateObjects { (asset, _, _) in
//            assets.append(asset)
//        }
//        
//        completion(assets)
//    }
    
    private func getAssetThumbnail(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true // Allow fetching from iCloud
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.progressHandler = { progress, error, _, _ in
            if let error = error {
                print("Error downloading cloud item: \(error.localizedDescription)")
                return
            }
//            print("Download progress: \(progress)")
            // Update UI with progress if needed
        }
        
        let scaledTargetSize = CGSize(width: targetSize.width * UIScreen.main.scale,
                                      height: targetSize.height * UIScreen.main.scale)
        
        imageManager.requestImage(for: asset,
                                  targetSize: scaledTargetSize,
                                  contentMode: .aspectFill,
                                  options: options) { (image, _) in
            completion(image)
        }
    }
    
    private func updateSelectedCountLabel() {
        if selectedAssets.isEmpty {
            selectionCountLabel.text = "Select Items"
        } else {
            let item = selectedAssets.count > 1 ? "Items" : "Item"
            selectionCountLabel.text = "\(selectedAssets.count) \(item) Selected"
        }
    }
    
    // Not in use
//    private func getFileName(from asset: PHAsset) -> String {
//        let resources = PHAssetResource.assetResources(for: asset)
//        return resources.first?.originalFilename ?? "unknown"
//    }
    
    
    
    // MARK: - UIGestureRecognizerDelegate
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }
        
        let velocity = panGesture.velocity(in: mediaCollectionView)
        if abs(velocity.y) > abs(velocity.x) {
            return true
        } else {
            return false
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }

        let velocity = panGesture.velocity(in: mediaCollectionView)
        if abs(velocity.y) > abs(velocity.x) {
            return true
        } else if abs(velocity.x) > abs(velocity.y) {
            return true
        }
        return false
    }
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == mediaCollectionView else {return}
        guard !assets.isEmpty else {return}
        
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height

        if offsetY > contentHeight - frameHeight - 20 {
            fetchMoreAssets(for: selectedAlbum)
        }
        
        updateDateRange()
    }

    private func updateDateRange() {
        guard !assets.isEmpty, let visibleIndexPaths = mediaCollectionView?.indexPathsForVisibleItems, !visibleIndexPaths.isEmpty else {
            dateRangeLabel.text = ""
            return
        }
        let sortedIndexPaths = visibleIndexPaths.sorted()
        
        guard let firstVisibleIndex = sortedIndexPaths.first?.item,
                  let lastVisibleIndex = sortedIndexPaths.last?.item,
                  firstVisibleIndex < assets.count,
                  lastVisibleIndex < assets.count else {
            dateRangeLabel.text = ""
            return
        }
            
        let firstAsset = assets[firstVisibleIndex]
        let lastAsset = assets[lastVisibleIndex]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMM yy"
        
        let startDate = firstAsset.creationDate ?? Date()
        let endDate = lastAsset.creationDate ?? Date()
        
        let startDateString = dateFormatter.string(from: startDate)
        let endDateString = dateFormatter.string(from: endDate)
        
        let dateRangeText = startDateString == endDateString ? startDateString : "\(startDateString) - \(endDateString)"
        dateRangeLabel.text = dateRangeText
    }
    
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        // user attempts to dismiss presented controller with default swipe down action
    }
    
    @IBAction func didClickAlbumToggleButton(_ sender: UIButton) {
        triggerHapticFeedback(style: .soft)
        sender.stopInteraction()
        UIView.animate(withDuration: 0.3, delay: 0.01, options: .curveEaseOut) {
            self.blurView.isHidden.toggle()
            self.albumTableView.isHidden.toggle()
            self.view.layoutIfNeeded()
        }
    }
    
    @IBAction func didClickAddButton(_ sender: UIButton) {
        triggerHapticFeedback(style: .soft)
        self.delegate?.didSelectMediaAssets(selectedAssets)
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didClickCancel(_ sender: UIButton) {
        triggerHapticFeedback(style: .soft)
        self.dismiss(animated: true)
    }

}

//MARK: TableView  Delegate / Datasource :
extension PickerViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return albums.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AlbumTableCell", for: indexPath) as! AlbumTableCell
        let album = albums[indexPath.row]
        let count = fetchMediaCount(for: album)
        cell.albumLabel.text = album.localizedTitle ?? ""
        cell.albumCountLabel.text = "\(count)"
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        UIView.animate(withDuration: 0.3) {
            self.albumTableView.isHidden = true
            self.blurView.isHidden = true
            self.view.layoutIfNeeded()
        }
        triggerHapticFeedback(style: .soft)
        let selectedAlbum = albums[indexPath.row]
        fetchAssets(for: selectedAlbum)
        dateRangeLabel.text = ""
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}


//MARK: CollectionView Delegate / Datasource :
extension PickerViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PickerCollectionViewCell", for: indexPath) as! PickerCollectionViewCell
        let asset = assets[indexPath.item]
        
        let cellSize = (collectionView.bounds.width - 8) / numberOfItemsPerRow // Three columns, minus spacing
        let targetSize = CGSize(width: cellSize, height: cellSize)
        
        if asset.sourceType == .typeCloudShared {
            cell.spinner.startAnimating()
            getAssetThumbnail(for: asset, targetSize: targetSize) { image in
                cell.spinner.stopAnimating()
                cell.imgView.image = image
            }
        } else {
            getAssetThumbnail(for: asset, targetSize: targetSize) { image in
                DispatchQueue.main.async {
                    cell.imgView.image = image
                }
            }
        }
        
        if asset.mediaType == .video {
            let duration = Int(asset.duration)
            let minutes = duration / 60
            let seconds = duration % 60
            cell.durationLabel.isHidden = false
            cell.videoView.isHidden = false
            cell.durationLabel.text = String(format: "%d:%02d", minutes, seconds)
        } else {
            cell.videoView.isHidden = true
            cell.durationLabel.isHidden = true
        }
        
        if let selectedIndex = selectedAssets.firstIndex(of: asset) {
            cell.showSelectionNumber(selectedIndex + 1)
        } else {
            cell.hideSelectionNumber()
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = assets[indexPath.item]
        
        
        if let existingIndex = selectedAssets.firstIndex(of: asset) {
            selectedAssets.remove(at: existingIndex)

            let deselectedIndexPath = IndexPath(item: indexPath.item, section: 0)
            collectionView.reloadItems(at: [deselectedIndexPath])
            
            for (index, asset) in selectedAssets.enumerated() {
                if let assetIndex = assets.firstIndex(of: asset) {
                    let affectedIndexPath = IndexPath(item: assetIndex, section: 0)
                    if let cell = collectionView.cellForItem(at: affectedIndexPath) as? PickerCollectionViewCell {
                        cell.showSelectionNumber(index + 1)
                    }
                }
            }
        } else {
            
            guard selectedAssets.count < maxSelectionLimit else {
                triggerHapticFeedback(style: .soft)
                showMaxSelectionAlert()
                return
            }
            
            selectedAssets.append(asset)

            let selectedIndexPath = IndexPath(item: indexPath.item, section: 0)
            collectionView.reloadItems(at: [selectedIndexPath])
        }
        updateSelectedCountLabel()
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let totalSpacing = (2 * sectionInsets.left) + ((numberOfItemsPerRow - 1) * minimumInteritemSpacing)
        let cellWidth = (collectionView.bounds.width - totalSpacing) / numberOfItemsPerRow
        return CGSize(width: cellWidth, height: cellWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return minimumInteritemSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return minimumLineSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets
    }
    
}


/*
 
 private func prepareMediaAssets(from selectedAssets: [PHAsset], completion: @escaping ([MediaAsset]) -> Void) {
         var mediaAssets: [MediaAsset] = []
         let dispatchGroup = DispatchGroup()
         
         for asset in selectedAssets {
             dispatchGroup.enter()
             
             let options = PHImageRequestOptions()
             options.isSynchronous = false
             options.deliveryMode = .highQualityFormat
             
             if asset.mediaType == .image {
                 // Fetch image data
                 PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                     let fileName = self.getFileName(from: asset)
                     let mediaAsset = MediaAsset(fileName: fileName, data: data, url: nil, mediaType: .image)
                     mediaAssets.append(mediaAsset)
                     dispatchGroup.leave()
                 }
             } else if asset.mediaType == .video {
                 // Fetch video URL
                 PHCachingImageManager().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                     if let urlAsset = avAsset as? AVURLAsset {
                         let fileName = self.getFileName(from: asset)
                         let mediaAsset = MediaAsset(fileName: fileName, data: nil, url: urlAsset.url, mediaType: .video)
                         mediaAssets.append(mediaAsset)
                     }
                     dispatchGroup.leave()
                 }
             } else {
                 dispatchGroup.leave()
             }
         }
         
         dispatchGroup.notify(queue: .main) {
             completion(mediaAssets)
         }
     }
     
     private func getFileName(from asset: PHAsset) -> String {
         let resources = PHAssetResource.assetResources(for: asset)
         return resources.first?.originalFilename ?? "unknown"
     }
 
 */

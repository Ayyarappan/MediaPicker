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

class PickerViewController: UIViewController {
    
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var bottomView: UIView!
    @IBOutlet weak var mediaCollectionView: UICollectionView!
    @IBOutlet weak var selectionCountLabel: UILabel!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var blurView: UIView!
    @IBOutlet weak var albumTableView: UITableView!
    @IBOutlet weak var albumTitleLabel: UILabel!
    @IBOutlet weak var albumSwitchButton: UIButton!
    
    
    var albums: [PHAssetCollection] = []
    var assets: [PHAsset] = []
    let imageManager = PHCachingImageManager()
    var selectedAssets: [PHAsset] = [] {
        didSet {
            if selectedAssets.isEmpty {
                selectionCountLabel.isHidden = true
                addButton.isEnabled = false
                addButton.alpha = 0.5
            } else {
                selectionCountLabel.isHidden = false
                addButton.isEnabled = true
                addButton.alpha = 1
            }
        }
    }
    var selectedAlbum: PHAssetCollection? // Currently selected album
    
    weak var delegate: MediaPickerDelegate?
    
    
    // collection view cell item
    private let numberOfItemsPerRow: CGFloat = 3
    private let minimumInteritemSpacing: CGFloat = 4
    private let minimumLineSpacing: CGFloat = 4
    private let sectionInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        
        blurView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(blurViewTapped)))
    }
    
    deinit {
        print("\(Self.self) deinited")
        blurView.removeBlur()
    }
    
    @objc func blurViewTapped() {
        UIView.animate(withDuration: 0.3, delay: 0.01, options: .curveEaseOut) {
            self.blurView.isHidden.toggle()
            self.albumTableView.isHidden.toggle()
            self.view.layoutIfNeeded()
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
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        mediaCollectionView.alpha = 0
        selectedAlbum = album
        assets = []
        let fetchResult = PHAsset.fetchAssets(in: album, options: fetchOptions)
        fetchResult.enumerateObjects { asset, _, _ in
            self.assets.append(asset)
        }
        
        let text = "\(self.selectedAlbum?.localizedTitle ?? "")"
        self.albumTitleLabel.text = text
        UIView.animate(withDuration: 0.3, delay: 0.01, options: .curveEaseOut) {
            self.mediaCollectionView.reloadData()
            self.mediaCollectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: false)
            self.mediaCollectionView.alpha = 1
            self.view.layoutIfNeeded()
        }
    }
    
    private func setupView() {
        let collectionNib = UINib(nibName: "PickerCollectionViewCell", bundle: nil)
        mediaCollectionView.register(collectionNib, forCellWithReuseIdentifier: "PickerCollectionViewCell")
        mediaCollectionView.delegate = self
        mediaCollectionView.dataSource = self
        
        let tableNib = UINib(nibName: "AlbumTableCell", bundle: nil)
        albumTableView.register(tableNib, forCellReuseIdentifier: "AlbumTableCell")
        albumTableView.delegate = self
        albumTableView.dataSource = self
        
        selectionCountLabel.isHidden = true
        addButton.isEnabled = false
        addButton.alpha = 0.5
        
        blurView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        blurView.isHidden = true
        blurView.addBlurEffect()
        albumTableView.isHidden = true
        
        // permission request
        requestPhotoLibraryAccess { [weak self] authorized in
            guard authorized, let self = self else { return }
            
            self.fetchAlbums()
            
            self.fetchAssets(for: albums.first)
            
            // old logic
//            self.fetchAllMedia { fetchedAssets in
//                self.assets = fetchedAssets
//                DispatchQueue.main.async {
//                    self.mediaCollectionView.reloadData()
//                }
//            }
        }
    }
    
    private func requestPhotoLibraryAccess(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized || status == .limited)
            }
        }
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
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
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
        let item = selectedAssets.count > 1 ? "Items" : "Item"
        selectionCountLabel.text = "\(selectedAssets.count) \(item) Selected"
    }
    
    private func getFileName(from asset: PHAsset) -> String {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.first?.originalFilename ?? "unknown"
    }
    
    @IBAction func didClickAlbumToggleButton(_ sender: UIButton) {
        UIView.animate(withDuration: 0.3, delay: 0.01, options: .curveEaseOut) {
            self.blurView.isHidden.toggle()
            self.albumTableView.isHidden.toggle()
            self.view.layoutIfNeeded()
        }
    }
    
    @IBAction func didClickAddButton(_ sender: UIButton) {
        self.delegate?.didSelectMediaAssets(selectedAssets)
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didClickCancel(_ sender: UIButton) {
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
        
        let selectedAlbum = albums[indexPath.row]
        fetchAssets(for: selectedAlbum)
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
        
        let cellSize = (collectionView.bounds.width - 8) / 3 // Three columns, minus spacing
        let targetSize = CGSize(width: cellSize, height: cellSize)
        
        getAssetThumbnail(for: asset, targetSize: targetSize) { image in
            DispatchQueue.main.async {
                cell.imgView.image = image
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
        
//        // Highlight the cell - old logic
//        if selectedAssets.contains(asset) {
//            cell.layer.borderWidth = 2
//            cell.layer.borderColor = UIColor.systemYellow.cgColor
//        } else {
//            cell.layer.borderWidth = 0
//        }
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
            selectedAssets.append(asset)

            let selectedIndexPath = IndexPath(item: indexPath.item, section: 0)
            collectionView.reloadItems(at: [selectedIndexPath])
        }
        
        
//        if let index = selectedAssets.firstIndex(of: selectedAsset) {
//            selectedAssets.remove(at: index)
//        } else {
////            guard selectedAssets.count < 5 else {
////                showMaxSelectionAlert()
////                return
////            }
//            selectedAssets.append(selectedAsset)
//        }
//        collectionView.reloadData()
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

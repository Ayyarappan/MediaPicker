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
    weak var delegate: MediaPickerDelegate?
    
    // collection view cell item
    private let numberOfItemsPerRow: CGFloat = 3
    private let minimumInteritemSpacing: CGFloat = 4
    private let minimumLineSpacing: CGFloat = 4
    private let sectionInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
    }
    
    private func setupView() {
        let collectionNib = UINib(nibName: "PickerCollectionViewCell", bundle: nil)
        mediaCollectionView.register(collectionNib, forCellWithReuseIdentifier: "PickerCollectionViewCell")
        mediaCollectionView.delegate = self
        mediaCollectionView.dataSource = self
        
        selectionCountLabel.isHidden = true
        addButton.isEnabled = false
        addButton.alpha = 0.5
        
        // permission request
        requestPhotoLibraryAccess { [weak self] authorized in
            guard authorized, let self = self else { return }
            self.fetchAllMedia { fetchedAssets in
                self.assets = fetchedAssets
                DispatchQueue.main.async {
                    self.mediaCollectionView.reloadData()
                }
            }
        }
    }
    
    private func requestPhotoLibraryAccess(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized || status == .limited)
            }
        }
    }
    
    private func fetchAllMedia(completion: @escaping ([PHAsset]) -> Void) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let allMedia = PHAsset.fetchAssets(with: fetchOptions)  // Fetch both images and videos
        var assets: [PHAsset] = []
        
        allMedia.enumerateObjects { (asset, _, _) in
            assets.append(asset)
        }
        
        completion(assets)
    }
    
    private func getAssetThumbnail(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        // Ensure the target size accounts for screen scale (e.g., Retina display)
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
    
//    private func prepareMediaAssets(from selectedAssets: [PHAsset], completion: @escaping ([MediaAsset]) -> Void) {
//        var mediaAssets: [MediaAsset] = []
//        let dispatchGroup = DispatchGroup()
//        
//        for asset in selectedAssets {
//            dispatchGroup.enter()
//            
//            let options = PHImageRequestOptions()
//            options.isSynchronous = false
//            options.deliveryMode = .highQualityFormat
//            options.resizeMode = .exact
//            
//            if asset.mediaType == .image {
//                // Fetch image data
//                PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
//                    let fileName = self.getFileName(from: asset)
//                    let mediaAsset = MediaAsset(fileName: fileName, data: data, url: nil, mediaType: .image)
//                    mediaAssets.append(mediaAsset)
//                    dispatchGroup.leave()
//                }
//            } else if asset.mediaType == .video {
//                // Fetch video URL
//                PHCachingImageManager().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
//                    if let urlAsset = avAsset as? AVURLAsset {
//                        let fileName = self.getFileName(from: asset)
//                        let mediaAsset = MediaAsset(fileName: fileName, data: nil, url: urlAsset.url, mediaType: .video)
//                        mediaAssets.append(mediaAsset)
//                    }
//                    dispatchGroup.leave()
//                }
//            } else {
//                dispatchGroup.leave()
//            }
//        }
//        
//        dispatchGroup.notify(queue: .main) {
//            completion(mediaAssets)
//        }
//    }
    
    private func getFileName(from asset: PHAsset) -> String {
        let resources = PHAssetResource.assetResources(for: asset)
        return resources.first?.originalFilename ?? "unknown"
    }
    
    @IBAction func didClickAddButton(_ sender: UIButton) {
        print("add tapped")
        self.delegate?.didSelectMediaAssets(selectedAssets)
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didClickCancel(_ sender: UIButton) {
        self.dismiss(animated: true)
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
        
        // Check if the asset is a video and update the label
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
        
        // Highlight the cell if selected
        if selectedAssets.contains(asset) {
            cell.layer.borderWidth = 2
            cell.layer.borderColor = UIColor.systemYellow.cgColor
        } else {
            cell.layer.borderWidth = 0
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedAsset = assets[indexPath.item]
        if let index = selectedAssets.firstIndex(of: selectedAsset) {
            selectedAssets.remove(at: index)
        } else {
//            guard selectedAssets.count < 5 else {
//                showMaxSelectionAlert()
//                return
//            }
            selectedAssets.append(selectedAsset)
        }
        collectionView.reloadItems(at: [indexPath])
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

//
//  MediaPreviewController.swift
//  MediaPicker
//
//  Created by Ayyarappan K on 09/01/25.
//

import UIKit
import Photos
import PhotosUI
import AVKit

struct MediaPreview {
    var item: PHAsset
    var isSelected: Bool? = true
    
    init(item: PHAsset, isSelected: Bool? = nil) {
        self.item = item
        self.isSelected = isSelected
    }
}

class MediaPreviewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    
    @IBOutlet weak var topBlurView: UIView!
    @IBOutlet weak var bottonBlurView: UIView!
    @IBOutlet weak var previewCollectionView: UICollectionView!
    @IBOutlet weak var selectionButton: UIButton!
    @IBOutlet weak var selectionCountLabel: UILabel!
    
    var selectedAssets = [PHAsset]()
    var previewItems : [MediaPreview] = [] {
        didSet {
            let selectedCount = previewItems.filter({$0.isSelected == true})
            let item = selectedCount.count < 2 ? "Item" : "Items"
            selectionCountLabel.text = "\(selectedCount.count) \(item) Selected"
        }
    }
    private var currentIndex: Int = 0       // track current index to update selectionButton
    let imageManager = PHCachingImageManager()
    var didUpdateSelectedAssets:((_ assets: [PHAsset]) -> ())?      // callback to update selection chaneges
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.isModalInPresentation = true
        self.presentationController?.delegate = self
        
        setupView()
    }
    
    deinit {
        print("\(Self.self) deinited")
        topBlurView.removeBlur()
        bottonBlurView.removeBlur()
    }
    
    private func setupView() {
        
        topBlurView.addBlurEffect()
        bottonBlurView.addBlurEffect()
        
        let collectionNib = UINib(nibName: "PickerCollectionViewCell", bundle: nil)
        previewCollectionView.register(collectionNib, forCellWithReuseIdentifier: "PickerCollectionViewCell")
        previewCollectionView.delegate = self
        previewCollectionView.dataSource = self
        
        for (index, _) in selectedAssets.enumerated() {
            let item = MediaPreview(item: selectedAssets[index], isSelected: true)
            previewItems.append(item)
        }
        
        let item = selectedAssets.count < 2 ? "Item" : "Items"
        selectionCountLabel.text = "\(selectedAssets.count) \(item) Selected"
        
        DispatchQueue.main.async {
            self.previewCollectionView.reloadData()
            self.updateButtonState(for: 0)
            self.view.layoutIfNeeded()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let layout = previewCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let newSize = CGSize(width: previewCollectionView.bounds.width, height: previewCollectionView.bounds.height)
            if layout.itemSize != newSize {
                layout.itemSize = newSize
                layout.invalidateLayout()
            }
        }
    }
    
    private func getAssetThumbnail(for asset: PHAsset, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        let scaledTargetSize = CGSize(width: targetSize.width * UIScreen.main.scale,
                                      height: targetSize.height * UIScreen.main.scale)
        imageManager.requestImage(for: asset,
                                  targetSize: scaledTargetSize,
                                  contentMode: .aspectFit,
                                  options: options) { (image, _) in
            completion(image)
        }
    }
    
    private func playVideo(from phAsset: PHAsset) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { avAsset, audioMix, info in
            guard let avAsset = avAsset else {
                print("Failed to fetch AVAsset")
                return
            }
            
            DispatchQueue.main.async {
                let player = AVPlayer(playerItem: AVPlayerItem(asset: avAsset))
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                self.present(playerViewController, animated: true) {
                    player.play()
                }
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCurrentIndexIfNeeded()
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateCurrentIndexIfNeeded()
    }
    
    private func updateCurrentIndexIfNeeded() {
        let center = view.convert(previewCollectionView.center, to: previewCollectionView)
        if let visibleIndexPath = previewCollectionView.indexPathForItem(at: center), visibleIndexPath.item != currentIndex {
            currentIndex = visibleIndexPath.item
            updateButtonState(for: currentIndex)
        }
    }
    
    private func updateButtonState(for index: Int) {
        let isSelected = previewItems[index].isSelected ?? false
        selectionButton.isSelected = isSelected ? true : false
    }
    
    func getSelectedAssets(from previews: [MediaPreview]) -> [PHAsset] {
        return previews
            .filter { $0.isSelected == true }
            .map { $0.item }
    }
    
    @IBAction func didTappedSelectionButton(_ sender: UIButton) {
        triggerHapticFeedback(style: .soft)
        sender.isSelected = !sender.isSelected
        
        previewItems[currentIndex].isSelected = !(previewItems[currentIndex].isSelected ?? false)
        updateButtonState(for: currentIndex)
    }
    
    @IBAction func didTappedDone(_ sender: UIButton) {
        triggerHapticFeedback(style: .soft)
        let items = getSelectedAssets(from: previewItems)
        self.didUpdateSelectedAssets?(items)
        self.dismiss(animated: true)
    }

}

extension MediaPreviewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return selectedAssets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PickerCollectionViewCell", for: indexPath) as! PickerCollectionViewCell
        let asset = selectedAssets[indexPath.item]
        
        let targetSize = CGSize(width: collectionView.bounds.width, height: collectionView.bounds.height)
        
        getAssetThumbnail(for: asset, targetSize: targetSize) { image in
            DispatchQueue.main.async {
                cell.imgView.contentMode = .scaleAspectFit
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
            cell.playButton.isHidden = false
        } else {
            cell.videoView.isHidden = true
            cell.durationLabel.isHidden = true
            cell.playButton.isHidden = true
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = selectedAssets[indexPath.item]
        if asset.mediaType == .video {
            self.playVideo(from: asset)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.size.width, height: collectionView.frame.size.height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
}

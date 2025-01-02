//
//  ViewController.swift
//  MediaPicker
//
//  Created by Ayyarappan K on 02/01/25.
//

import UIKit
import AVFoundation
import Photos
import PhotosUI
import AVKit

class ViewController: UIViewController {
    
    @IBOutlet weak var mediaCollectionView: UICollectionView!
    
    private let numberOfItemsPerRow: CGFloat = 3
    var selectedAssets : [PHAsset] = []
    let imageManager = PHCachingImageManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupView()
    }
    
    private func setupView() {
        let collectionNib = UINib(nibName: "PickerCollectionViewCell", bundle: nil)
        mediaCollectionView.register(collectionNib, forCellWithReuseIdentifier: "PickerCollectionViewCell")
        mediaCollectionView.delegate = self
        mediaCollectionView.dataSource = self
        
        DispatchQueue.main.async {
            self.mediaCollectionView.reloadData()
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
    
    // MARK: - Helper function
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
    

    @IBAction func didClickPicker(_ sender: UIButton) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Picker", bundle: nil)
        let pickerVC = storyBoard.instantiateViewController(withIdentifier: "PickerViewController") as! PickerViewController
        pickerVC.delegate = self
        self.present(pickerVC, animated: true)
    }
    
}


extension ViewController: MediaPickerDelegate {
    func didSelectMediaAssets(_ mediaAssets: [PHAsset]) {
        print("assets return count: \(mediaAssets.count)")
        
        selectedAssets = mediaAssets
        
        DispatchQueue.main.async {
            self.mediaCollectionView.reloadData()
        }
    }
}


extension ViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return selectedAssets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PickerCollectionViewCell", for: indexPath) as! PickerCollectionViewCell
        let asset = selectedAssets[indexPath.item]
        
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
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = selectedAssets[indexPath.item]
        if asset.mediaType == .video {
            self.playVideo(from: asset)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let totalSpacing = (2 * 4) + ((numberOfItemsPerRow - 1) * 4)
        let cellWidth = (collectionView.bounds.width - totalSpacing) / numberOfItemsPerRow
        return CGSize(width: cellWidth, height: cellWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 4
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 4
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
    }
    
}

//
//  PickerCollectionViewCell.swift
//  MediaPicker
//
//  Created by Ayyarappan K on 02/01/25.
//

import UIKit
import Photos

class PickerCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    var selectionLabel: UILabel!
    var asset: PHAsset?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        durationLabel.layer.masksToBounds = true
        setupSelectionLabel()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        selectionLabel.frame = CGRect(x: contentView.bounds.width - 32, y: 5, width: 26, height: 26)
    }
    
    private func setupSelectionLabel() {
        selectionLabel = UILabel(frame: CGRect(x: contentView.bounds.width - 32, y: 5, width: 26, height: 26))
        selectionLabel.backgroundColor = #colorLiteral(red: 0, green: 0.5019607843, blue: 0, alpha: 1)
        selectionLabel.textColor = .white
        selectionLabel.font = .boldSystemFont(ofSize: 14)
        selectionLabel.textAlignment = .center
        selectionLabel.layer.cornerRadius = 13
        selectionLabel.layer.masksToBounds = true
        selectionLabel.layer.borderWidth = 1.5
        selectionLabel.layer.borderColor = UIColor.white.cgColor
        contentView.addSubview(selectionLabel)
        contentView.bringSubviewToFront(selectionLabel)
        selectionLabel.isHidden = true
    }

    func showSelectionNumber(_ number: Int) {
        selectionLabel.text = "\(number)"
        selectionLabel.isHidden = false
    }

    func hideSelectionNumber() {
        selectionLabel.isHidden = true
    }
    
}

//
//  PickerCollectionViewCell.swift
//  MediaPicker
//
//  Created by Ayyarappan K on 02/01/25.
//

import UIKit

class PickerCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var videoView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        durationLabel.layer.masksToBounds = true
    }
    
}

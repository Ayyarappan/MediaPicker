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
    
    private var selectionLabel: UILabel!
    
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
        selectionLabel.backgroundColor = #colorLiteral(red: 0.9411764741, green: 0.4980392158, blue: 0.3529411852, alpha: 1)
        selectionLabel.textColor = .white
        selectionLabel.font = .boldSystemFont(ofSize: 15)
        selectionLabel.textAlignment = .center
        selectionLabel.layer.cornerRadius = 13
        selectionLabel.layer.masksToBounds = true
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

//
//  AlbumTableCell.swift
//  MediaPicker
//
//  Created by Ayyarappan K on 03/01/25.
//

import UIKit

class AlbumTableCell: UITableViewCell {
    
    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var albumCountLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

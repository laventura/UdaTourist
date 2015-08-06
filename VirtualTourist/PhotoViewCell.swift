//
//  PhotoViewCell.swift
//  VirtualTourist
//
//  Created by Atul Acharya on 8/5/15.
//  Copyright (c) 2015 Atul Acharya. All rights reserved.
//

import UIKit

class PhotoViewCell: UICollectionViewCell {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var cellUrlString: String!      // should be the same as the Photo's imgUrlString
    
}

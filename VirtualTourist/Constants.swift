//
//  Constants.swift
//  VirtualTourist
//
//  Created by Atul Acharya on 7/29/15.
//  Copyright (c) 2015 Atul Acharya. All rights reserved.
//

import Foundation

extension Client {
    
    // MARK: - Constants
    struct Constants {
        static let BaseURL : String     = "https://api.flickr.com/services/rest/"
        static let APIKey : String      = "880a6e7da3f104a51fbcf2e96e99b2a3"
        static let Extras : String      = "url_m"
        static let DataFormat : String  = "json"
        static let NoJSONCallbank       = "1"
        static let MAX_PHOTOS_WANTED    = "12"
        
        static let LAT_MIN              = -90.0
        static let LAT_MAX              = 90.0
        static let LON_MIN              = -180.0
        static let LON_MAX              = 180.0
        
        static let Radius               = "10"
        
        static let BOUNDING_BOX_HALF_WIDTH = 1.0
        static let BOUNDING_BOX_HALF_HEIGHT = 1.0
        
    }
    
    struct Methods{
        static let Search: String = "flickr.photos.search"
    }
    

}
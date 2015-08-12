//
//  ImageCache.swift
//  VirtualTourist
//
//  Created by Atul Acharya on 8/7/15.
//  Copyright (c) 2015 Atul Acharya. All rights reserved.
//

// Code from Udacity's iOS Persistence lesson
// Adapted for local Documents Directory, rather than memory cache

import Foundation
import UIKit

class ImageCache {
    
    // Singleton
    class func sharedInstance() -> ImageCache {
        struct Singleton {
            static var sharedInstance = ImageCache()
        }
        return Singleton.sharedInstance
    }
    
    //MARK: - Helper
    
    func pathForIdentifier(identifier: String) -> String {
        
        let manager = NSFileManager.defaultManager()
        let documentsDirectoryURL = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first as! NSURL
        let url = documentsDirectoryURL.URLByAppendingPathComponent(identifier)
        
        return url.path!
        
    }
    
    //MARK: - Retreiving images
    
    func imageWithIdentifier(identifier: String?) -> UIImage? {
        
        //If identifier is nil or empty, return
        if identifier == nil || identifier! == "" {
            return nil
        }
        
        //Get path for identifier
        let path = pathForIdentifier(identifier!)
        
        var data: NSData?
        //Look for image in hard drive
        if let data = NSData(contentsOfFile: path) {
            return UIImage(data: data)
        }
        
        return nil
    }
    
    //MARK: - Saving images
    
    func storeImage(image: UIImage?, identifier: String) {
        let path = pathForIdentifier(identifier)
        
        //If the image is nil, remove images from cache
        if image == nil {
            NSFileManager.defaultManager().removeItemAtPath(path, error: nil)
            return
        }
        
        //Change image representation to PNG and save it to Documents Directory
        let data = UIImagePNGRepresentation(image!)
        data.writeToFile(path, atomically: true)
    }
    
    //MARK: - Clearing images from Docs directory
    
    // Deletes image from docs directory
    func deleteImage(identifier: String) {
        // call store image with nil to delete the image from docs directory
        storeImage(nil, identifier: identifier)
    }
    
}
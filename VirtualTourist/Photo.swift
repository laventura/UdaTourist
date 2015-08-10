//
//  Photo.swift
//  VirtualTourist
//
//  Created by Atul Acharya on 7/29/15.
//  Copyright (c) 2015 Atul Acharya. All rights reserved.
//

import Foundation
import CoreData
import MapKit
import UIKit

enum DownloadStatus {
    case NotLoaded, Loading, Loaded
}

@objc(Photo)
class Photo: NSManagedObject, Printable {

    // the Flickr URL of the photo
    @NSManaged var urlString: String

    // Pin (location) to which this photo belongs
    @NSManaged var pin: Pin                 // the Pin a Photo belongs to
    // @NSManaged var imgData: NSData?         // TODO: to be removed
    @NSManaged var title: String            // photo title
    @NSManaged var localFilename: String    // localname in Docs dir
    
    struct Keys {
        static let URLString    = "urlString"
        static let Title        = "title"
        static let Pin          = "pin"
        static let LocalFile    = "localFilename"   // localfilename
        static let ID           = "id"              // photo's ID from Flickr
        static let Secret       = "secret"          // photo's Secret from Flickr
    }
    
    var isDownloading: Bool     = false
    var downloadStatus: DownloadStatus = .NotLoaded
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)
        super.init(entity: entity!, insertIntoManagedObjectContext: context)
        
        urlString   = dictionary[Keys.URLString]    as! String
        title       = dictionary[Keys.Title]        as! String
        pin         = dictionary[Keys.Pin]          as! Pin
        localFilename = dictionary[Keys.LocalFile]  as! String
        downloadStatus = .NotLoaded
    }
    
    func updatePhoto(dictionary: [String:AnyObject], context: NSManagedObjectContext) {
        urlString   = dictionary[Keys.URLString]    as! String
        title       = dictionary[Keys.Title]        as! String
        pin         = dictionary[Keys.Pin]          as! Pin
        isDownloading = false
        localFilename = dictionary[Keys.LocalFile]  as! String
        downloadStatus = .NotLoaded
    }
    
    // required for Printable
    override var description: String {
        return "[Photo: id: \(self.localFilename) at \(self.pin)]"
    }
    
    // download Photo from its imgURL
    func downloadImage() {
        if ImageCache.sharedInstance().imageWithIdentifier(self.localFilename) == nil {
            isDownloading = true
            downloadStatus = .Loading    // in progress

            let url     = NSURL(string: urlString)!
            let request = NSURLRequest(URL: url)
            NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) -> Void in
                if error == nil {
                    
                    // Update status - very imp
                    self.downloadStatus = .Loaded

                    // save file to Docs dir
                    let picImage = UIImage(data: data!)
                    ImageCache.sharedInstance().storeImage(picImage!, identifier: self.localFilename)
                    
                    // inform CoreData
                    CoreDataStackManager.sharedInstance().saveContext()
                    
                    // Fire the event - will be caught in AlbumVC
                    NSNotificationCenter.defaultCenter().postNotificationName(Client.Event.NOTIF_ONE_PHOTO_LOADED, object: self)
                } else {
                    self.downloadStatus = .NotLoaded
                    self.isDownloading  = false
                    CoreDataStackManager.sharedInstance().saveContext()
                }
            }
        }
    }
    
    // delete Photo
    func delete() {        
        // Delete the associated img File from local File system
        ImageCache.sharedInstance().deleteImage(self.localFilename)
        downloadStatus = .NotLoaded
        
        // delete from Core Data
        sharedContext.deleteObject(self)
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    // MARK: - Core Data
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }

}

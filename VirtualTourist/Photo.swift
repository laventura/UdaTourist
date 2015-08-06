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

@objc(Photo)
class Photo: NSManagedObject, Printable {

    // the Flickr URL of the photo
    @NSManaged var urlString: String
    // filepath of the Docs directory where photo stored
    ////  @NSManaged var file: String
    // Pin (location) to which this photo belongs
    @NSManaged var pin: Pin
    @NSManaged var imgData: NSData?
    @NSManaged var title: String
    
    struct Keys {
        //static let URL  = "url"
        //static let File = "file"
        static let URLString    = "urlString"
        static let IMGData      = "imgData"
        static let Title        = "title"
        static let Pin          = "pin"
    }
    
    var isDownloading: Bool     = false
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)
        super.init(entity: entity!, insertIntoManagedObjectContext: context)
        
        urlString   = dictionary[Keys.URLString] as! String
        title       = dictionary[Keys.Title] as! String
        pin         = dictionary[Keys.Pin] as! Pin
        
    }
    
    func updatePhoto(dictionary: [String:AnyObject], context: NSManagedObjectContext) {
        urlString   = dictionary[Keys.URLString] as! String
        title       = dictionary[Keys.Title] as! String
        pin         = dictionary[Keys.Pin] as! Pin
        imgData     = nil
        isDownloading = false
        
    }
    
    // required for Printable
    override var description: String {
        return "[Photo: \(self.urlString) at \(self.pin)]"
    }
    
    // download Photo from its imgURL
    func downloadPhoto() {
        if imgData == nil && isDownloading != true {
            isDownloading = true
            // println("-- Downloading pic: [\(urlString)]")
            let url     = NSURL(string: urlString)!
            let request = NSURLRequest(URL: url)
            NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) {(response, data, error) -> Void in
                if error == nil {
                    // println("Downloaded img for Photo:[\(self.title)]")
                    self.imgData        = data
                    CoreDataStackManager.sharedInstance().saveContext()
                } else {
                    // println("Error downloading image: \(error)")
                    self.isDownloading  = false
                    self.imgData        = nil
                    CoreDataStackManager.sharedInstance().saveContext()
                }
            }
        }
    }

}

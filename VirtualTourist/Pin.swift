//
//  Pin.swift
//  VirtualTourist
//
//  Created by Atul Acharya on 7/29/15.
//  Copyright (c) 2015 Atul Acharya. All rights reserved.
//

import Foundation
import CoreData
import MapKit
import UIKit



@objc(Pin)
class Pin: NSManagedObject, Printable {
    
    struct Keys {
        static let Latitude     = "latitude"
        static let Longitude    = "longitude"
        static let Locname      = "locname"
        static let NumPhotos    = "numPhotos"
        static let NumPages     = "numPages"
        static let Photos       = "photos"
    }

    @NSManaged var latitude:    Double
    @NSManaged var longitude:   Double
    @NSManaged var photos:      NSSet       // Set of Photos downloaded
    @NSManaged var locname:     String?
    @NSManaged var numPages:    NSNumber?
    @NSManaged var numPhotos:   NSNumber?
    
    var isDownloading: Bool     = false
    
    let MAX_NUM_PHOTOS          = Client.Constants.MAX_PHOTOS_WANTED.toInt()!
    
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }

    init(dictionary: [String:AnyObject], context: NSManagedObjectContext) {
        
        let entity =  NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        
        super.init(entity: entity,insertIntoManagedObjectContext: context)
        
        self.latitude = (dictionary[Keys.Latitude] as! NSNumber).doubleValue
        self.longitude = (dictionary[Keys.Longitude] as! NSNumber).doubleValue
        
        self.locname = "[\(self.latitude),\(self.longitude)]" // init name
        
        println("Selected location:\(self.locname!)")
        
        self.updatePinName()

    }
    
    override var description: String {
        return "[Pin: \(self.locname!)]"
    }
    
    func updatePinName() {
        CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: self.latitude, longitude: self.longitude), completionHandler: { (placemarks, error) -> Void in
                if (error != nil) {
                    self.locname = "[\(self.latitude),\(self.longitude)]"
                } else if (placemarks.count > 0) {
                    let placemark = placemarks[0] as! CLPlacemark
                    if placemark.subLocality != nil {
                        self.locname = placemark.subLocality
                    } else if placemark.locality != nil {
                        self.locname = placemark.locality
                    } else if placemark.country != nil {
                        self.locname = placemark.country
                    } else if (placemark.addressDictionary["Name"] != nil) {
                        self.locname = placemark.addressDictionary["Name"] as? String
                    }
                }
        })
    }
    
    // Deletes all Photos for this Pin
    func deletePhotos() {
        var currentPhotos = photos.allObjects as! [Photo]
        for photo in currentPhotos {
            photo.delete()
        }
    }
    
    // Returns the total num of pics in the photoset
    func numPicsDownloaded() -> Int {
        return self.photos.count
    }
    
    // fetch Photos for the Pin
    func downloadPhotos( completionHandler: (isSuccess: Bool, errorString: String?) -> Void ) {
        
        if isDownloading == true {
            completionHandler(isSuccess: false, errorString: nil)
            return
        }
        
        isDownloading = true
        // fetch photos for this pin
        Client.sharedInstance().fetchPhotosForPin(self)  { (result, error) -> Void in
            
            self.isDownloading = false
            
            if error != nil {
                completionHandler(isSuccess: false, errorString: "Error downloading pics from Flickr")
                return
            }
            
            // 2. check the "photos" dict
            if let photosDict = result.valueForKey("photos") as? [String:AnyObject] {
                // 2a. check Total # photos
                let numPhotos = (photosDict["total"] as! String).toInt()!
                self.numPhotos = numPhotos
                
                if numPhotos < self.photos.count {
                    // TODO: delete some photos from CoreData
                    for k in 1...(self.photos.allObjects.count - numPhotos) {
                        self.sharedContext.deleteObject( self.photos.allObjects[k-1] as! NSManagedObject )
                    }
                    CoreDataStackManager.sharedInstance().saveContext()
                }
                
                if numPhotos == 0 {
                    completionHandler(isSuccess: true, errorString: nil)
                    return
                }

                // 2b. check # pages
                if self.numPages == 0 {
                    if let xNumPages = photosDict["pages"] as? Int {
                        // TODO: 
                        // Note: Flickr only returns upto 4000 photos --> 40 pages * 100 pics
                        let pgLimit = min(xNumPages, 40)
                        self.numPages = pgLimit
                    } else {
                        completionHandler(isSuccess: false, errorString: "No 'pages' found in results")
                    }
                }
                
                // 3. Parse the Photos array finally
                if let photosArray = photosDict["photo"] as? [[String:AnyObject]] {
                    var tmpPhotos = [Photo]()
                    var currentPhotos = self.photos.allObjects as! [Photo]
                    
                    // download pics - on the main queue
                    dispatch_async(dispatch_get_main_queue()) {
                        
                        // 3.a.
                        for index in 1...min(photosArray.count, self.MAX_NUM_PHOTOS) {
                        
                            let randomIndex         = Int(arc4random_uniform(UInt32(photosArray.count)))
                            let aPhotoDictionary    = photosArray[randomIndex] as [String:AnyObject]
                            
                            let aPhotoTitle         = aPhotoDictionary["title"] as! String
                            let imgUrlString        = aPhotoDictionary["url_m"] as! String
                            let aPhotoID            = aPhotoDictionary["id"]    as! String
                            let aPhotoSecret        = aPhotoDictionary["secret"] as! String
                            
                            let aPhoto: [String:AnyObject] = [
                                Photo.Keys.Title:       aPhotoTitle,
                                Photo.Keys.URLString:   imgUrlString,
                                Photo.Keys.Pin:         self,
                                Photo.Keys.LocalFile:   aPhotoID + "_" + aPhotoSecret   // localfilename
                            ]
                            
                            if self.photos.count >= index { // update existing photo
                                var existingPhoto = currentPhotos[index-1]
                                existingPhoto.updatePhoto(aPhoto, context: self.sharedContext)
                                tmpPhotos.append(existingPhoto)
                                
                            } else { // create new photo
                                let tmpPic = Photo(dictionary: aPhoto, context: self.sharedContext)
                                tmpPhotos.append(tmpPic)
                            }
                            
                        } // for
                        
                        for photo in tmpPhotos {
                            photo.downloadImage()
                        }
                        // 3.x. Now save Coredata
                        CoreDataStackManager.sharedInstance().saveContext()
                        
                        completionHandler(isSuccess: true, errorString: nil)
                    } // on the main Q
                    
                } else {
                    // println("[Pic: ## No photos found for this location")
                    completionHandler(isSuccess: false, errorString: "No photos found for location: \(self.locname!)")
                }
            }
            
        }  // fetchPhotosForPin closure
    } // func
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }


}

//
//  PhotosViewController.swift
//  VirtualTourist
//
//  Created by Atul Acharya on 8/5/15.
//  Copyright (c) 2015 Atul Acharya. All rights reserved.
//

import UIKit
import CoreData
import MapKit


class PhotosViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, NSFetchedResultsControllerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
  
    var receivedPin: Pin!
    
    var alert: UIAlertController?
    // var picActions: UIAlertController!
    
    // selected Photos to be deleted
    var selectedPhotosDict  = [NSIndexPath: Photo]()
    
    var imagesLoaded        = 0
    
    let cellReuseID         = "IDPhotoViewCell2"
    
    // dynamic label titles
    let ID_BTN_REMOVE       = "Removed Selected"
    let ID_BTN_NEW_COLLECT  = "   New Collection   "
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        newCollectionButton.setTitle(ID_BTN_NEW_COLLECT, forState: UIControlState.Normal)
        newCollectionButton.enabled = false     // init;  later we will enable as images load
        
        selectedPhotosDict = [NSIndexPath: Photo]()
        
        // setup map region in upper view
        setupMap()
        
        if receivedPin.photos.count == 0 {
            receivedPin.downloadPhotos({ (isSuccess, errorString) -> Void in
                if isSuccess {
                    println("Downloaded \(self.receivedPin.photos.count) pics for \(self.receivedPin.locname!)")
                } else {
                    if errorString != nil {
                        println("...ERROR newCollection for: \(self.receivedPin.locname!)")
                        Client.showAlert("Error", message: errorString!, onViewController: self)
                    }
                }
                
            })
        }
        
        // get the FRC
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch(nil)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        // self.navigationController?.navigationBar.
        self.navigationItem.title = "\(receivedPin.locname!)"
        
        self.navigationItem.backBarButtonItem?.title = "Back"
        
        self.collectionView.allowsMultipleSelection = true
        
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        selectedPhotosDict.removeAll(keepCapacity: false)
    }
    
    // sets mapview with Pin on the receivedPin
    func setupMap() {
        let pinCoord = CLLocationCoordinate2DMake(receivedPin.latitude, receivedPin.longitude)
        
        let theAnnotation = MKPointAnnotation()
        theAnnotation.coordinate = pinCoord
        
        self.mapView.addAnnotation(theAnnotation)
        
        // update
        self.mapView.centerCoordinate = pinCoord
        
        let miles = 30.0
        var scale = abs((cos(2 * M_PI * pinCoord.latitude / 360.0) ))
        var span  = MKCoordinateSpan(latitudeDelta: miles/69.0, longitudeDelta: miles/(scale*69.0))
        var region = MKCoordinateRegion(center: pinCoord, span: span)
        self.mapView.setRegion(region, animated: true)
        
        self.mapView.alpha = 0.9 // test
    }
    
    // MARK: - Core Data
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        fetchRequest.predicate       = NSPredicate(format: "pin == %@", self.receivedPin)
        
        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.sharedContext, sectionNameKeyPath: nil, cacheName: nil)
        
        return frc
        
        } ()
    
    // MARK: - Actions
    
    @IBAction func getNewCollection(sender: UIButton) {
        
        // Check if REMOVE operation; we come here if atleast 1 Photo is selected
        if sender.titleLabel?.text == ID_BTN_REMOVE {
            
            if selectedPhotosDict.count > 0 {
                for (theIndex, thePhoto) in selectedPhotosDict {
                    
                    // Delete selected Photo from CoreData, and Save Context
                    sharedContext.deleteObject(thePhoto)
                    CoreDataStackManager.sharedInstance().saveContext()
                    
                    // ... also remove from our list
                    selectedPhotosDict.removeValueForKey(theIndex)
                }
            }
            
            // restore New Collection Button
            if selectedPhotosDict.isEmpty {
                newCollectionButton.setTitle(ID_BTN_NEW_COLLECT, forState: UIControlState.Normal)
            }
            return
        }
        
        // ELSE it must be GetNewCollection...
        
        let MAX_DOWNLOAD_PHOTOS = Client.Constants.MAX_PHOTOS_WANTED.toInt()!
        
        // println("*** New Collection *** geting more \(MAX_DOWNLOAD_PHOTOS); current items:\(collectionView.numberOfItemsInSection(0))")
        
        if receivedPin.numPhotos?.integerValue < MAX_DOWNLOAD_PHOTOS {
            Client.showAlert("Error", message: "All pics for this pin downloaded!", onViewController: self)
        }
        
        // Reset
        imagesLoaded = 0
        newCollectionButton.enabled = false
        
        // reset all images...
        for index in 0...collectionView.numberOfItemsInSection(0)-1 {
            let ix = NSIndexPath(forRow: index, inSection: 0)!
            // println("[  ix section,row,item: \(ix.section), \(ix.row), \(ix.item) ]")
            var aCell = collectionView.cellForItemAtIndexPath(ix)! as! PhotoViewCell
            
            aCell.imageView?.image = nil
            aCell.activityIndicator?.startAnimating()
        }
        
        // insert missing photos??
        // println("MAX - # Existing: \(MAX_DOWNLOAD_PHOTOS - collectionView.numberOfItemsInSection(0))")
        
        if MAX_DOWNLOAD_PHOTOS > collectionView.numberOfItemsInSection(0) {
            for ix in 1...(MAX_DOWNLOAD_PHOTOS - collectionView.numberOfItemsInSection(0)) {
                let photoDict: [String:AnyObject] = [
                    Photo.Keys.Title:   "",
                    Photo.Keys.URLString: "temp",       // test
                    Photo.Keys.Pin: self.receivedPin
                ]
                Photo(dictionary: photoDict, context: sharedContext)
                CoreDataStackManager.sharedInstance().saveContext()
            }
        }
        
        println("... Now fetching more pics for: \(self.receivedPin.locname!)")
        // now get more photos
        receivedPin.downloadPhotos { (isSuccess, errorString) -> Void in
            if isSuccess {
                println("...obtained new collection for: \(self.receivedPin.locname!)")
            } else {
                if errorString != nil {
                    println("...ERROR getting newCollection for: \(self.receivedPin.locname!)")
                    Client.showAlert("Error", message: errorString!, onViewController: self)
                }
            }
            
        }
        
    }

    // MARK: - Fetched Results Controller Delegate
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {

    }
    
    // section change
    func controller(controller: NSFetchedResultsController,
        didChangeSection sectionInfo: NSFetchedResultsSectionInfo,
        atIndex sectionIndex: Int,
        forChangeType type: NSFetchedResultsChangeType) {
            dispatch_async(dispatch_get_main_queue()) {
                switch type {
                case .Insert:
                    self.collectionView.insertSections(NSIndexSet(index: sectionIndex))
                case .Delete:
                    self.collectionView.deleteSections(NSIndexSet(index: sectionIndex))
                default:
                    return
                }
            }
    }
    
    
    // object change
    func controller(controller: NSFetchedResultsController,
        didChangeObject anObject: AnyObject,
        atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType,
        newIndexPath: NSIndexPath?) {
            
            switch type {
            case .Insert:
                self.collectionView.insertItemsAtIndexPaths([newIndexPath!])
            case .Delete:
                // println("  _del \(indexPath!.section) \(indexPath!.row), \(indexPath!.item)")
                self.collectionView.deleteItemsAtIndexPaths([indexPath!])
            case .Update:
                // println("__Update item: at :\(indexPath!.row)")
                let cell  = self.collectionView.cellForItemAtIndexPath(indexPath!) as! PhotoViewCell
                let photo = controller.objectAtIndexPath(indexPath!) as! Photo
                self.configureCell(cell, withPhoto: photo)
            default:
                return
            }
            
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        self.collectionView.endEditing(true)
    }
    
    
    // helper to configure each cell in the grid
    func configureCell(cell: PhotoViewCell, withPhoto photo: Photo) {
        cell.imageView!.image = nil
        
        // update
        if photo.imgData != nil {
            cell.activityIndicator?.stopAnimating()     // automatically 'hides when stopped' (set in Storyboard)
            cell.imageView?.image = UIImage(data: photo.imgData!)
            cell.cellUrlString = photo.urlString
            updateNewCollectionButton()     // check if Button can be enabled yet
        } else {
            cell.activityIndicator?.startAnimating()
        }
    }
    
    // Helper to enable/disable NewCollection button - based on images loaded
    func updateNewCollectionButton() {
        imagesLoaded += 1
        if imagesLoaded == fetchedResultsController.sections![0].numberOfObjects {
            newCollectionButton.enabled = true
        }
    }
    
    
    // MARK: - Collection View Data Source
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return fetchedResultsController.sections!.count
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchedResultsController.sections![section].numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        
        // println("[  index section,row,item: \(indexPath.section), \(indexPath.row), \(indexPath.item) ]")
        
        let cell: PhotoViewCell = collectionView.dequeueReusableCellWithReuseIdentifier(cellReuseID, forIndexPath: indexPath) as! PhotoViewCell
        
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            if (photo.imgData == nil) {
                cell.activityIndicator?.startAnimating()    // show LOADING status to User
                photo.downloadPhoto()   // get a New Photo
                cell.cellUrlString = photo.urlString
            } else {
                cell.imageView?.image = UIImage(data: photo.imgData!)
                self.updateNewCollectionButton()     // check if NewCollection button can be enabled
                cell.cellUrlString = photo.urlString
            }
        })
        return cell
    }
    
    // MARK: - Collection View Delegate
    
    // if Photo selected, add it to our Dict for deletion, later
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        // Show selected Photo: turn the cell slightly grayish
        var selectedCell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoViewCell
        selectedCell.alpha = 0.3
        
        let thePhoto = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        // Save selected photo to our Dict...
        selectedPhotosDict[indexPath] = thePhoto
        // ...Change Button title to REMOVE
        if selectedPhotosDict.count > 0 {
            newCollectionButton.setTitle(ID_BTN_REMOVE, forState: UIControlState.Normal)
        }
        
        // showSelectedPhotos()
        
    }
    
    // if Photo De-selected, remove it from our Dict (i.e. not to be deleted)
    func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath) {
        
        let thePhoto = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        // Restore the cell's
        var selectedCell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoViewCell
        selectedCell.alpha = 1.0
        
        // remove De-selected Index,Photo from our Dict...
        if let removedIndex = selectedPhotosDict.removeValueForKey(indexPath) {
            // println("  removed index: \(indexPath.row)")
        }
        
        // ... change Button to NEW COLLECTION if no selected Photos
        if selectedPhotosDict.isEmpty {
            newCollectionButton.setTitle(ID_BTN_NEW_COLLECT, forState: UIControlState.Normal)
        }
        // showSelectedPhotos()

    }
    
    // debug
    func showSelectedPhotos() {
        if selectedPhotosDict.isEmpty {
            println("[ empty Dict]")
        }
        for (ix, photo) in selectedPhotosDict {
            println("[ Dict: \(ix.row), \(ix.item) -> \(photo.urlString) ]")
        }
    }
    
    
    
}

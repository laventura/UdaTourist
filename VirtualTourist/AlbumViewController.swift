//
//  AlbumViewController.swift
//  VirtualTourist
//
//  Created by Atul Acharya on 7/31/15.
//  Copyright (c) 2015 Atul Acharya. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class AlbumViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, NSFetchedResultsControllerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionButton: UIButton!
    
    var receivedPin: Pin!
    
    var alert: UIAlertController?
    var chosenIndex: NSIndexPath?
    var picActions: UIAlertController!
    
    let cellReuseID = "IDPhotoViewCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        self.navigationItem.title = receivedPin.locname
        self.navigationItem.hidesBackButton = false
        /// TESTING
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
        self.title = "Foo \(receivedPin.locname)"
        var refreshButton   = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Refresh, target: self, action: "getNewCollection:")

        self.navigationItem.rightBarButtonItems = [refreshButton]
        println("- - - - - - Nav item: \(self.navigationItem)")
    
        newCollectionButton.enabled = true
        
        // setup map region in upper view
        setupMap()
        // TESTING TESTINg
        //self.mapView.hidden = true
        //self.mapView.backgroundColor = UIColor.greenColor()
        // self.mapView.opaque = false
        
        if receivedPin.photos.count == 0 {
            receivedPin.downloadPhotos({ (isSuccess, errorString) -> Void in
                if isSuccess {
                    println("Downloaded \(self.receivedPin.photos.count) pics for \(self.receivedPin.locname)")
                } else {
                    if errorString != nil {
                        println("## Raise alert: Error downloading pics for \(self.receivedPin.locname)")
                        Client.showAlert("Error", message: errorString!, onViewController: self)
                    }
                }
                
            })
        }
        
        // get the FRC
        fetchedResultsController.delegate = self
        fetchedResultsController.performFetch(nil)
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
        
        self.mapView.alpha = 0.5 // test
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

    
    // MARK - Actions
    @IBAction func getNewCollection(sender: UIButton) {
        println("*** Called getNewCollection ***")
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: - Fetched Results Controller Delegate
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        
    }

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

    
    func controller(controller: NSFetchedResultsController,
        didChangeObject anObject: AnyObject,
        atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType,
        newIndexPath: NSIndexPath?) {
        
            switch type {
            case .Insert:
                // println("__Insert item")
                self.collectionView.insertItemsAtIndexPaths([newIndexPath!])
            case .Delete:
                // println("__Delete item")
                self.collectionView.deleteItemsAtIndexPaths([indexPath!])
            case .Update:
                // println("__Update item")
                let cell  = self.collectionView.cellForItemAtIndexPath(indexPath!) as! PhotoCollectionViewCell
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
    func configureCell(cell: PhotoCollectionViewCell, withPhoto photo: Photo) {
        cell.imageView!.image = nil
        
        // update
        if photo.imgData != nil {
            cell.activityIndicator?.stopAnimating()     // automatically 'hides when stopped' (set in Storyboard)
            //cell.activityIndicator?.hidden = true
            cell.imageView?.image = UIImage(data: photo.imgData!)
            // TODO: track NewCollectionButton func
        } else {
            cell.activityIndicator?.startAnimating()
            //cell.activityIndicator?.hidden = false
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


        let cell: PhotoCollectionViewCell = collectionView.dequeueReusableCellWithReuseIdentifier(cellReuseID, forIndexPath: indexPath) as! PhotoCollectionViewCell
        
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
            if (photo.imgData == nil) {
                //cell.activityIndicator?.hidden = false
                cell.activityIndicator?.startAnimating()    // show LOADING status to User
                photo.downloadPhoto()   // get a New Photo
            } else {
                //cell.activityIndicator?.hidden = true
                cell.imageView?.image = UIImage(data: photo.imgData!)
                // TODO: somethign with NewCollectionButton
            }
        })
        return cell
    }
    
    // MARK: - Collection View Delegate
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        chosenIndex = indexPath
        
        picActions = UIAlertController(title: "Delete", message: "Delete photo from collection?", preferredStyle: UIAlertControllerStyle.ActionSheet)
        picActions.addAction(
            UIAlertAction(title: "Delete", style: UIAlertActionStyle.Destructive, handler: deletePhotoHandler))
        picActions.addAction(
            UIAlertAction(title: "Cancel", style: UIAlertActionStyle.Cancel, handler: nil))
        
        self.presentViewController(picActions, animated: true, completion: nil)
        
    }
    
    // Delete selected Pic
    func deletePhotoHandler(sender: UIAlertAction!) -> Void {
        println(".... Deleting pic at... \(self.chosenIndex)")
        self.sharedContext.deleteObject(self.fetchedResultsController.objectAtIndexPath(chosenIndex!) as! NSManagedObject)
        CoreDataStackManager.sharedInstance().saveContext()
    }
    
    

}

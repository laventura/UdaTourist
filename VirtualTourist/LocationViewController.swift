//
//  LocationViewController.swift
//  VirtualTourist
//
//  Created by Atul Acharya on 7/31/15.
//  Copyright (c) 2015 Atul Acharya. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class LocationViewController: UIViewController, MKMapViewDelegate, NSFetchedResultsControllerDelegate {

    @IBOutlet weak var mapView: MKMapView!
    
    var alert:  UIAlertController?
    var selectedPin: PinAnnotation!
    
    let segueID = "segueToAlbum"
    
    let userDefaults = NSUserDefaults.standardUserDefaults()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self

        // gesture
        let longPress = UILongPressGestureRecognizer(target: self, action: Selector("handleLongPressToAddPin:"))
        longPress.minimumPressDuration = 1.1    // seconds
        mapView.addGestureRecognizer(longPress)
        
        // fetch results
        fetchedResultsController.performFetch(nil)
        fetchedResultsController.delegate   = self
        
        if let pins = fetchedResultsController.fetchedObjects {
            for aPin in pins {
                self.showPinOnMap(aPin as! Pin)
            }
        }
        
        //
        // set region - check previously stored state from User Defaults
        if userDefaults.doubleForKey(Keys.Latitude) != 0 {
            mapView.setRegion(MKCoordinateRegionMake(
                CLLocationCoordinate2DMake(userDefaults.doubleForKey(Keys.Latitude),
                                            userDefaults.doubleForKey(Keys.Longitude)),
                MKCoordinateSpanMake(userDefaults.doubleForKey(Keys.DeltaLatitude),
                                    userDefaults.doubleForKey(Keys.DeltaLongitude))),
                animated: true)
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        self.navigationController?.navigationBarHidden = false
        self.navigationItem.title = "Virtual Tourist"
        self.mapView.deselectAnnotation(selectedPin, animated: false)
    }
    
    override func viewWillDisappear(animated: Bool) {
        self.navigationController?.navigationBarHidden = false
    }

    
    // MARK: - Map 
    // show the newly formed pin; prefetch photos as needed
    func showPinOnMap(pin: Pin) {
        var newPinAnnotation = PinAnnotation(thePin: pin)
        
        // prefetch photos now, if none exist
        if pin.photos.count == 0 {
            pin.downloadPhotos({ (isSuccess, errorString) -> Void in
                if isSuccess {
                    // println("LocVC: got some pics...for \(pin.locname!)")
                    if pin.photos.count > 0 {
                        (self.mapView.viewForAnnotation(newPinAnnotation) as! MKPinAnnotationView).pinColor = .Purple
                    } else {
                        // What TODO
                        println("LocVC: Still no photos found for \(pin.locname!)")
                    }
                } else {
                    if errorString != nil {
                        Client.showAlert("Error", message: errorString!, onViewController: self)
                    }
                }
            })
        }
        
        // show on map
        mapView.addAnnotation(newPinAnnotation)
    }
    
    // MARK: Gesture
    func handleLongPressToAddPin(gestureRecognizer: UIGestureRecognizer) {
        if (gestureRecognizer.state != UIGestureRecognizerState.Began) {
            return
        }
        
        var coordinates = mapView.convertPoint(gestureRecognizer.locationInView(mapView), toCoordinateFromView: mapView)
        
        let newPinInfo: [String: AnyObject] = [
            Pin.Keys.Locname:   "",
            Pin.Keys.Latitude:  coordinates.latitude,
            Pin.Keys.Longitude: coordinates.longitude
        ]
        
        var newPin = Pin(dictionary: newPinInfo, context: sharedContext)
        sharedContext.save(nil)
    }
    


    // MARK: - Navigation

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let id = segue.identifier {
            if id == segueID {
                let destinationVC = segue.destinationViewController as! PhotosViewController
                destinationVC.receivedPin = selectedPin.pin
            }
        }
    }
    
    // MARK: Fetched Results Controller
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest                = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors    = [NSSortDescriptor(key: Pin.Keys.Locname, ascending: true)]
        
        let frc = NSFetchedResultsController(fetchRequest: fetchRequest,
                managedObjectContext: self.sharedContext,
                sectionNameKeyPath: nil,
                cacheName: nil)
        return frc
    } ()

    
    // add New Pin to Map
    func controller(controller: NSFetchedResultsController,
            didChangeObject anObject: AnyObject,
            atIndexPath indexPath: NSIndexPath?,
            forChangeType type: NSFetchedResultsChangeType,
            newIndexPath: NSIndexPath?) {
        
                var aPin = anObject as! Pin
        
                switch type {
                case .Insert:
                    showPinOnMap(aPin)
                default:
                    return
                }
    }
    
    
    
    // MARK: Map View Delegate
    
    func mapView(mapView: MKMapView!, regionDidChangeAnimated animated: Bool) {
        // Save map region for future use
        userDefaults.setDouble(mapView.centerCoordinate.latitude, forKey: Keys.Latitude)
        userDefaults.setDouble(mapView.centerCoordinate.longitude, forKey: Keys.Longitude)
        userDefaults.setDouble(mapView.region.span.latitudeDelta, forKey: Keys.DeltaLatitude)
        userDefaults.setDouble(mapView.region.span.longitudeDelta, forKey: Keys.DeltaLongitude)
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        if newState == MKAnnotationViewDragState.Ending {
            (view as! MKPinAnnotationView).pinColor = .Purple
            view.resignFirstResponder()
            (view.annotation as! PinAnnotation).pin.downloadPhotos({ (isSuccess, errorString) -> Void in
                if isSuccess {
                    var someAnnot = view.annotation as! PinAnnotation
                    if someAnnot.pin.photos.count > 0 {
                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            (self.mapView.viewForAnnotation(someAnnot) as! MKPinAnnotationView).pinColor = .Red
                        })
                    }
                } else {
                    if errorString != nil {
                        self.alert = UIAlertController(title: "Error", message: errorString, preferredStyle: UIAlertControllerStyle.Alert)
                        self.alert?.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (alertAction) -> Void in
                            self.alert?.dismissViewControllerAnimated(true, completion: nil)
                        }))
                        self.presentViewController(self.alert!, animated: true, completion: nil)
                    }
                }
            })
        }
    }
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if annotation is MKUserLocation {
            return nil
        }
        
        let reuseID = "IDLocationPin"
        
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseID) as? MKPinAnnotationView
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            pinView!.animatesDrop = true
            if (annotation as! PinAnnotation).pin.photos.count == 0 {
                pinView!.pinColor =  MKPinAnnotationColor.Green
            } else {
                pinView!.pinColor =  MKPinAnnotationColor.Red
            }
            
            // Disclosure Button
            var button = UIButton.buttonWithType(UIButtonType.DetailDisclosure) as! UIButton
            button.addTarget(self, action: "showPhotosAtPin:", forControlEvents: UIControlEvents.TouchUpInside)
            pinView!.rightCalloutAccessoryView = button
            pinView!.canShowCallout = true
            pinView!.draggable      = true
            
        } else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    func mapView(mapView: MKMapView!, didSelectAnnotationView view: MKAnnotationView!) {
        selectedPin = view.annotation as! PinAnnotation
    }
    
    func mapView(mapView: MKMapView!, annotationView view: MKAnnotationView!, calloutAccessoryControlTapped control: UIControl!) {
        
        if control == view.rightCalloutAccessoryView {
            println("Disclosure clicked: \(view.annotation.title!)")
        }
    }
    
    // show photos
    func showPhotosAtPin(sender: UIButton!) {
        var mkview = self.mapView.viewForAnnotation(selectedPin)
        
        // check if currently downloading...
        if selectedPin.pin.isDownloading {
            self.alert = UIAlertController(title: "Downloading Photos", message: "Getting pics from Flickr...", preferredStyle: UIAlertControllerStyle.Alert)
            self.alert?.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (alertAction) -> Void in
                self.alert?.dismissViewControllerAnimated(true, completion: nil)
            }))
            self.presentViewController(self.alert!, animated: true, completion: nil)
        } else if selectedPin.pin.photos.count == 0 {   // no images
            self.alert = UIAlertController(title: "No Pics!", message: "None found at this location.\nTry another location!", preferredStyle: UIAlertControllerStyle.Alert)
            self.alert?.addAction(UIAlertAction(title: "OK", style: .Default, handler: { (alertAction) -> Void in
                self.alert?.dismissViewControllerAnimated(true, completion: nil)
            }))
            self.presentViewController(self.alert!, animated: true, completion: nil)
        } else {    // images exist - segue to Album
            self.performSegueWithIdentifier(segueID, sender: nil)
        }
        
        mapView.deselectAnnotation(selectedPin, animated: false)
    
    }
   
    struct Keys {
    
        static let Latitude         = "latitude"
        static let Longitude        = "longitude"
        static let DeltaLatitude    = "delta_latitude"
        static let DeltaLongitude   = "delta_longitude"
    }
    

}

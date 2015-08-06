//
//  PinAnnotation.swift
//  VirtualTourist
//
//  Created by Atul Acharya on 7/31/15.
//  Copyright (c) 2015 Atul Acharya. All rights reserved.
//

import Foundation
import MapKit

class PinAnnotation: NSObject, MKAnnotation {
    
    var pin: Pin!
    
    init(thePin: Pin) {
        pin = thePin
        CLLocationCoordinate2DMake((thePin.latitude), (thePin.longitude))
    }
    
    // REQD: coordinate of the annotation
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake((pin.latitude), (pin.longitude))
    }
    
    // REQD: title showed on the annotation
    var title: String {
        return pin.locname!
    }
    
    var subtitle: String {
        return "\(pin.latitude),\(pin.longitude)"
    }
    
    // REQD
    func setCoordinate(newCoordinate: CLLocationCoordinate2D) {
        pin.latitude    = newCoordinate.latitude
        pin.longitude   = newCoordinate.longitude
        pin.updatePinName()
        CoreDataStackManager.sharedInstance().saveContext()
    }
}
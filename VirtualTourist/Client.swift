//
//  Client.swift
//  VirtualTourist
//
//  Created by Atul Acharya on 7/29/15.
//  Copyright (c) 2015 Atul Acharya. All rights reserved.
//

import Foundation
import CoreData
import MapKit

class Client:NSObject {
    
    var session: NSURLSession
    
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    // MARK: - Fetch Photos - low level
    func fetchPhotosForPin(pin: Pin, completionHandler: (result:AnyObject!, error:NSError?) -> Void ) -> NSURLSessionDataTask {
        
        var methodArgs = [
            "method":   Methods.Search,
            "api_key":  Constants.APIKey,
            "bbox":     createBoundingBox(CLLocationCoordinate2D(latitude:(pin.latitude as NSNumber).doubleValue, longitude:(pin.longitude as NSNumber).doubleValue)),
            "extras":   Constants.Extras,
            "format":   Constants.DataFormat,
            "nojsoncallback": Constants.NoJSONCallbank
        ]
        
        // choose a random page for Flickr
        let randomPage = Int(arc4random_uniform(UInt32( pin.numPages != nil ? pin.numPages!.intValue : 40 )))
        methodArgs["page"] = "\(randomPage)"
        
        let urlString = Constants.BaseURL + Client.escapedParameters(methodArgs)
        let url     = NSURL(string: urlString)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { data, response, downloadError  in
            if let error = downloadError {
                println(" Client: Couldn't download photos:\(error)")
                completionHandler(result: nil, error: error)
            } else {
                var jsonError: NSError? = nil
                let jsonResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &jsonError) as! NSDictionary
                
                if jsonError == nil {
                    completionHandler(result: jsonResult, error: nil)   // everything OK
                } else {
                    completionHandler(result: nil, error: jsonError)    // json parsing error
                }
            }
        }
        
        task.resume()
        
        return task
    }
    
    
    // MARK: - Shared Instance
    
    class func sharedInstance() -> Client {
        struct Singleton {
            static var sharedInstance = Client()
        }
        
        return Singleton.sharedInstance
    }
    
    // MARK: - Helper funcs
    
    func createBoundingBox(coordinates: CLLocationCoordinate2D) -> String {
        let latitude = coordinates.latitude
        let longitude = coordinates.longitude
        
        /* Fix added to ensure box is bounded by minimum and maximums */
        let bottom_left_lon = max(longitude - Constants.BOUNDING_BOX_HALF_WIDTH, Constants.LON_MIN)
        let bottom_left_lat = max(latitude - Constants.BOUNDING_BOX_HALF_HEIGHT, Constants.LAT_MIN)
        let top_right_lon = min(longitude + Constants.BOUNDING_BOX_HALF_HEIGHT, Constants.LON_MAX)
        let top_right_lat = min(latitude + Constants.BOUNDING_BOX_HALF_HEIGHT, Constants.LAT_MAX)
        
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }
    
    /* Helper function: Given a dictionary of parameters, convert to a string for a url */
    class func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* FIX: Replace spaces with '+' */
            let replaceSpaceValue = stringValue.stringByReplacingOccurrencesOfString(" ", withString: "+", options: NSStringCompareOptions.LiteralSearch, range: nil)
            
            /* Append it */
            urlVars += [key + "=" + "\(replaceSpaceValue)"]
        }
        
        return (!urlVars.isEmpty ? "?" : "") + join("&", urlVars)
    }
    
    /* Helper: Given raw JSON, return a usable Foundation object */
    class func parseJSONWithCompletionHandler(data: NSData, completionHandler: (result: AnyObject!, error: NSError?) -> Void) {
        
        var parsingError: NSError? = nil
        
        let parsedResult: AnyObject? = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments, error: &parsingError)
        
        if parsingError != nil {
            completionHandler(result: nil, error: parsingError)
        } else {
            completionHandler(result: parsedResult, error: nil)
        }
    }
    
    //Displays an alert with the OK button and a message
    class func showAlert(title: String, message: String, onViewController controller: UIViewController){
        var alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
        controller.presentViewController(alert, animated: true, completion: nil)
    }

}

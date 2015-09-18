//
//  FlickrClient.swift
//  Virtual Tourist
//
//  Created by Ioannis Tornazakis on 31/5/15.
//  Copyright (c) 2015 Ioannis Tornazakis. All rights reserved.
//

import Foundation
import MapKit
import CoreData

class FlickrClient: NSObject {
    
    // MARK: - Properties
    
    var session: NSURLSession
    
    // MARK: - Session
    
    override init() {
        self.session = NSURLSession.sharedSession()
        super.init()
    }

    // MARK: - Shared Instance
    
    class func sharedInstance() -> FlickrClient {
        
        struct Singleton {
            static var sharedInstance = FlickrClient()
        }
        
        return Singleton.sharedInstance
    }
    
    // MARK: - Shared Image Cache
    
    struct Cache {
        static let imageCache = ImageCache()
    }

    // MARK: - Core Data Context
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    // MARK: - Methods
    
    /**
     *  Set the method arguments
     */
    func getMethodArguments(pin: Pin) -> [String: AnyObject] {
        
        // Set the method arguments
        let methodArguments = [
            "method": FlickrClient.Constants.METHOD_NAME,
            "api_key": FlickrClient.Constants.API_KEY,
            "bbox": self.createBoundingBoxString(pin),
            "safe_search": FlickrClient.Constants.SAFE_SEARCH,
            "extras": FlickrClient.Constants.EXTRAS,
            "format": FlickrClient.Constants.DATA_FORMAT,
            "nojsoncallback": FlickrClient.Constants.NO_JSON_CALLBACK,
            "per_page": FlickrClient.Constants.PER_PAGE
        ]
    
        return methodArguments
    }
    
    /**
    *  Get the urls from the current pin page and save them to CoreData
    */
    func getPhotosURLs(pin: Pin, completionHandler: (success: Bool, errorString: String?) -> Void) {
        
            println("getPhotosURLs")
        
            // Get the method arguments adjusted for the pin
            let methodArguments = self.getMethodArguments(pin)
            
            // Append the page to the method's arguments
            var withPageDictionary = methodArguments
            withPageDictionary["page"] = pin.currentPage
            
            // Create the session and the request
            let session = NSURLSession.sharedSession()
            let urlString = FlickrClient.Constants.BASE_URL + escapedParameters(withPageDictionary)
            let url = NSURL(string: urlString)!
            let request = NSURLRequest(URL: url)
            
            let task = session.dataTaskWithRequest(request) { data, response, downloadError in
                
                if let error = downloadError {
                    
                    // Download failed
                    completionHandler(success: false, errorString: "Could not complete the request)")
                
                } else {
                
                    // Download succeeded
                    var parsingError: NSError? = nil
                    let parsedResult = NSJSONSerialization.JSONObjectWithData(
                            data,
                            options: NSJSONReadingOptions.AllowFragments,
                            error: &parsingError
                        ) as! NSDictionary
                    
                    // Parse the page data
                    if let photosDictionary = parsedResult.valueForKey("photos") as? [String:AnyObject] {
                        
                        // Get the available pages for the pin and save it into core data
                        pin.totalPages = photosDictionary["pages"] as! Int
                        
                        dispatch_async(dispatch_get_main_queue()) {
                            CoreDataStackManager.sharedInstance().saveContext()
                        }
                        
                        // Get the total number of photos from the current page
                        var totalPhotos = 0
                        if let numberOfPhotos = photosDictionary["total"] as? String {
                            totalPhotos = (numberOfPhotos as NSString).integerValue
                        }
                        
                        // If there are photos, save their urls to the core data
                        if totalPhotos > 0 {
                            
                            if let photosArray = photosDictionary["photo"] as? [[String:AnyObject]] {
                                
                                for photo in photosArray {
                                    
                                    if let url = photo["url_m"] as? String{
                                        
                                        // Set up the dictionary to create the photo
                                        let dictionary: [String : AnyObject] = [
                                            Photo.Keys.PosterPath : photo["url_m"] as! String,
                                            Photo.Keys.Id : photo["id"] as! String,
                                            Photo.Keys.Downloaded : false
                                        ]
                                        
                                        // Initialize the photo
                                        let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                                        
                                        // Set the pin that the photo is asociated with
                                        photo.pin = pin
                                        
                                        // Save the photo into core data as a pre-fetch activity
                                        dispatch_async(dispatch_get_main_queue()) {
                                            CoreDataStackManager.sharedInstance().saveContext()
                                        }
                                    }
                                }
                                
                                // All succeded!!!
                                completionHandler(success: true, errorString: nil)
                                
                            } else {
                                completionHandler(success: false, errorString: "Cant find key 'photo' in \(photosDictionary)")
                                return
                            }
                        } else {
                            completionHandler(success: false, errorString: "No image found")
                            return
                        }
                    } else {
                        completionHandler(success: false, errorString: "Cant find key 'photos' in \(parsedResult)")
                        return
                    }
                }
            }
            
            task.resume()
    }

    /**
     *  Use task to download image data so it can be cancelled 
     *  from the collection view cell
     */
    func taskForImage(filePath: String, completionHandler :(imageData:NSData?, error:NSError?) -> Void)-> NSURLSessionTask {
        
        let url = NSURL(string: filePath)!
        let request = NSURLRequest(URL: url)
        
        let task = session.dataTaskWithRequest(request) { data, response, downloadError in
            
            if let error = downloadError {
                completionHandler(imageData: nil, error: error)
            } else {
                completionHandler(imageData: data, error: nil)
            }
        }
        
        task.resume()
        return task
    }
    
    // MARK: - Helpers
    
    /**
    *  Locate a pin given its map coordinates
    */
    func locatePinFromAnnotation(annotation: MKAnnotation, storedPins: [Pin]!) -> Pin? {
        
        // Get the coordinates of the pin from the map annotation
        let pinArray = storedPins.filter {
            $0.latitude == annotation.coordinate.latitude   &&
                $0.longitude == annotation.coordinate.longitude
        }
        
        // Return the first pin that matches the above condition
        return pinArray.first
    }
    
    /**
     * Create the box on the map from which the images will be pulled
     */
    func createBoundingBoxString(pin: Pin) -> String {
        
        // Convert coordinates to Double values to use with max and min
        let latitude = pin.latitude as Double
        let longitude = pin.longitude as Double
        
        // Fix added to ensure box is bounded by minimum and maximums
        let bottomLeftLong = max(
            longitude - FlickrClient.Constants.BOUNDING_BOX_HALF_WIDTH,
            FlickrClient.Constants.LONG_MIN
        )
        
        let bottomLeftLat = max(
            latitude - FlickrClient.Constants.BOUNDING_BOX_HALF_HEIGHT,
            FlickrClient.Constants.LAT_MIN
        )
        
        let topRightLong = min(
            longitude + FlickrClient.Constants.BOUNDING_BOX_HALF_WIDTH,
            FlickrClient.Constants.LONG_MAX
        )
        
        let topRightLat = min(
            latitude + FlickrClient.Constants.BOUNDING_BOX_HALF_HEIGHT,
            FlickrClient.Constants.LAT_MAX
        )
        
        // Return the bounding box as String
        return "\(bottomLeftLong),\(bottomLeftLat),\(topRightLong),\(topRightLat)"
    }
    
    /**
     * Given a dictionary of parameters, convert to a string for a url
     */
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            //Make sure that it is a string value
            let stringValue = "\(value)"
            
            // Escape it
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            // Append it
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        
        return (!urlVars.isEmpty ? "?" : "") + join("&", urlVars)
    }

}

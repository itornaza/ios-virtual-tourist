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
    
    var session: URLSession
    
    // MARK: - Session added to the default constructor
    
    override init() {
        self.session = URLSession.shared
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
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // MARK: - Methods
    
    /// Set the method arguments
    func getMethodArguments(_ pin: Pin) -> [String: AnyObject] {
        
        // Set the method arguments
        let methodArguments = [
            FlickrClient.Constants.METHOD_STR           : FlickrClient.Constants.METHOD_NAME,
            FlickrClient.Constants.API_KEY_STR          : FlickrClient.Constants.API_KEY,
            FlickrClient.Constants.BBOX_STR             : self.createBoundingBoxString(pin),
            FlickrClient.Constants.SAFE_SEARCH_STR      : FlickrClient.Constants.SAFE_SEARCH,
            FlickrClient.Constants.EXTRAS_STR           : FlickrClient.Constants.EXTRAS,
            FlickrClient.Constants.FORMAT_STR           : FlickrClient.Constants.DATA_FORMAT,
            FlickrClient.Constants.NOJSONCALLBACK_STR   : FlickrClient.Constants.NO_JSON_CALLBACK,
            FlickrClient.Constants.PER_PAGE_STR         : FlickrClient.Constants.PER_PAGE,
            FlickrClient.Constants.ACCURACY_STR         : FlickrClient.Constants.ACCURACY
        ]
    
        return methodArguments as [String : AnyObject]
    }
    
    /// Get the urls from the current pin page and save them to CoreData
    func getPhotosURLs(_ pin: Pin, completionHandler: @escaping (_ success: Bool, _ errorString: String?) -> Void) {
        
            // Get the method arguments adjusted for the pin
            let methodArguments = self.getMethodArguments(pin)
            
            // Append the page to the method's arguments
            var withPageDictionary = methodArguments
            withPageDictionary["page"] = pin.currentPage as AnyObject?
            
            // Create the session and the request
            let session = URLSession.shared
            let urlString = FlickrClient.Constants.BASE_URL + escapedParameters(withPageDictionary)
            let url = URL(string: urlString)!
            let request = URLRequest(url: url)
            
            let task = session.dataTask(with: request, completionHandler: { data, response, downloadError in
                
                if let _ = downloadError {
                    
                    // Download failed
                    completionHandler(false, "Could not complete the request)")
                
                } else {
                
                    // Download succeeded
                    let parsedResult = (try! JSONSerialization.jsonObject(
                            with: data!,
                            options: JSONSerialization.ReadingOptions.allowFragments)) as! NSDictionary
                    
                    // Parse the page data
                    if let photosDictionary = parsedResult.value(forKey: "photos") as? [String:AnyObject] {
                        
                        // Get the available pages for the pin and save it into core data
                        pin.totalPages = photosDictionary["pages"] as! Int
                        DispatchQueue.main.async {
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
                                    
                                    if let _ = photo["url_m"] as? String {
                                        
                                        // Set up the dictionary to create the photo
                                        let dictionary: [String : AnyObject] = [
                                            Photo.Keys.PosterPath : photo["url_m"] as! String as AnyObject,
                                            Photo.Keys.Id : photo["id"] as! String as AnyObject,
                                            Photo.Keys.Downloaded : false as AnyObject
                                        ]
                                        
                                        // Initialize the photo
                                        let photo = Photo(dictionary: dictionary, context: self.sharedContext)
                                        
                                        // Set the pin that the photo is asociated with
                                        photo.pin = pin
                                        
                                        // Save the photo into core data as a pre-fetch activity
                                        DispatchQueue.main.async {
                                            CoreDataStackManager.sharedInstance().saveContext()
                                        }   
                                    }
                                }
                                
                                // Request succeded with images
                                completionHandler(true, nil)
                                
                            } else {
                                
                                // Request failed
                                completionHandler(false, "Cant find key 'photo' in \(photosDictionary)")
                                return
                            }
                        } else {
                            
                            // Request succeded with no images
                            completionHandler(true, "No image found")
                            return
                        }
                    } else {
                        
                        // Request failed
                        completionHandler(false, "Cant find key 'photos' in \(parsedResult)")
                        return
                    }
                }
            }) 
            
            task.resume()
    }

    /// Use task to download image data so it can be cancelled from the collection view cell
    func taskForImage(_ filePath: String, completionHandler :@escaping (_ imageData:Data?, _ error:NSError?) -> Void)-> URLSessionTask {
        let url = URL(string: filePath)!
        let request = URLRequest(url: url)
        let task = session.dataTask(with: request, completionHandler: { data, response, downloadError in
            if let error = downloadError {
                completionHandler(nil, error as NSError?)
            } else {
                completionHandler(data, nil)
            }
        }) 
        task.resume()
        return task
    }
    
    // MARK: - Helpers
    
    /// Create the box on the map from which the images will be pulled
    func createBoundingBoxString(_ pin: Pin) -> String {
        
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
    
    /// Given a dictionary of parameters, convert to a string for a url
    func escapedParameters(_ parameters: [String : AnyObject]) -> String {
        var urlVars = [String]()
        for (key, value) in parameters {
            
            //Make sure that it is a string value
            let stringValue = "\(value)"
            
            // Escape it
            let escapedValue = stringValue.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)
            
            // Append it
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joined(separator: "&")
    }

}

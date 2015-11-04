//
//  TravelLocationsViewController.swift
//  Virtual Tourist
//
//  Created by Ioannis Tornazakis on 27/5/15.
//  Copyright (c) 2015 Ioannis Tornazakis. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class TravelLocationsViewController: UIViewController,
                                     MKMapViewDelegate,
                                     UIGestureRecognizerDelegate,
                                     NSFetchedResultsControllerDelegate {

    // MARK: - Properties
    
    // Constants
    
    let LONG_TAP_DURATION: CFTimeInterval = 0.65
    
    // Core Data properties
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: Pin.Keys.Longitude, ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        
        }()
    
    /**
    *  A convenient property for the map persistence
    */
    var filePath : String {
        let manager = NSFileManager.defaultManager()
        let url: NSURL = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }
    
    // MARK: - Outlets
    
    @IBOutlet weak var mapView: MKMapView!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the Core Data delegate
        self.fetchedResultsController.delegate = self
        
        // Show the existing pins on the map
        self.displayStoredPins()
        
        // Set the Map delegate
        self.mapView.delegate = self
        
        // Preserve the last map state that the user selected
        restoreMapRegion(false)
        
        // Configure tap recognizer
        self.configureLongTap(self.LONG_TAP_DURATION)
        
    }
    
    // MARK: - MKMapViewDelegate
    
    /**
     *  didSelectAnnotationView
     *
     *  When the user taps on a dropped pin, we transit to the PhotoAlbumViewController
     *  and notify the controller about the selected pin
     */
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        
        // Set the next view controller
        let nextVC = storyboard!.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as!
        PhotoAlbumViewController
        
        // Locate the pin object from map the annotation and
        // assign the pin to the destination view controller
        let storedPins = fetchedResultsController.fetchedObjects as! [Pin]
        
        // Assign the selected pin to the next controller for handling
        nextVC.pin = self.locatePinFromAnnotation(view.annotation!, storedPins: storedPins)
        
        // Segue to the next view controller
        self.presentViewController(nextVC, animated: false, completion: nil)
    }
    
    /**
     *  Get notified when the map region is changed
     */
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }
    
    // MARK: - Gestures
    
    func configureLongTap(duration: CFTimeInterval) {
        let longTap = UILongPressGestureRecognizer(target: self, action: "handleLongTap:")
        longTap.minimumPressDuration = duration
        mapView.addGestureRecognizer(longTap)
    }
    
    /**
     * Drops a pin to the map at the tapped location
     */
    func handleLongTap(recognizer: UIGestureRecognizer) {
        
        if (recognizer.state == UIGestureRecognizerState.Ended) {
            
            // Avoid to throw a second pin while doing the gesture
            self.mapView.removeGestureRecognizer(recognizer)
            
        } else {
        
            // Get the tap location from the screen
            let tapLocation = recognizer.locationInView(self.mapView)
            
            // Get the map coordinates from the tap location
            let coordinates: CLLocationCoordinate2D = self.mapView.convertPoint(
                tapLocation,
                toCoordinateFromView: self.mapView
            )
            
            // Create the pin at the tap location
            self.createAnnotation(coordinates)
            
            // Add Pin to Core Data
            self.addPinToStack(coordinates)
        }
        
        // Recursively reconfigure the long tap for next use
        self.configureLongTap(self.LONG_TAP_DURATION)
    }
    
    // MARK: - Core Data Helpers

    /**
     *  Add the dropped pin to Core Data on the main thread
     */
    func addPinToStack(coordinates: CLLocationCoordinate2D) {
        
        // Initialize the dictionary
        let dictionary: [String : AnyObject] = [
            Pin.Keys.Latitude   : coordinates.latitude,
            Pin.Keys.Longitude  : coordinates.longitude,
            Pin.Keys.CurrentPage: 1,
            Pin.Keys.TotalPages : 1
        ]
        
        // Create the pin using the dictionary
        _ = Pin(dictionary: dictionary, context: sharedContext)
        
        // Add pin to Core Data, on the main thread
        dispatch_async(dispatch_get_main_queue()) {
            CoreDataStackManager.sharedInstance().saveContext()
            
            do {
                // Fetch from core data to include the new pin
                try self.fetchedResultsController.performFetch()
            } catch _ {
            }
        }
    }
    
    // MARK: - MapKit Helpers
    
    /**
    *  Displays all the stored pins on the map
    */
    func displayStoredPins() {
        
        do {
            // Fetch pins from core data
            try self.fetchedResultsController.performFetch()
        } catch _ {
        }
        
        // Get the pins from the Core Data
        let storedPins = fetchedResultsController.fetchedObjects as! [Pin]
        
        // Display a pin for each stored location
        for pin in storedPins {
            let coordinates = CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)
            self.createAnnotation(coordinates)
        }
    }
    
    /**
     *  Drop a pin given it's coordinates
     */
    func createAnnotation(coordinates: CLLocationCoordinate2D) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinates
        self.mapView.addAnnotation(annotation)
    }
    
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
     *  Save the last map center and span that the user selected
     */
    func saveMapRegion() {
        
        // Place the "center" and "span" of the map into a dictionary
        // The "span" is the width and height of the map in degrees.
        // It represents the zoom level of the map.
        
        let dictionary = [
            "latitude"      : mapView.region.center.latitude,
            "longitude"     : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta": mapView.region.span.longitudeDelta
        ]
        
        // Archive the dictionary into the filePath
        NSKeyedArchiver.archiveRootObject(dictionary, toFile: filePath)
    }
    
    /**
     *  Restore the last map center and span that the user selected
     */
    func restoreMapRegion(animated: Bool) {
        
        // if we can unarchive a dictionary, we will use it to set the map back to its
        // previous center and span
        if let regionDictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String : AnyObject] {
            
            let longitude = regionDictionary["longitude"] as! CLLocationDegrees
            let latitude = regionDictionary["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            let longitudeDelta = regionDictionary["latitudeDelta"] as! CLLocationDegrees
            let latitudeDelta = regionDictionary["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            
            let savedRegion = MKCoordinateRegion(center: center, span: span)
            
            mapView.setRegion(savedRegion, animated: animated)
        }
    }
}

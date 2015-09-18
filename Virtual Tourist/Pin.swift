//
//  Pin.swift
//  Virtual Tourist
//
//  Created by Ioannis Tornazakis on 31/5/15.
//  Copyright (c) 2015 Ioannis Tornazakis. All rights reserved.
//

import Foundation
import MapKit
import CoreData

// Make Pin available to Objective-C code
@objc(Pin)

class Pin: NSManagedObject {
    
    // MARK: - Properties
    
    struct Keys {
        static let Latitude = "latitude"
        static let Longitude = "longitude"
        static let CurrentPage = "current_page"
        static let TotalPages = "flickr_pages"
        static let Photos = "photos"
    }
    
    // MARK: - Properties converted to Core Data Attributes
    
    @NSManaged var latitude: Double // Objective-C does not support CLLocationDegrees
    @NSManaged var longitude: Double
    @NSManaged var currentPage: Int // Keep track of the page that photos are loaded from
    @NSManaged var totalPages: Int  // Know the pages that are available to get photos from
    @NSManaged var photos: [Photo]
    
    // MARK: - Constructors
    
    /**
     *  Standard Core Data init method
     */
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    /**
     *  The two argument init method
     */
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        // Get the entity from the Virtual_Tourist.xcdatamodeld
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        
        // Insert the new Pin into the Core Data Stack
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        // Initialize the Pin's properties from a dictionary
        latitude = (dictionary[Keys.Latitude] as? CLLocationDegrees)!
        longitude = (dictionary[Keys.Longitude] as? CLLocationDegrees)!
        currentPage = (dictionary[Keys.CurrentPage] as? Int)!
        totalPages = (dictionary[Keys.TotalPages] as? Int)!
    }
}

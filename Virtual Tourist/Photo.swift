//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Ioannis Tornazakis on 31/5/15.
//  Copyright (c) 2015 Ioannis Tornazakis. All rights reserved.
//

import Foundation
import UIKit
import CoreData

// Make Photo available to Objective-C code
@objc(Photo)

class Photo: NSManagedObject {
    
    // MARK: - Properties
    
    struct Keys {
        static let Id           = "id"
        static let PosterPath   = "poster_path"
        static let Downloaded   = "downloaded"
    }
    
    // MARK: - Properties converted to Core Data Attributes
    
    @NSManaged var id: String
    @NSManaged var posterPath: String
    @NSManaged var downloaded: Bool
    @NSManaged var pin: Pin
    
    // MARK: - Computed Property
    
    var posterImage: UIImage? {
        get {
            return FlickrClient.Cache.imageCache.imageWithIdentifier(id)
        }
        set {
            FlickrClient.Cache.imageCache.storeImage(newValue, withIdentifier: id)
        }
    }
    
    // MARK: - Constructors
    
    /// Standard Core Data init method
    override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
    }
    
    /// The two argument init method
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {

        // Get the entity from the Virtual_Tourist.xcdatamodeld
        let entity = NSEntityDescription.entity(forEntityName: "Photo", in: context)!
        
        // Insert the new Photo into the Core Data Stack
        super.init(entity: entity, insertInto: context)
        
        // Initialize the Photo's properties from a dictionary
        id = dictionary[Keys.Id] as! String
        posterPath = dictionary[Keys.PosterPath] as! String
        downloaded = dictionary[Keys.Downloaded] as! Bool
    }
    
}

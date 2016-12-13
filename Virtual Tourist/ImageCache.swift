//
//  ImageCache.swift
//  Virtual Tourist
//
//  Created by Ioannis Tornazakis on 27/8/15.
//  Copyright (c) 2015 Ioannis Tornazakis. All rights reserved.
//

import UIKit

class ImageCache {
    
    // MARK: - Properties
    
    fileprivate var inMemoryCache = NSCache()
    
    // MARK: - Retreiving images
    
    func imageWithIdentifier(_ identifier:String?) -> UIImage? {
        
        // If the identifier is nil, or empty, return nil
        if identifier == nil || identifier! == "" {
            return nil
        }
        
        let path = pathForIdentifier(identifier!)
        
        // First try the memory cache
        if let image = inMemoryCache.object(forKey: path) as? UIImage {
            return image
        }
        
        // Next Try the hard drive
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
            _ = UIImage(data: data)
            return UIImage(data: data)
        }
        
        // Otherwise return nil
        return nil
    }
    
    // MARK: - Saving images
  
    func storeImage(_ image:UIImage?, withIdentifier identifier:String) {
        
        let path = pathForIdentifier(identifier)
        
        // If the image is nil, remove images from the cache
        if image == nil {
            inMemoryCache.removeObject(forKey: path)
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch _ {
            }
            return
        }
        
        // Otherwise, keep the image in memory
        inMemoryCache.setObject(image!, forKey: path)
        
        // And in the Documents directory
        let data = UIImagePNGRepresentation(image!)
        try? data!.write(to: URL(fileURLWithPath: path), options: [.atomic])
        
    }
    
    // MARK: - Helper
    
    func pathForIdentifier(_ identifier: String) -> String {
        let documentsDirectoryURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fullURL = documentsDirectoryURL.appendingPathComponent(identifier)
        return fullURL.path
    }
}

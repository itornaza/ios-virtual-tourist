//
//  FlickrConstants.swift
//  Virtual Tourist
//
//  Created by Ioannis Tornazakis on 31/5/15.
//  Copyright (c) 2015 Ioannis Tornazakis. All rights reserved.
//

import Foundation

extension FlickrClient {
    
    // MARK: - Constants
    
    struct Constants {
        
        // Argument Names
        static let METHOD_STR           = "method"
        static let API_KEY_STR          = "api_key"
        static let BBOX_STR             = "bbox"
        static let SAFE_SEARCH_STR      = "safe_search"
        static let EXTRAS_STR           = "extras"
        static let FORMAT_STR           = "format"
        static let NOJSONCALLBACK_STR   = "nojsoncallback"
        static let PER_PAGE_STR         = "per_page"
        static let ACCURACY_STR         = "accuracy"
        
        // Parameters
        static let BASE_URL             = "https://api.flickr.com/services/rest/"
        static let METHOD_NAME          = "flickr.photos.search"
        static let API_KEY              = "73fb59ee36298b83066340c2af3adf78"
        static let EXTRAS               = "url_m"
        static let SAFE_SEARCH          = "1"
        static let DATA_FORMAT          = "json"
        static let NO_JSON_CALLBACK     = "1"
        static let ACCURACY             = "6"
        
        // Support 3 cols by 7 rows on the collection view
        static let PER_PAGE = "21"
        
        // Area boundaries to download images from
        static let BOUNDING_BOX_HALF_WIDTH  = 0.1
        static let BOUNDING_BOX_HALF_HEIGHT = 0.1
        static let LAT_MIN  = -90.0
        static let LAT_MAX  = 90.0
        static let LONG_MIN = -180.0
        static let LONG_MAX = 180.0
    }
}
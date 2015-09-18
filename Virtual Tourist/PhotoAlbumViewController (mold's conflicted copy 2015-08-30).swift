//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//
//  Created by Ioannis Tornazakis on 27/5/15.
//  Copyright (c) 2015 Ioannis Tornazakis. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController,
                                MKMapViewDelegate,
                                UICollectionViewDataSource,
                                UICollectionViewDelegate,
                                NSFetchedResultsControllerDelegate {
    
    // MARK: - Properties
    
    var pin: Pin!   // Initialized during the segue from the TravelLocationsViewController
    
    // Constants
    let COLS_PER_ROW: CGFloat = 3.0
    
    // Counters
    var totalImages: Int = 0 // Initializes the collection view cells
    var countDown: Int! // Controls the state of the new collection button
    var pageNumber: Int! // Holds the random page number from Flickr
    
    // Core Data
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext!
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        println("fetchedResultsController")
        
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        
        fetchRequest.sortDescriptors = []
        
        // Fetch only the photos for the selected pin
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.pin)
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        
        }()
    
    // MARK: - Outlets
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionBarButton: UIBarButtonItem!
    @IBOutlet weak var noImageLabel: UILabel!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        println("viewDidLoad")
        
        // Set the delegates
        self.collectionView.delegate = self
        self.fetchedResultsController.delegate = self
        
        // Start the fetch
        self.fetchedResultsController.performFetch(nil)

        // Configure the UI
        self.configureUI()
        self.newCollectionBarButton.enabled = false
        
        // Show the selected pin on the top map
        self.showPinOnMap(self.pin.latitude, longitude: self.pin.longitude)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        println("viewWillAppear")
        
        if pin.photos.isEmpty {
            
            // Get images info from Flicker (pre-fetch)
            FlickrClient.sharedInstance().getPhotosURLs(pin) { success, errorString in
                
                if errorString != nil {
                    // TODO: Alert "There are no images to display"
                }
            }
         }
    }
    
    /**
     *  Configure the collection view layout
     */
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        println("viewDidLayoutSubviews")
        
        let layout : UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let width = floor(self.collectionView.frame.size.width / self.COLS_PER_ROW)
        layout.itemSize = CGSize(width: width, height: width)
        collectionView.collectionViewLayout = layout
    }
    
    // MARK: - Actions
    
    @IBAction func backButtonTouch(sender: AnyObject) {
        
        println("backButtonTouch")
        
        // Show the Travel locations view controller
        dispatch_async(dispatch_get_main_queue(), {
            
            // Grab storyboard
            var storyboard = UIStoryboard (name: "Main", bundle: nil)
            
            // Get the destination controller from the storyboard id
            var nextVC = storyboard.instantiateViewControllerWithIdentifier("TravelLocationsViewController")
                as! UIViewController
            
            // Go to the destination controller
            self.presentViewController(nextVC, animated: false, completion: nil)
        })
    }
    
    @IBAction func newCollectionButtonTouchUp(sender: AnyObject) {
        
        println("newCollectionButtonTouchUp")
        
        self.newCollectionBarButton.enabled = false
        
        // Remove the old collection
        for photo in fetchedResultsController.fetchedObjects as! [Photo] {
            sharedContext.deleteObject(photo)
        }
        
        // Update the pin's current page
        self.updateCurrentPage()
        
        // Get the new collection data
        FlickrClient.sharedInstance().getPhotosURLs(pin) { success, errorString in
            if errorString != nil {
                // TODO: Display the error!
            } else {
                // Save the new collection in core data
                dispatch_async(dispatch_get_main_queue()) {
                    CoreDataStackManager.sharedInstance().saveContext()
                    self.newCollectionBarButton.enabled = true
                }
            }
        }
    }
    
    // MARK: - Collection View
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        
        println("numberOfSectionsInCollectionView")
        
        return self.fetchedResultsController.sections?.count ?? 0
    }

    /**
     *  Number of images in section
     */
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        println("numberOfItemsInSection")
        
        let sectionInfo = self.fetchedResultsController.sections![section] as! NSFetchedResultsSectionInfo
        totalImages = sectionInfo.numberOfObjects

        return sectionInfo.numberOfObjects
    }
    
    /**
     *  Cell for item at index path
     */
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath)
        -> UICollectionViewCell {
            
        println("cellForItemAtIndexPath")
            
        // Dequeue a reusable cell from the table, using the correct “reuse identifier”
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("cell", forIndexPath: indexPath)
            as! PhotoAlbumCollectionViewCell

        self.configureCell(cell, indexPath: indexPath)

        return cell
    }
    
    /**
     *  Did select item at index path to delete an image
     */
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        
        println("didSelectItemAtIndexPath")
        
        // Update the total images in section to compensate for the deletion
        self.totalImages -= 1

        // Remove the image at index path (wrapped within the array)
        self.collectionView.deleteItemsAtIndexPaths([indexPath])
    }
    
    // MARK: - Helpers
    
    func configureCell(cell: PhotoAlbumCollectionViewCell, indexPath: NSIndexPath) {
        
        println("configureCell")
        
        // Create a temporary variable  to hold the value that will be assigned 
        // to the cell imageView at the end of this func
        var posterImage = UIImage(named: "posterPlaceHolder")
        
        // Get the indexed photo from the core data
        let photo = self.fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        
        // Branch on the state of the photo
        if photo.posterPath == "" {
            
            // 1. The photo does not exist
            posterImage = UIImage(named: "noImage")
            
        } else if photo.posterImage != nil {
            
            // 2. The photo is already on the cache
            posterImage = photo.posterImage
            
        } else {
            
            // 3. The Photo has not completed download yet!
            cell.spinner.startAnimating()
            
            // Initiate the download under a task that can be cancelled
            let task = FlickrClient.sharedInstance().taskForImage(photo.posterPath) { imageData, error in
                
                if let downloadError = error {
                    dispatch_async(dispatch_get_main_queue()) {
                        
                        // TODO: Find an image for the nophoto.png?
                        cell.imageView.image =  UIImage(named: "nophoto.png")
                        cell.spinner.stopAnimating()
                    }
                }
                
                // Create the image from the downloaded data
                let image = UIImage(data: imageData!)
                
                // Update the photo object properties
                photo.posterImage = image
                photo.downloaded = true
                
                // Update the cell and core data on main thread
                dispatch_async(dispatch_get_main_queue()) {
                    cell.imageView.image = image
                    CoreDataStackManager.sharedInstance().saveContext()
                    cell.spinner.stopAnimating()
                }
            }
            
            // Cancel task if the cell is outside the visible screen area
            cell.taskToCancelifCellIsReused = task
        }
    
        // Set the image in the cell to the value of the posterImage
        cell.imageView!.image = posterImage
    }
    
    /**
     *  Displays a pin at the desired location
     */
    func showPinOnMap(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        
        println("showPinOnMap")
        
        self.mapView.delegate = self
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        var annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        self.mapView.addAnnotation(annotation)
    }
    
    /**
     *  Checks whether to enable the new collection button
     */
    func checkNewCollectionButton() {
        
        println("checkNewCollectionButton")
        
        // Use core data to get the photos for the selected pin
        let photos = fetchedResultsController.fetchedObjects as! [Photo]

        // Check if there is at least one that is not downloaded yet
        let downloaded = photos.filter {
            $0.downloaded == false
        }
        
        // If all photos are downloaded, enable the collection button
        self.newCollectionBarButton.enabled = true
    }
    
    /**
     *  Set the current page for the pin to the next legitimate value
     */
    func updateCurrentPage() {
        
        println("updateCurrentPage")
        
        if pin.currentPage >= pin.totalPages {
            pin.currentPage = 1
        } else {
            pin.currentPage++
        }
    }
    
    func configureUI() {
        
        println("configureUI")
        
        self.collectionView.backgroundColor = UIColor.whiteColor()
    }
    
}

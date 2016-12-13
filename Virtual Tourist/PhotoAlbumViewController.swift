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
                                UICollectionViewDataSource,
                                UICollectionViewDelegate,
                                MKMapViewDelegate,
                                NSFetchedResultsControllerDelegate {
    
    // MARK: - Properties
    
    // Gets the pin that the user selected on the map
    var pin: Pin!
    
    // Constants
    let COLS_PER_ROW: CGFloat = 3.0
    let DEFAULT_SPAN: Double = 0.5
    
    // Core Data
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController<Photo> = {
        let fetchRequest = NSFetchRequest<Photo>(entityName: "Photo")
        fetchRequest.sortDescriptors = []
        
        // Fetch only the photos for the selected pin
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.pin)
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        
        }()
    
    // FetchedResultsController
    var selectedIndexes = [IndexPath]()
    var insertedIndexPaths: [IndexPath]!
    var deletedIndexPaths: [IndexPath]!
    var updatedIndexPaths: [IndexPath]!
    
    // MARK: - Outlets
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var newCollectionBarButton: UIBarButtonItem!
    @IBOutlet weak var noImageLabel: UILabel!
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure the UI
        self.configureUI()
        self.newCollectionBarButton.isEnabled = false
        
        // Set the delegates
        self.collectionView.delegate = self
        self.mapView.delegate = self
        self.fetchedResultsController.delegate = self
        
        // Show the selected pin on the top map
        self.showPinOnMap(self.pin.latitude, longitude: self.pin.longitude)
        
        // Start the fetch
        var error: NSError?
        do {
            try self.fetchedResultsController.performFetch()
        } catch let error1 as NSError {
            error = error1
        }
        
        if let _ = error {
            self.alertView("Could not get images from flickr")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if pin.photos.isEmpty {
            
            // Get images info from Flicker
            FlickrClient.sharedInstance().getPhotosURLs(pin) { success, errorString in
                if success == false {
                    self.alertView("Could not get images from flickr")
                } else {
                    
                    // Check if there are no images for this pin to update the UI
                    if self.pin.photos.count == 0 || self.pin.photos.isEmpty {
                        DispatchQueue.main.async {
                            self.noImageLabel.isHidden = false
                        }
                    }
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Clear leftovers
        self.fetchedResultsController.delegate = nil
    }
    
    // MARK: - Actions
    
    @IBAction func backButtonTouch(_ sender: AnyObject) {
        
        // Show the Travel locations view controller
        DispatchQueue.main.async(execute: {
            
            // Grab storyboard
            let storyboard = UIStoryboard (name: "Main", bundle: nil)
            
            // Get the destination controller from the storyboard id
            let nextVC = storyboard.instantiateViewController(withIdentifier: "TravelLocationsViewController")
                
            
            // Go to the destination controller
            self.present(nextVC, animated: false, completion: nil)
        })
    }
    
    @IBAction func newCollectionButtonTouchUp(_ sender: AnyObject) {
        
        self.newCollectionBarButton.isEnabled = false
        
        // Remove the old collection
        for photo in fetchedResultsController.fetchedObjects as [Photo]! {
            sharedContext.delete(photo)
        }
        
        // Update the pin's current page
        self.updateCurrentPage()
        
        // Get the new collection data
        FlickrClient.sharedInstance().getPhotosURLs(pin) { success, errorString in
            if errorString != nil {
                self.alertView("Could not download images")
            } else {
                // Save the new collection in core data
                DispatchQueue.main.async {
                    CoreDataStackManager.sharedInstance().saveContext()
                }
            }
        }
    }
    
    // MARK: - Alerts
    
    /// Throws an alert view to display error messages
    func alertView(_ message: String) {
        DispatchQueue.main.async(execute: {
            let alertController = UIAlertController(title: "Error!", message: message, preferredStyle: .alert)
            let dismiss = UIAlertAction(title: "Dismiss", style: .default, handler: nil)
            alertController.addAction(dismiss)
            self.present(alertController, animated: true, completion: nil)
        })
    }
    
    // MARK: - Collection View Delegate
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return self.fetchedResultsController.sections?.count ?? 0
    }

    /// Number of images in section
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section] 
        return sectionInfo.numberOfObjects
    }
    
    /// Cell for item at index path
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath)
        -> UICollectionViewCell {
            
        // Dequeue a reusable cell from the table, using the correct “reuse identifier”
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
            as! PhotoAlbumCollectionViewCell

        self.configureCell(cell, indexPath: indexPath)
        self.checkNewCollectionButton()
            
        return cell
    }
    
    /// Did select item at index path to delete an image
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        // Local variables
        var photo: Photo // Holds the photo to be deleted
        
        // Define a cell
        _ = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
            as! PhotoAlbumCollectionViewCell
        
        // Check for cell toggle condition
        if let index = selectedIndexes.index(of: indexPath) {
            selectedIndexes.remove(at: index)
        } else {
            selectedIndexes.append(indexPath)
        }
        
        // Force the cell to reload!
        let paths = [indexPath]
        self.collectionView.reloadItems(at: paths)
        
        // Locate the photo to delete from core data using the index
        // Note: Since we are deleting one image at a time, there shall be only one element in the selectedIndexes array
        photo = fetchedResultsController.object(at: selectedIndexes.first!) 
        
        do {
            // Remove the associated photo from disk and cache
            try FileManager.default.removeItem(atPath: photo.posterPath)
        } catch _ {
        }
        photo.posterImage = nil // Triggers removal from the ImageCache
        
        // Remove the photo from core data
        sharedContext.delete(photo)
        
        self.checkNewCollectionButton()
        
        // Save the change
        DispatchQueue.main.async {
            CoreDataStackManager.sharedInstance().saveContext()
        }
        
        // Reset the index array for reuse
        selectedIndexes = [IndexPath]()
    }
    
    // MARK: - Fetched Results Controller Delegate
    
    /// We are about to handle some new changes
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
        // Start out with empty arrays for each change type
        insertedIndexPaths = [IndexPath]()
        deletedIndexPaths = [IndexPath]()
        updatedIndexPaths = [IndexPath]()
    }
    
    /// May be called multiple times, once for each photo object that is added, deleted, or changed. We store the index paths into the three arrays
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type{
        case .insert:
            insertedIndexPaths.append(newIndexPath!)
            break
        case .delete:
            deletedIndexPaths.append(indexPath!)
            break
        case .update:
            updatedIndexPaths.append(indexPath!)
            break
        default:
            break
        }
    }
    
    /// This method is invoked after all of the changed in the current batch have been collected into the three index path arrays (insert, delete, and upate). We now need to loop through the arrays and perform the changes. The most interesting thing about the method is the collection view's "performBatchUpdates" method. Notice that all of the changes are performed inside a closure that is handed to the collection view.
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView.performBatchUpdates( { () -> Void in
            for indexPath in self.insertedIndexPaths {
                self.collectionView.insertItems(at: [indexPath])
            }
            for indexPath in self.deletedIndexPaths {
                self.collectionView.deleteItems(at: [indexPath])
            }
            for indexPath in self.updatedIndexPaths {
                self.collectionView.reloadItems(at: [indexPath])
            }
        }, completion: nil)
    }
    
    // MARK: - Helpers
    
    func configureCell(_ cell: PhotoAlbumCollectionViewCell, indexPath: IndexPath) {
            
        // Create a temporary variable  to hold the value that will be assigned to the cell imageView at the end of this func
        var posterImage = UIImage(named: "imagePlaceholder")
        
        // Get the indexed photo from the core data
        let photo = self.fetchedResultsController.object(at: indexPath) 
        
        // Branch on the state of the photo
        if photo.posterImage != nil {
            
            // The photo is already on the cache
            posterImage = photo.posterImage
            
        } else {
            
            // The Photo has not completed download yet!
            cell.spinner.startAnimating()
            
            // Initiate the download under a task that can be cancelled
            let task = FlickrClient.sharedInstance().taskForImage(photo.posterPath) { imageData, error in
                
                if let _ = error {
                    self.alertView("Could not download images")
                    
                    // Handle UI elements on the main thread
                    DispatchQueue.main.async {
                        cell.imageView.image =  UIImage(named: "imagePlaceholder")
                        cell.spinner.stopAnimating()
                    }
                }
                
                if let data = imageData {
                    
                    // Create the image from the downloaded data
                    let image = UIImage(data: data)
                    
                    // Update the photo object properties
                    photo.posterImage = image
                    photo.downloaded = true
                    
                    // Update the cell and core data on main thread
                    DispatchQueue.main.async {
                        cell.imageView.image = image
                        cell.spinner.stopAnimating()
                        CoreDataStackManager.sharedInstance().saveContext()
                    }
                    
                } else {
                    DispatchQueue.main.async {
                        cell.imageView.image =  UIImage(named: "imagePlaceholder")
                        cell.spinner.stopAnimating()
                    }
                }
            }
            
            // Cancel task if the cell is outside the visible screen area
            cell.taskToCancelifCellIsReused = task
        }
        
        // Set the image in the cell to the value of the posterImage
        cell.imageView!.image = posterImage
    }
    
    /// Displays a pin at the desired location
    func showPinOnMap(_ latitude: CLLocationDegrees, longitude: CLLocationDegrees) {

        // Set the delegate
        self.mapView.delegate = self
        
        // Create and add the annotation from the given coordinates
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        self.mapView.addAnnotation(annotation)
        
        // Center map around the annotation
        let span = MKCoordinateSpanMake(self.DEFAULT_SPAN, self.DEFAULT_SPAN)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
    }
    
    /// Checks whether to enable the new collection button
    func checkNewCollectionButton() {
        
        // Use core data to get the photos for the selected pin
        let photos = fetchedResultsController.fetchedObjects as [Photo]!
    
        // Check if there is at least one that is not downloaded yet
        let downloaded = photos?.filter {
            $0.downloaded == false
        }
        
        // If all photos are downloaded, enable the collection button
        if (downloaded?.count)! < 1 {
            self.newCollectionBarButton.isEnabled = true
        }
        
    }
    
    /// Set the current page for the pin to the next legitimate value
    func updateCurrentPage() {
        if pin.currentPage >= pin.totalPages {
            pin.currentPage = 1
        } else {
            pin.currentPage += 1
        }
    }
    
    // MARK: - Aesthetics
    
    /// Configure the collection view layout
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let layout : UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        let width = floor(self.collectionView.frame.size.width / self.COLS_PER_ROW)
        layout.itemSize = CGSize(width: width, height: width)
        collectionView.collectionViewLayout = layout
    }
    
    func configureUI() {
        self.collectionView.backgroundColor = UIColor.white
    }
}

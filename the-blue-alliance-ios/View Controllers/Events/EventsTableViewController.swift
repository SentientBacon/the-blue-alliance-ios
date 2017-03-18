//
//  EventsTableViewController.swift
//  the-blue-alliance
//
//  Created by Zach Orr on 1/7/17.
//  Copyright © 2017 The Blue Alliance. All rights reserved.
//

import UIKit
import TBAKit
import CoreData

let EventSegue = "EventSegue"
let EventCellReuseIdentifier = "EventCell"

class EventsTableViewController: UITableViewController, DynamicTableList {
    public var persistentContainer: NSPersistentContainer! {
        didSet {
            let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "district.name", ascending: true),
                                            NSSortDescriptor(key: "startDate", ascending: true),
                                            NSSortDescriptor(key: "name", ascending: true)]
            fetchRequest.predicate = NSPredicate(format: "week == %ld && year == %ld", week, year)
            
            fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: persistentContainer!.viewContext, sectionNameKeyPath: "district.name", cacheName: nil)
            
            do {
                try self.fetchedResultsController.performFetch()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    typealias FetchedObject = Event
    public var fetchedResultsController: NSFetchedResultsController<Event>! {
        didSet {
            fetchedResultsController.delegate = self
        }
    }

    @IBOutlet var navigationTitleLabel: UILabel?
    @IBOutlet var navigationDetailLabel: UILabel?
    
    internal var weeks: [Int]?
    internal var week: Int = 1
    internal var year: Int = {
        var year = UserDefaults.standard.integer(forKey: StatusConstants.currentSeasonKey)
        if year == 0 {
            // Default to the last safe year we know about
            year = 2017
        }
        return year
    }()

    // MARK: - View Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UINib(nibName: "EventTableViewCell", bundle: nil), forCellReuseIdentifier: EventCellReuseIdentifier)
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 88.0
        
        updateInterface()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        TBAEvent.fetchEvents(year) { (events, error) in
            if error != nil {
                let alertController = UIAlertController(title: "Error!", message: "Unable to load events - \(error!.localizedDescription)", preferredStyle: .alert)
                
                let okAction = UIAlertAction(title: "Okay", style: .default, handler: nil)
                alertController.addAction(okAction)
                
                DispatchQueue.main.async {
                    self.present(alertController, animated: true, completion: nil)
                }
                return
            }
            
            print("Loaded \(events?.count) events")
            
            // TODO: The API for core data stuff is shit right now, take a pass at renaming
            self.persistentContainer?.performBackgroundTask({ (backgroundContext) in
                // Insert the events
                events?.forEach({ (modelEvent) in
                    do {
                        _ = try Event.insert(with: modelEvent, in: backgroundContext)
                    } catch {
                        print("Unable to insert event: \(error)")
                    }
                })
                
                // Save the context.
                do {
                    try backgroundContext.save()
                    DispatchQueue.main.async {
                        self.setupWeeks()
                    }
                } catch {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    let nserror = error as NSError
                    fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
                }
            })
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }
    
    // MARK: - Private Methods
    
    func updateInterface() {
        if week == -1 {
            navigationTitleLabel?.text = "---- Events"
        } else {
            navigationTitleLabel?.text = "Week \(week) Events"
        }
        
        navigationDetailLabel?.text = "▾ \(year)"
    }
    
    func setupCurrentWeek() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Event.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "year == %ld", year)
        fetchRequest.resultType = NSFetchRequestResultType.dictionaryResultType
        // TODO: Do we sort by week or startDate... or endDate?
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "week", ascending: true)]
        fetchRequest.propertiesToFetch = ["startDate", "endDate", "week"].map({ (propertyName) -> NSPropertyDescription in
            return Event.entity().propertiesByName[propertyName]!
        })
        
        guard let eventDates = try? persistentContainer?.viewContext.fetch(fetchRequest) as! [[String: Any]] else {
            // TODO: Throw init error
            return
        }
        
        if eventDates.count == 0 {
            // TODO: This is no good... we need to have some events. Show a "No Events for this year" data state?
        }
        
        /*
        let currentDate = Date()
        var newestEvent = eventDates.first
        for eventDate in eventDates.dropFirst() {
            if currentDate >
            
            let newestEndDate = newestEvent["endDate"]
            let startDate = eventDate["startDate"]
            // let endDate = eventDate["endDate"]
        }
        */
    }
    
    func setupWeeks() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Event.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "year == %ld", year)
        fetchRequest.resultType = NSFetchRequestResultType.dictionaryResultType
        fetchRequest.propertiesToFetch = [Event.entity().propertiesByName["week"]!]
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "week", ascending: true)]
        fetchRequest.returnsDistinctResults = true
        
        guard let weeks = try? persistentContainer?.viewContext.fetch(fetchRequest) as! [[String: NSNumber]] else {
            // TODO: Throw init error
            return
        }

        self.weeks = weeks.map({ (_ weekDict: [String: NSNumber]) -> Int in
            // TODO: Don't force upwrap zachzor
            return weekDict["week"]!.intValue
        })
        
        if year == Calendar.current.year && week == -1 {
            // If it's the current year, setup the current week for this year
            setupCurrentWeek()
        } else {
            // Otherwise, default to the first week for this year
            if let firstWeek = self.weeks?.first {
                week = firstWeek
            } else {
                // TODO: Show "No events for current year"
            }
        }
        updateInterface()
    }
    
    // MARK: Table View
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return itemCount(at: section)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return cell(at: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelectItem(at: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.contentView.backgroundColor = UIColor.primaryDarkBlue
            headerView.textLabel?.textColor = UIColor.white
            headerView.textLabel?.font = UIFont.systemFont(ofSize: 14)
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if let event = fetchedResultsController.sections?[section].objects?.first as? Event, let district = event.district {
            return "\(district.name!) District"
        } else {
           return "Regional"
        }
    }
    
    // MARK: - Data DynamicTableList
    
    public func cellIdentifier(at indexPath: IndexPath) -> String {
        return EventCellReuseIdentifier
    }
    
    func listView(_ listView: UITableView, configureCell cell: UITableViewCell, withObject object: Event, atIndexPath indexPath: IndexPath) {
        if let cell = cell as? EventTableViewCell {
            cell.event = object
        }
    }
    
    public func listView(_ listView: UITableView, didSelectObject object: Event, atIndexPath indexPath: IndexPath) {
        performSegue(withIdentifier: EventSegue, sender: nil)
    }
    
    // MARK: - Fetched Controller
    
    @objc func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.reloadData()
    }
    
    // MARK: - Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SelectYear" {
            let nav = segue.destination as! UINavigationController
            let selectYearTableViewController = nav.viewControllers.first as! SelectNumberTableViewController
            
            selectYearTableViewController.selectNumberType = .year
            selectYearTableViewController.currentNumber = year
            selectYearTableViewController.numbers = Array(1992...Calendar.current.year).reversed()
        } else if segue.identifier == "EventSegue" {
            if let indexPath = self.tableView.indexPathForSelectedRow {
                let event = fetchedResultsController.object(at: indexPath)
                let eventViewController = (segue.destination as! UINavigationController).topViewController as! EventViewController
                eventViewController.event = event
            }
        }
    }
    
}

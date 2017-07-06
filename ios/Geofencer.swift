//
//  Geofencer.swift
//

import Foundation
import AudioToolbox
import WebKit
import CoreLocation
import UserNotifications

let TAG = "Geofencer"
let iOS8 = floor(NSFoundationVersionNumber) > floor(NSFoundationVersionNumber_iOS_7_1)
let iOS7 = floor(NSFoundationVersionNumber) <= floor(NSFoundationVersionNumber_iOS_7_1)

enum GeofenceError : Error {
    case RuntimeError(String)
}

func logMessage(message: String) {
    NSLog("%@ - %@", TAG, message)
}

func logMessage(messages: [String]) {
    for message in messages {
        logMessage(message: message);
    }
}

@available(iOS 8.0, *)
@objc(Geofencer) class Geofencer : NSObject {
    var bridge: RCTBridge!

    lazy var geoNotificationManager = GeoNotificationManager()
    let priority = DispatchQueue.GlobalQueuePriority.default

    @objc func initialize(callback success: RCTResponseSenderBlock, errorCallback failed: RCTResponseSenderBlock) -> Void {
        logMessage(message: "Plugin initialization")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(Geofencer.didReceiveLocalNotification),
            name: NSNotification.Name(rawValue: "RNLocalNotification"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(Geofencer.didReceiveTransition),
            name: NSNotification.Name(rawValue: "handleTransition"),
            object: nil
        )

        //let faker = GeofenceFaker(manager: geoNotificationManager)
        //faker.start()

        if iOS8 {
            promptForNotificationPermission()
        }

        geoNotificationManager = GeoNotificationManager()
        geoNotificationManager.registerPermissions()

        let (ok, warnings, errors) = geoNotificationManager.checkRequirements()

        logMessage(messages: warnings)
        logMessage(messages: errors)

        if ok {
            success([[]])
        } else {
            failed([["error": (errors + warnings).joined(separator: "\n")]])
        }
    }

    func promptForNotificationPermission() {
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().requestAuthorization(options:[.badge, .alert, .sound]) { (granted, error) in
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        } else {
            UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
        }
    }

    func addOrUpdate(geofences: Array<AnyObject>, callback success: @escaping RCTResponseSenderBlock, errorCallback failed: @escaping RCTResponseSenderBlock) {
        DispatchQueue.global(qos: .background).async {
            do {
                for geo in geofences {
                    try self.geoNotificationManager.addOrUpdateGeoNotification(geoNotification: JSON(geo))
                }

                success([[]])
            } catch {
                failed([["error": "Failed to add/update geofences"]])
            }
        }
    }

    func getWatched(callback success: @escaping RCTResponseSenderBlock, errorCallback failed: @escaping RCTResponseSenderBlock) {
        DispatchQueue.global(qos: .background).async {
            do {
                let watched = try self.geoNotificationManager.getWatchedGeoNotifications()!
                let watchedJsonString = watched.description

                success([watchedJsonString])
            } catch {
                failed([["error": "Failed to get watched geofences"]])
            }
        }
    }

    func remove(ids: Array<AnyObject>, callback success: @escaping RCTResponseSenderBlock, errorCallback failed: @escaping RCTResponseSenderBlock) {
        DispatchQueue.global(qos: .background).async {
            do {
                for id in ids {
                    try self.geoNotificationManager.removeGeoNotification(id: id as! String)
                }

                success([[]])
            } catch {
                failed([["error": "Failed to remove geofences"]])
            }
        }
    }

    func removeAll(callback success: @escaping RCTResponseSenderBlock, errorCallback failed: @escaping RCTResponseSenderBlock) {
        DispatchQueue.global(qos: .background).async {
            do {
                try self.geoNotificationManager.removeAllGeoNotifications()

                success([[]])
            } catch {
                failed([["error": "Failed to remove all geofences"]])
            }
        }
    }

    @objc func didReceiveTransition (notification: NSNotification) {
        logMessage(message: "didReceiveTransition")
        if let geoNotificationString = notification.object as? String {
            self.bridge.eventDispatcher().sendAppEvent(withName: "GeofencerOnTransitionReceived", body: geoNotificationString)
        }
    }

    @objc func didReceiveLocalNotification (notification: NSNotification) {
        logMessage(message: "didReceiveLocalNotification")
        if UIApplication.shared.applicationState != UIApplicationState.active {
            var data = "undefined"
            if let uiNotification = notification.object as? UILocalNotification {
                if let notificationData = uiNotification.userInfo?["geofence.notification.data"] as? String {
                    data = notificationData
                }

                self.bridge.eventDispatcher().sendAppEvent(withName: "GeofencerOnTransitionReceived", body: data)
            }
        }
    }
}

// class for faking crossing geofences
@available(iOS 8.0, *)
class GeofenceFaker {
    let priority = DispatchQueue.GlobalQueuePriority.default
    let geoNotificationManager: GeoNotificationManager

    init(manager: GeoNotificationManager) {
        geoNotificationManager = manager
    }

    func start() {
        DispatchQueue.global(qos: .background).async {
            do {
                while (true) {
                     logMessage(message: "FAKER")
                     let notify = arc4random_uniform(4)
                     if notify == 0 {
                         logMessage(message: "FAKER notify chosen, need to pick up some region")
                         var geos = try self.geoNotificationManager.getWatchedGeoNotifications()!
                         if geos.count > 0 {
                             //WTF Swift??
                             let index = arc4random_uniform(UInt32(geos.count))
                             let geo = geos[Int(index)]
                             let id = geo["id"].stringValue
                             DispatchQueue.global(qos: .background).async {
                                 if let region = self.geoNotificationManager.getMonitoredRegion(id: id) {
                                     logMessage(message: "FAKER Trigger didEnterRegion")
                                     //self.geoNotificationManager.locationManager(
                                     //    self.geoNotificationManager.locationManager,
                                     //    didEnterRegion: region
                                     //)
                                 }
                             }
                         }
                     }
                     Thread.sleep(forTimeInterval: 3)
                }
            } catch {
                // EMPTY!
            }
        }
    }

    func stop() {

    }
}

@available(iOS 8.0, *)
class GeoNotificationManager : NSObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    let store = GeoNotificationStore()

    override init() {
        logMessage(message: "GeoNotificationManager init")
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func registerPermissions() {
        if iOS8 {
            locationManager.requestAlwaysAuthorization()
        }
    }

    func addOrUpdateGeoNotification(geoNotification: JSON) throws {
        logMessage(message: "GeoNotificationManager addOrUpdate")

        let (_, warnings, errors) = checkRequirements()

        logMessage(messages: warnings)
        logMessage(messages: errors)

        let location = CLLocationCoordinate2DMake(
            geoNotification["latitude"].doubleValue,
            geoNotification["longitude"].doubleValue
        )
        logMessage(message: "AddOrUpdate geo: \(geoNotification)")
        let radius = geoNotification["radius"].doubleValue as CLLocationDistance
        let id = geoNotification["id"].stringValue

        let region = CLCircularRegion(center: location, radius: radius, identifier: id)

        var transitionType = 0
        if let i = geoNotification["transitionType"].int {
            transitionType = i
        }
        region.notifyOnEntry = 0 != transitionType & 1
        region.notifyOnExit = 0 != transitionType & 2

        //store
        store.addOrUpdate(geoNotification: geoNotification)
        locationManager.startMonitoring(for: region)
    }

    func checkRequirements() -> (Bool, [String], [String]) {
        var errors = [String]()
        var warnings = [String]()

        if (!CLLocationManager.isMonitoringAvailable(for: CLRegion.self)) {
            errors.append("Geofencing not available")
        }

        if (!CLLocationManager.locationServicesEnabled()) {
            errors.append("Error: Locationservices not enabled")
        }

        let authStatus = CLLocationManager.authorizationStatus()

        if (authStatus != CLAuthorizationStatus.authorizedAlways) {
            errors.append("Warning: Location always permissions not granted")
        }

        if (iOS8) {
            if let notificationSettings = UIApplication.shared.currentUserNotificationSettings {
                if notificationSettings.types == .none {
                    errors.append("Error: notification permission missing")
                } else {
                    if !notificationSettings.types.contains(.sound) {
                        warnings.append("Warning: notification settings - sound permission missing")
                    }

                    if !notificationSettings.types.contains(.alert) {
                        warnings.append("Warning: notification settings - alert permission missing")
                    }

                    if !notificationSettings.types.contains(.badge) {
                        warnings.append("Warning: notification settings - badge permission missing")
                    }
                }
            } else {
                errors.append("Error: notification permission missing")
            }
        }

        let ok = (errors.count == 0)

        return (ok, warnings, errors)
    }

    func getWatchedGeoNotifications() throws -> [JSON]? {
        return try store.getAll()
    }

    func getMonitoredRegion(id: String) -> CLRegion? {
        for object in locationManager.monitoredRegions {
            let region = object

            if (region.identifier == id) {
                return region
            }
        }
        return nil
    }

    func removeGeoNotification(id: String) throws {
        store.remove(id: id)
        let region = getMonitoredRegion(id: id)
        if (region != nil) {
            logMessage(message: "Stoping monitoring region \(id)")
            locationManager.stopMonitoring(for: region!)
        }
    }

    func removeAllGeoNotifications() throws {
        store.clear()
        for object in locationManager.monitoredRegions {
            let region = object
            logMessage(message: "Stoping monitoring region \(region.identifier)")
            locationManager.stopMonitoring(for: region)
        }
    }

    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        logMessage(message: "update location")
    }

    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        logMessage(message: "fail with error: \(error)")
    }

    func locationManager(manager: CLLocationManager, didFinishDeferredUpdatesWithError error: NSError?) {
        logMessage(message: "deferred fail error: \(error)")
    }

    func locationManager(manager: CLLocationManager, didEnterRegion region: CLRegion) {
        logMessage(message: "Entering region \(region.identifier)")
        handleTransition(region: region, transitionType: 1)
    }

    func locationManager(manager: CLLocationManager, didExitRegion region: CLRegion) {
        logMessage(message: "Exiting region \(region.identifier)")
        handleTransition(region: region, transitionType: 2)
    }

    func locationManager(manager: CLLocationManager, didStartMonitoringForRegion region: CLRegion) {
        if region is CLCircularRegion {
            let lat = (region as! CLCircularRegion).center.latitude
            let lng = (region as! CLCircularRegion).center.longitude
            let radius = (region as! CLCircularRegion).radius

            logMessage(message: "Starting monitoring for region \(region) lat \(lat) lng \(lng) of radius \(radius)")
        }
    }

    func locationManager(manager: CLLocationManager, didDetermineState state: CLRegionState, forRegion region: CLRegion) {
        logMessage(message: "State for region " + region.identifier)
    }

    func locationManager(manager: CLLocationManager, monitoringDidFailForRegion region: CLRegion?, withError error: NSError) {
        logMessage(message: "Monitoring region " + region!.identifier + " failed " + error.description)
    }

    func handleTransition(region: CLRegion!, transitionType: Int) {
        do {
            if var geoNotification = try store.findById(id: region.identifier) {
                if isWithinTimeRange(geoNotification: geoNotification) {
                    geoNotification["transitionType"].int = transitionType

                    if geoNotification["notification"].exists() {
                        notifyAbout(geo: geoNotification)
                    }

                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "handleTransition"), object: geoNotification.rawString(String.Encoding.utf8, options: []))
                }
            }
        } catch {
            // EMPTY!
        }
    }

    func isWithinTimeRange(geoNotification: JSON) -> Bool {
        let now = NSDate()
        var greaterThanOrEqualToStartTime: Bool = true
        var lessThanEndTime: Bool = true
        if geoNotification["startTime"].exists() {
            if let startTime = parseDate(dateStr: geoNotification["startTime"].string) {
                greaterThanOrEqualToStartTime = (now.compare(startTime as Date) == ComparisonResult.orderedDescending || now.compare(startTime as Date) == ComparisonResult.orderedSame)
            }
        }
        if geoNotification["endTime"].exists() {
            if let endTime = parseDate(dateStr: geoNotification["endTime"].string) {
                lessThanEndTime = now.compare(endTime as Date) == ComparisonResult.orderedAscending
            }
        }
        return greaterThanOrEqualToStartTime && lessThanEndTime
    }

    func parseDate(dateStr: String?) -> NSDate? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = NSTimeZone(name: "UTC") as! TimeZone
        return dateFormatter.date(from: dateStr!) as! NSDate
    }

    func notifyAbout(geo: JSON) {
        logMessage(message: "Creating notification")
        let notification = UILocalNotification()
        notification.timeZone = NSTimeZone.default
        let dateTime = NSDate()
        notification.fireDate = dateTime as Date
        notification.soundName = UILocalNotificationDefaultSoundName
        notification.alertBody = geo["notification"]["text"].stringValue
        if let json = geo["notification"]["data"] as JSON? {
            notification.userInfo = ["geofence.notification.data": json.rawString(String.Encoding.utf8, options: [])!]
        }
        UIApplication.shared.scheduleLocalNotification(notification)

        if let vibrate = geo["notification"]["vibrate"].array {
            if (!vibrate.isEmpty && vibrate[0].intValue > 0) {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
}

class GeoNotificationStore {
    init() {
        createDBStructure()
    }

    func createDBStructure() {
        let (tables, err) = SD.existingTables()

        if (err != nil) {
            logMessage(message: "Cannot fetch sqlite tables: \(err)")
            return
        }

        if (tables.filter { $0 == "GeoNotifications" }.count == 0) {
            if let err = SD.executeChange("CREATE TABLE GeoNotifications (ID TEXT PRIMARY KEY, Data TEXT)") {
                //there was an error during this function, handle it here
                logMessage(message: "Error while creating GeoNotifications table: \(err)")
            } else {
                //no error, the table was created successfully
                logMessage(message: "GeoNotifications table was created successfully")
            }
        }
    }

    func addOrUpdate(geoNotification: JSON) {
        do {
            if (try findById(id: geoNotification["id"].stringValue) != nil) {
                update(geoNotification: geoNotification)
            }
            else {
                add(geoNotification: geoNotification)
            }
        } catch {
            // EMPTY!
        }
    }

    func add(geoNotification: JSON) {
        let id = geoNotification["id"].stringValue
        let err = SD.executeChange("INSERT INTO GeoNotifications (Id, Data) VALUES(?, ?)",
            withArgs: [id as AnyObject, geoNotification.description as AnyObject])

        if err != nil {
            logMessage(message: "Error while adding \(id) GeoNotification: \(err)")
        }
    }

    func update(geoNotification: JSON) {
        let id = geoNotification["id"].stringValue
        let err = SD.executeChange("UPDATE GeoNotifications SET Data = ? WHERE Id = ?",
            withArgs: [geoNotification.description as AnyObject, id as AnyObject])

        if err != nil {
            logMessage(message: "Error while adding \(id) GeoNotification: \(err)")
        }
    }

    func findById(id: String) throws -> JSON? {
        let (resultSet, err) = SD.executeQuery("SELECT * FROM GeoNotifications WHERE Id = ?", withArgs: [id as AnyObject])

        if err != nil {
            //there was an error during the query, handle it here
            logMessage(message: "Error while fetching \(id) GeoNotification table: \(err)")
            return nil
        } else {
            if (resultSet.count > 0) {
                let jsonString = resultSet[0]["Data"]!.asString()!
                return try JSON(data: jsonString.data(using: String.Encoding.utf8)!)
            }
            else {
                return nil
            }
        }
    }

    func getAll() throws -> [JSON]? {
        let (resultSet, err) = SD.executeQuery("SELECT * FROM GeoNotifications")

        if err != nil {
            //there was an error during the query, handle it here
            logMessage(message: "Error while fetching from GeoNotifications table: \(err)")
            return nil
        } else {
            var results = [JSON]()
            for row in resultSet {
                if let data = row["Data"]?.asString() {
                    try results.append(JSON(data: data.data(using: String.Encoding.utf8)!))
                }
            }
            return results
        }
    }

    func remove(id: String) {
        let err = SD.executeChange("DELETE FROM GeoNotifications WHERE Id = ?", withArgs: [id as AnyObject])

        if err != nil {
            logMessage(message: "Error while removing \(id) GeoNotification: \(err)")
        }
    }

    func clear() {
        let err = SD.executeChange("DELETE FROM GeoNotifications")

        if err != nil {
            logMessage(message: "Error while deleting all from GeoNotifications: \(err)")
        }
    }
}

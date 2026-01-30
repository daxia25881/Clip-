//
//  PasteboardMonitor.swift
//  Clip
//
//  Created by Riley Testut on 6/11/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import AVFoundation
import UserNotifications
import CoreLocation

import ClipKit
import Roxas

private let PasteboardMonitorDidChangePasteboard: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void =
{ (center, observer, name, object, userInfo) in
    ApplicationMonitor.shared.pasteboardMonitor.didChangePasteboard()
}

private let PasteboardMonitorIgnoreNextPasteboardChange: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void =
{ (center, observer, name, object, userInfo) in
    ApplicationMonitor.shared.pasteboardMonitor.ignoreNextPasteboardChange = true
}

class PasteboardMonitor
{
    private(set) var isStarted = false
    fileprivate var ignoreNextPasteboardChange = false
    
    private let feedbackGenerator = UINotificationFeedbackGenerator()
}

extension PasteboardMonitor
{
    func start(completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        guard !self.isStarted else { return }
        self.isStarted = true
        
        SnippetManager.shared.startMonitoring()
        PendingMessageManager.shared.startMonitoring()
                
        self.registerForNotifications()
        completionHandler(.success(()))
    }
}

private extension PasteboardMonitor
{
    func registerForNotifications()
    {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(center, nil, PasteboardMonitorDidChangePasteboard, CFNotificationName.didChangePasteboard.rawValue, nil, .deliverImmediately)
        CFNotificationCenterAddObserver(center, nil, PasteboardMonitorIgnoreNextPasteboardChange, CFNotificationName.ignoreNextPasteboardChange.rawValue, nil, .deliverImmediately)
        
        #if !targetEnvironment(simulator)
        let beginListeningSelector = ["Notifications", "Change", "Pasteboard", "To", "Listening", "begin"].reversed().joined()
        
        let className = ["Connection", "Server", "PB"].reversed().joined()
        
        let PBServerConnection = NSClassFromString(className) as AnyObject
        _ = PBServerConnection.perform(NSSelectorFromString(beginListeningSelector))
        #endif
        
        let changedNotification = ["changed", "pasteboard", "apple", "com"].reversed().joined(separator: ".")
        NotificationCenter.default.addObserver(self, selector: #selector(PasteboardMonitor.pasteboardDidUpdate), name: Notification.Name(changedNotification), object: nil)
    }
    
    @objc func pasteboardDidUpdate()
    {
        guard !self.ignoreNextPasteboardChange else {
            self.ignoreNextPasteboardChange = false
            return
        }
        
        DispatchQueue.main.async {
            if UIApplication.shared.applicationState != .background
            {
                // Don't present notifications for items copied from within Clip.
                guard !UIPasteboard.general.contains(pasteboardTypes: [UTI.clipping]) else { return }
            }
            
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                if settings.soundSetting == .enabled
                {
                    UIDevice.current.vibrate()
                }
            }
            
            // Only send notification if enabled in settings
            if UserDefaults.shared.showClipboardNotification {
                let content = UNMutableNotificationContent()
                content.categoryIdentifier = UNNotificationCategory.clipboardReaderIdentifier
                content.title = NSLocalizedString("Clipboard Changed", comment: "")
                content.body = NSLocalizedString("Successfully saved to Clip.", comment: "")
                
                let request = UNNotificationRequest(identifier: "ClipboardChanged", content: content, trigger: nil)
                UNUserNotificationCenter.current().add(request) { (error) in
                    if let error = error {
                        print(error)
                    }
                }
            }
            
            SnippetManager.shared.readLatestAndUpload()
        }
    }
}

private extension PasteboardMonitor
{
    func didChangePasteboard()
    {
        DatabaseManager.shared.refresh()
        
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["ClipboardChanged"])
    }
}

// MARK: - SnippetManager (Embedded for Compilation)

class SnippetManager {
    static let shared = SnippetManager()
    
    private var targetPath: String {
        return UserDefaults.shared.snippetTargetPath ?? ""
    }

    private var monitorSource: DispatchSourceFileSystemObject?
    private let fileQueue = DispatchQueue(label: "com.rileytestut.Clip.SnippetManager")
    private var lastProcessedDate: Date = .distantPast
    
    private var uploadQueue: [String] = []
    private var isUploading = false

    private init() {}
    
    func startMonitoring() {
        guard !targetPath.isEmpty, FileManager.default.fileExists(atPath: targetPath) else {
            print("SnippetManager: Target path is empty or does not exist: \(targetPath)")
            // Fallback or retry logic could go here, but for now we just log
            return
        }

        let descriptor = open(targetPath, O_EVTONLY)
        
        guard descriptor > 0 else {
            print("SnippetManager: Unable to open directory for monitoring: \(targetPath)")
            return
        }
        
        monitorSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: fileQueue)
        
        monitorSource?.setEventHandler { [weak self] in
            self?.handleDirectoryChange()
        }
        
        monitorSource?.setCancelHandler {
            close(descriptor)
        }
        
        monitorSource?.resume()
        print("SnippetManager: Started monitoring \(targetPath)")
    }
    
    private func handleDirectoryChange() {
        print("SnippetManager: Directory changed detected.")
        // Slight delay to ensure file write is complete
        fileQueue.asyncAfter(deadline: .now() + 0.4) {
            self.readLatestAndUpload()
        }
    }
    
    func readLatestAndUpload() {
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(atPath: targetPath)
            let plistFiles = files.filter { $0.hasSuffix(".plist") }
            
            guard !plistFiles.isEmpty else {
                print("SnippetManager: No plist files found.")
                return
            }
            
            // Find newest file
            var newestFile: String?
            var newestDate: Date = .distantPast
            
            for file in plistFiles {
                let filePath = (targetPath as NSString).appendingPathComponent(file)
                let attributes = try fileManager.attributesOfItem(atPath: filePath)
                if let date = attributes[.creationDate] as? Date {
                    if date > newestDate {
                        newestDate = date
                        newestFile = filePath
                    }
                }
            }
            
            guard let fileToRead = newestFile else { return }
            
            // Avoid re-processing the same file based on creation date
            guard newestDate > self.lastProcessedDate else {
                print("SnippetManager: File already processed or not new (Date: \(newestDate)). Skipping.")
                return
            }
            
            self.lastProcessedDate = newestDate
            print("SnippetManager: Reading file \(fileToRead)")
            
            // Read and parse plist
            if let data = try? Data(contentsOf: URL(fileURLWithPath: fileToRead)),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                
                let content = extractContent(from: plist)
                saveAndQueue(content: content)
            }
        } catch {
            print("SnippetManager: Error reading directory - \(error)")
        }
    }
    
    private func extractContent(from plist: [String: Any]) -> String {
        // Check "items" array (new format)
        if let items = plist["items"] as? [[String: Any]] {
            for item in items {
                if let text = item["public.utf8-plain-text"] as? String {
                    return text
                }
            }
        }
        
        return "Unknown Content"
    }
    
    private func saveAndQueue(content: String) {
        print("SnippetManager: Saving content locally before queuing upload...")
        DatabaseManager.shared.save(text: content) { [weak self] result in
            switch result {
            case .success:
                print("SnippetManager: Saved to local database.")
            case .failure(let error):
                print("SnippetManager: Failed to save locally (error: \(error)), but will still attempt upload.")
            }
            
            self?.fileQueue.async {
                self?.uploadQueue.append(content)
                self?.processUploadQueue()
            }
        }
    }
    
    private func processUploadQueue() {
        guard let urlString = UserDefaults.shared.webdavURL, let url = URL(string: urlString) else {
            return
        }
        
        guard let username = UserDefaults.shared.webdavUsername, let password = UserDefaults.shared.webdavPassword else {
            return
        }
        
        guard !isUploading, let content = uploadQueue.first else { return }
        
        isUploading = true
        print("SnippetManager: Processing upload queue. Items pending: \(uploadQueue.count)")
        
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        
        let authString = "\(username):\(password)"
        if let authData = authString.data(using: .utf8)
        {
            let base64Auth = authData.base64EncodedString()
            req.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }
        
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let random = Int.random(in: 1000...9999)
        let body: [String: Any] = [
            "Clipboard": content,
            "Type": "Text",
            "Device": "iPhone-Troll-888",
            "Random_number": "\(random)"
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: body, options: [])
            req.httpBody = data
            
            print("SnippetManager: Uploading content to WebDAV...")
            
            URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
                self?.fileQueue.async {
                    if let error = error {
                        print("SnippetManager: Upload error: \(error). Retrying in 5s...")
                        self?.scheduleRetry()
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                        print("SnippetManager: Upload success (Status: \(httpResponse.statusCode)).")
                        
                        if self?.uploadQueue.isEmpty == false {
                            self?.uploadQueue.removeFirst()
                        }
                        self?.isUploading = false
                        self?.processUploadQueue()
                    } else {
                        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                        print("SnippetManager: Upload failed with status \(status). Retrying in 5s...")
                        self?.scheduleRetry()
                    }
                }
            }.resume()
        } catch {
            print("SnippetManager: JSON serialization error: \(error)")
            isUploading = false
        }
    }
    
    private func scheduleRetry() {
        self.isUploading = false
        self.fileQueue.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.processUploadQueue()
        }
    }
}

// MARK: - PendingMessageManager

class PendingMessageManager {
    static let shared = PendingMessageManager()
    
    private var targetPath: String {
        return UserDefaults.shared.barkPath ?? ""
    }
    
    private var monitorSource: DispatchSourceFileSystemObject?
    private let fileQueue = DispatchQueue(label: "com.rileytestut.Clip.PendingMessageManager", attributes: .concurrent)
    
    private init() {}
    
    func startMonitoring() {
        guard !targetPath.isEmpty, FileManager.default.fileExists(atPath: targetPath) else {
            print("PendingMessageManager: Target path is empty or does not exist: \(targetPath)")
            return
        }
        
        let descriptor = open(targetPath, O_EVTONLY)
        
        guard descriptor > 0 else {
            print("PendingMessageManager: Unable to open directory for monitoring: \(targetPath)")
            return
        }
        
        monitorSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: fileQueue)
        
        monitorSource?.setEventHandler { [weak self] in
            self?.handleDirectoryChange()
        }
        
        monitorSource?.setCancelHandler {
            close(descriptor)
        }
        
        monitorSource?.resume()
        print("PendingMessageManager: Started monitoring \(targetPath)")
    }
    
    private func handleDirectoryChange() {
        print("PendingMessageManager: Directory change detected.")
        // Slight delay to ensure file write is complete
        fileQueue.asyncAfter(deadline: .now() + 1.0) {
            self.fetchLatestFromWebDAV()
        }
    }
    
    private func fetchLatestFromWebDAV() {
        guard let urlString = UserDefaults.shared.webdavURL, let url = URL(string: urlString) else {
            print("PendingMessageManager: WebDAV URL is not configured.")
            return
        }
        
        guard let username = UserDefaults.shared.webdavUsername, let password = UserDefaults.shared.webdavPassword else {
            print("PendingMessageManager: WebDAV credentials are not configured.")
            return
        }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        
        let authString = "\(username):\(password)"
        if let authData = authString.data(using: .utf8) {
            let base64Auth = authData.base64EncodedString()
            req.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }
        
        print("PendingMessageManager: Fetching content from WebDAV...")
        
        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            if let error = error {
                print("PendingMessageManager: Fetch error: \(error)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                print("PendingMessageManager: Fetch failed with status \(status).")
                return
            }
            
            guard let data = data else {
                print("PendingMessageManager: No data received.")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let clipboard = json["Clipboard"] as? String {
                    print("PendingMessageManager: Extracted Clipboard: \(clipboard)")
                    self?.saveToDatabase(content: clipboard)
                } else {
                    print("PendingMessageManager: 'Clipboard' key not found in response.")
                }
            } catch {
                print("PendingMessageManager: JSON parsing error: \(error)")
            }
        }.resume()
    }
    
    // MARK: - Legacy method (preserved but not called)
    func readLatestAndSave() {
        do {
            let fileManager = FileManager.default
            let files = try fileManager.contentsOfDirectory(atPath: targetPath)
            let plistFiles = files.filter { $0.hasSuffix(".plist") }
            
            guard !plistFiles.isEmpty else {
                print("PendingMessageManager: No plist files found.")
                return
            }
            
            // Find newest file by creation date
            var newestFile: String?
            var newestDate: Date = .distantPast
            
            for file in plistFiles {
                let filePath = (targetPath as NSString).appendingPathComponent(file)
                let attributes = try fileManager.attributesOfItem(atPath: filePath)
                if let date = attributes[.creationDate] as? Date {
                    if date > newestDate {
                        newestDate = date
                        newestFile = filePath
                    }
                }
            }
            
            guard let fileToRead = newestFile else { return }
            print("PendingMessageManager: Reading file \(fileToRead)")
            
            // Read and parse plist
            if let data = try? Data(contentsOf: URL(fileURLWithPath: fileToRead)),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                
                if let body = plist["body"] as? String {
                    print("PendingMessageManager: Extracted body: \(body)")
                    saveToDatabase(content: body)
                } else {
                    print("PendingMessageManager: 'body' key not found or not a string.")
                }
            }
        } catch {
            print("PendingMessageManager: Error reading directory - \(error)")
        }
    }
    
    private func saveToDatabase(content: String) {
        DatabaseManager.shared.save(text: content) { result in
            switch result {
            case .success:
                print("PendingMessageManager: Text saved to local history.")
                self.sendCopyNotification(text: content)
            case .failure(let error):
                print("PendingMessageManager: Failed to save to local history: \(error)")
            }
        }
    }
    
    private func sendCopyNotification(text: String) {
        guard UserDefaults.shared.showCloudNotification else { return }
        
        let notificationContent = UNMutableNotificationContent()
        notificationContent.title = NSLocalizedString("Cloud Message Received", comment: "")
        notificationContent.body = NSLocalizedString("Swipe down to copy to clipboard.", comment: "")
        notificationContent.categoryIdentifier = UNNotificationCategory.clipboardReaderIdentifier
        notificationContent.userInfo = [
            "Action": "CopyToPasteboard",
            "Text": text
        ]
        
        let request = UNNotificationRequest(identifier: "PendingMessageCopy-\(UUID().uuidString)", content: notificationContent, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("PendingMessageManager: Failed to add notification: \(error)")
            }
        }
    }
}

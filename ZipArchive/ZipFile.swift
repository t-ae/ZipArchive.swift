//
//  ZipFile.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/07.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation

public class ZipFile {
    
    private init() {}

    public class func createFromDirectory(sourceDirectoryName: String, destinationArchiveFileName: String, compressionLevel: CompressionLevel = .Default, includeBaseDirectory: Bool = false, entryNameEncoding: NSStringEncoding = NSUTF8StringEncoding) {
        createFromDirectory(sourceDirectoryName, destinationArchiveFileName: destinationArchiveFileName, compressionLevel: compressionLevel, includeBaseDirectory: includeBaseDirectory, entryNameEncoding: entryNameEncoding, password: "", passwordEncoding: NSASCIIStringEncoding)
    }
    
    public class func createFromDirectory(sourceDirectoryName: String, destinationArchiveFileName: String, password: String, compressionLevel: CompressionLevel = .Default, includeBaseDirectory: Bool = false, entryNameEncoding: NSStringEncoding = NSUTF8StringEncoding, passwordEncoding: NSStringEncoding = NSASCIIStringEncoding) {
        createFromDirectory(sourceDirectoryName, destinationArchiveFileName: destinationArchiveFileName, compressionLevel: compressionLevel, includeBaseDirectory: includeBaseDirectory, entryNameEncoding: entryNameEncoding, password: password, passwordEncoding: passwordEncoding)
    }
    
    private class func createFromDirectory(sourceDirectoryName: String, destinationArchiveFileName: String, compressionLevel: CompressionLevel, includeBaseDirectory: Bool, entryNameEncoding: NSStringEncoding, password: String, passwordEncoding: NSStringEncoding) {
        let fm = NSFileManager.defaultManager()
        guard let subpaths = try? fm.subpathsOfDirectoryAtPath(sourceDirectoryName) else {
            // ERROR
            return
        }
        
        guard let zip = ZipArchive(path: destinationArchiveFileName, mode: .Create, entryNameEncoding: entryNameEncoding, passwordEncoding: passwordEncoding) else {
            // ERROR
            return
        }
        defer {
            zip.dispose()
        }
        
        let directoryName = sourceDirectoryName as NSString
        let baseDirectoryName = directoryName.lastPathComponent as NSString
        
        for subpath in subpaths {
            let fullpath = directoryName.stringByAppendingPathComponent(subpath)
            var entryName = subpath
            if includeBaseDirectory {
                entryName = baseDirectoryName.stringByAppendingPathComponent(entryName)
            }
            guard let _ = zip.createEntryFromFile(fullpath, entryName: entryName, compressionLevel: compressionLevel, password: password) else {
                // ERROR
                break
            }
        }
    }
    
    public class func extractToDirectory(sourceArchiveFileName: String, destinationDirectoryName: String, entryNameEncoding: NSStringEncoding = NSUTF8StringEncoding) {
        extractToDirectory(sourceArchiveFileName, destinationDirectoryName: destinationDirectoryName, entryNameEncoding: entryNameEncoding, password: "", passwordEncoding: NSASCIIStringEncoding)
    }

    public class func extractToDirectory(sourceArchiveFileName: String, destinationDirectoryName: String, password: String, entryNameEncoding: NSStringEncoding = NSUTF8StringEncoding, passwordEncoding: NSStringEncoding = NSASCIIStringEncoding) {
        extractToDirectory(sourceArchiveFileName, destinationDirectoryName: destinationDirectoryName, entryNameEncoding: entryNameEncoding, password: password, passwordEncoding: passwordEncoding)
    }
    
    private class func extractToDirectory(sourceArchiveFileName: String, destinationDirectoryName: String, entryNameEncoding: NSStringEncoding, password: String, passwordEncoding: NSStringEncoding) {
        guard let unzip = ZipArchive(path: sourceArchiveFileName, mode: .Read, entryNameEncoding: entryNameEncoding, passwordEncoding: passwordEncoding) else {
            // ERROR
            return
        }
        defer {
            unzip.dispose()
        }
        
        unzip.extractToDirectory(destinationDirectoryName, password: password)
    }
    
    public class func openRead(archiveFileName: String) -> ZipArchive? {
        return open(archiveFileName, mode: .Read, entryNameEncoding: NSUTF8StringEncoding)
    }
    
    public class func open(archiveFileName: String, mode: ZipArchiveMode) -> ZipArchive? {
        return open(archiveFileName, mode: mode, entryNameEncoding: NSUTF8StringEncoding)
    }
    
    public class func open(archiveFileName: String, mode: ZipArchiveMode, entryNameEncoding: NSStringEncoding, passwordEncoding: NSStringEncoding = NSASCIIStringEncoding) -> ZipArchive? {
        return ZipArchive(path: archiveFileName, mode: mode, entryNameEncoding: entryNameEncoding, passwordEncoding: passwordEncoding)
    }
    
}

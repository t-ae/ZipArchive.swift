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

    public class func createFromDirectory(
        sourceDirectoryName: String,
        destinationArchiveFileName: String,
        compressionLevel: CompressionLevel = .Default,
        includeBaseDirectory: Bool = false,
        entryNameEncoding: String.Encoding = .utf8)
        throws
    {
        try createFromDirectory(
            sourceDirectoryName: sourceDirectoryName,
            destinationArchiveFileName: destinationArchiveFileName,
            compressionLevel: compressionLevel,
            includeBaseDirectory: includeBaseDirectory,
            entryNameEncoding: entryNameEncoding,
            password: nil,
            passwordEncoding: .ascii)
    }
    
    public class func createFromDirectory(
        sourceDirectoryName: String,
        destinationArchiveFileName: String,
        password: String,
        compressionLevel: CompressionLevel = .Default,
        includeBaseDirectory: Bool = false,
        entryNameEncoding: String.Encoding = .utf8,
        passwordEncoding: String.Encoding = .ascii)
        throws
    {
        try createFromDirectory(
            sourceDirectoryName: sourceDirectoryName,
            destinationArchiveFileName: destinationArchiveFileName,
            compressionLevel: compressionLevel,
            includeBaseDirectory: includeBaseDirectory,
            entryNameEncoding: entryNameEncoding,
            password: password,
            passwordEncoding: passwordEncoding)
    }
    
    private class func createFromDirectory(
        sourceDirectoryName: String,
        destinationArchiveFileName: String,
        compressionLevel: CompressionLevel,
        includeBaseDirectory: Bool,
        entryNameEncoding: String.Encoding,
        password: String?,
        passwordEncoding: String.Encoding)
        throws
    {
        let fm = FileManager.default
        let subpaths = try fm.subpathsOfDirectory(atPath: sourceDirectoryName)
        
        guard let zip = ZipArchive(path: destinationArchiveFileName, mode: .Create, entryNameEncoding: entryNameEncoding, passwordEncoding: passwordEncoding) else {
            throw ZipError.IO
        }
        defer {
            zip.dispose()
        }
        
        let directoryName = sourceDirectoryName as NSString
        let baseDirectoryName = directoryName.lastPathComponent as NSString
        
        for subpath in subpaths {
            let fullpath = directoryName.appendingPathComponent(subpath)
            var entryName = subpath
            if includeBaseDirectory {
                entryName = baseDirectoryName.appendingPathComponent(entryName)
            }
            let entry = zip.createEntryFromFile(sourceFileName: fullpath, entryName: entryName, compressionLevel: compressionLevel, password: password)
            if entry == nil {
                throw ZipError.IO
            }
        }
    }
    
    public class func extractToDirectory(sourceArchiveFileName: String, destinationDirectoryName: String, entryNameEncoding: String.Encoding = .utf8) throws {
        try extractToDirectory(sourceArchiveFileName: sourceArchiveFileName, destinationDirectoryName: destinationDirectoryName, entryNameEncoding: entryNameEncoding, password: "", passwordEncoding: .ascii)
    }

    public class func extractToDirectory(sourceArchiveFileName: String, destinationDirectoryName: String, password: String, entryNameEncoding: String.Encoding = .utf8, passwordEncoding: String.Encoding = .ascii) throws {
        try extractToDirectory(sourceArchiveFileName: sourceArchiveFileName, destinationDirectoryName: destinationDirectoryName, entryNameEncoding: entryNameEncoding, password: password, passwordEncoding: passwordEncoding)
    }
    
    private class func extractToDirectory(sourceArchiveFileName: String, destinationDirectoryName: String, entryNameEncoding: String.Encoding, password: String, passwordEncoding: String.Encoding) throws {
        guard let unzip = ZipArchive(path: sourceArchiveFileName, mode: .Read, entryNameEncoding: entryNameEncoding, passwordEncoding: passwordEncoding) else {
            throw ZipError.IO
        }
        defer {
            unzip.dispose()
        }
        
        try unzip.extractToDirectory(destinationDirectoryName: destinationDirectoryName, password: password)
    }
    
    public class func openRead(archiveFileName: String) -> ZipArchive? {
        return open(archiveFileName: archiveFileName, mode: .Read, entryNameEncoding: .utf8)
    }
    
    public class func open(archiveFileName: String, mode: ZipArchiveMode) -> ZipArchive? {
        return open(archiveFileName: archiveFileName, mode: mode, entryNameEncoding: .utf8)
    }
    
    public class func open(archiveFileName: String, mode: ZipArchiveMode, entryNameEncoding: String.Encoding, passwordEncoding: String.Encoding = .ascii) -> ZipArchive? {
        return ZipArchive(path: archiveFileName, mode: mode, entryNameEncoding: entryNameEncoding, passwordEncoding: passwordEncoding)
    }
    
}

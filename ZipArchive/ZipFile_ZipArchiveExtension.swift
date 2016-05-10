//
//  ZipArchiveExtension.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2016/01/26.
//  Copyright © 2016 yaslab. All rights reserved.
//

import Foundation
import Minizip

/* calculate the CRC32 of a file, because to encrypt a file, we need known the CRC32 of the file before */
private func crc32__(withFilePath path: String) throws -> UInt {
    let fm = NSFileManager.defaultManager()
    if !fm.fileExistsAtPath(path) {
        throw ZipError.FileNotFound
    }
    guard let stream = NSInputStream(fileAtPath: path) else {
        throw ZipError.IO
    }
    
    stream.open()
    if let _ = stream.streamError {
        throw ZipError.IO
    }
    
    let buffer = UnsafeMutablePointer<UInt8>.alloc(kZipArchiveDefaultBufferSize)
    //let bufferLength = sizeof(UInt8) * kZipArchiveBufferCount
    
    var crc: uLong = 0
    
    while true {
        let len = stream.read(buffer, maxLength: kZipArchiveDefaultBufferSize)
        if len <= 0 {
            break
        }
        crc = crc32(crc, buffer, uInt(len))
    }
    
    buffer.destroy()
    buffer.dealloc(kZipArchiveDefaultBufferSize)
    stream.close()
    if let _ = stream.streamError {
        throw ZipError.IO
    }
    
    return crc
}

extension ZipArchive {

//    public func createEntryFromFile(sourceFileName: String, entryName: String) -> ZipArchiveEntry? {
//        return createEntryFromFile(sourceFileName, entryName: entryName, compressionLevel: .Default, password: nil)
//    }
//
//    public func createEntryFromFile(sourceFileName: String, entryName: String, compressionLevel: CompressionLevel) -> ZipArchiveEntry? {
//        return createEntryFromFile(sourceFileName, entryName: entryName, compressionLevel: compressionLevel, password: nil)
//    }

    public func createEntryFromFile(sourceFileName: String, entryName: String, compressionLevel: CompressionLevel = .Default, password: String? = nil) -> ZipArchiveEntry? {
        //let url = NSURL(fileURLWithPath: sourceFileName)
        //guard let fileWrapper = try? NSFileWrapper(URL: url, options: NSFileWrapperReadingOptions(rawValue: 0)) else {
        //    // ERROR
        //    return nil
        //}
        let fm = NSFileManager.defaultManager()
        guard let fileAttributes = try? fm.attributesOfItemAtPath(sourceFileName) else {
            // ERROR
            return nil
        }

        guard let fileDate = fileAttributes[NSFileModificationDate] as? NSDate else {
            // ERROR
            return nil
        }
        guard let filePermissions = fileAttributes[NSFilePosixPermissions] as? NSNumber else {
            // ERROR
            return nil
        }
        guard let nsFileType = fileAttributes[NSFileType] as? NSString else {
            // ERROR
            return nil
        }
        let fileType = FileType.fromNSFileType(nsFileType)

        var name = entryName
        var level = compressionLevel

        // pre-process
        var crc: UInt = 0
        var isLargeFile = false
        if fileType == .Directory {
            if !name.hasSuffix("/") {
                name += "/"
            }
            level = .NoCompression
        }
        else if fileType == .SymbolicLink {
            // Nothing to do
        }
        else if fileType == .Regular {
            if let password = password {
                if !password.isEmpty {
                    do {
                        crc = try crc32__(withFilePath: sourceFileName)
                    }
                    catch {
                        return nil
                    }
                }
            }
            if let fileSize = fileAttributes[NSFileSize] {
                if fileSize.unsignedLongLongValue >= 0xffffffff {
                    isLargeFile = true
                }
            }
        }
        else {
            // Not supported
            return nil
        }

        guard let entry = createEntry(name, compressionLevel: level) else {
            // ERROR
            return nil
        }
        entry.lastWriteTime = fileDate
        entry.filePermissions = filePermissions.unsignedShortValue
        entry.fileType = fileType
        guard let zipStream = entry.open(password, crc32: crc, isLargeFile: isLargeFile) else {
            // ERROR
            return nil
        }
        defer {
            zipStream.close()
        }

        if fileType == .Directory {
            // write zero byte
            var len: UInt8 = 0
            let _ = zipStream.write(&len, maxLength: Int(len))
        }
        else if fileType == .SymbolicLink {
            guard let destination = try? fm.destinationOfSymbolicLinkAtPath(sourceFileName) else {
                // ERROR
                return nil
            }
            
//            guard let destination = fileWrapper.symbolicLinkDestinationURL?.relativeString else {
//                // ERROR
//                return nil
//            }
            
            // TODO: use filesysytem file name string encoding
            guard let destinationCStr = destination.cStringUsingEncoding(entryNameEncoding) else {
                // ERROR
                return nil
            }
            let bytes = UnsafePointer<UInt8>(destinationCStr)
            let err = zipStream.write(bytes, maxLength: destinationCStr.count)
            if err < 0 {
                // ERROR
                return nil
            }
        }
        else if fileType == .Regular {
            guard let fileInputStream = NSInputStream(fileAtPath: sourceFileName) else {
                // ERROR
                return nil
            }
            fileInputStream.open()
            let buffer = UnsafeMutablePointer<UInt8>.alloc(kZipArchiveDefaultBufferSize)
            //let bufferLength = sizeof(UInt8) * kZipArchiveBufferCount
            while true {
                let len = fileInputStream.read(buffer, maxLength: kZipArchiveDefaultBufferSize)
                if len < 0 {
                    // ERROR
                    break
                }
                if len == 0 {
                    // END
                    break
                }
                let err = zipStream.write(buffer, maxLength: len)
                if err < 0 {
                    // ERROR
                    break
                }
            }
            fileInputStream.close()
            buffer.destroy()
            buffer.dealloc(kZipArchiveDefaultBufferSize)
        }

        return entry
    }

//    public func extractToDirectory(destinationDirectoryName: String) throws {
//        try extractToDirectory(destinationDirectoryName, password: "")
//    }

    public func extractToDirectory(destinationDirectoryName: String, password: String? = nil) throws {
        var directories = [ZipArchiveEntry]()
        var symbolicLinks = [ZipArchiveEntry]()
        var files = [ZipArchiveEntry]()

        for entry in entries {
            if entry.fileType == .Directory || entry.fullName.hasSuffix("/") {
                directories.append(entry)
            }
            else if entry.fileType == .SymbolicLink {
                symbolicLinks.append(entry)
            }
            else {
                files.append(entry)
            }
        }

        let fm = NSFileManager.defaultManager()
        let directory = destinationDirectoryName as NSString

        let createBaseDirectory = { (entry: ZipArchiveEntry) throws in
            if entry.fullName.containsString("/") {
                let lastIndex = entry.fullName.rangeOfString("/", options: NSStringCompareOptions.BackwardsSearch)!.startIndex
                let dir = entry.fullName.substringToIndex(lastIndex)
                let path = directory.stringByAppendingPathComponent(dir)
                if !fm.fileExistsAtPath(path) {
                    try fm.createDirectoryAtPath(path, withIntermediateDirectories: true, attributes: nil)
                }
            }
        }

        for entry in files {
            let fullPath = directory.stringByAppendingPathComponent(entry.fullName)
            try createBaseDirectory(entry)
            
            try entry.extractToFile(fullPath, overwrite: false, password: password)

            var attributes = try fm.attributesOfItemAtPath(fullPath)
            attributes[NSFileModificationDate] = entry.lastWriteTime
            attributes[NSFilePosixPermissions] = NSNumber(unsignedShort: entry.filePermissions)
            attributes[NSFileType] = entry.fileType.toNSFileType()
            try fm.setAttributes(attributes, ofItemAtPath: fullPath)
        }

        for entry in symbolicLinks {
            let fullPath = directory.stringByAppendingPathComponent(entry.fullName)
            guard let data = entry.extractToData() else {
                throw ZipError.IO
            }
            guard let destination = String(data: data, encoding: NSUTF8StringEncoding) else {
                throw ZipError.IO
            }
            
            try createBaseDirectory(entry)
            
            try fm.createSymbolicLinkAtPath(fullPath, withDestinationPath: destination)

//            var path1 = [CChar](count: data.length + 1, repeatedValue: 0)
//            memcpy(&path1, data.bytes, data.length)
//            guard let path2 = fullPath.cStringUsingEncoding(NSUTF8StringEncoding) else {
//                // ERROR
//                return
//            }
//            let err = symlink(path1, path2)
//            if err != 0 {
//                // ERROR
//                return
//            }
        }

        for entry in directories {
            let fullPath = directory.stringByAppendingPathComponent(entry.fullName)

            if !fm.fileExistsAtPath(fullPath) {
                let attributes = [
                    NSFileModificationDate : entry.lastWriteTime,
                    NSFilePosixPermissions : NSNumber(unsignedShort: entry.filePermissions)
                ]
                try fm.createDirectoryAtPath(fullPath, withIntermediateDirectories: true, attributes: attributes)
            }
            else {
                var attributes = try fm.attributesOfItemAtPath(fullPath)
                attributes[NSFileModificationDate] = entry.lastWriteTime
                attributes[NSFilePosixPermissions] = NSNumber(unsignedShort: entry.filePermissions)
                try fm.setAttributes(attributes, ofItemAtPath: fullPath)
            }
        }
    }
    
}

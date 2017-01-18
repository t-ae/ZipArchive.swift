//
//  ZipArchiveExtension.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2016/01/26.
//  Copyright © 2016 yaslab. All rights reserved.
//

import Foundation
import Czlib
//import minizip

/* calculate the CRC32 of a file, because to encrypt a file, we need known the CRC32 of the file before */
private func crc32__(withFilePath path: String) throws -> UInt32 {
    let fm = FileManager.default
    if !fm.fileExists(atPath: path) {
        throw ZipError.fileNotFound
    }
    guard let stream = InputStream(fileAtPath: path) else {
        throw ZipError.io
    }

    stream.open()
    if let _ = stream.streamError {
        throw ZipError.io
    }

    var buffer = [UInt8](repeating: 0, count: kZipArchiveDefaultBufferSize)
    //let bufferLength = sizeof(UInt8) * kZipArchiveBufferCount

    var crc: UInt = 0
    //var crc: UInt = 0xffffffff

    while true {
        let len = stream.read(&buffer, maxLength: kZipArchiveDefaultBufferSize)
        if len <= 0 {
            break
        }
        crc = crc32(crc, buffer, uInt(len))
    }

    stream.close()
    if let _ = stream.streamError {
        throw ZipError.io
    }

    return UInt32(crc)
}

extension ZipArchive {

//    public func createEntryFromFile(sourceFileName: String, entryName: String) -> ZipArchiveEntry? {
//        return createEntryFromFile(sourceFileName, entryName: entryName, compressionLevel: .Default, password: nil)
//    }
//
//    public func createEntryFromFile(sourceFileName: String, entryName: String, compressionLevel: CompressionLevel) -> ZipArchiveEntry? {
//        return createEntryFromFile(sourceFileName, entryName: entryName, compressionLevel: compressionLevel, password: nil)
//    }

    public func createEntryFrom(filePath: String, entryName: String, compressionLevel: CompressionLevel = .default, password: String? = nil) throws -> ZipArchiveEntry {
        
        //let url = NSURL(fileURLWithPath: sourceFileName)
        //guard let fileWrapper = try? NSFileWrapper(URL: url, options: NSFileWrapperReadingOptions(rawValue: 0)) else {
        //    // ERROR
        //    return nil
        //}
        let fileManager = FileManager.default
        let fileAttributes = try fileManager.attributesOfItem(atPath: filePath)

        guard let fileDate = fileAttributes[.modificationDate] as? Date else {
            // ERROR
            throw ZipError.io
        }
        guard let filePermissions = fileAttributes[.posixPermissions] as? NSNumber else {
            // ERROR
            throw ZipError.io
        }
        guard let nsFileType = fileAttributes[.type] as? String else {
            // ERROR
            throw ZipError.io
        }
        let fileType = FileType.fromNSFileType(fileType: FileAttributeType(rawValue: nsFileType))

        var name = entryName
        var level = compressionLevel

        // pre-process
        var crc32: UInt32 = 0
        var isLargeFile = false
        if fileType == .directory {
            if !name.hasSuffix("/") {
                name += "/"
            }
            level = .noCompression
        }
        else if fileType == .symbolicLink {
            // Nothing to do
        }
        else if fileType == .regular {
            if let password = password {
                if !password.isEmpty {
                    crc32 = try crc32__(withFilePath: filePath)
                }
            }
            if let fileSize = fileAttributes[FileAttributeKey.size] as? NSNumber {
                if fileSize.uint64Value >= 0xffffffff {
                    isLargeFile = true
                }
            }
        }
        else {
            // Not supported
            throw ZipError.notSupported
        }

        let entry = try createEntry(entryName: name, compressionLevel: level)
        entry.lastWriteTime = fileDate
        entry.filePermissions = filePermissions.uint16Value
        entry.fileType = fileType
        let zipStream = try entry.open(password: password, crc32: crc32, isLargeFile: isLargeFile)
        defer {
            zipStream.close()
        }

        if fileType == .directory {
            // write zero byte
            var len: UInt8 = 0
            // TODO: ignore passwprd
            let _ = zipStream.write(buffer: &len, maxLength: Int(len))
        }
        else if fileType == .symbolicLink {
            let destination = try fileManager.destinationOfSymbolicLink(atPath: filePath)

//            guard let destination = fileWrapper.symbolicLinkDestinationURL?.relativeString else {
//                // ERROR
//                return nil
//            }

            // TODO: use filesysytem file name string encoding
            let err = destination.withCString { (cstr) -> Int in
                let len = Int(strlen(cstr))
                return cstr.withMemoryRebound(to: UInt8.self, capacity: len) { (p) -> Int in
                    // TODO: ignore password, do not compress??
                    return zipStream.write(buffer: p, maxLength: len)
                }
            }
            if err < 0 {
                // ERROR
                throw ZipError.io
            }
        }
        else if fileType == .regular {
            guard let fileInputStream = InputStream(fileAtPath: filePath) else {
                // ERROR
                throw ZipError.io
            }
            fileInputStream.open()
            defer {
                fileInputStream.close()
            }
            let buffer = malloc(kZipArchiveDefaultBufferSize).assumingMemoryBound(to: UInt8.self)
            defer {
                free(buffer)
            }
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
                let err = zipStream.write(buffer: buffer, maxLength: len)
                if err < 0 {
                    // ERROR
                    break
                }
            }
            let err = zipStream.write(buffer: buffer, maxLength: 0) // flash
            if err < 0 {
                // ERROR
                throw ZipError.io
            }
        }

        return entry
    }

//    public func extractToDirectory(destinationDirectoryName: String) throws {
//        try extractToDirectory(destinationDirectoryName, password: "")
//    }

    public func extractTo(directoryPath: String, password: String? = nil) throws {
        var directories = [ZipArchiveEntry]()
        var symbolicLinks = [ZipArchiveEntry]()
        var files = [ZipArchiveEntry]()

        for entry in entries {
            if entry.fileType == .directory || entry.fullName.hasSuffix("/") {
                directories.append(entry)
            }
            else if entry.fileType == .symbolicLink {
                symbolicLinks.append(entry)
            }
            else {
                files.append(entry)
            }
        }

        let fm = FileManager.default
        let directory = directoryPath as NSString

        let createBaseDirectory = { (entry: ZipArchiveEntry) throws in
            if entry.fullName.contains("/") {
                let lastIndex = entry.fullName.range(of: "/", options: .backwards)!.lowerBound
                let dir = entry.fullName.substring(to: lastIndex)
                let path = directory.appendingPathComponent(dir)
                if !fm.fileExists(atPath: path) {
                    try fm.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
                }
            }
        }

        for entry in files {
            let fullPath = directory.appendingPathComponent(entry.fullName)
            try createBaseDirectory(entry)

            try entry.extractTo(filePath: fullPath, overwrite: false, password: password)

            var attributes = try fm.attributesOfItem(atPath: fullPath)
            attributes[FileAttributeKey.modificationDate] = entry.lastWriteTime
            attributes[FileAttributeKey.posixPermissions] = NSNumber(value: entry.filePermissions)
            attributes[FileAttributeKey.type] = entry.fileType.toNSFileType().rawValue
            try fm.setAttributes(attributes, ofItemAtPath: fullPath)
        }

        for entry in symbolicLinks {
            let fullPath = directory.appendingPathComponent(entry.fullName)
            let data = try entry.extractToData()
            guard let destination = String(data: data, encoding: .utf8) else {
                throw ZipError.io
            }

            try createBaseDirectory(entry)

            try fm.createSymbolicLink(atPath: fullPath, withDestinationPath: destination)

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
            let fullPath = directory.appendingPathComponent(entry.fullName)

            if !fm.fileExists(atPath: fullPath) {
                let attributes: [String : Any] = [
                    FileAttributeKey.modificationDate.rawValue : entry.lastWriteTime,
                    FileAttributeKey.posixPermissions.rawValue : NSNumber(value: entry.filePermissions)
                ]
                try fm.createDirectory(atPath: fullPath, withIntermediateDirectories: true, attributes: attributes)
            }
            else {
                var attributes = try fm.attributesOfItem(atPath: fullPath)
                attributes[FileAttributeKey.modificationDate] = entry.lastWriteTime
                attributes[FileAttributeKey.posixPermissions] = NSNumber(value: entry.filePermissions)
                try fm.setAttributes(attributes, ofItemAtPath: fullPath)
            }
        }
    }

}

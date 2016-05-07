//
//  ZipArchive.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/07.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation
import Minizip

public class ZipArchive {

    private var stream: ZipArchiveStream
    internal let mode: ZipArchiveMode
    internal let entryNameEncoding: NSStringEncoding
    internal let passwordEncoding: NSStringEncoding

    internal var zipfp: zipFile = nil
    internal var unzfp: unzFile = nil
    
    private var _entries = [ZipArchiveEntry]()
    public var entries: AnySequence<ZipArchiveEntry> {
        return AnySequence { [unowned self]() -> AnyGenerator<ZipArchiveEntry> in
            var index = 0
            return AnyGenerator { () -> ZipArchiveEntry? in
                if self._entries.count == index {
                    return nil
                }
                let entry = self._entries[index]
                index += 1
                return entry
            }
        }
    }
    
    private var disposed: Bool = false
    
    public init?(stream: ZipArchiveStream, mode: ZipArchiveMode, entryNameEncoding: NSStringEncoding, passwordEncoding: NSStringEncoding) {
        self.stream = stream
        self.mode = mode
        self.entryNameEncoding = entryNameEncoding
        self.passwordEncoding = passwordEncoding
        
        var fileFuncDef = createFileFuncDef(stream)
        
        switch mode {
        case .Read:
            if !stream.canRead {
                // ERROR
                return nil
            }
            unzfp = unzOpen2_64(nil, &fileFuncDef)
            if unzfp != nil {
                readEntries()
            }
        case .Create:
            if !stream.canWrite {
                // ERROR
                return nil
            }
            zipfp = zipOpen2_64(nil, APPEND_STATUS_CREATE, nil, &fileFuncDef)
        }
        
        if zipfp == nil && unzfp == nil {
            // ERROR
            return nil
        }
    }
    
    deinit {
        if !disposed {
            dispose()
        }
    }
    
    public func dispose() {
        if disposed {
            // ERROR
            return
        }
        
        if zipfp != nil {
            zipClose(zipfp, nil)
            zipfp = nil
        }
        if unzfp != nil {
            unzClose(unzfp)
            unzfp = nil
        }
        disposed = true
    }
    
    public func createEntry(entryName: String) -> ZipArchiveEntry? {
        return createEntry(entryName, compressionLevel: .Default)
    }
    
    public func createEntry(entryName: String, compressionLevel: CompressionLevel) -> ZipArchiveEntry? {
        if zipfp == nil || entryName == "" {
            return nil
        }
        guard let entry = ZipArchiveEntry(owner: self, entryName: entryName, compressionLevel: compressionLevel) else {
            return nil
        }
        _entries.append(entry)
        return entry
    }
    
    public func getEntry(entryName: String) -> ZipArchiveEntry? {
        if entryName == "" {
            return nil
        }
        for entry in entries {
            if entry.fullName == entryName {
                return entry
            }
        }
        return nil
    }

    private func readEntries() {
        var err = unzGoToFirstFile(unzfp)
        while err == UNZ_OK {
            guard let entry = ZipArchiveEntry(owner: self) else {
                break
            }
            _entries.append(entry)
            err = unzGoToNextFile(unzfp)
        }
    }
    
}

public extension ZipArchive {
    
    public convenience init?(path: String) {
        self.init(path: path, mode: .Read, entryNameEncoding: NSUTF8StringEncoding, passwordEncoding: NSASCIIStringEncoding)
    }
    
    public convenience init?(path: String, mode: ZipArchiveMode) {
        self.init(path: path, mode: mode, entryNameEncoding: NSUTF8StringEncoding, passwordEncoding: NSASCIIStringEncoding)
    }
    
    public convenience init?(path: String, mode: ZipArchiveMode, entryNameEncoding: NSStringEncoding) {
        self.init(path: path, mode: mode, entryNameEncoding: entryNameEncoding, passwordEncoding: NSASCIIStringEncoding)
    }
    
    public convenience init?(path: String, mode: ZipArchiveMode, entryNameEncoding: NSStringEncoding, passwordEncoding: NSStringEncoding) {
        var stream: ZipArchiveStream? = nil
        switch mode {
        case .Read:
            if let fileHandle = NSFileHandle(forReadingAtPath: path) {
                stream = ZipArchiveFileStream(fileHandle: fileHandle, closeOnDealloc: true)
            }
        case .Create:
            let fm = NSFileManager.defaultManager()
            if !fm.fileExistsAtPath(path) {
                fm.createFileAtPath(path, contents: nil, attributes: nil)
            }
            if let fileHandle = NSFileHandle(forWritingAtPath: path) {
                stream = ZipArchiveFileStream(fileHandle: fileHandle, closeOnDealloc: true)
            }
        }
        if stream == nil {
            return nil
        }
        self.init(stream: stream!, mode: mode, entryNameEncoding: entryNameEncoding, passwordEncoding: passwordEncoding)
    }
    
}

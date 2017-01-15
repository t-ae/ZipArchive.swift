//
//  ZipArchive.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/07.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation

public class ZipArchive {

    internal var stream: IOStream
    internal let mode: ZipArchiveMode
    internal let entryNameEncoding: String.Encoding
    internal let passwordEncoding: String.Encoding

    internal var zip: Zip? = nil
    internal var unzip: Unzip? = nil

    private var _entries = [ZipArchiveEntry]()
    public var entries: AnySequence<ZipArchiveEntry> {
        return AnySequence { [unowned self]() -> AnyIterator<ZipArchiveEntry> in
            var index = 0
            return AnyIterator { () -> ZipArchiveEntry? in
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

    public init?(stream: IOStream, mode: ZipArchiveMode, entryNameEncoding: String.Encoding, passwordEncoding: String.Encoding) {
        self.stream = stream
        self.mode = mode
        self.entryNameEncoding = entryNameEncoding
        self.passwordEncoding = passwordEncoding

        switch mode {
        case .read:
            if !stream.canRead {
                // ERROR
                return nil
            }
            if let unzip = Unzip(stream: stream) {
                self.unzip = unzip
                guard readEntries(unzip: unzip) else {
                    return nil
                }
            }
        case .create:
            if !stream.canWrite {
                // ERROR
                return nil
            }
            self.zip = Zip(stream: stream)
        }

        if zip == nil && unzip == nil {
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

        zip?.finalize()
        zip = nil
        
        unzip = nil
        
        disposed = true
    }

    public func createEntry(entryName: String) -> ZipArchiveEntry? {
        return createEntry(entryName: entryName, compressionLevel: .default)
    }

    public func createEntry(entryName: String, compressionLevel: CompressionLevel) -> ZipArchiveEntry? {
        if zip == nil || entryName == "" {
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

    private func readEntries(unzip: Unzip) -> Bool {
        for centralDirectoryHeader in unzip.centralDirectoryHeaders {
            guard let entry = ZipArchiveEntry(owner: self, centralDirectoryHeader: centralDirectoryHeader) else {
                return false
            }
            _entries.append(entry)
        }
        return true
    }

}

public extension ZipArchive {

    public convenience init?(path: String) {
        self.init(path: path, mode: .read, entryNameEncoding: .utf8, passwordEncoding: .ascii)
    }

    public convenience init?(path: String, mode: ZipArchiveMode) {
        self.init(path: path, mode: mode, entryNameEncoding: .utf8, passwordEncoding: .ascii)
    }

    public convenience init?(path: String, mode: ZipArchiveMode, entryNameEncoding: String.Encoding) {
        self.init(path: path, mode: mode, entryNameEncoding: entryNameEncoding, passwordEncoding: .ascii)
    }

    public convenience init?(path: String, mode: ZipArchiveMode, entryNameEncoding: String.Encoding, passwordEncoding: String.Encoding) {
        var stream: IOStream? = nil
        switch mode {
        case .read:
            if let fileHandle = FileHandle(forReadingAtPath: path) {
                stream = ZipArchiveFileStream(fileHandle: fileHandle, closeOnDealloc: true)
            }
        case .create:
            let fm = FileManager.default
            if !fm.fileExists(atPath: path) {
                fm.createFile(atPath: path, contents: nil, attributes: nil)
            }
            if let fileHandle = FileHandle(forWritingAtPath: path) {
                stream = ZipArchiveFileStream(fileHandle: fileHandle, closeOnDealloc: true)
            }
        }
        if stream == nil {
            return nil
        }
        self.init(stream: stream!, mode: mode, entryNameEncoding: entryNameEncoding, passwordEncoding: passwordEncoding)
    }

}

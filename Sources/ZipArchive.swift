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

    public init(
        stream: IOStream,
        mode: ZipArchiveMode,
        entryNameEncoding: String.Encoding,
        passwordEncoding: String.Encoding) throws {
        
        self.stream = stream
        self.mode = mode
        self.entryNameEncoding = entryNameEncoding
        self.passwordEncoding = passwordEncoding

        switch mode {
        case .read:
            if !stream.canRead {
                // stream can not read
                throw ZipError.argument
            }
            let unzip = try Unzip(stream: stream)
            try readEntries(unzip: unzip)
            self.unzip = unzip
        case .create:
            if !stream.canWrite {
                // stream can not write
                throw ZipError.argument
            }
            self.zip = Zip(stream: stream)
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

    public func createEntry(entryName: String, compressionLevel: CompressionLevel = .default) throws -> ZipArchiveEntry {
        if zip == nil || entryName == "" {
            throw ZipError.argument
        }
        let entry = ZipArchiveEntry(owner: self, entryName: entryName, compressionLevel: compressionLevel)
        _entries.append(entry)
        return entry
    }

    public func getEntry(entryName: String) throws -> ZipArchiveEntry {
        if entryName == "" {
            throw ZipError.argument
        }
        for entry in entries {
            if entry.fullName == entryName {
                return entry
            }
        }
        throw ZipError.argument
    }

    private func readEntries(unzip: Unzip) throws {
        for centralDirectoryHeader in unzip.centralDirectoryHeaders {
            let entry = try ZipArchiveEntry(owner: self, centralDirectoryHeader: centralDirectoryHeader)
            _entries.append(entry)
        }
    }

}

public extension ZipArchive {

    public convenience init(
        path: String,
        mode: ZipArchiveMode = .read,
        entryNameEncoding: String.Encoding = .utf8,
        passwordEncoding: String.Encoding = .ascii) throws {
        
        var stream: IOStream? = nil
        switch mode {
        case .read:
            if let fileHandle = FileHandle(forReadingAtPath: path) {
                stream = ZipArchiveFileStream(fileHandle: fileHandle, closeOnDealloc: true)
            }
        case .create:
            let fm = FileManager.default
            if fm.fileExists(atPath: path) {
                throw ZipError.io
            }
            fm.createFile(atPath: path, contents: nil, attributes: nil)
            if let fileHandle = FileHandle(forWritingAtPath: path) {
                stream = ZipArchiveFileStream(fileHandle: fileHandle, closeOnDealloc: true)
            }
        }
        if stream == nil {
            throw ZipError.io
        }
        try self.init(stream: stream!, mode: mode, entryNameEncoding: entryNameEncoding, passwordEncoding: passwordEncoding)
    }

}

//
//  ZipArchiveEntryStream.StoreStream.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/14.
//  Copyright © 2017年 yaslab. All rights reserved.
//

import Foundation

internal class ZipArchiveEntryUnzipStream_store: IOStream {
    
    private weak var archiveEntry: ZipArchiveEntry?
    private let unzip: Unzip
    
    private var isStreamEnd = false
    
    internal init?(archiveEntry: ZipArchiveEntry) {
        self.archiveEntry = archiveEntry
        
        guard let unzip = archiveEntry.archive?.unzip else {
            return nil
        }
        self.unzip = unzip
        
        let success = open()
        if !success {
            return nil
        }
    }
    
    internal var canRead: Bool {
        return true
    }
    
    internal var canSeek: Bool {
        return false
    }
    
    internal var canWrite: Bool {
        return false
    }
    
    private var _position: UInt64 = 0
    internal var position: UInt64 {
        return _position
    }
    
    private func open() -> Bool {
        guard let archiveEntry = archiveEntry else {
            // ERROR
            return false
        }
        
        // unzip では必ず値が入っている
        guard let centralDirectoryHeader = archiveEntry.centralDirectoryHeader else {
            return false
        }
        
        guard let (localHeader, byteSize) = unzip.openFile(centralDirectoryHeader: centralDirectoryHeader) else {
            return false
        }
        
        return true
    }
    
    internal func close() -> Bool {
        unzip.closeFile()
        return true
    }
    
    internal func read(buffer: UnsafeMutableRawPointer, maxLength len: Int) -> Int {
        return unzip.stream.read(buffer: buffer, maxLength: len)
    }
    
    func seek(offset: Int, origin: SeekOrigin) -> Int {
        return -1
    }
    
    func write(buffer: UnsafeRawPointer, maxLength len: Int) -> Int {
        return -1
    }
    
}

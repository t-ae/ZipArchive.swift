//
//  ZipArchiveEntryStream.Store.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/15.
//  Copyright © 2017 yaslab. All rights reserved.
//

import Foundation

class StoreStream: ZipArchiveEntryStream {
    
    private let stream: IOStream
    private let closeHandler: (() -> Void)
    
    init(stream: IOStream, closeHandler: @escaping (() -> Void)) {
        self.stream = stream
        self.closeHandler = closeHandler
    }
    
    var canRead: Bool {
        return stream.canRead
    }
    
    var canSeek: Bool {
        return false
    }
    
    var canWrite: Bool {
        return stream.canWrite
    }
    
    var position: UInt64 {
        // Not Supported
        preconditionFailure()
    }
    
    func close() -> Bool {
        closeHandler()
        return true
    }
    
    func read(buffer: UnsafeMutableRawPointer, maxLength len: Int) -> Int {
        return stream.read(buffer: buffer, maxLength: len)
    }
    
    func seek(offset: Int, origin: SeekOrigin) -> Int {
        // Not Supported
        preconditionFailure()
    }
    
    func write(buffer: UnsafeRawPointer, maxLength len: Int) -> Int {
        return stream.write(buffer: buffer, maxLength: len)
    }
    
}

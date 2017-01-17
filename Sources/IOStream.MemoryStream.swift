//
//  Stream.MemoryStream.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/11.
//  Copyright © 2017 yaslab. All rights reserved.
//

import Foundation

public class ZipArchiveMemoryStream: IOStream {
    
    internal let _data: NSData
    internal var _offset: Int
    
    public var data: NSData {
        return _data
    }
    
    public init(data: NSData) {
        _data = data
        _offset = 0
    }
    
    public var canRead: Bool {
        return true
    }
    
    public var canSeek: Bool {
        return true
    }
    
    public var canWrite: Bool {
        if let _ = _data as? NSMutableData {
            return true
        }
        return false
    }
    
    public var position: UInt64 {
        return UInt64(_offset)
    }
    
    public func read(buffer: UnsafeMutableRawPointer, maxLength len: Int) -> Int {
        var length = len
        if _offset + length > _data.length {
            length = _data.length - _offset
        }
        let range = NSRange(location: _offset, length: length)
        _data.getBytes(buffer, range: range)
        _offset += length
        return length
    }
    
    public func seek(offset: Int, origin: SeekOrigin) -> Int {
        var maxOffset: Int = 0
        if _data.length > 0 {
            maxOffset = _data.length - 1
        }
        
        var newOffset: Int
        switch origin {
        case .begin:
            newOffset = offset
        case .current:
            newOffset = _offset + offset
        case .end:
            newOffset = maxOffset + offset
        }
        
        if newOffset < 0 || newOffset > maxOffset {
            errno = EINVAL
            return -1 // ERROR
        }
        
        _offset = newOffset
        return 0 // SUCCESS
    }
    
    public func close() -> Bool {
        return true
    }
    
    public func write(buffer: UnsafeRawPointer, maxLength len: Int) -> Int {
        let mutableData = _data as! NSMutableData
        if _offset + len > mutableData.length {
            mutableData.length = _offset + len
        }
        let range = NSRange(location: _offset, length: len)
        mutableData.replaceBytes(in: range, withBytes: buffer, length: len)
        _offset += len
        return len
    }
    
}

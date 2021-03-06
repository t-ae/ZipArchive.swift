//
//  ZipArchiveStream.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2016/01/26.
//  Copyright © 2016 yaslab. All rights reserved.
//

import Foundation

public enum SeekOrigin {
    
    case begin
    case current
    case end
    
}

public protocol ZipArchiveStream: class {

    var canRead: Bool { get }
    var canSeek: Bool { get }
    var canWrite: Bool { get }
    var position: UInt64 { get }
    
    func close() -> Bool
    func read(buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int
    func seek(offset: Int, origin: SeekOrigin) -> Int
    func write(buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int

}

// -----------------------------------------------------------------------------

public class ZipArchiveFileStream: ZipArchiveStream {

    private let _fileHandle: FileHandle
    private let _closeopt: Bool

    public var fileHandle: FileHandle {
        return _fileHandle
    }

    public convenience init(fileHandle: FileHandle) {
        self.init(fileHandle: fileHandle, closeOnDealloc: false)
    }

    public init(fileHandle: FileHandle, closeOnDealloc closeopt: Bool) {
        _fileHandle = fileHandle
        _closeopt = closeopt
    }
    
    deinit {
        if _closeopt {
            _ = close()
        }
    }

    public var canRead: Bool {
        // TODO: return false if stream closed
        
        // O_RDONLY, O_WRONLY, O_RDWR
        let flag = fcntl(_fileHandle.fileDescriptor, F_GETFL)
        if (flag | O_RDONLY) != 0 {
            return true
        }
        if (flag | O_RDWR) != 0 {
            return true
        }
        return false
    }
    
    public var canSeek: Bool {
        // TODO: return false if stream closed
        // TODO: return false if `_fileHandle` representing a pipe or socket
        
        return true
    }
    
    public var canWrite: Bool {
        // TODO: return false if stream closed
        
        // O_RDONLY, O_WRONLY, O_RDWR
        let flag = fcntl(_fileHandle.fileDescriptor, F_GETFL)
        if (flag | O_WRONLY) != 0 {
            return true
        }
        if (flag | O_RDWR) != 0 {
            return true
        }
        return false
    }
    
    public var position: UInt64 {
        return _fileHandle.offsetInFile
    }
    
    public func read(buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        if len <= 0 {
            return 0
        }
        let readLen = Darwin.read(_fileHandle.fileDescriptor, buffer, len)
        if readLen < 0 {
            return 0 // ERROR
        }
        return readLen
    }
    
    public func seek(offset: Int, origin: SeekOrigin) -> Int {
        var whence: Int32
        switch origin {
        case .begin:
            whence = SEEK_SET
        case .current:
            whence = SEEK_CUR
        case .end:
            whence = SEEK_END
        }
        if lseek(_fileHandle.fileDescriptor, off_t(offset), whence) < 0 {
            return -1 // ERROR
        }
        return 0 // SUCCESS
    }

    public func close() -> Bool {
        _fileHandle.closeFile()
        return true
    }
    
    public func write(buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        if len <= 0 {
            return 0
        }
        let writeLen = Darwin.write(_fileHandle.fileDescriptor, buffer, len)
        if writeLen < 0 {
            return 0 // ERROR
        }
        return writeLen
    }
    
}

// -----------------------------------------------------------------------------

public class ZipArchiveMemoryStream: ZipArchiveStream {

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
    
    public func read(buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
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

    public func write(buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
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

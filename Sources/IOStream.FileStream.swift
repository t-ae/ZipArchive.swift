//
//  Stream.FileStream.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/11.
//  Copyright © 2017年 yaslab. All rights reserved.
//

import Foundation

public class ZipArchiveFileStream: IOStream {
    
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
    
    public func read(buffer: UnsafeMutableRawPointer, maxLength len: Int) -> Int {
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
    
    public func write(buffer: UnsafeRawPointer, maxLength len: Int) -> Int {
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

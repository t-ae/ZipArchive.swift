//
//  ZipArchiveEntryStream.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/08.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation
import Minizip

//func createError() -> NSError {
//    return NSError(domain: "ZipStreamErrorDomain", code: -1, userInfo: nil)
//}

// For zip
internal class ZipArchiveEntryZipStream: ZipArchiveStream {
    
    private weak var archiveEntry: ZipArchiveEntry?
    private let password: [CChar]?
    private let crc32: UInt
    private let isLargeFile: Bool
    
    private var fp: zipFile = nil
    
    internal init(archiveEntry: ZipArchiveEntry, password: [CChar]? = nil, crc32: UInt = 0, isLargeFile: Bool = false) {
        self.archiveEntry = archiveEntry
        self.password = password
        self.crc32 = crc32
        self.isLargeFile = isLargeFile
        
        open()
        //super.init(toMemory: ())
    }
    
    
    
    internal var canRead: Bool {
        return false
    }
    
    internal var canSeek: Bool {
        return false
    }
    
    internal var canWrite: Bool {
        return true
    }
    
    private var _position: UInt64 = 0
    internal var position: UInt64 {
        return _position
    }
    
    
    
    // MARK: - NSStream
    
    private func open() {
        //if _streamStatus != .NotOpen {
        //    _streamStatus = .Error
        //    _streamError = createError()
        //    return
        //}
        //_streamStatus = .Opening

        guard let archiveEntry = archiveEntry else {
            // ERROR
            return
        }
        
        guard let archive = archiveEntry.archive else {
            // ERROR
            return
        }

        let tm = tmZip(fromDate: archiveEntry.lastWriteTime)
        
        var mode = archiveEntry.filePermissions
        if archiveEntry.fileType == .Directory {
            mode = mode | S_IFDIR
        }
        else if archiveEntry.fileType == .SymbolicLink {
            mode = mode | S_IFLNK
        }
        else {
            mode = mode | S_IFREG
        }
        let fa = UInt(mode) << 16
        
        var fileInfo = zip_fileinfo(tmz_date: tm, dosDate: 0, internal_fa: 0, external_fa: fa)
        
        fp = archive.zipfp

        let compressionLevel = archiveEntry.compressionLevel.toRawValue()

        var pwd: UnsafePointer<CChar> = nil
        if let password = password {
            pwd = UnsafePointer<CChar>(password)
        }

        let zip64: Int32 = isLargeFile ? 1 : 0
        
        if zipOpenNewFileInZip3_64(fp, archiveEntry.fileNameInZip, &fileInfo, nil, 0, nil, 0, nil, Z_DEFLATED, compressionLevel, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, pwd, crc32, zip64) != ZIP_OK {
            //_streamStatus = .Error
            //_streamError = createError()
            return
        }
        
        //_streamStatus = .Open
    }
    
    internal func close() {
        if zipCloseFileInZip(fp) != ZIP_OK {
            //_streamStatus = .Error
            //_streamError = createError()
        }
        //if _streamStatus != .Error {
        //    _streamStatus = .Closed
        //}
    }
    
    //private var _streamStatus: NSStreamStatus = .NotOpen
    //internal override var streamStatus: NSStreamStatus {
    //    return _streamStatus
    //}
    
    //private var _streamError: NSError? = nil
    /* @NSCopying */ //internal override var streamError: NSError? {
        //return _streamError?.copy() as? NSError
    //}
    
    // MARK: - NSOutputStream
    
    internal func write(buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        //if _streamStatus == .Error {
        //    return -1
        //}
        //if _streamStatus == .Open {
        //    _streamStatus = .Writing
        //}
        //if _streamStatus != .Writing {
        //    _streamStatus = .Error
        //    _streamError = createError()
        //    return -1
        //}
        let err = zipWriteInFileInZip(fp, buffer, UInt32(len))
        if err <= ZIP_ERRNO {
            //_streamStatus = .Error
            //_streamError = createError()
            return -1
        }
        _position += UInt64(len)
        return len
    }
    
    //internal override var hasSpaceAvailable: Bool {
    //    get {
    //        switch _streamStatus {
    //        case .NotOpen, .Opening, .Open, .Writing:
    //            return true
    //        default:
    //            return false
    //        }
    //    }
    //}
    
    
    
    internal func read(buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        return -1
    }

    internal func seek(offset: Int, origin: SeekOrigin) -> Int {
        return -1
    }
    
}

// -----------------------------------------------------------------------------

// For unzip
internal class ZipArchiveEntryUnzipStream: ZipArchiveStream {
    
    private weak var archiveEntry: ZipArchiveEntry?
    private let password: [CChar]?
    private let innerBufferSize: Int
    private var innerBuffer: UnsafeMutablePointer<UInt8> = nil
    
    private var fp: unzFile = nil
    
    internal init(archiveEntry: ZipArchiveEntry, password: [CChar]? = nil, innerBufferSize: Int = kZipArchiveDefaultBufferSize) {
        self.archiveEntry = archiveEntry
        self.password = password
        self.innerBufferSize = innerBufferSize
        
        open()
        //super.init(data: NSData())
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
    
    
    
    // MARK: - NSStream
    
    private func open() {
        //if _streamStatus != .NotOpen {
        //    _streamStatus = .Error
        //    _streamError = createError()
        //    return
        //}
        //_streamStatus = .Opening
        
        guard let archiveEntry = archiveEntry else {
            // ERROR
            return
        }
        
        guard let archive = archiveEntry.archive else {
            // ERROR
            return
        }
        
        fp = archive.unzfp
        
        if unzLocateFile(fp, archiveEntry.fileNameInZip, nil) != UNZ_OK {
            //_streamStatus = .Error
            //_streamError = createError()
            return
        }
        
        if let password = password {
            if unzOpenCurrentFilePassword(fp, password) != UNZ_OK {
                //_streamStatus = .Error
                //_streamError = createError()
                return
            }
        }
        else {
            if unzOpenCurrentFile(fp) != UNZ_OK {
                //_streamStatus = .Error
                //_streamError = createError()
                return
            }
        }
        
        //_streamStatus = .Open
    }
    
    internal func close() {
        if unzCloseCurrentFile(fp) != UNZ_OK {
            //_streamStatus = .Error
            //_streamError = createError()
        }
        if innerBuffer != nil {
            innerBuffer.destroy()
            innerBuffer.dealloc(innerBufferSize)
            innerBuffer = nil
        }
        //if _streamStatus != .Error {
        //    _streamStatus = .Closed
        //}
    }
    
    //private var _streamStatus: NSStreamStatus = .NotOpen
    //internal override var streamStatus: NSStreamStatus {
    //    return _streamStatus
    //}
    
    //private var _streamError: NSError? = nil
    /* @NSCopying */ //internal override var streamError: NSError? {
        //return _streamError?.copy() as? NSError
    //}
    
    // MARK: - NSInputStream
    
    internal func read(buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        //if _streamStatus == .Error {
        //    return -1
        //}
        //if _streamStatus == .Open {
        //    _streamStatus = .Reading
       // }
        //if _streamStatus != .Reading {
        //    _streamStatus = .Error
        //    _streamError = createError()
        //    return -1
        //}
        let readBytes = unzReadCurrentFile(fp, buffer, UInt32(len))
        //if readBytes <= UNZ_ERRNO {
        //    _streamStatus = .Error
        //    _streamError = createError()
        //}
        //else if readBytes == UNZ_EOF {
        //    _streamStatus = .AtEnd
        //}
        _position += UInt64(readBytes)
        return Int(readBytes)
    }
    
//    internal override func getBuffer(buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>>, length len: UnsafeMutablePointer<Int>) -> Bool {
//        if innerBuffer == nil {
//            innerBuffer = UnsafeMutablePointer<UInt8>.alloc(innerBufferSize)
//        }
//        let bytes = read(innerBuffer, maxLength: innerBufferSize)
//        if bytes == Int(UNZ_EOF) || bytes <= Int(UNZ_ERRNO) {
//            return false
//        }
//        buffer.memory = innerBuffer
//        len.memory = min(innerBufferSize, bytes)
//        return true
//    }
    
//    internal override var hasBytesAvailable: Bool {
//        get {
//            switch _streamStatus {
//            case .NotOpen, .Opening, .Open, .Reading:
//                return true
//            default:
//                return false
//            }
//        }
//    }
    
    func seek(offset: Int, origin: SeekOrigin) -> Int {
        return -1
    }
    
    func write(buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        return -1
    }
    
}

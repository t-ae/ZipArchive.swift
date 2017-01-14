//
//  ZipArchiveEntryStream.InflateStream.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/14.
//  Copyright © 2017年 yaslab. All rights reserved.
//

import Foundation

// For unzip
internal class InflateStream: ZipArchiveEntryStream {
    
    private weak var archiveEntry: ZipArchiveEntry?
    private let unzip: Unzip
    private let inflate: InflateHelper
    
    private var isStreamEnd = false
    
    //private weak var archiveEntry: ZipArchiveEntry?
    //private let password: [CChar]?
    
    //private var fp: unzFile? = nil
    
    internal init?(archiveEntry: ZipArchiveEntry/*, password: [CChar]? = nil*/) {
        self.archiveEntry = archiveEntry
        //self.password = password
        
        guard let unzip = archiveEntry.archive?.unzip else {
            return nil
        }
        self.unzip = unzip
        
        // unzip では必ず値が入っている
        guard let centralDirectoryHeader = archiveEntry.centralDirectoryHeader else {
            return nil
        }
        
        guard let inflate = InflateHelper(compressedSize: Int(centralDirectoryHeader.compressedSize)) else {
            return nil
        }
        self.inflate = inflate
        
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
        //
        //        guard let unzip = archiveEntry.archive?.unzip else {
        //            // ERROR
        //            return false
        //        }
        
        //fp = archive.unzfp
        
        //        if unzLocateFile(fp, archiveEntry.fileNameInZip, nil) != UNZ_OK {
        //            return false
        //        }
        //
        //        if let password = password {
        //            if unzOpenCurrentFilePassword(fp, password) != UNZ_OK {
        //                return false
        //            }
        //        }
        //        else {
        //            if unzOpenCurrentFile(fp) != UNZ_OK {
        //                return false
        //            }
        //        }
        
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
        //        if unzCloseCurrentFile(fp) != UNZ_OK {
        //            return false
        //        }
        //        guard let archiveEntry = archiveEntry else {
        //            // ERROR
        //            return false
        //        }
        //
        //        guard let unzip = archiveEntry.archive?.unzip else {
        //            // ERROR
        //            return false
        //        }
        
        unzip.closeFile()
        inflate.inflateEnd()
        
        return true
    }
    
    internal func read(buffer: UnsafeMutableRawPointer, maxLength len: Int) -> Int {
        //let readBytes = unzReadCurrentFile(fp, buffer, UInt32(len))
        //let readBytes = unzip.stream.read(buffer: buffer, maxLength: len)
        
        if self.isStreamEnd {
            return 0
        }
        
        let (outBytes, isStreamEnd) = inflate.inflate(inStream: unzip.stream, outBuffer: buffer, outBufferSize: len)
        
        if outBytes > 0 {
            _position += UInt64(outBytes)
        }
        
        self.isStreamEnd = isStreamEnd
        
        return outBytes
    }
    
    func seek(offset: Int, origin: SeekOrigin) -> Int {
        return -1
    }
    
    func write(buffer: UnsafeRawPointer, maxLength len: Int) -> Int {
        return -1
    }
    
}

//
//  ZipArchiveEntryStream.DeflateStream.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/14.
//  Copyright © 2017年 yaslab. All rights reserved.
//

import Foundation

// For zip
internal class DeflateStream: ZipArchiveEntryStream {
    
    private weak var archiveEntry: ZipArchiveEntry?
    private let zip: Zip
    private let deflate: DeflateHelper
    private let crypt: ZipCrypto?
    //private let password: [CChar]?
    //private let crc32: UInt
    //private let isLargeFile: Bool
    
    //private var fp: zipFile? = nil
    
    private var localFileHeader: LocalFileHeader? = nil
    
    
    
    private var isStreamEnd = false
    
    internal init?(archiveEntry: ZipArchiveEntry, password: [CChar]? = nil, crc32: UInt32 = 0/*, isLargeFile: Bool = false*/) {
        self.archiveEntry = archiveEntry
        if let password = password {
            self.crypt = ZipCrypto(password: password, crc32ForCrypting: crc32, crc32Table: getCRCTable())
        } else {
            self.crypt = nil
        }
        //self.password = password
        //self.crc32 = crc32
        //self.isLargeFile = isLargeFile
        
        let compressionLevel = archiveEntry.compressionLevel
        
        guard let zip = archiveEntry.archive?.zip else {
            return nil
        }
        self.zip = zip
        
        guard let deflate = DeflateHelper(compressionLevel: compressionLevel) else {
            return nil
        }
        self.deflate = deflate
        
        let success = open()
        if !success {
            return nil
        }
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
    
    private func open() -> Bool {
        guard let archiveEntry = archiveEntry else {
            // ERROR
            return false
        }
        
        guard let archive = archiveEntry.archive else {
            // ERROR
            return false
        }
        
        //let tm = tmZip(fromDate: archiveEntry.lastWriteTime)
        let (date, time) = ZipUtility.convertDateTime(date: archiveEntry.lastWriteTime)
        
        guard let fileName = archiveEntry.fullName.cString(using: archive.entryNameEncoding) else {
            return false
        }
        let fileNameLength = UInt16(strlen(fileName))
        
        
        
        //var fileInfo = zip_fileinfo(tmz_date: tm, dosDate: 0, internal_fa: 0, external_fa: fa)
        
        //fp = archive.zipfp
        
        //        let compressionLevel = archiveEntry.compressionLevel.toRawValue()
        
        //        var pwd: UnsafePointer<CChar>? = nil
        //        if let password = password {
        //            pwd = UnsafePointer<CChar>(password)
        //        }
        
        //        let zip64: Int32 = isLargeFile ? 1 : 0
        //
        //        if zipOpenNewFileInZip3_64(fp, archiveEntry.fileNameInZip, &fileInfo, nil, 0, nil, 0, nil, Z_DEFLATED, compressionLevel, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, pwd, crc32, zip64) != ZIP_OK {
        //            return false
        //        }
        
        // TODO: ここでヘッダを書き出さず、もっと上位でやる
        let localFileHeader = LocalFileHeader(
            versionNeededToExtract: 20, // TODO:
            generalPurposeBitFlag: 0b0000_0000_0000_1000, // TODO:
            compressionMethod: 8, // TODO:
            lastModFileTime: time,
            lastModFileDate: date,
            crc32: 0,
            compressedSize: 0,
            uncompressedSize: 0,
            fileNameLength: fileNameLength,
            extraFieldLength: 0,
            fileName: fileName,
            extraField: [])
        self.localFileHeader = localFileHeader
        
        guard zip.openNewFile(localFileHeader: localFileHeader, crypt: self.crypt) == true else {
            return false
        }
        
        return true
    }
    
    internal func close() -> Bool {
        //if zipCloseFileInZip(fp) != ZIP_OK {
        //    return false
        //}
        
        
        
        
        guard let archiveEntry = archiveEntry else {
            // ERROR
            return false
        }
        guard let localFileHeader = localFileHeader else {
            // ERROR
            return false
        }
        
        
        var mode = archiveEntry.filePermissions
        if archiveEntry.fileType == .directory {
            mode = mode | S_IFDIR
        }
        else if archiveEntry.fileType == .symbolicLink {
            mode = mode | S_IFLNK
        }
        else {
            mode = mode | S_IFREG
        }
        let fileAttributes = UInt32(mode) << 16
        
        
        let dataDescriptor = DataDescriptor(
            crc32: UInt32(deflate.crc32),
            compressedSize: UInt32(deflate.compressedSize),
            uncompressedSize: UInt32(deflate.uncompressedSize))
        
        zip.closeFile(localFileHeader: localFileHeader, dataDescriptor: dataDescriptor, fileAttributes: fileAttributes)
        deflate.deflateEnd()
        
        return true
    }
    
    internal func read(buffer: UnsafeMutableRawPointer, maxLength len: Int) -> Int {
        return -1
    }
    
    internal func seek(offset: Int, origin: SeekOrigin) -> Int {
        return -1
    }
    
    internal func write(buffer: UnsafeRawPointer, maxLength len: Int) -> Int {
        //let err = zipWriteInFileInZip(fp, buffer, UInt32(len))
        //if err <= ZIP_ERRNO {
        //    return -1
        //}
        
        if self.isStreamEnd {
            return 0
        }
        
        let (inBytes, isStreamEnd) = deflate.deflate(outStream: zip.stream, crypt: crypt, inBuffer: buffer, inBufferSize: len)
        
        _position += UInt64(inBytes)
        
        self.isStreamEnd = isStreamEnd
        
        return inBytes
    }
    
}

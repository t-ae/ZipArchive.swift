//
//  ZipArchiveEntryStream.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/08.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation
import minizip

// For zip
internal class ZipArchiveEntryZipStream: ZipArchiveStream {

    private weak var archiveEntry: ZipArchiveEntry?
    private let password: [CChar]?
    private let crc32: UInt
    private let isLargeFile: Bool

    private var fp: zipFile? = nil

    internal init?(archiveEntry: ZipArchiveEntry, password: [CChar]? = nil, crc32: UInt = 0, isLargeFile: Bool = false) {
        self.archiveEntry = archiveEntry
        self.password = password
        self.crc32 = crc32
        self.isLargeFile = isLargeFile

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

        let tm = tmZip(fromDate: archiveEntry.lastWriteTime)

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
        let fa = UInt(mode) << 16

        var fileInfo = zip_fileinfo(tmz_date: tm, dosDate: 0, internal_fa: 0, external_fa: fa)

        fp = archive.zipfp

        let compressionLevel = archiveEntry.compressionLevel.toRawValue()

        var pwd: UnsafePointer<CChar>? = nil
        if let password = password {
            pwd = UnsafePointer<CChar>(password)
        }

        let zip64: Int32 = isLargeFile ? 1 : 0

        if zipOpenNewFileInZip3_64(fp, archiveEntry.fileNameInZip, &fileInfo, nil, 0, nil, 0, nil, Z_DEFLATED, compressionLevel, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, pwd, crc32, zip64) != ZIP_OK {
            return false
        }

        return true
    }

    internal func close() -> Bool {
        if zipCloseFileInZip(fp) != ZIP_OK {
            return false
        }
        return true
    }

    internal func read(buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        return -1
    }

    internal func seek(offset: Int, origin: SeekOrigin) -> Int {
        return -1
    }

    internal func write(buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        let err = zipWriteInFileInZip(fp, buffer, UInt32(len))
        if err <= ZIP_ERRNO {
            return -1
        }
        _position += UInt64(len)
        return len
    }

}

// -----------------------------------------------------------------------------

// For unzip
internal class ZipArchiveEntryUnzipStream: ZipArchiveStream {

    private weak var archiveEntry: ZipArchiveEntry?
    private let password: [CChar]?

    private var fp: unzFile? = nil

    internal init?(archiveEntry: ZipArchiveEntry, password: [CChar]? = nil) {
        self.archiveEntry = archiveEntry
        self.password = password

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

        guard let archive = archiveEntry.archive else {
            // ERROR
            return false
        }

        fp = archive.unzfp

        if unzLocateFile(fp, archiveEntry.fileNameInZip, nil) != UNZ_OK {
            return false
        }

        if let password = password {
            if unzOpenCurrentFilePassword(fp, password) != UNZ_OK {
                return false
            }
        }
        else {
            if unzOpenCurrentFile(fp) != UNZ_OK {
                return false
            }
        }

        return true
    }

    internal func close() -> Bool {
        if unzCloseCurrentFile(fp) != UNZ_OK {
            return false
        }
        return true
    }

    internal func read(buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        let readBytes = unzReadCurrentFile(fp, buffer, UInt32(len))

        _position += UInt64(readBytes)
        return Int(readBytes)
    }

    func seek(offset: Int, origin: SeekOrigin) -> Int {
        return -1
    }

    func write(buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        return -1
    }

}

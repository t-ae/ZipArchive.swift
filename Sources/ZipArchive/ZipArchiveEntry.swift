//
//  ZipArchiveEntry.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/17.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation
import CMinizip

public class ZipArchiveEntry {

    public private(set) weak var archive: ZipArchive?

    internal let fileNameInZip: [CChar]
    public let fullName: String
    public let name: String

    public private(set) var length: UInt64
    public private(set) var compressedLength: UInt64
    internal let compressionLevel: CompressionLevel

    public var lastWriteTime: NSDate
    public var filePermissions: UInt16
    public var fileType: FileType

    // For unzip
    internal init?(owner: ZipArchive) {
        self.archive = owner

        var fileInfo = unz_file_info64()
        var fileNameInZip = [CChar]()
        var err = unzGetCurrentFileInfo64(owner.unzfp, &fileInfo, nil, 0, nil, 0, nil, 0)
        if err == UNZ_OK {
            fileNameInZip = [CChar](repeating: 0, count: Int(fileInfo.size_filename) + 1)
            err = unzGetCurrentFileInfo64(owner.unzfp, nil, &fileNameInZip, fileInfo.size_filename, nil, 0, nil, 0)
        }
        if err != UNZ_OK {
            return nil
        }

        self.fileNameInZip = fileNameInZip

        guard let fullName = String(cString: fileNameInZip, encoding: owner.entryNameEncoding) else {
            return nil
        }
        self.fullName = fullName
        self.name = (fullName as NSString).lastPathComponent

        self.length = fileInfo.uncompressed_size
        self.compressedLength = fileInfo.compressed_size

        var compressionLevel = Z_DEFAULT_COMPRESSION
        var isNotSupportedCompressionMethod = false
        switch Int32(fileInfo.compression_method) {
        case 0: // Stored
            compressionLevel = Z_NO_COMPRESSION
        case Z_DEFLATED:
            let level = (fileInfo.flag & 0x06) >> 1
            if level == 0 {
                compressionLevel = Z_NO_COMPRESSION
            }
            else if level == 1 {
                compressionLevel = Z_BEST_COMPRESSION
            }
            else if level == 2 || level == 3 {
                // 2:fast, 3:extra fast
                compressionLevel = Z_BEST_SPEED
            }
        case Z_BZIP2ED:
            isNotSupportedCompressionMethod = true
        default:
            isNotSupportedCompressionMethod = true
        }
        if isNotSupportedCompressionMethod {
            return nil
        }
        self.compressionLevel = CompressionLevel.fromRawValue(rawValue: compressionLevel)

        var fileDate: NSDate!
        if let date = date(fromDosDate: fileInfo.dosDate) {
            fileDate = date
        }
        else {
            // ERROR
            fileDate = NSDate(timeIntervalSinceReferenceDate: 0)
        }
        self.lastWriteTime = fileDate

        let mode = mode_t(fileInfo.external_fa >> 16)
        self.filePermissions = mode
        self.fileType = FileType.fromRawValue(rawValue: mode)

        if self.fileType == .Unknown {
            return nil
        }
    }

    // For zip
    internal init?(owner: ZipArchive, entryName: String, compressionLevel: CompressionLevel) {
        self.archive = owner

        self.fullName = entryName
        self.name = (entryName as NSString).lastPathComponent

        guard let fileNameInZip = entryName.cString(using: owner.entryNameEncoding) else {
            return nil
        }
        self.fileNameInZip = fileNameInZip

        self.length = 0
        self.compressedLength = 0

        self.compressionLevel = compressionLevel

        self.lastWriteTime = NSDate()
        self.filePermissions = 0777
        self.fileType = .Regular
    }

    /// Open zip archive entry as `ZipArchiveStream`.
    /// - parameter password:
    /// - parameter crc32:
    /// - parameter isLargeFile:
    /// - returns:
    public func open(password: String? = nil, crc32: UInt = 0, isLargeFile: Bool = false) -> ZipArchiveStream? {
        guard let archive = archive else {
            return nil
        }

        var passwordCString: [CChar]? = nil
        if let password = password {
            if !password.isEmpty {
                passwordCString = password.cString(using: archive.passwordEncoding)
                if passwordCString == nil {
                    // CString encoding error
                    return nil
                }
            }
        }

        var stream: ZipArchiveStream?
        switch archive.mode {
        case .Read:
            stream = ZipArchiveEntryUnzipStream(archiveEntry: self, password: passwordCString)
            break
        case .Create:
            stream = ZipArchiveEntryZipStream(archiveEntry: self, password: passwordCString, crc32: crc32, isLargeFile: isLargeFile)
            break
        }
        return stream
    }

    // Not supported
    //public func delete() {
    //    self.archive = nil
    //}

}

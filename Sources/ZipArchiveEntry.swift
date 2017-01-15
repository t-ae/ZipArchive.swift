//
//  ZipArchiveEntry.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/17.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation
import Czlib

public class ZipArchiveEntry {

    public private(set) weak var archive: ZipArchive?
    internal var centralDirectoryHeader: CentralDirectoryHeader? = nil

    public let fullName: String
    public let name: String

    public var length: UInt64 {
        return UInt64(centralDirectoryHeader?.uncompressedSize ?? 0)
    }
    public var compressedLength: UInt64 {
        return UInt64(centralDirectoryHeader?.compressedSize ?? 0)
    }
    internal let compressionLevel: CompressionLevel

    public var lastWriteTime: Date
    public var filePermissions: UInt16
    public var fileType: FileType

    // For unzip
    internal init?(owner: ZipArchive, centralDirectoryHeader: CentralDirectoryHeader) {
        self.archive = owner
        self.centralDirectoryHeader = centralDirectoryHeader

        let fileNameInZip = centralDirectoryHeader.fileName
        guard let fullName = String(cString: fileNameInZip, encoding: owner.entryNameEncoding) else {
            return nil
        }
        self.fullName = fullName
        self.name = (fullName as NSString).lastPathComponent

        var compressionLevel = Z_DEFAULT_COMPRESSION
        var isNotSupportedCompressionMethod = false
        switch Int32(centralDirectoryHeader.compressionMethod) {
        case 0: // Stored
            compressionLevel = Z_NO_COMPRESSION
        case Z_DEFLATED:
            let level = (centralDirectoryHeader.generalPurposeBitFlag & 0x06) >> 1
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
        default:
            isNotSupportedCompressionMethod = true
        }
        if isNotSupportedCompressionMethod {
            return nil
        }
        self.compressionLevel = CompressionLevel.fromRawValue(rawValue: compressionLevel)

        self.lastWriteTime = ZipUtility.convertDateTime(date: centralDirectoryHeader.lastModFileDate, time: centralDirectoryHeader.lastModFileTime)

        let mode = mode_t(centralDirectoryHeader.externalFileAttributes >> 16)
        self.filePermissions = mode
        self.fileType = FileType.fromRawValue(rawValue: mode)

        if self.fileType == .unknown {
            return nil
        }
    }

    // For zip
    internal init?(owner: ZipArchive, entryName: String, compressionLevel: CompressionLevel) {
        self.archive = owner

        self.fullName = entryName
        self.name = (entryName as NSString).lastPathComponent

        self.compressionLevel = compressionLevel

        self.lastWriteTime = Date()
        self.filePermissions = 0777
        self.fileType = .regular
    }

    /// Open zip archive entry as `ZipArchiveStream`.
    /// - parameter password:
    /// - parameter crc32:
    /// - parameter isLargeFile:
    /// - returns:
    public func open(crypt: ZipCrypto? = nil, isLargeFile: Bool = false) -> ZipArchiveEntryStream? {
        guard let archive = archive else {
            return nil
        }

        var stream: ZipArchiveEntryStream?
        switch archive.mode {
        case .read:
            guard let unzip = archive.unzip else {
                return nil
            }
            guard let centralDirectoryHeader = centralDirectoryHeader else {
                return nil
            }

            guard let (localFileHeader, _) = unzip.openFile(centralDirectoryHeader: centralDirectoryHeader) else {
                return nil
            }
            
            // TODO: Validate localFileHeader, centralDirectoryHeader
            // ...
            
            switch Int32(centralDirectoryHeader.compressionMethod) {
            case 0: // Store
                stream = StoreStream(stream: archive.stream) {
                    unzip.closeFile()
                }
            case Z_DEFLATED:
                stream = DeflateStream(stream: archive.stream, mode: .decompress, leaveOpen: true) { (_, _, _) in
                    unzip.closeFile()
                }
            default:
                return nil
            }
            break
        case .create:
            guard let zip = archive.zip else {
                return nil
            }
            
            let (date, time) = ZipUtility.convertDateTime(date: lastWriteTime)
            
            guard let fileName = fullName.cString(using: archive.entryNameEncoding) else {
                return nil
            }
            let fileNameLength = UInt16(strlen(fileName))
            
            // TODO: ここでヘッダを書き出さず、もっと上位でやる????
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
            //self.localFileHeader = localFileHeader
            
            // TODO: remove crypt
            guard zip.openNewFile(localFileHeader: localFileHeader, crypt: crypt) == true else {
                return nil
            }
            
            var mode = filePermissions
            let type = fileType
            
            stream = DeflateStream(stream: archive.stream, compressionLevel: compressionLevel, leaveOpen: true) { (crc32, compressedSize, uncompressedSize) in
                //var mode = archiveEntry.filePermissions
                if type == .directory {
                    mode = mode | S_IFDIR
                }
                else if type == .symbolicLink {
                    mode = mode | S_IFLNK
                }
                else {
                    mode = mode | S_IFREG
                }
                let fileAttributes = UInt32(mode) << 16
                
                let dataDescriptor = DataDescriptor(
                    crc32: UInt32(crc32),
                    compressedSize: UInt32(compressedSize),
                    uncompressedSize: UInt32(uncompressedSize))

                zip.closeFile(localFileHeader: localFileHeader, dataDescriptor: dataDescriptor, fileAttributes: fileAttributes)
            }
            break
        }
        return stream
    }
    
    // Not supported
    //public func delete() {
    //    self.archive = nil
    //}

}

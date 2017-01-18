//
//  ZipArchiveEntry.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/17.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation

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
    internal init(owner: ZipArchive, centralDirectoryHeader: CentralDirectoryHeader) throws {
        self.archive = owner
        self.centralDirectoryHeader = centralDirectoryHeader
        
        guard let fullName = String.init(data: centralDirectoryHeader.fileName, encoding: owner.entryNameEncoding) else {
            throw ZipError.stringEncodingMismatch
        }
        self.fullName = fullName
        self.name = (fullName as NSString).lastPathComponent

        let compressionMethod = CompressionMethod(rawValue: Int(centralDirectoryHeader.compressionMethod))

        var compressionLevel: CompressionLevel = .optimal
        
        if compressionMethod == .store {
            compressionLevel = .noCompression
        } else if compressionMethod == .deflate {
            let level = (centralDirectoryHeader.generalPurposeBitFlag & 0x06) >> 1
            if level == 0 {
                compressionLevel = .noCompression
            }
            else if level == 1 {
                compressionLevel = .optimal
            }
            else if level == 2 {
                // 2:fast
                compressionLevel = .default
            }
            else if level == 3 {
                // 3:extra fast
                compressionLevel = .fastest
            }
        } else {
            // Not Supported
            throw ZipError.notSupported
        }
        
        self.compressionLevel = compressionLevel

        self.lastWriteTime = ZipUtility.convertDateTime(date: centralDirectoryHeader.lastModFileDate, time: centralDirectoryHeader.lastModFileTime)

        let mode = mode_t(centralDirectoryHeader.externalFileAttributes >> 16)
        self.filePermissions = mode
        self.fileType = FileType.fromRawValue(rawValue: mode)

        if self.fileType == .unknown {
            throw ZipError.invalidData
        }
    }

    // For zip
    internal init(owner: ZipArchive, entryName: String, compressionLevel: CompressionLevel) {
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
    public func open(password: String? = nil, crc32: UInt32 = 0, isLargeFile: Bool = false) throws -> ZipArchiveEntryStream {
        guard let archive = archive else {
            throw ZipError.objectDisposed
        }

        var stream: ZipArchiveEntryStream
        switch archive.mode {
        case .read:
            guard let unzip = archive.unzip else {
                throw ZipError.objectDisposed
            }
            guard let centralDirectoryHeader = centralDirectoryHeader else {
                throw ZipError.objectDisposed
            }

            let (localFileHeader, _) = try unzip.openFile(centralDirectoryHeader: centralDirectoryHeader)
            
            // TODO: Validate localFileHeader, centralDirectoryHeader
            // ...
            
            let tmpStream: IOStream
            
            if let password = password {
                guard let cstr = password.cString(using: archive.passwordEncoding) else {
                    throw ZipError.stringEncodingMismatch
                }
                tmpStream = ZipCryptoStream(stream: archive.stream, password: cstr, crc32ForCrypting: crc32, crc32Table: getCRCTable())
            } else {
                tmpStream = archive.stream
            }
            
            let compressionMethod = CompressionMethod(rawValue: Int(centralDirectoryHeader.compressionMethod))
            
            switch compressionMethod {
            case CompressionMethod.store:
                stream = StoreStream(stream: tmpStream, uncompressedSize: centralDirectoryHeader.uncompressedSize) {
                    unzip.closeFile()
                }
            case CompressionMethod.deflate:
                stream = DeflateStream(stream: tmpStream, mode: .decompress, leaveOpen: true) { (crc32, _, _) in
                    unzip.closeFile()
                }
            default:
                throw ZipError.notSupported
            }
                        
        case .create:
            guard let zip = archive.zip else {
                throw ZipError.objectDisposed
            }
            
            let (date, time) = ZipUtility.convertDateTime(date: lastWriteTime)
            
            // TODO: check max length (16bit)
            guard let fileName = fullName.data(using: archive.entryNameEncoding) else {
                throw ZipError.stringEncodingMismatch
            }
            
            var generalPurposeBitFlag: UInt16 = 0
            if let _ = password {
                generalPurposeBitFlag |= 0b0000_0000_0000_0001 // Password
            }
            //generalPurposeBitFlag |= 0b0000_0000_0000_1000 // Data descriptor
            if archive.entryNameEncoding == .utf8 {
                generalPurposeBitFlag |= 0b0000_1000_0000_0000 // UTF-8
            }
            
            // TODO: ここでヘッダを書き出さず、もっと上位でやる????
            let localFileHeader = LocalFileHeader(
                versionNeededToExtract: 20, // TODO:
                generalPurposeBitFlag: generalPurposeBitFlag,
                compressionMethod: 8, // TODO:
                lastModFileTime: time,
                lastModFileDate: date,
                crc32: 0,
                compressedSize: 0,
                uncompressedSize: 0,
                fileNameLength: UInt16(fileName.count),
                extraFieldLength: 0,
                fileName: fileName,
                extraField: [])
            //self.localFileHeader = localFileHeader
            
            // TODO: remove crypt
            guard zip.openNewFile(localFileHeader: localFileHeader) == true else {
                throw ZipError.io
            }
            
            var mode = filePermissions
            let type = fileType
            
            let tmpStream: IOStream
            let headerSize: Int
            
            if let password = password {
                guard let cstr = password.cString(using: archive.passwordEncoding) else {
                    throw ZipError.stringEncodingMismatch
                }
                let zipCryptoStream = ZipCryptoStream(stream: archive.stream, password: cstr, crc32ForCrypting: crc32, crc32Table: getCRCTable())
                tmpStream = zipCryptoStream
                headerSize = zipCryptoStream.headerSize
            } else {
                tmpStream = archive.stream
                headerSize = 0
            }
            
            stream = DeflateStream(stream: tmpStream, compressionLevel: compressionLevel, leaveOpen: true) { (crc32, compressedSize, uncompressedSize) in
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
                    compressedSize: UInt32(compressedSize) + UInt32(headerSize),
                    uncompressedSize: UInt32(uncompressedSize))

                zip.closeFile(localFileHeader: localFileHeader, dataDescriptor: dataDescriptor, fileAttributes: fileAttributes)
            }
        }
        return stream
    }
    
    // Not supported
    //public func delete() {
    //    self.archive = nil
    //}

}

//
//  Zip.Unzip.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/11.
//  Copyright © 2017 yaslab. All rights reserved.
//

import Foundation

final class Unzip {
    
    let stream: IOStream
    let endOfCentralDirectoryRecord: EndOfCentralDirectoryRecord
    let centralDirectoryHeaders: [CentralDirectoryHeader]
    
    init(stream: IOStream) throws {
        self.stream = stream

        self.endOfCentralDirectoryRecord = try Unzip.searchEndOfCentralDirectoryRecord(stream: stream)

        let sizeOfTheCentralDirectory = Int(endOfCentralDirectoryRecord.sizeOfTheCentralDirectory)
        let offsetOfStartOfCentralDirectory = Int(endOfCentralDirectoryRecord.offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber)
        let buffer = malloc(sizeOfTheCentralDirectory).assumingMemoryBound(to: UInt8.self)
        defer {
            free(buffer)
        }
        guard stream.seek(offset: offsetOfStartOfCentralDirectory, origin: .begin) == 0 else {
            throw ZipError.io
        }
        guard stream.read(buffer: buffer, maxLength: sizeOfTheCentralDirectory) == sizeOfTheCentralDirectory else {
            throw ZipError.io
        }
        
        var centralDirectoryHeaders = [CentralDirectoryHeader]()
        let fileCount = Int(endOfCentralDirectoryRecord.totalNumberOfEntriesInTheCentralDirectoryOnThisDisk)
        var offset = 0
        for _ in 0 ..< fileCount {
            var byteSize = 0
            let centralDirectoryHeader = Unzip.makeCentralDirectoryHeader(buffer: buffer, offset: offset, length: sizeOfTheCentralDirectory, byteSize: &byteSize)
            centralDirectoryHeaders.append(centralDirectoryHeader)
            
            offset += byteSize
        }
        
        self.centralDirectoryHeaders = centralDirectoryHeaders
    }
    
    private static func searchEndOfCentralDirectoryRecord(stream: IOStream) throws -> EndOfCentralDirectoryRecord {
        guard stream.seek(offset: 0, origin: .end) == 0 else {
            throw ZipError.io
        }
        let maxLength = Int(min(stream.position, 1024))
        
        guard stream.seek(offset: -maxLength, origin: .end) == 0 else {
            throw ZipError.io
        }
        
        var buffer = malloc(maxLength).assumingMemoryBound(to: UInt8.self)
        defer {
            free(buffer)
        }
        
        let readed = stream.read(buffer: buffer, maxLength: maxLength)
        guard readed == maxLength else {
            throw ZipError.io
        }
        
        for i in (3 ..< maxLength).reversed() {
            if buffer[i] == 0x06 && buffer[i - 1] == 0x05 && buffer[i - 2] == 0x4b && buffer[i - 3] == 0x50 {
                let offset = i - 3
                let length = maxLength - offset
                return makeEndOfCentralDirectoryRecord(buffer: buffer, offset: offset, length: length)
            }
        }
        
        throw ZipError.invalidData
    }
    
    private static func makeEndOfCentralDirectoryRecord(buffer: UnsafeMutablePointer<UInt8>, offset: Int, length: Int) -> EndOfCentralDirectoryRecord {
        let data = NSData(bytesNoCopy: buffer + offset, length: length, freeWhenDone: false)
        
        var byteSize = 0
        
        let signature: UInt32 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        
        guard signature == EndOfCentralDirectoryRecord.signature else {
            // TODO: Error
            fatalError()
        }
        
        let numberOfThisDisk: UInt16 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let numberOfTheDiskWithTheStartOfTheCentralDirectory: UInt16 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let totalNumberOfEntriesInTheCentralDirectoryOnThisDisk: UInt16 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let totalNumberOfEntriesInTheCentralDirectory: UInt16 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let sizeOfTheCentralDirectory: UInt32 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber: UInt32 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let zipFileCommentLength: UInt16 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        
        guard Int(zipFileCommentLength) == (length - byteSize) else {
            // TODO: Error
            // 不一致でも無視していいかもしれない
            fatalError()
        }
        
        var zipFileComment = [CSignedChar](repeating: 0, count: Int(zipFileCommentLength) + 1)
        memcpy(&zipFileComment, buffer + byteSize, Int(zipFileCommentLength))
        
        return EndOfCentralDirectoryRecord(
            numberOfThisDisk: numberOfThisDisk,
            numberOfTheDiskWithTheStartOfTheCentralDirectory: numberOfTheDiskWithTheStartOfTheCentralDirectory,
            totalNumberOfEntriesInTheCentralDirectoryOnThisDisk: totalNumberOfEntriesInTheCentralDirectoryOnThisDisk,
            totalNumberOfEntriesInTheCentralDirectory: totalNumberOfEntriesInTheCentralDirectory,
            sizeOfTheCentralDirectory: sizeOfTheCentralDirectory,
            offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber: offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber,
            zipFileCommentLength: zipFileCommentLength,
            zipFileComment: zipFileComment)
    }
    
    static func makeCentralDirectoryHeader(buffer: UnsafeMutablePointer<UInt8>, offset: Int, length: Int, byteSize: inout Int) -> CentralDirectoryHeader {
        let data = NSData(bytesNoCopy: buffer, length: length, freeWhenDone: false)
        
        byteSize = 0
        
        let signature: UInt32 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        
        guard signature == CentralDirectoryHeader.signature else {
            // TODO: Error
            fatalError()
        }
        
        let versionMadeBy: UInt16 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let versionNeededToExtract: UInt16 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let generalPurposeBitFlag: UInt16 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let compressionMethod: UInt16 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let lastModFileTime: UInt16 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let lastModFileDate: UInt16 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let crc32: UInt32 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let compressedSize: UInt32 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let uncompressedSize: UInt32 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let fileNameLength: UInt16 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let extraFieldLength: UInt16 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let fileCommentLength: UInt16 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let diskNumberStart: UInt16 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let internalFileAttributes: UInt16 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let externalFileAttributes: UInt32 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        let relativeOffsetOfLocalHeader: UInt32 = BinaryUtility.deserialize(data, offset + byteSize, &byteSize)
        
        var fileName = [CSignedChar](repeating: 0, count: Int(fileNameLength) + 1)
        data.getBytes(&fileName, range: NSRange(location: offset + byteSize, length: Int(fileNameLength)))
        byteSize += Int(fileNameLength)
        
        var extraField = [CSignedChar](repeating: 0, count: Int(extraFieldLength) + 1)
        data.getBytes(&extraField, range: NSRange(location: offset + byteSize, length: Int(extraFieldLength)))
        byteSize += Int(extraFieldLength)
        
        var fileComment = [CSignedChar](repeating: 0, count: Int(fileCommentLength) + 1)
        data.getBytes(&fileComment, range: NSRange(location: offset + byteSize, length: Int(fileCommentLength)))
        byteSize += Int(fileCommentLength)
        
        return CentralDirectoryHeader(
            versionMadeBy: versionMadeBy,
            versionNeededToExtract: versionNeededToExtract,
            generalPurposeBitFlag: generalPurposeBitFlag,
            compressionMethod: compressionMethod,
            lastModFileTime: lastModFileTime,
            lastModFileDate: lastModFileDate,
            crc32: crc32,
            compressedSize: compressedSize,
            uncompressedSize: uncompressedSize,
            fileNameLength: fileNameLength,
            extraFieldLength: extraFieldLength,
            fileCommentLength: fileCommentLength,
            diskNumberStart: diskNumberStart,
            internalFileAttributes: internalFileAttributes,
            externalFileAttributes: externalFileAttributes,
            relativeOffsetOfLocalHeader: relativeOffsetOfLocalHeader,
            fileName: fileName,
            extraField: extraField,
            fileComment: fileComment)
    }
    
    var isOpen: Bool = false
    
    func openFile(fileName: [CSignedChar]) throws -> (LocalFileHeader, Int) {
        guard let centralDirectoryHeader = centralDirectoryHeaders.filter({ strcmp($0.fileName, fileName) == 0 }).first else {
            throw ZipError.argument
        }
        return try openFile(centralDirectoryHeader: centralDirectoryHeader)
    }

    func openFile(centralDirectoryHeader: CentralDirectoryHeader) throws -> (LocalFileHeader, Int) {
        if isOpen {
            throw ZipError.argument
        }
        
        //currentFile = centralDirectoryHeader
        
        let offset = Int(centralDirectoryHeader.relativeOffsetOfLocalHeader)
        guard stream.seek(offset: offset, origin: .begin) == 0 else {
            throw ZipError.io
        }
        
        // without filename and extrafield
        var localHeaderSize = 4 + 2 + 2 + 2 + 2 + 2 + 4 + 4 + 4 + 2 + 2
        
        let buffer = malloc(localHeaderSize).assumingMemoryBound(to: UInt8.self)
        defer {
            free(buffer)
        }
        
        guard stream.read(buffer: buffer, maxLength: localHeaderSize) == localHeaderSize else {
            throw ZipError.io
        }
        
        let data = NSData(bytesNoCopy: buffer, length: localHeaderSize, freeWhenDone: false)
        
        var byteSize = 0
        
        let signature: UInt32 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        
        guard signature == LocalFileHeader.signature else {
            throw ZipError.invalidData
        }
        
        let versionNeededToExtract: UInt16 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let generalPurposeBitFlag: UInt16 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let compressionMethod: UInt16 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let lastModFileTime: UInt16 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let lastModFileDate: UInt16 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let crc32: UInt32 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let compressedSize: UInt32 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let uncompressedSize: UInt32 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let fileNameLength: UInt16 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        let extraFieldLength: UInt16 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        
        var fileName = [CSignedChar](repeating: 0, count: Int(fileNameLength) + 1)
        guard stream.read(buffer: &fileName, maxLength: Int(fileNameLength)) == Int(fileNameLength) else {
            throw ZipError.io
        }
        byteSize += Int(fileNameLength)
        
        // NOTE: central と local とで長さが違うことがある
        var extraField = [CSignedChar](repeating: 0, count: Int(extraFieldLength) + 1)
        guard stream.read(buffer: &extraField, maxLength: Int(extraFieldLength)) == Int(extraFieldLength) else {
            throw ZipError.io
        }
        byteSize += Int(extraFieldLength)
        
        let localFileHeader = LocalFileHeader(
            versionNeededToExtract: versionNeededToExtract,
            generalPurposeBitFlag: generalPurposeBitFlag,
            compressionMethod: compressionMethod,
            lastModFileTime: lastModFileTime,
            lastModFileDate: lastModFileDate,
            crc32: crc32,
            compressedSize: compressedSize,
            uncompressedSize: uncompressedSize,
            fileNameLength: fileNameLength,
            extraFieldLength: extraFieldLength,
            fileName: fileName,
            extraField: extraField)
        
        return (localFileHeader, localHeaderSize)
    }
    
    func closeFile() {
        isOpen = false
    }
    
}

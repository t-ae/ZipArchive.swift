//
//  LocalFileHeader.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/09.
//  Copyright © 2017年 yaslab. All rights reserved.
//

import Foundation

enum ZipUtility {
    
    static func convertDateTime(date: UInt16, time: UInt16) -> Date {
        var components = DateComponents()
        
        components.year     = Int((date & 0b1111_1110_0000_0000) >> 9) + 1980
        components.month    = Int((date & 0b0000_0001_1110_0000) >> 5)
        components.day      = Int(date & 0b0000_0000_0001_1111)
        
        components.hour     = Int((time & 0b1111_1000_0000_0000) >> 11)
        components.minute   = Int((time & 0b0000_0111_1110_0000) >> 5)
        components.second   = Int(time & 0b0000_0000_0001_1111) * 2
        
        guard let date = Calendar.current.date(from: components) else {
            return Date(timeIntervalSince1970: 0)
        }
        return date
    }
    
    static func convertDateTime(date: Date) -> (UInt16, UInt16) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        
        var date: UInt16 = 0
        var year = components.year! - 1980
        if year < 0 {
            year = 0
        }
        date += UInt16(year) << 9
        date += UInt16(components.month!) << 5
        date += UInt16(components.day!)
        
        var time: UInt16 = 0
        time += UInt16(components.hour!) << 11
        time += UInt16(components.minute!) << 5
        time += UInt16(components.second! / 2)
        
        return (date, time)
    }
    
}

struct LocalFileHeader {

    static let signature: UInt32 = 0x04034b50
    let versionNeededToExtract: UInt16
    let generalPurposeBitFlag: UInt16
    let compressionMethod: UInt16
    let lastModFileTime: UInt16
    let lastModFileDate: UInt16
    let crc32: UInt32
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let fileNameLength: UInt16
    let extraFieldLength: UInt16
    
    let fileName: [CSignedChar]
    let extraField: [CSignedChar]
    
}

struct DataDescriptor {
    
    static let signature: UInt32 = 0x08074b50
    let crc32: UInt32
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    
}

struct CentralDirectoryHeader {
    
    static let signature: UInt32 = 0x02014b50
    let versionMadeBy: UInt16 // *
    let versionNeededToExtract: UInt16
    let generalPurposeBitFlag: UInt16
    let compressionMethod: UInt16
    let lastModFileTime: UInt16
    let lastModFileDate: UInt16
    let crc32: UInt32
    let compressedSize: UInt32
    let uncompressedSize: UInt32
    let fileNameLength: UInt16
    let extraFieldLength: UInt16
    let fileCommentLength: UInt16 // *
    let diskNumberStart: UInt16 // *
    let internalFileAttributes: UInt16 // *
    let externalFileAttributes: UInt32 // *
    let relativeOffsetOfLocalHeader: UInt32 // *
    
    let fileName: [CSignedChar]
    let extraField: [CSignedChar]
    let fileComment: [CSignedChar] // *
    
}

struct EndOfCentralDirectoryRecord {
    
    static let signature: UInt32 = 0x06054b50
    let numberOfThisDisk: UInt16
    let numberOfTheDiskWithTheStartOfTheCentralDirectory: UInt16
    let totalNumberOfEntriesInTheCentralDirectoryOnThisDisk: UInt16
    let totalNumberOfEntriesInTheCentralDirectory: UInt16
    let sizeOfTheCentralDirectory: UInt32
    let offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber: UInt32
    let zipFileCommentLength: UInt16
    let zipFileComment: [CSignedChar]
    
}

final class Unzip {
    
    let stream: ZipArchiveStream
    let endOfCentralDirectoryRecord: EndOfCentralDirectoryRecord
    let centralDirectoryHeaders: [CentralDirectoryHeader]
    
    //var currentFile: CentralDirectoryHeader
    
    // TODO: return nil ==> throw error??
    init?(stream: ZipArchiveStream) {
        self.stream = stream
        
        guard let endOfCentralDirectoryRecord = Unzip.searchEndOfCentralDirectoryRecord(stream: stream) else {
            return nil
        }
        self.endOfCentralDirectoryRecord = endOfCentralDirectoryRecord

        
        
        
        let sizeOfTheCentralDirectory = Int(endOfCentralDirectoryRecord.sizeOfTheCentralDirectory)
        let offsetOfStartOfCentralDirectory = Int(endOfCentralDirectoryRecord.offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber)
        let buffer = malloc(sizeOfTheCentralDirectory).assumingMemoryBound(to: UInt8.self)
        defer {
            free(buffer)
        }
        guard stream.seek(offset: offsetOfStartOfCentralDirectory, origin: .begin) == 0 else {
            return nil
        }
        guard stream.read(buffer: buffer, maxLength: sizeOfTheCentralDirectory) == sizeOfTheCentralDirectory else {
            return nil
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
        
        if centralDirectoryHeaders.count == 0 {
            // no entries
            return nil
        }
        
        //currentFile = centralDirectoryHeaders[0]
    }
    
    // TODO: return nil ==> throw error??
    private static func searchEndOfCentralDirectoryRecord(stream: ZipArchiveStream) -> EndOfCentralDirectoryRecord? {
        guard stream.seek(offset: 0, origin: .end) == 0 else {
            // TODO: Error
            return nil
        }
        let maxLength = Int(min(stream.position, 1024))
        
        guard stream.seek(offset: -maxLength, origin: .end) == 0 else {
            // TODO: Error
            return nil
        }
        
        var buffer = malloc(maxLength).assumingMemoryBound(to: UInt8.self)
        defer {
            free(buffer)
        }

        let readed = stream.read(buffer: buffer, maxLength: maxLength)
        guard readed == maxLength else {
            // TODO: Error
            return nil
        }
        
        for i in (3 ..< maxLength).reversed() {
            if buffer[i] == 0x06 && buffer[i - 1] == 0x05 && buffer[i - 2] == 0x4b && buffer[i - 3] == 0x50 {
                let offset = i - 3
                let length = maxLength - offset
                return makeEndOfCentralDirectoryRecord(buffer: buffer, offset: offset, length: length)
            }
        }
        
        return nil
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
    
    // TODO: throw error??
    func openFile(fileName: [CSignedChar]) -> (LocalFileHeader, Int)? {
        guard let centralDirectoryHeader = centralDirectoryHeaders.filter({ strcmp($0.fileName, fileName) == 0 }).first else {
            return nil
        }
        return openFile(centralDirectoryHeader: centralDirectoryHeader)
    }
    
    
    func openFile(centralDirectoryHeader: CentralDirectoryHeader) -> (LocalFileHeader, Int)? {
        if isOpen {
            return nil
        }
        
        //currentFile = centralDirectoryHeader
        
        let offset = Int(centralDirectoryHeader.relativeOffsetOfLocalHeader)
        guard stream.seek(offset: offset, origin: .begin) == 0 else {
            return nil
        }
        
        // without filename and extrafield
        var localHeaderSize = 4 + 2 + 2 + 2 + 2 + 2 + 4 + 4 + 4 + 2 + 2
        
        let buffer = malloc(localHeaderSize).assumingMemoryBound(to: UInt8.self)
        defer {
            free(buffer)
        }
        
        guard stream.read(buffer: buffer, maxLength: localHeaderSize) == localHeaderSize else {
            return nil
        }
        
        let data = NSData(bytesNoCopy: buffer, length: localHeaderSize, freeWhenDone: false)
        
        var byteSize = 0
        
        let signature: UInt32 = BinaryUtility.deserialize(data, byteSize, &byteSize)
        
        guard signature == LocalFileHeader.signature else {
            // TODO: Error
            return nil
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
            return nil
        }
        byteSize += Int(fileNameLength)
        
        // NOTE: central と local とで長さが違うことがある
        var extraField = [CSignedChar](repeating: 0, count: Int(extraFieldLength) + 1)
        guard stream.read(buffer: &extraField, maxLength: Int(extraFieldLength)) == Int(extraFieldLength) else {
            return nil
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

// For new zip file
class Zip {
    
    let stream: ZipArchiveStream
    
    private var currentFileOffset: Int? = nil
    
    private var centralDirectoryHeaders = [CentralDirectoryHeader]()
    
    init(stream: ZipArchiveStream) {
        self.stream = stream
    }

    func openNewFile(localFileHeader: LocalFileHeader) -> Bool {
        guard stream.seek(offset: 0, origin: .end) == 0 else {
            return false
        }
        
        currentFileOffset = Int(stream.position)

        let data = NSMutableData()
        
        _ = BinaryUtility.serialize(data, LocalFileHeader.signature)
        _ = BinaryUtility.serialize(data, localFileHeader.versionNeededToExtract)
        _ = BinaryUtility.serialize(data, localFileHeader.generalPurposeBitFlag)
        _ = BinaryUtility.serialize(data, localFileHeader.compressionMethod)
        _ = BinaryUtility.serialize(data, localFileHeader.lastModFileTime)
        _ = BinaryUtility.serialize(data, localFileHeader.lastModFileDate)
        _ = BinaryUtility.serialize(data, localFileHeader.crc32) // 0
        _ = BinaryUtility.serialize(data, localFileHeader.compressedSize) // 0
        _ = BinaryUtility.serialize(data, localFileHeader.uncompressedSize)
        _ = BinaryUtility.serialize(data, localFileHeader.fileNameLength)
        _ = BinaryUtility.serialize(data, localFileHeader.extraFieldLength)
        data.append(localFileHeader.fileName, length: Int(localFileHeader.fileNameLength))
        data.append(localFileHeader.extraField, length: Int(localFileHeader.extraFieldLength))
        
        guard stream.write(buffer: data.bytes, maxLength: data.length) == data.length else {
            return false
        }
        
        return true
    }

    func closeFile(localFileHeader: LocalFileHeader, dataDescriptor: DataDescriptor, fileAttributes: UInt32) -> Bool {
        guard let currentFileOffset = currentFileOffset else {
            return false
        }
        defer {
            self.currentFileOffset = nil
        }
        
        // TODO: seek の offset は Int64 がいいかもしれない
        let crc32HeaderOffset = currentFileOffset + 4 + 2 + 2 + 2 + 2 + 2
        guard stream.seek(offset: crc32HeaderOffset, origin: .begin) == 0 else {
            return false
        }
        
        var crc32 = dataDescriptor.crc32
        var compressedSize = dataDescriptor.compressedSize
        var uncompressedSize = dataDescriptor.uncompressedSize
        withUnsafePointer(to: &crc32) { _ = stream.write(buffer: $0, maxLength: MemoryLayout.size(ofValue: $0)) }
        withUnsafePointer(to: &compressedSize) { _ = stream.write(buffer: $0, maxLength: MemoryLayout.size(ofValue: $0)) }
        withUnsafePointer(to: &uncompressedSize) { _ = stream.write(buffer: $0, maxLength: MemoryLayout.size(ofValue: $0)) }
        
        guard stream.seek(offset: 0, origin: .end) == 0 else {
            return false
        }
        
        let data = NSMutableData()
        
        _ = BinaryUtility.serialize(data, DataDescriptor.signature)
        _ = BinaryUtility.serialize(data, dataDescriptor.crc32)
        _ = BinaryUtility.serialize(data, dataDescriptor.compressedSize)
        _ = BinaryUtility.serialize(data, dataDescriptor.uncompressedSize)

        guard stream.write(buffer: data.bytes, maxLength: data.length) == data.length else {
            return false
        }
        
        let centralDirectoryHeader = CentralDirectoryHeader(
            versionMadeBy: 7,
            versionNeededToExtract: localFileHeader.versionNeededToExtract,
            generalPurposeBitFlag: localFileHeader.generalPurposeBitFlag,
            compressionMethod: localFileHeader.compressionMethod,
            lastModFileTime: localFileHeader.lastModFileTime,
            lastModFileDate: localFileHeader.lastModFileDate,
            crc32: dataDescriptor.crc32,
            compressedSize: dataDescriptor.compressedSize,
            uncompressedSize: dataDescriptor.uncompressedSize,
            fileNameLength: localFileHeader.fileNameLength,
            extraFieldLength: localFileHeader.extraFieldLength,
            fileCommentLength: 0,
            diskNumberStart: 0,
            internalFileAttributes: 0,
            externalFileAttributes: fileAttributes,
            relativeOffsetOfLocalHeader: UInt32(currentFileOffset),
            fileName: localFileHeader.fileName,
            extraField: localFileHeader.extraField,
            fileComment: [])
        centralDirectoryHeaders.append(centralDirectoryHeader)
        
        return true
    }
    
    func finalize() -> Bool {
        guard stream.seek(offset: 0, origin: .end) == 0 else {
            return false
        }

        let centralDirectoryOffset = UInt32(stream.position)
        
        for centralDirectoryHeader in centralDirectoryHeaders {
            let data = NSMutableData()
            
            _ = BinaryUtility.serialize(data, CentralDirectoryHeader.signature)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.versionMadeBy)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.versionNeededToExtract)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.generalPurposeBitFlag)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.compressionMethod)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.lastModFileTime)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.lastModFileDate)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.crc32)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.compressedSize)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.uncompressedSize)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.fileNameLength)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.extraFieldLength)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.fileCommentLength)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.diskNumberStart)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.internalFileAttributes)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.externalFileAttributes)
            _ = BinaryUtility.serialize(data, centralDirectoryHeader.relativeOffsetOfLocalHeader)
            data.append(centralDirectoryHeader.fileName, length: Int(centralDirectoryHeader.fileNameLength))
            data.append(centralDirectoryHeader.extraField, length: Int(centralDirectoryHeader.extraFieldLength))
            data.append(centralDirectoryHeader.fileComment, length: Int(centralDirectoryHeader.fileCommentLength))
            
            guard stream.write(buffer: data.bytes, maxLength: data.length) == data.length else {
                return false
            }
        }

        let centralDirectorySize = UInt32(stream.position) - centralDirectoryOffset
        let fileCount = UInt16(centralDirectoryHeaders.count)
        
        let endOfCentralDirectoryRecord = EndOfCentralDirectoryRecord(
            numberOfThisDisk: 0,
            numberOfTheDiskWithTheStartOfTheCentralDirectory: 0,
            totalNumberOfEntriesInTheCentralDirectoryOnThisDisk: fileCount,
            totalNumberOfEntriesInTheCentralDirectory: fileCount,
            sizeOfTheCentralDirectory: centralDirectorySize,
            offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber: centralDirectoryOffset,
            zipFileCommentLength: 0,
            zipFileComment: [])
        
        let data = NSMutableData()
        _ = BinaryUtility.serialize(data, EndOfCentralDirectoryRecord.signature)
        _ = BinaryUtility.serialize(data, endOfCentralDirectoryRecord.numberOfThisDisk)
        _ = BinaryUtility.serialize(data, endOfCentralDirectoryRecord.numberOfTheDiskWithTheStartOfTheCentralDirectory)
        _ = BinaryUtility.serialize(data, endOfCentralDirectoryRecord.totalNumberOfEntriesInTheCentralDirectoryOnThisDisk)
        _ = BinaryUtility.serialize(data, endOfCentralDirectoryRecord.totalNumberOfEntriesInTheCentralDirectory)
        _ = BinaryUtility.serialize(data, endOfCentralDirectoryRecord.sizeOfTheCentralDirectory)
        _ = BinaryUtility.serialize(data, endOfCentralDirectoryRecord.offsetOfStartOfCentralDirectoryWithRespectToTheStartingDiskNumber)
        _ = BinaryUtility.serialize(data, endOfCentralDirectoryRecord.zipFileCommentLength)
        data.append(endOfCentralDirectoryRecord.zipFileComment, length: endOfCentralDirectoryRecord.zipFileComment.count)
        
        guard stream.write(buffer: data.bytes, maxLength: data.length) == data.length else {
            return false
        }
        
        return true
    }
    
}

//
//  Zip.Zip.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/11.
//  Copyright © 2017年 yaslab. All rights reserved.
//

import Foundation

// For new zip file
class Zip {
    
    let stream: IOStream
    
    private var currentFileOffset: Int? = nil
    
    private var centralDirectoryHeaders = [CentralDirectoryHeader]()
    
    init(stream: IOStream) {
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
        _ = BinaryUtility.serialize(data, localFileHeader.uncompressedSize) // 0
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
        
        let data = NSMutableData()
        
        _ = BinaryUtility.serialize(data, dataDescriptor.crc32)
        _ = BinaryUtility.serialize(data, dataDescriptor.compressedSize)
        _ = BinaryUtility.serialize(data, dataDescriptor.uncompressedSize)
        
        guard stream.write(buffer: data.bytes, maxLength: data.length) == data.length else {
            return false
        }
        
        //        var crc32 = dataDescriptor.crc32
        //        var compressedSize = dataDescriptor.compressedSize
        //        var uncompressedSize = dataDescriptor.uncompressedSize
        //        withUnsafePointer(to: &crc32) { _ = stream.write(buffer: $0, maxLength: MemoryLayout.size(ofValue: $0)) }
        //        withUnsafePointer(to: &compressedSize) { _ = stream.write(buffer: $0, maxLength: MemoryLayout.size(ofValue: $0)) }
        //        withUnsafePointer(to: &uncompressedSize) { _ = stream.write(buffer: $0, maxLength: MemoryLayout.size(ofValue: $0)) }
        
        guard stream.seek(offset: 0, origin: .end) == 0 else {
            return false
        }
        
        data.length = 0

        // write dataDescriptor
//        _ = BinaryUtility.serialize(data, DataDescriptor.signature)
//        _ = BinaryUtility.serialize(data, dataDescriptor.crc32)
//        _ = BinaryUtility.serialize(data, dataDescriptor.compressedSize)
//        _ = BinaryUtility.serialize(data, dataDescriptor.uncompressedSize)
//        
//        guard stream.write(buffer: data.bytes, maxLength: data.length) == data.length else {
//            return false
//        }

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

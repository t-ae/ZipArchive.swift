//
//  LocalFileHeader.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/09.
//  Copyright © 2017年 yaslab. All rights reserved.
//

import Foundation

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

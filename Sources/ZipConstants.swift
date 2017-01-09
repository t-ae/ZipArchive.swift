//
//  ZipConstants.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/08.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation
import minizip

public let kZipArchiveDefaultBufferSize = 8192

public enum ZipError: Error {
    
    case argument
    case argumentNull
    case pathTooLong
    case directoryNotFound
    case io
    case unauthorizedAccess
    case fileNotFound
    case invalidData
    case objectDisposed
    case notSupported
    
}

public enum ZipArchiveMode {

    case read
    case create
    //case update
    
}

public enum CompressionLevel {
    
    case noCompression
    case fastest
    case optimal
    case `default`

    internal static func fromRawValue(rawValue: Int32) -> CompressionLevel {
        switch rawValue {
        case Z_NO_COMPRESSION: return .noCompression
        case Z_BEST_SPEED: return .fastest
        case Z_BEST_COMPRESSION: return .optimal
        default: return .default
        }
    }

    internal func toRawValue() -> Int32 {
        switch self {
        case .noCompression: return Z_NO_COMPRESSION
        case .fastest: return Z_BEST_SPEED
        case .optimal: return Z_BEST_COMPRESSION
        case .default: return Z_DEFAULT_COMPRESSION
        }
    }
    
}

public enum FileType {

    //case namedPipe
    case characterSpecial
    case directory
    case blockSpecial
    case regular
    case symbolicLink
    case socket
    //case whiteout
    case unknown

    internal static func fromRawValue(rawValue: UInt16) -> FileType {
        var type = rawValue & S_IFMT
        // TODO: when windows, type == 0 ????
        if type == 0 {
            type = S_IFREG
        }
        switch type {
        //case S_IFIFO: return .NamedPipe
        case S_IFCHR: return .characterSpecial
        case S_IFDIR: return .directory
        case S_IFBLK: return .blockSpecial
        case S_IFREG: return .regular
        case S_IFLNK: return .symbolicLink
        case S_IFSOCK: return .socket
        //case S_IFWHT: return .whiteout
        default: return .unknown
        }
    }

    internal static func fromNSFileType(fileType: FileAttributeType) -> FileType {
        switch fileType {
        case FileAttributeType.typeDirectory: return .directory
        case FileAttributeType.typeRegular: return .regular
        case FileAttributeType.typeSymbolicLink: return .symbolicLink
        case FileAttributeType.typeSocket: return .socket
        case FileAttributeType.typeCharacterSpecial: return .characterSpecial
        case FileAttributeType.typeBlockSpecial: return .blockSpecial
        //case NSFileTypeUnknown: return .unknown
        default: return .unknown
        }
    }

    internal func toNSFileType() -> FileAttributeType {
        switch self {
        case .directory: return .typeDirectory
        case .regular: return .typeRegular
        case .symbolicLink: return .typeSymbolicLink
        case .socket :return .typeSocket
        case .characterSpecial: return .typeCharacterSpecial
        case .blockSpecial: return .typeBlockSpecial
        default: return .typeUnknown
        }
    }

}

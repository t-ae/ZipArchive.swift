//
//  ZipConstants.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/08.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation
import CMinizip

public let kZipArchiveDefaultBufferSize = 8192

public enum ZipError: Error {
    case Argument
    case ArgumentNull
    case PathTooLong
    case DirectoryNotFound
    case IO
    case UnauthorizedAccess
    case FileNotFound
    case InvalidData
    case ObjectDisposed
    case NotSupported
}

public enum ZipArchiveMode {
    case Read
    case Create
    //case Update
}

public enum CompressionLevel {
    case NoCompression
    case Fastest
    case Optimal
    case Default

    internal static func fromRawValue(rawValue: Int32) -> CompressionLevel {
        switch rawValue {
        case Z_NO_COMPRESSION: return .NoCompression
        case Z_BEST_SPEED: return .Fastest
        case Z_BEST_COMPRESSION: return .Optimal
        default: return .Default
        }
    }

    internal func toRawValue() -> Int32 {
        switch self {
        case .NoCompression: return Z_NO_COMPRESSION
        case .Fastest: return Z_BEST_SPEED
        case .Optimal: return Z_BEST_COMPRESSION
        case .Default: return Z_DEFAULT_COMPRESSION
        }
    }
}

public enum FileType {

    //case NamedPipe
    case CharacterSpecial
    case Directory
    case BlockSpecial
    case Regular
    case SymbolicLink
    case Socket
    //case Whiteout
    case Unknown

    internal static func fromRawValue(rawValue: UInt16) -> FileType {
        var type = rawValue & S_IFMT
        // TODO: when windows, type == 0 ????
        if type == 0 {
            type = S_IFREG
        }
        switch type {
        //case S_IFIFO: return .NamedPipe
        case S_IFCHR: return .CharacterSpecial
        case S_IFDIR: return .Directory
        case S_IFBLK: return .BlockSpecial
        case S_IFREG: return .Regular
        case S_IFLNK: return .SymbolicLink
        case S_IFSOCK: return .Socket
        //case S_IFWHT: return .Whiteout
        default: return .Unknown
        }
    }

    internal static func fromNSFileType(fileType: FileAttributeType) -> FileType {
        switch fileType {
        case FileAttributeType.typeDirectory: return .Directory
        case FileAttributeType.typeRegular: return .Regular
        case FileAttributeType.typeSymbolicLink: return .SymbolicLink
        case FileAttributeType.typeSocket: return .Socket
        case FileAttributeType.typeCharacterSpecial: return .CharacterSpecial
        case FileAttributeType.typeBlockSpecial: return .BlockSpecial
        //case NSFileTypeUnknown: return .Unknown
        default: return .Unknown
        }
    }

    internal func toNSFileType() -> FileAttributeType {
        switch self {
        case .Directory: return .typeDirectory
        case .Regular: return .typeRegular
        case .SymbolicLink: return .typeSymbolicLink
        case .Socket :return .typeSocket
        case .CharacterSpecial: return .typeCharacterSpecial
        case .BlockSpecial: return .typeBlockSpecial
        default: return .typeUnknown
        }
    }

}

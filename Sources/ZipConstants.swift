//
//  ZipConstants.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/08.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation
import Czlib

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
    
    case stringEncodingMismatch
    
}

public enum ZipArchiveMode {

    case read
    case create
    //case update
    
}

public struct CompressionMethod: RawRepresentable, Equatable {

    /// 0
    public static let store = CompressionMethod(0)
    /// 8
    public static let deflate = CompressionMethod(Int(Z_DEFLATED))

    public init(_ rawValue: Int) {
        self.init(rawValue: rawValue)
    }
    
    // MARK: - RawRepresentable
    
    public private(set) var rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    // MARK: - Equatable
    
    public static func == (lhs: CompressionMethod, rhs: CompressionMethod) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }

}

public struct CompressionLevel: RawRepresentable {

    /// 0
    public static let noCompression = CompressionLevel(rawValue: Int(Z_NO_COMPRESSION))
    /// 1
    public static let fastest = CompressionLevel(rawValue: Int(Z_BEST_SPEED))
    /// 6
    public static let `default` = CompressionLevel(rawValue: Int(Z_DEFAULT_COMPRESSION))
    /// 9
    public static let optimal = CompressionLevel(rawValue: Int(Z_BEST_COMPRESSION))
    
    public init(_ rawValue: Int) {
        self.init(rawValue: rawValue)
    }
    
    // MARK: - RawRepresentable
    
    public private(set) var rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: CompressionLevel, rhs: CompressionLevel) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
}

//public enum CompressionLevel {
//    
//    case noCompression
//    case fastest
//    case optimal
//    case `default`
//
//    internal static func fromRawValue(rawValue: Int32) -> CompressionLevel {
//        switch rawValue {
//        case Z_NO_COMPRESSION: return .noCompression
//        case Z_BEST_SPEED: return .fastest
//        case Z_BEST_COMPRESSION: return .optimal
//        default: return .default
//        }
//    }
//
//    internal func toRawValue() -> Int32 {
//        switch self {
//        case .noCompression: return Z_NO_COMPRESSION
//        case .fastest: return Z_BEST_SPEED
//        case .optimal: return Z_BEST_COMPRESSION
//        case .default: return Z_DEFAULT_COMPRESSION
//        }
//    }
//    
//}

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

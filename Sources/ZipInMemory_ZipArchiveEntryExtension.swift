//
//  ZipArchiveEntryExtension.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2016/01/31.
//  Copyright © 2016年 yaslab. All rights reserved.
//

import Foundation

// In-Memory
extension ZipArchiveEntry {
    
//    public func extractToData() -> NSData? {
//        return extractToData(nil)
//    }
    
    public func extractToData(password: String? = nil) -> Data? {
        var crypt: ZipCrypto? = nil
        if let password = password {
            guard let archive = archive else {
                //throw ZipError.objectDisposed
                return nil
            }
            guard let cstr = password.cString(using: archive.passwordEncoding) else {
                //throw ZipError.stringEncodingMismatch
                return nil
            }
            // TODO: error if ZipCrypto.init == nil
            crypt = ZipCrypto(password: cstr, crc32ForCrypting: 0, crc32Table: getCRCTable())
        }
        
        guard let unzipStream = open(crypt: crypt) else {
            // ERROR
            return nil
        }
        defer {
            _ = unzipStream.close()
        }
        
        var data = Data(count: Int(length))
        let len = data.withUnsafeMutableBytes { (p) -> Int in
            return unzipStream.read(buffer: p, maxLength: Int(length))
        }
        
        if len != Int(length) {
            // ERROR
            return nil
        }
        
        return data
    }

}

//
//  ZipArchiveEntryExtension.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2016/01/31.
//  Copyright © 2016 yaslab. All rights reserved.
//

import Foundation

// In-Memory
extension ZipArchiveEntry {
    
//    public func extractToData() -> NSData? {
//        return extractToData(nil)
//    }
    
    public func extractToData(password: String? = nil) throws -> Data {
        let unzipStream = try open(password: password)
        defer {
            _ = unzipStream.close()
        }
        
        var data = Data(count: Int(length))
        let len = data.withUnsafeMutableBytes { (p) -> Int in
            return unzipStream.read(buffer: p, maxLength: Int(length))
        }
        
        if len != Int(length) {
            // ERROR
            throw ZipError.io
        }
        
        return data
    }

}

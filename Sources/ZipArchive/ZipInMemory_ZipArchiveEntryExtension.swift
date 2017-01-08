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
        guard let unzipStream = open(password: password) else {
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

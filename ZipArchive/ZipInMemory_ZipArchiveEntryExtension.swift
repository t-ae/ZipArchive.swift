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
    
    public func extractToData() -> NSData? {
        return extractToData("")
    }
    
    public func extractToData(password: String) -> NSData? {
        guard let unzipStream = open(password) else {
            // ERROR
            return nil
        }
        defer {
            unzipStream.close()
        }
        
        guard let data = NSMutableData(length: Int(length)) else {
            // ERROR
            return nil
        }
        let buffer = UnsafeMutablePointer<UInt8>(data.mutableBytes)
        
        let len = unzipStream.read(buffer, maxLength: Int(length))
        if len != Int(length) {
            // ERROR
            return nil
        }
        
        return data
    }

}

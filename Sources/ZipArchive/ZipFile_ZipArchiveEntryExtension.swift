//
//  ZipArchiveEntryExtension.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/07.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation

extension ZipArchiveEntry {

//    public func extractToFile(destinationFileName: String) throws {
//        try extractToFile(destinationFileName, overwrite: false, password: "")
//    }
//    
//    public func extractToFile(destinationFileName: String, overwrite: Bool) throws {
//        try extractToFile(destinationFileName, overwrite: overwrite, password: "")
//    }
    
    public func extractToFile(destinationFileName: String, overwrite: Bool = false, password: String? = nil) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: destinationFileName) {
            if !overwrite {
                throw ZipError.io
            }
        }

        guard let unzipStream = open(password: password) else {
            throw ZipError.io
        }
        defer {
            unzipStream.close()
        }
        
        guard let fileOutputStream = OutputStream(toFileAtPath: destinationFileName, append: false) else {
            throw ZipError.io
        }
        fileOutputStream.open()
        defer {
            fileOutputStream.close()
        }
        
        var buffer = [UInt8].init(repeating: 0, count: kZipArchiveDefaultBufferSize)
        
        while true {
            let len = unzipStream.read(buffer: &buffer, maxLength: kZipArchiveDefaultBufferSize)
            if len < 0 {
                throw ZipError.io
            }
            if len == 0 {
                // END
                break
            }
            let err = fileOutputStream.write(&buffer, maxLength: len)
            if err < 0 {
                throw ZipError.io
            }
        }
    }
    
}

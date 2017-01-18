//
//  ZipArchiveEntryExtension.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/07.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation

extension ZipArchiveEntry {

    public func extractTo(filePath: String, overwrite: Bool = false, password: String? = nil) throws {
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: filePath) {
            if !overwrite {
                throw ZipError.io
            }
        }
        
        let unzipStream = try open(password: password)
        defer {
            unzipStream.close()
        }
        
        guard let fileOutputStream = OutputStream(toFileAtPath: filePath, append: false) else {
            throw ZipError.io
        }
        fileOutputStream.open()
        defer {
            fileOutputStream.close()
        }
        
        let buffer = malloc(kZipArchiveDefaultBufferSize).assumingMemoryBound(to: UInt8.self)
        defer {
            free(buffer)
        }
        
        while true {
            let len = unzipStream.read(buffer: buffer, maxLength: kZipArchiveDefaultBufferSize)
            if len < 0 {
                throw ZipError.io
            }
            if len == 0 {
                // END
                break
            }
            let err = fileOutputStream.write(buffer, maxLength: len)
            if err < 0 {
                throw ZipError.io
            }
        }
    }
    
}

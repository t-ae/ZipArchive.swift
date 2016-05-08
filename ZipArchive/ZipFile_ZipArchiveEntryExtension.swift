//
//  ZipArchiveEntryExtension.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/07.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation

extension ZipArchiveEntry {

    public func extractToFile(destinationFileName: String) {
        extractToFile(destinationFileName, overwrite: false, password: "")
    }
    
    public func extractToFile(destinationFileName: String, overwrite: Bool) {
        extractToFile(destinationFileName, overwrite: overwrite, password: "")
    }
    
    public func extractToFile(destinationFileName: String, overwrite: Bool, password: String) {
        let fm = NSFileManager.defaultManager()
        if fm.fileExistsAtPath(destinationFileName) {
            if !overwrite {
                // Do Nothing
                return
            }
        }

        guard let unzipStream = open(password) else {
            // ERROR
            return
        }
        defer {
            unzipStream.close()
        }
        
        guard let fileOutputStream = NSOutputStream(toFileAtPath: destinationFileName, append: false) else {
            // ERROR
            return
        }
        fileOutputStream.open()
        defer {
            fileOutputStream.close()
        }
        
        let buffer = UnsafeMutablePointer<UInt8>.alloc(kZipArchiveDefaultBufferSize)
        defer {
            buffer.destroy()
            buffer.dealloc(kZipArchiveDefaultBufferSize)
        }
        
        while true {
            let len = unzipStream.read(buffer, maxLength: kZipArchiveDefaultBufferSize)
            if len < 0 {
                // ERROR
                break
            }
            if len == 0 {
                // END
                break
            }
            let err = fileOutputStream.write(buffer, maxLength: len)
            if err < 0 {
                // ERROR
                break
            }
        }
    }
    
}

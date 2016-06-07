//
//  BaseTestCase.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2016/01/31.
//  Copyright © 2016 yaslab. All rights reserved.
//

import XCTest

class BaseTestCase: XCTestCase {

    let fileManager = NSFileManager.defaultManager()
    let testBaseDirectory = "/tmp/ZipArchiveTest/"
    var testDataDirectory: String { return testBaseDirectory + "ZipArchiveData/" }
    var zipDestinationDirectory: String { return  testBaseDirectory + "Zip/" }
    var unzipDestinationDirectory: String { return  testBaseDirectory + "Unzip/" }
    
    let bufferSize = 8192
    
    override func setUp() {
        super.setUp()
    }
    
    func cleanUp() throws {
        if fileManager.fileExistsAtPath(testBaseDirectory) {
            try fileManager.removeItemAtPath(testBaseDirectory)
        }
        try fileManager.createDirectoryAtPath(testBaseDirectory, withIntermediateDirectories: false, attributes: nil)
        try fileManager.createDirectoryAtPath(testDataDirectory, withIntermediateDirectories: false, attributes: nil)
        try fileManager.createDirectoryAtPath(zipDestinationDirectory, withIntermediateDirectories: false, attributes: nil)
        try fileManager.createDirectoryAtPath(unzipDestinationDirectory, withIntermediateDirectories: false, attributes: nil)
    }
    
    func executeCommand(command: String, workingDirectory: String?) -> Int32 {
        var success: Bool
        let prevDirectory = fileManager.currentDirectoryPath
        if let workingDirectory = workingDirectory {
            success = fileManager.changeCurrentDirectoryPath(workingDirectory)
            XCTAssertTrue(success)
            if !success {
                return -1
            }
        }
        
        let ret = system(command)
        
        if let _ = workingDirectory {
            success = fileManager.changeCurrentDirectoryPath(prevDirectory)
            XCTAssertTrue(success)
            if !success {
                return -1
            }
        }
        
        return ret
    }
    
    func createFixedData(size: Int = 1234) -> NSData {
        let data = NSMutableData()
        var byte = UInt8(rand() % 0x0100)
        for _ in 0 ..< size {
            data.appendBytes(&byte, length: 1)
        }
        return data
    }
    
    func createRandomData(size: Int = 1234) -> NSData {
        let data = NSMutableData()
        for _ in 0 ..< size {
            var byte = UInt8(rand() % 0x0100)
            data.appendBytes(&byte, length: 1)
        }
        return data
    }
    
    func createFiles(files: [String : NSData], baseDirectory: String) -> Bool {
        var success = true
        for fileName in files.keys {
            if fileName.hasSuffix("/") {
                let directory = baseDirectory + fileName
                var isDirectory = ObjCBool(false)
                if !fileManager.fileExistsAtPath(directory, isDirectory: &isDirectory) {
                    do {
                        try fileManager.createDirectoryAtPath(directory, withIntermediateDirectories: true, attributes: nil)
                    }
                    catch {
                        success = false
                        break
                    }
                }
                else {
                    if !isDirectory.boolValue {
                        success = false
                        break
                    }
                }
            }
            else {
                let data = files[fileName]!
                let stragePath = baseDirectory + fileName
                let directory = NSURL(string: stragePath)!.URLByDeletingLastPathComponent!.path!
                if !fileManager.fileExistsAtPath(directory) {
                    do {
                        try fileManager.createDirectoryAtPath(directory, withIntermediateDirectories: true, attributes: nil)
                    }
                    catch {
                        success = false
                        break
                    }
                }
                success = data.writeToFile(stragePath, atomically: true)
                if !success {
                    break
                }
            }
        }
        return success
    }
    
}

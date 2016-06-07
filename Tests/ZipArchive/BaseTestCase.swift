//
//  BaseTestCase.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2016/01/31.
//  Copyright © 2016 yaslab. All rights reserved.
//

import XCTest

class BaseTestCase: XCTestCase {

    let fileManager = NSFileManager.default()
    let testBaseDirectory = "/tmp/ZipArchiveTest/"
    var testDataDirectory: String { return testBaseDirectory + "ZipArchiveData/" }
    var zipDestinationDirectory: String { return  testBaseDirectory + "Zip/" }
    var unzipDestinationDirectory: String { return  testBaseDirectory + "Unzip/" }
    
    let bufferSize = 8192
    
    override func setUp() {
        super.setUp()
    }
    
    func cleanUp() throws {
        if fileManager.fileExists(atPath: testBaseDirectory) {
            try fileManager.removeItem(atPath: testBaseDirectory)
        }
        try fileManager.createDirectory(atPath: testBaseDirectory, withIntermediateDirectories: false, attributes: nil)
        try fileManager.createDirectory(atPath: testDataDirectory, withIntermediateDirectories: false, attributes: nil)
        try fileManager.createDirectory(atPath: zipDestinationDirectory, withIntermediateDirectories: false, attributes: nil)
        try fileManager.createDirectory(atPath: unzipDestinationDirectory, withIntermediateDirectories: false, attributes: nil)
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
            data.append(&byte, length: 1)
        }
        return data
    }
    
    func createRandomData(size: Int = 1234) -> NSData {
        let data = NSMutableData()
        for _ in 0 ..< size {
            var byte = UInt8(rand() % 0x0100)
            data.append(&byte, length: 1)
        }
        return data
    }
    
    func createFiles(files: [String : NSData], baseDirectory: String) -> Bool {
        var success = true
        for fileName in files.keys {
            if fileName.hasSuffix("/") {
                let directory = baseDirectory + fileName
                var isDirectory = ObjCBool(false)
                if !fileManager.fileExists(atPath: directory, isDirectory: &isDirectory) {
                    do {
                        try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
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
                let directory = NSURL(string: stragePath)!.deletingLastPathComponent!.path!
                if !fileManager.fileExists(atPath: directory) {
                    do {
                        try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
                    }
                    catch {
                        success = false
                        break
                    }
                }
                success = data.write(toFile: stragePath, atomically: true)
                if !success {
                    break
                }
            }
        }
        return success
    }
    
}

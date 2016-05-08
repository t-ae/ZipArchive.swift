//
//  ZipFileTests.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2016/01/31.
//  Copyright © 2016 yaslab. All rights reserved.
//

import XCTest
import ZipArchive

class ZipFileTests: BaseTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        srand(UInt32(time(nil)))
        
        do {
            try cleanUp()
        }
        catch { XCTFail() }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {
        let files: [String : NSData] = [
            "test_data1.dat" : createData()
        ]
        
        let created = createFiles(files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let zipFileName = "test.zip"
        let zipFilePath = zipDestinationDirectory + zipFileName
        
        try! ZipFile.createFromDirectory(testDataDirectory, destinationArchiveFileName: zipFilePath, password: "abcde")
        try! ZipFile.extractToDirectory(zipFilePath, destinationDirectoryName: unzipDestinationDirectory, password: "abcde")
        
        for fileName in files.keys {
            let data = files[fileName]!
            let unzippedPath = unzipDestinationDirectory + fileName
            let unzippedData = NSData(contentsOfFile: unzippedPath)!
            XCTAssertTrue(data.isEqualToData(unzippedData))
        }
    }

    func testExample2() {
        let files: [String : NSData] = [
            "test_data1.dat" : createData()
        ]
        
        let created = createFiles(files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let zipFileName = "test.zip"
        let zipFilePath = zipDestinationDirectory + zipFileName
        
        let ret = executeCommand("zip -P 'abcde' '\(zipFilePath)' -r .", workingDirectory: testDataDirectory)
        XCTAssertEqual(0, ret)
        
        try! ZipFile.extractToDirectory(zipFilePath, destinationDirectoryName: unzipDestinationDirectory, password: "abcde")
        
        for fileName in files.keys {
            let data = files[fileName]!
            let unzippedPath = unzipDestinationDirectory + fileName
            let unzippedData = NSData(contentsOfFile: unzippedPath)!
            XCTAssertTrue(data.isEqualToData(unzippedData))
        }
    }
    
    func testExample3() {
        let files: [String : NSData] = [
            "test_data1.dat" : createData()
        ]
        
        let created = createFiles(files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let zipFileName = "test.zip"
        let zipFilePath = zipDestinationDirectory + zipFileName
        
        try! ZipFile.createFromDirectory(testDataDirectory, destinationArchiveFileName: zipFilePath, password: "abcde")

        let ret = executeCommand("unzip -d '\(unzipDestinationDirectory)' -P abcde '\(zipFilePath)'", workingDirectory: nil)
        XCTAssertEqual(0, ret)
        
        for fileName in files.keys {
            let data = files[fileName]!
            let unzippedPath = unzipDestinationDirectory + fileName
            let unzippedData = NSData(contentsOfFile: unzippedPath)!
            XCTAssertTrue(data.isEqualToData(unzippedData))
        }
    }
    
}

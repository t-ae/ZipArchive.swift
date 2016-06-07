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

    // MARK: Fixed Data
    
    func testSelfZipSelfUnzipWithFixedDataAndPassword() {
        let files: [String : NSData] = [
            "test_data1.dat" : createFixedData()
        ]
        _testSelfZipSelfUnzipWithPassword(files)
    }
    
    func testSystemZipSelfUnzipWithFixedDataAndPassword() {
        let files: [String : NSData] = [
            "test_data1.dat" : createFixedData()
        ]
        _testSystemZipSelfUnzipWithPassword(files)
    }
    
    func testSelfZipSystemUnzipWithFixedDataAndPassword() {
        let files: [String : NSData] = [
            "test_data1.dat" : createFixedData()
        ]
        _testSelfZipSystemUnzipWithPassword(files)
    }
    
    // MARK: Random Data
    
    func testSelfZipSelfUnzipWithRandomDataAndPassword() {
        let files: [String : NSData] = [
            "test_data1.dat" : createRandomData()
        ]
        _testSelfZipSelfUnzipWithPassword(files)
    }
    
    func testSystemZipSelfUnzipWithRandomDataAndPassword() {
        let files: [String : NSData] = [
            "test_data1.dat" : createRandomData()
        ]
        _testSystemZipSelfUnzipWithPassword(files)
    }
    
    func testSelfZipSystemUnzipWithRandomDataAndPassword() {
        let files: [String : NSData] = [
            "test_data1.dat" : createRandomData()
        ]
        _testSelfZipSystemUnzipWithPassword(files)
    }
    
    // MARK: Utility
    
    private func _testSelfZipSelfUnzipWithPassword(files: [String : NSData]) {
        let created = createFiles(files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let zipFileName = "test.zip"
        let zipFilePath = zipDestinationDirectory + zipFileName
        let password = "abcde"
        
        try! ZipFile.createFromDirectory(testDataDirectory, destinationArchiveFileName: zipFilePath, password: password)
        try! ZipFile.extractToDirectory(zipFilePath, destinationDirectoryName: unzipDestinationDirectory, password: password)
        
        for fileName in files.keys {
            let data = files[fileName]!
            let unzippedPath = unzipDestinationDirectory + fileName
            let unzippedData = NSData(contentsOfFile: unzippedPath)!
            XCTAssertTrue(data.isEqualToData(unzippedData))
        }
    }

    private func _testSystemZipSelfUnzipWithPassword(files: [String : NSData]) {
        let created = createFiles(files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let zipFileName = "test.zip"
        let zipFilePath = zipDestinationDirectory + zipFileName
        let password = "abcde"
        
        let ret = executeCommand("zip -P '\(password)' '\(zipFilePath)' -r .", workingDirectory: testDataDirectory)
        XCTAssertEqual(0, ret)
        
        try! ZipFile.extractToDirectory(zipFilePath, destinationDirectoryName: unzipDestinationDirectory, password: password)
        
        for fileName in files.keys {
            let data = files[fileName]!
            let unzippedPath = unzipDestinationDirectory + fileName
            let unzippedData = NSData(contentsOfFile: unzippedPath)!
            XCTAssertTrue(data.isEqualToData(unzippedData))
        }
    }
    
    private func _testSelfZipSystemUnzipWithPassword(files: [String : NSData]) {
        let created = createFiles(files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let zipFileName = "test.zip"
        let zipFilePath = zipDestinationDirectory + zipFileName
        let password = "abcde"
        
        try! ZipFile.createFromDirectory(testDataDirectory, destinationArchiveFileName: zipFilePath, password: password)

        let ret = executeCommand("unzip -d '\(unzipDestinationDirectory)' -P '\(password)' '\(zipFilePath)'", workingDirectory: nil)
        XCTAssertEqual(0, ret)
        
        for fileName in files.keys {
            let data = files[fileName]!
            let unzippedPath = unzipDestinationDirectory + fileName
            let unzippedData = NSData(contentsOfFile: unzippedPath)!
            XCTAssertTrue(data.isEqualToData(unzippedData))
        }
    }
    
}

//
//  ZipFileTests.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2016/01/31.
//  Copyright © 2016 yaslab. All rights reserved.
//

import XCTest
@testable import ZipArchive

class ZipFileTests: BaseTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        //srand(UInt32(time(nil)))
        
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
        let files: [String : Data] = [
            "test_data1.dat" : createFixedData()
        ]
        _testSelfZipSelfUnzipWithPassword(files: files)
    }
    
    func testSystemZipSelfUnzipWithFixedDataAndPassword() {
        let files: [String : Data] = [
            "test_data1.dat" : createFixedData()
        ]
        _testSystemZipSelfUnzipWithPassword(files: files)
    }
    
    func testSelfZipSystemUnzipWithFixedDataAndPassword() {
        let files: [String : Data] = [
            "test_data1.dat" : createFixedData()
        ]
        _testSelfZipSystemUnzipWithPassword(files: files)
    }
    
    // MARK: Random Data
    
    func testSelfZipSelfUnzipWithRandomDataAndPassword() {
        let files: [String : Data] = [
            "test_data1.dat" : createRandomData()
        ]
        _testSelfZipSelfUnzipWithPassword(files: files)
    }
    
    func testSystemZipSelfUnzipWithRandomDataAndPassword() {
        let files: [String : Data] = [
            "test_data1.dat" : createRandomData(),
            "test_data2.dat" : createRandomData(),
            "test_data3.dat" : createFixedData(),
            "test_data4.dat" : createFixedData(),
            "test_data5.dat" : createRandomData(),
            "test_data6.dat" : createFixedData(),
            "test_data7.dat" : createRandomData(),
            "test_data8.dat" : createFixedData()
        ]
        _testSystemZipSelfUnzipWithPassword(files: files)
    }
    
    func testSelfZipSystemUnzipWithRandomDataAndPassword() {
        let files: [String : Data] = [
            "test_data1.dat" : createRandomData(),
            "test_data2.dat" : createRandomData(),
            "test_data3.dat" : createFixedData(),
            "test_data4.dat" : createFixedData(),
            "test_data5.dat" : createRandomData(),
            "test_data6.dat" : createFixedData(),
            "test_data7.dat" : createRandomData(),
            "test_data8.dat" : createFixedData()
        ]
        _testSelfZipSystemUnzipWithPassword(files: files)
    }
    
    // MARK: Utility
    
    private func _testSelfZipSelfUnzipWithPassword(files: [String : Data]) {
        let created = createFiles(files: files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let zipFileName = "test.zip"
        let zipFilePath = zipDestinationDirectory + zipFileName
        let password = "abcde"
        
        try! ZipFile.createFromDirectory(sourceDirectoryName: testDataDirectory, destinationArchiveFileName: zipFilePath, password: password)
        try! ZipFile.extractToDirectory(sourceArchiveFileName: zipFilePath, destinationDirectoryName: unzipDestinationDirectory, password: password)
        
        for fileName in files.keys {
            let data = files[fileName]!
            let unzippedPath = unzipDestinationDirectory + fileName
            let unzippedData = try! Data(contentsOf: URL(fileURLWithPath: unzippedPath))
            XCTAssertEqual(data, unzippedData)
        }
    }

    private func _testSystemZipSelfUnzipWithPassword(files: [String : Data]) {
        let created = createFiles(files: files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let zipFileName = "test.zip"
        let zipFilePath = zipDestinationDirectory + zipFileName
        let password = "abcde"
        
        let ret = executeCommand(
            command: "/usr/bin/zip",
            arguments: ["-P", password, zipFilePath, "-r", "."],
            workingDirectory: testDataDirectory
        )
        XCTAssertEqual(0, ret)
        
        try! ZipFile.extractToDirectory(sourceArchiveFileName: zipFilePath, destinationDirectoryName: unzipDestinationDirectory, password: password)
        
        for fileName in files.keys {
            let data = files[fileName]!
            let unzippedPath = unzipDestinationDirectory + fileName
            let unzippedData = try! Data(contentsOf: URL(fileURLWithPath: unzippedPath))
            XCTAssertEqual(data, unzippedData)
        }
    }
    
    private func _testSelfZipSystemUnzipWithPassword(files: [String : Data]) {
        let created = createFiles(files: files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let zipFileName = "test.zip"
        let zipFilePath = zipDestinationDirectory + zipFileName
        let password = "abcde"
        //let password = "a"
        
        try! ZipFile.createFromDirectory(sourceDirectoryName: testDataDirectory, destinationArchiveFileName: zipFilePath, password: password)

        let ret = executeCommand(
            command: "/usr/bin/unzip",
            arguments: ["-d", unzipDestinationDirectory, "-P", password, zipFilePath],
            workingDirectory: nil
        )
        XCTAssertEqual(0, ret)
        
        for fileName in files.keys {
            let data = files[fileName]!
            let unzippedPath = unzipDestinationDirectory + fileName
            let unzippedData = try! Data(contentsOf: URL(fileURLWithPath: unzippedPath))
            XCTAssertEqual(data, unzippedData)
        }
    }
    
}

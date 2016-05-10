//
//  ZipArchiveTests.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2016/01/31.
//  Copyright © 2016 yaslab. All rights reserved.
//

import XCTest
import ZipArchive

class ZipArchiveTestCase: BaseTestCase {

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

    func test圧縮ファイル() {
        let files: [String : NSData] = [
            "test_data.dat" : createFixedData()
        ]

        let archiveFile = zipDestinationDirectory + "test.zip"
        let archive = ZipArchive(path: archiveFile, mode: .Create)!
        defer { archive.dispose() }
        
        for fileName in files.keys {
            let entry = archive.createEntry(fileName)!
            let stream = entry.open()!
            let data = files[fileName]!
            stream.write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
        }
        
        let ret = executeCommand("unzip -d '\(unzipDestinationDirectory)' '\(archiveFile)'", workingDirectory: nil)
        XCTAssertEqual(0, ret)
        
        for fileName in files.keys {
            let unzipTestDataFile = unzipDestinationDirectory + fileName
            let unzipTestData = NSData(contentsOfFile: unzipTestDataFile)!
            let data = files[fileName]!
            XCTAssertTrue(data.isEqualToData(unzipTestData))
        }
    }

    func test解凍ファイル() {
        let files: [String : NSData] = [
            "test_data.dat" : createFixedData()
        ]

        let created = createFiles(files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let archiveFile = zipDestinationDirectory + "test.zip"
        let fileArgs =  files.map { (pair) -> String in pair.0 }.joinWithSeparator(" ")
        let ret = executeCommand("zip '\(archiveFile)' \(fileArgs)", workingDirectory: testDataDirectory)
        XCTAssertEqual(0, ret)
        
        let archive = ZipArchive(path: archiveFile, mode: .Read)!
        defer { archive.dispose() }
        
        var count = 0
        for entry in archive.entries {
            let stream = entry.open()!
            let data = NSMutableData(length: Int(entry.length))!
            stream.read(UnsafeMutablePointer<UInt8>(data.mutableBytes), maxLength: data.length)
            let testData = files[entry.fullName]!
            XCTAssertTrue(data.isEqualToData(testData))
            count += 1
        }
        
        XCTAssertEqual(files.count, count)
    }
    
    func test解凍ファイルとディレクトリ() {
        let files: [String : NSData] = [
            "test_data1.dat" : createFixedData(),
            "subdir/test_data2.dat" : createRandomData(),
            "subdir/" : createRandomData(0)
        ]
        
        let created = createFiles(files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let archiveFile = zipDestinationDirectory + "test.zip"
        let ret = executeCommand("zip '\(archiveFile)' -r .", workingDirectory: testDataDirectory)
        XCTAssertEqual(0, ret)
        
        let archive = ZipArchive(path: archiveFile, mode: .Read)!
        defer { archive.dispose() }
        
        var count = 0
        for entry in archive.entries {
            let stream = entry.open()!
            let data = NSMutableData(length: Int(entry.length))!
            stream.read(UnsafeMutablePointer<UInt8>(data.mutableBytes), maxLength: data.length)
            let testData = files[entry.fullName]!
            XCTAssertTrue(data.isEqualToData(testData))
            count += 1
        }
        
        XCTAssertEqual(files.count, count)
    }

    func test圧縮ファイルのバッファサイズ() {
        let files: [String : NSData] = [
            "test_data1.dat" : createFixedData(kZipArchiveDefaultBufferSize - 1),
            "test_data2.dat" : createFixedData(kZipArchiveDefaultBufferSize),
            "test_data3.dat" : createFixedData(kZipArchiveDefaultBufferSize + 1),
            "test_data4.dat" : createRandomData(kZipArchiveDefaultBufferSize * 2 - 1),
            "test_data5.dat" : createRandomData(kZipArchiveDefaultBufferSize * 2),
            "test_data6.dat" : createRandomData(kZipArchiveDefaultBufferSize * 2 + 1),
            "test_data7.dat" : createFixedData(kZipArchiveDefaultBufferSize * 3 - 1),
            "test_data8.dat" : createRandomData(kZipArchiveDefaultBufferSize * 3),
            "test_data9.dat" : createFixedData(kZipArchiveDefaultBufferSize * 3 + 1),
        ]
        
        let created = createFiles(files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let archiveFile = zipDestinationDirectory + "test.zip"
        let archive = ZipArchive(path: archiveFile, mode: .Create)!
        defer { archive.dispose() }
        
        for fileName in files.keys {
            let testDataFilePath = testDataDirectory + fileName
            archive.createEntryFromFile(testDataFilePath, entryName: fileName)
        }

        let ret = executeCommand("unzip -d '\(unzipDestinationDirectory)' '\(archiveFile)'", workingDirectory: nil)
        XCTAssertEqual(0, ret)
        
        for fileName in files.keys {
            let data = files[fileName]!
            let unzippedPath = unzipDestinationDirectory + fileName
            let unzippedData = NSData(contentsOfFile: unzippedPath)!
            XCTAssertTrue(data.isEqualToData(unzippedData))
        }
    }
    
    func test解凍ファイルのバッファサイズ() {
        let files: [String : NSData] = [
            "test_data1.dat" : createRandomData(kZipArchiveDefaultBufferSize - 1),
            "test_data2.dat" : createRandomData(kZipArchiveDefaultBufferSize),
            "test_data3.dat" : createRandomData(kZipArchiveDefaultBufferSize + 1),
            "test_data4.dat" : createFixedData(kZipArchiveDefaultBufferSize * 2 - 1),
            "test_data5.dat" : createFixedData(kZipArchiveDefaultBufferSize * 2),
            "test_data6.dat" : createFixedData(kZipArchiveDefaultBufferSize * 2 + 1),
            "test_data7.dat" : createRandomData(kZipArchiveDefaultBufferSize * 3 - 1),
            "test_data8.dat" : createFixedData(kZipArchiveDefaultBufferSize * 3),
            "test_data9.dat" : createRandomData(kZipArchiveDefaultBufferSize * 3 + 1),
        ]
        
        let created = createFiles(files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let archiveFile = zipDestinationDirectory + "test.zip"
        let fileArgs =  files.map { (pair) -> String in pair.0 }.joinWithSeparator(" ")
        let ret = executeCommand("zip '\(archiveFile)' \(fileArgs)", workingDirectory: testDataDirectory)
        XCTAssertEqual(0, ret)
        
        let archive = ZipArchive(path: archiveFile, mode: .Read)!
        defer { archive.dispose() }
        
        var count = 0
        for entry in archive.entries {
            let stream = entry.open()!
            let data = NSMutableData(length: Int(entry.length))!
            stream.read(UnsafeMutablePointer<UInt8>(data.mutableBytes), maxLength: data.length)
            let testData = files[entry.fullName]!
            XCTAssertTrue(data.isEqualToData(testData))
            count += 1
        }
        
        XCTAssertEqual(files.count, count)
    }
    
}

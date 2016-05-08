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
            "test_data.dat" : createData()
        ]

        let archiveFile = zipDestinationDirectory + "test.zip"
        let archive = ZipArchive(path: archiveFile, mode: .Create)!
        
        for fileName in files.keys {
            let entry = archive.createEntry(fileName)!
            let stream = entry.open()!
            let data = files[fileName]!
            stream.write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
        }
        
        archive.dispose()
        
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
            "test_data.dat" : createData()
        ]

        try! createFiles(files, baseDirectory: testDataDirectory)
        
        let archiveFile = zipDestinationDirectory + "test.zip"
        let fileArgs =  files.map { (pair) -> String in pair.0 }.joinWithSeparator(" ")
        let ret = executeCommand("zip '\(archiveFile)' \(fileArgs)", workingDirectory: testDataDirectory)
        XCTAssertEqual(0, ret)
        
        let archive = ZipArchive(path: archiveFile, mode: .Read)!
        
        var count = 0
        for entry in archive.entries {
            let stream = entry.open()!
            let data = NSMutableData(length: Int(entry.length))!
            stream.read(UnsafeMutablePointer<UInt8>(data.mutableBytes), maxLength: data.length)
            let testData = files[entry.fullName]!
            XCTAssertTrue(data.isEqualToData(testData))
            count += 1
        }
        
        archive.dispose()
        
        XCTAssertEqual(files.count, count)
    }
    
    func test解凍ファイルとディレクトリ() {
        let files: [String : NSData] = [
            "test_data1.dat" : createData(),
            "subdir/test_data2.dat" : createData(),
            "subdir/" : createData(0)
        ]
        
        try! createFiles(files, baseDirectory: testDataDirectory)
        
        let archiveFile = zipDestinationDirectory + "test.zip"
        let ret = executeCommand("zip '\(archiveFile)' -r .", workingDirectory: testDataDirectory)
        XCTAssertEqual(0, ret)
        
        let archive = ZipArchive(path: archiveFile, mode: .Read)!
        
        var count = 0
        for entry in archive.entries {
            let stream = entry.open()!
            let data = NSMutableData(length: Int(entry.length))!
            stream.read(UnsafeMutablePointer<UInt8>(data.mutableBytes), maxLength: data.length)
            let testData = files[entry.fullName]!
            XCTAssertTrue(data.isEqualToData(testData))
            count += 1
        }
        
        archive.dispose()
        
        XCTAssertEqual(files.count, count)
    }

    func test圧縮ファイルのバッファサイズ() {
        let files: [String : NSData] = [
            "test_data1.dat" : createData(kZipArchiveDefaultBufferSize - 1),
            "test_data2.dat" : createData(kZipArchiveDefaultBufferSize),
            "test_data3.dat" : createData(kZipArchiveDefaultBufferSize + 1),
            "test_data4.dat" : createData(kZipArchiveDefaultBufferSize * 2 - 1),
            "test_data5.dat" : createData(kZipArchiveDefaultBufferSize * 2),
            "test_data6.dat" : createData(kZipArchiveDefaultBufferSize * 2 + 1),
            "test_data7.dat" : createData(kZipArchiveDefaultBufferSize * 3 - 1),
            "test_data8.dat" : createData(kZipArchiveDefaultBufferSize * 3),
            "test_data9.dat" : createData(kZipArchiveDefaultBufferSize * 3 + 1),
        ]
        
        try! createFiles(files, baseDirectory: testDataDirectory)

        let archiveFile = zipDestinationDirectory + "test.zip"
        let archive = ZipArchive(path: archiveFile, mode: .Create)!
        for fileName in files.keys {
            let testDataFilePath = testDataDirectory + fileName
            archive.createEntryFromFile(testDataFilePath, entryName: fileName)
        }
        archive.dispose()

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
            "test_data1.dat" : createData(kZipArchiveDefaultBufferSize - 1),
            "test_data2.dat" : createData(kZipArchiveDefaultBufferSize),
            "test_data3.dat" : createData(kZipArchiveDefaultBufferSize + 1),
            "test_data4.dat" : createData(kZipArchiveDefaultBufferSize * 2 - 1),
            "test_data5.dat" : createData(kZipArchiveDefaultBufferSize * 2),
            "test_data6.dat" : createData(kZipArchiveDefaultBufferSize * 2 + 1),
            "test_data7.dat" : createData(kZipArchiveDefaultBufferSize * 3 - 1),
            "test_data8.dat" : createData(kZipArchiveDefaultBufferSize * 3),
            "test_data9.dat" : createData(kZipArchiveDefaultBufferSize * 3 + 1),
        ]
        
        try! createFiles(files, baseDirectory: testDataDirectory)
        
        let archiveFile = zipDestinationDirectory + "test.zip"
        let fileArgs =  files.map { (pair) -> String in pair.0 }.joinWithSeparator(" ")
        let ret = executeCommand("zip '\(archiveFile)' \(fileArgs)", workingDirectory: testDataDirectory)
        XCTAssertEqual(0, ret)
        
        let archive = ZipArchive(path: archiveFile, mode: .Read)!
        
        var count = 0
        for entry in archive.entries {
            let stream = entry.open()!
            let data = NSMutableData(length: Int(entry.length))!
            stream.read(UnsafeMutablePointer<UInt8>(data.mutableBytes), maxLength: data.length)
            let testData = files[entry.fullName]!
            XCTAssertTrue(data.isEqualToData(testData))
            count += 1
        }
        
        archive.dispose()
        
        XCTAssertEqual(files.count, count)
    }
    
}

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
        
        for fileName in files.keys {
            let entry = archive.createEntry(entryName: fileName)!
            let stream = entry.open()!
            let data = files[fileName]!
            stream.write(buffer: UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
        }
        
        archive.dispose()
        
        let ret = executeCommand(command: "unzip -d '\(unzipDestinationDirectory)' '\(archiveFile)'", workingDirectory: nil)
        XCTAssertEqual(0, ret)
        
        for fileName in files.keys {
            let unzipTestDataFile = unzipDestinationDirectory + fileName
            let unzipTestData = NSData(contentsOfFile: unzipTestDataFile)!
            let data = files[fileName]!
            XCTAssertTrue(data.isEqual(to: unzipTestData))
        }
    }

    func test解凍ファイル() {
        let files: [String : NSData] = [
            "test_data.dat" : createFixedData()
        ]

        let created = createFiles(files: files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let archiveFile = zipDestinationDirectory + "test.zip"
        let fileArgs =  files.map { (pair) -> String in pair.0 }.joined(separator: " ")
        let ret = executeCommand(command: "zip '\(archiveFile)' \(fileArgs)", workingDirectory: testDataDirectory)
        XCTAssertEqual(0, ret)
        
        let archive = ZipArchive(path: archiveFile, mode: .Read)!
        
        var count = 0
        for entry in archive.entries {
            let stream = entry.open()!
            let data = NSMutableData(length: Int(entry.length))!
            stream.read(buffer: UnsafeMutablePointer<UInt8>(data.mutableBytes), maxLength: data.length)
            let testData = files[entry.fullName]!
            XCTAssertTrue(data.isEqual(to: testData))
            count += 1
        }

        archive.dispose()
        
        XCTAssertEqual(files.count, count)
    }
    
    func test解凍ファイルとディレクトリ() {
        let files: [String : NSData] = [
            "test_data1.dat" : createFixedData(),
            "subdir/test_data2.dat" : createRandomData(),
            "subdir/" : createRandomData(size: 0)
        ]
        
        let created = createFiles(files: files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let archiveFile = zipDestinationDirectory + "test.zip"
        let ret = executeCommand(command: "zip '\(archiveFile)' -r .", workingDirectory: testDataDirectory)
        XCTAssertEqual(0, ret)
        
        let archive = ZipArchive(path: archiveFile, mode: .Read)!
        
        var count = 0
        for entry in archive.entries {
            let stream = entry.open()!
            let data = NSMutableData(length: Int(entry.length))!
            stream.read(buffer: UnsafeMutablePointer<UInt8>(data.mutableBytes), maxLength: data.length)
            let testData = files[entry.fullName]!
            XCTAssertTrue(data.isEqual(to: testData))
            count += 1
        }

        archive.dispose()
        
        XCTAssertEqual(files.count, count)
    }

    func test圧縮ファイルのバッファサイズ() {
        let files: [String : NSData] = [
            "test_data1.dat" : createFixedData(size: kZipArchiveDefaultBufferSize - 1),
            "test_data2.dat" : createFixedData(size: kZipArchiveDefaultBufferSize),
            "test_data3.dat" : createFixedData(size: kZipArchiveDefaultBufferSize + 1),
            "test_data4.dat" : createRandomData(size: kZipArchiveDefaultBufferSize * 2 - 1),
            "test_data5.dat" : createRandomData(size: kZipArchiveDefaultBufferSize * 2),
            "test_data6.dat" : createRandomData(size: kZipArchiveDefaultBufferSize * 2 + 1),
            "test_data7.dat" : createFixedData(size: kZipArchiveDefaultBufferSize * 3 - 1),
            "test_data8.dat" : createRandomData(size: kZipArchiveDefaultBufferSize * 3),
            "test_data9.dat" : createFixedData(size: kZipArchiveDefaultBufferSize * 3 + 1),
        ]
        
        let created = createFiles(files: files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let archiveFile = zipDestinationDirectory + "test.zip"
        let archive = ZipArchive(path: archiveFile, mode: .Create)!
        
        for fileName in files.keys {
            let testDataFilePath = testDataDirectory + fileName
            archive.createEntryFromFile(sourceFileName: testDataFilePath, entryName: fileName)
        }
        
        archive.dispose()

        let ret = executeCommand(command: "unzip -d '\(unzipDestinationDirectory)' '\(archiveFile)'", workingDirectory: nil)
        XCTAssertEqual(0, ret)
        
        for fileName in files.keys {
            let data = files[fileName]!
            let unzippedPath = unzipDestinationDirectory + fileName
            let unzippedData = NSData(contentsOfFile: unzippedPath)!
            XCTAssertTrue(data.isEqual(to: unzippedData))
        }
    }
    
    func test解凍ファイルのバッファサイズ() {
        let files: [String : NSData] = [
            "test_data1.dat" : createRandomData(size: kZipArchiveDefaultBufferSize - 1),
            "test_data2.dat" : createRandomData(size: kZipArchiveDefaultBufferSize),
            "test_data3.dat" : createRandomData(size: kZipArchiveDefaultBufferSize + 1),
            "test_data4.dat" : createFixedData(size: kZipArchiveDefaultBufferSize * 2 - 1),
            "test_data5.dat" : createFixedData(size: kZipArchiveDefaultBufferSize * 2),
            "test_data6.dat" : createFixedData(size: kZipArchiveDefaultBufferSize * 2 + 1),
            "test_data7.dat" : createRandomData(size: kZipArchiveDefaultBufferSize * 3 - 1),
            "test_data8.dat" : createFixedData(size: kZipArchiveDefaultBufferSize * 3),
            "test_data9.dat" : createRandomData(size: kZipArchiveDefaultBufferSize * 3 + 1),
        ]
        
        let created = createFiles(files: files, baseDirectory: testDataDirectory)
        XCTAssertTrue(created)
        
        let archiveFile = zipDestinationDirectory + "test.zip"
        let fileArgs =  files.map { (pair) -> String in pair.0 }.joined(separator: " ")
        let ret = executeCommand(command: "zip '\(archiveFile)' \(fileArgs)", workingDirectory: testDataDirectory)
        XCTAssertEqual(0, ret)
        
        let archive = ZipArchive(path: archiveFile, mode: .Read)!
        
        var count = 0
        for entry in archive.entries {
            let stream = entry.open()!
            let data = NSMutableData(length: Int(entry.length))!
            stream.read(buffer: UnsafeMutablePointer<UInt8>(data.mutableBytes), maxLength: data.length)
            let testData = files[entry.fullName]!
            XCTAssertTrue(data.isEqual(to: testData))
            count += 1
        }

        archive.dispose()
        
        XCTAssertEqual(files.count, count)
    }
    
}

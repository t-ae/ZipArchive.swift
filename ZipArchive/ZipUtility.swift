//
//  ZipUtility.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/08.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation
import Minizip

internal func createFileFuncDef(opaque: ZipArchiveStream) -> zlib_filefunc64_def {
    var filefuncDef = zlib_filefunc64_def()
    
    filefuncDef.opaque = unsafeBitCast(opaque as AnyObject, UnsafeMutablePointer<Void>.self)
    
    filefuncDef.zopen64_file = { (opaque: voidpf, _: UnsafePointer<Void>, _: Int32) -> voidpf in
        return opaque
    }
    filefuncDef.zread_file = { (_: voidpf, _stream: voidpf, buf: UnsafeMutablePointer<Void>, size: uLong) -> uLong in
        let stream = unsafeBitCast(_stream, AnyObject.self) as! ZipArchiveStream
        let ret = stream.read(UnsafeMutablePointer<UInt8>(buf), maxLength: Int(size))
        return uLong(ret)
    }
    filefuncDef.zwrite_file = { (_: voidpf, _stream: voidpf, buf: UnsafePointer<Void>, size: uLong) -> uLong in
        let stream = unsafeBitCast(_stream, AnyObject.self) as! ZipArchiveStream
        let ret = stream.write(UnsafePointer<UInt8>(buf), maxLength: Int(size))
        return uLong(ret)
    }
    filefuncDef.ztell64_file = { (_: voidpf, _stream: voidpf) -> ZPOS64_T in
        let stream = unsafeBitCast(_stream, AnyObject.self) as! ZipArchiveStream
        return ZPOS64_T(stream.position)
    }
    filefuncDef.zseek64_file = { (_: voidpf, _stream: voidpf, _offset: ZPOS64_T, _origin: Int32) -> Int in
        let stream = unsafeBitCast(_stream, AnyObject.self) as! ZipArchiveStream
        let offset = Int(_offset)
        
        var origin: SeekOrigin
        switch _origin {
        case ZLIB_FILEFUNC_SEEK_SET:
            origin = .Begin
        case ZLIB_FILEFUNC_SEEK_CUR:
            origin = .Current
        case ZLIB_FILEFUNC_SEEK_END:
            origin = .End
        default:
            // ERROR
            errno = EINVAL
            return -1
        }
        return stream.seek(offset, origin: origin)
    }
    filefuncDef.zclose_file = { (_: voidpf, _stream: voidpf) -> Int32 in
        let stream = unsafeBitCast(_stream, AnyObject.self) as! ZipArchiveStream
        stream.close()
        return 0
    }
    filefuncDef.zerror_file = { (_: voidpf, _stream: voidpf) -> Int32 in
        return 0
    }
    
    return filefuncDef
}

/* calculate the CRC32 of a file, because to encrypt a file, we need known the CRC32 of the file before */
public func crc32__(withFilePath path: String) throws -> UInt {
    let fm = NSFileManager.defaultManager()
    if !fm.fileExistsAtPath(path) {
        throw ZipError.FileNotFound
    }
    guard let stream = NSInputStream(fileAtPath: path) else {
        throw ZipError.IO
    }
    
    stream.open()
    if let _ = stream.streamError {
        throw ZipError.IO
    }
    
    let buffer = UnsafeMutablePointer<UInt8>.alloc(kZipArchiveDefaultBufferSize)
    //let bufferLength = sizeof(UInt8) * kZipArchiveBufferCount
    
    var crc: uLong = 0
    
    while true {
        let len = stream.read(buffer, maxLength: kZipArchiveDefaultBufferSize)
        if len <= 0 {
            break
        }
        crc = crc32(crc, buffer, uInt(len))
    }
    
    buffer.destroy()
    buffer.dealloc(kZipArchiveDefaultBufferSize)
    stream.close()
    if let _ = stream.streamError {
        throw ZipError.IO
    }
    
    return crc
}

internal func date(fromDosDate dosDateTime: uLong) -> NSDate? {
    let date = dosDateTime >> 16
    let calendar = NSCalendar.currentCalendar()
    let comps = NSDateComponents()
    comps.second = Int(2 * (dosDateTime & 0x1F))
    comps.minute = Int((dosDateTime & 0x07E0) / 0x20)
    comps.hour = Int((dosDateTime & 0xF800) / 0x0800)
    comps.day = Int(date & 0x1F)
    comps.month = Int((date & 0x01E0) / 0x20)
    comps.year = Int(((date & 0xFE00) / 0x0200) + 1980)
    return calendar.dateFromComponents(comps)
}

internal func tmZip(fromDate date: NSDate) -> tm_zip {
    let calendar = NSCalendar.currentCalendar()
    let comps = calendar.components([.Second, .Minute, .Hour, .Day, .Month, .Year], fromDate: date)
    var tm = tm_zip()
    tm.tm_sec = uInt(comps.second)
    tm.tm_min = uInt(comps.minute)
    tm.tm_hour = uInt(comps.hour)
    tm.tm_mday = uInt(comps.day)
    tm.tm_mon = uInt(comps.month - 1)
    tm.tm_year = uInt(comps.year)
    return tm
}

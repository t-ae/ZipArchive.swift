//
//  ZipArchiveEntryStream.Deflate.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/15.
//  Copyright © 2017 yaslab. All rights reserved.
//

import Foundation
import Czlib

// compress
private func deflateInit2(_ strm: z_streamp!, _ level: Int32, _ method: Int32, _ windowBits: Int32, _ memLevel: Int32, _ strategy: Int32) -> Int32 {
    let streamSize = Int32(MemoryLayout<z_stream>.size)
    return deflateInit2_(strm, level, method, windowBits, memLevel, strategy, ZLIB_VERSION, streamSize)
}

// decompress
private func inflateInit2(_ strm: z_streamp!, _ windowBits: Int32) -> Int32 {
    let streamSize = Int32(MemoryLayout<z_stream>.size)
    return inflateInit2_(strm, windowBits, ZLIB_VERSION, streamSize)
}

public enum CompressionMode {
    
    case compress
    case decompress
    
}

public class DeflateStream: ZipArchiveEntryStream {
    
    private let stream: IOStream
    private let mode: CompressionMode
    private let compressionLevel: CompressionLevel
    private let leaveOpen: Bool
    private let streamEndHandler: ((UInt, UInt, UInt) -> Void)
    
    private var z = z_stream()
    
    private let innerBuffer: UnsafeMutableBufferPointer<UInt8> = {
        let bufferSize = 1024
        let buffer = malloc(1024).assumingMemoryBound(to: UInt8.self)
        return UnsafeMutableBufferPointer(start: buffer, count: bufferSize)
    }()
    
    //private(set) var crc32 = UInt(bitPattern: -1) // 0xffffffff
    //private(set) var crc32: UInt = 0xffffffff
    private(set) var crc32: UInt = 0
    
    init(stream: IOStream, compressionLevel: CompressionLevel, leaveOpen: Bool = false, streamEndHandler: @escaping ((UInt, UInt, UInt) -> Void)) {
        self.stream = stream
        self.mode = .compress
        self.compressionLevel = compressionLevel
        self.leaveOpen = leaveOpen
        self.streamEndHandler = streamEndHandler
        
        zInit()
    }
    
    init(stream: IOStream, mode: CompressionMode, leaveOpen: Bool = false, streamEndHandler: @escaping ((UInt, UInt, UInt) -> Void)) {
        self.stream = stream
        self.mode = mode
        self.compressionLevel = .optimal
        self.leaveOpen = leaveOpen
        self.streamEndHandler = streamEndHandler
        
        zInit()
    }
    
    private func zInit() {
        switch mode {
        case .compress:
            let status = deflateInit2(&z, compressionLevel.toRawValue(), Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY)
        case .decompress:
            let status = inflateInit2(&z, -MAX_WBITS)
        }
    }
    
    deinit {
        if !leaveOpen {
            _ = close()
        }
        free(innerBuffer.baseAddress)
        switch mode {
        case .compress:
            let status = deflateEnd(&z)
        case .decompress:
            let status = inflateEnd(&z)
        }
    }
    
    public var canRead: Bool {
        switch mode {
        case .compress:
            return false
        case .decompress:
            return true
        }
    }
    
    public var canSeek: Bool {
        return false
    }
    
    public var canWrite: Bool {
        switch mode {
        case .compress:
            return true
        case .decompress:
            return false
        }
    }
    
    public var position: UInt64 {
        // Not Supported
        preconditionFailure()
    }
    
    public func close() -> Bool {
        //return stream.close()
        return true
    }
    
    // decompress
    public func read(buffer: UnsafeMutableRawPointer, maxLength len: Int) -> Int {
        z.next_out = buffer.assumingMemoryBound(to: UInt8.self)
        z.avail_out = UInt32(len)
        
        var status = Z_OK
        var isStreamEnd = false
        while status == Z_OK {
            if z.avail_in == 0 {
                // TODO: guard ...
                var size = stream.read(buffer: innerBuffer.baseAddress!, maxLength: innerBuffer.count)
                //if (Int(z.total_in) + size) > compressedSize {
                //    size = compressedSize - Int(z.total_in)
                //}
                
                z.next_in = innerBuffer.baseAddress
                z.avail_in = UInt32(size)
            }
            status = inflate(&z, Z_NO_FLUSH)
            if status == Z_STREAM_END {
                isStreamEnd = true
                break
            }
            if status != Z_OK {
                // TODO: ERROR
                if let message = z.msg {
                    print("Error inflate => msg: " + String(cString: message))
                }
                return -1
            }
            if z.avail_out == 0 {
                break
            }
        }
        
        let readBytes = len - Int(z.avail_out)
        crc32 = Czlib.crc32(crc32, buffer.assumingMemoryBound(to: UInt8.self), UInt32(readBytes))
        
        if isStreamEnd {
            let compressedSize = z.total_in
            let uncompressedSize = z.total_out
            streamEndHandler(crc32, compressedSize, uncompressedSize)
        }
        
        return readBytes
    }
    
    public func seek(offset: Int, origin: SeekOrigin) -> Int {
        // Not Supported
        preconditionFailure()
    }
    
    // compress
    public func write(buffer: UnsafeRawPointer, maxLength len: Int) -> Int {
        let mutableBuffer = UnsafeMutableRawPointer(mutating: buffer).assumingMemoryBound(to: UInt8.self)
        let bufferSize = UInt32(len)
        z.next_in = mutableBuffer
        z.avail_in = bufferSize
        
        crc32 = Czlib.crc32(crc32, mutableBuffer, bufferSize)
        
        z.next_out = innerBuffer.baseAddress
        z.avail_out = UInt32(innerBuffer.count)
        let flush = (len == 0) ? Z_FINISH : Z_NO_FLUSH
        var status = Z_OK
        var isStreamEnd = false
        while status == Z_OK {
            status = deflate(&z, flush)
            if status == Z_STREAM_END {
                isStreamEnd = true
                break
            }
            if status != Z_OK {
                // TODO: ERROR
                if let message = z.msg {
                    print("Error deflate => msg: " + String(cString: message))
                }
                return -1
            }
            if z.avail_out == 0 {
                guard stream.write(buffer: innerBuffer.baseAddress!, maxLength: innerBuffer.count) == innerBuffer.count else {
                    // TODO: ERROR
                    print("Error stream.write")
                    return -1
                }
                z.next_out = innerBuffer.baseAddress
                z.avail_out = UInt32(innerBuffer.count)
            }
            else {
                break
            }
        }
        
        let count = innerBuffer.count - Int(z.avail_out)
        if count != 0 {
            guard stream.write(buffer: innerBuffer.baseAddress!, maxLength: count) == count else {
                // TODO: ERROR
                print("Error stream.write")
                return -1
            }
        }
        
        if isStreamEnd {
            let compressedSize = z.total_out
            let uncompressedSize = z.total_in
            streamEndHandler(crc32, compressedSize, uncompressedSize)
        }
        
        let writeBytes = len - Int(z.avail_in)
        return writeBytes
    }
    
}

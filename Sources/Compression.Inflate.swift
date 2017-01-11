//
//  Compression.Inflate.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/11.
//  Copyright © 2017年 yaslab. All rights reserved.
//

import Foundation
import Czlib

private func inflateInit2(_ strm: z_streamp!, _ windowBits: Int32) -> Int32 {
    let streamSize = Int32(MemoryLayout<z_stream>.size)
    return inflateInit2_(strm, windowBits, ZLIB_VERSION, streamSize)
}

class InflateHelper {
    
    private var z = z_stream()
    private let inBufferSize = 1024
    private let inBuffer: UnsafeMutablePointer<UInt8>
    
    private let compressedSize: Int
    
    private(set) var crc32: UInt = 0
    
    init?(compressedSize: Int) {
        self.compressedSize = compressedSize
        
        self.inBuffer = malloc(inBufferSize).assumingMemoryBound(to: UInt8.self)
        
        z.zalloc = nil
        z.zfree = nil
        z.opaque = nil
        
        z.next_in = nil
        z.avail_in = 0
        
        z.next_out = nil
        z.avail_out = 0
        
        guard inflateInit2(&z, -MAX_WBITS) == Z_OK else {
            // TODO:
            //let message = String(cString: z.msg)
            return nil
        }
    }
    
    deinit {
        free(inBuffer)
    }
    
    func inflate(inStream: IOStream, outBuffer: UnsafeMutableRawPointer, outBufferSize: Int) -> (Int, Bool) {
        var isStreamEnd = false
        
        z.next_out = outBuffer.assumingMemoryBound(to: UInt8.self) /* 出力ポインタ */
        z.avail_out = UInt32(outBufferSize)    /* 出力バッファ残量 */
        
        var status = Z_OK
        while status != Z_STREAM_END {
            if (z.avail_in == 0) {  /* 入力残量がゼロになれば */
                z.next_in = inBuffer;  /* 入力ポインタを元に戻す */
                
                /* データを読む */
                var size = inStream.read(buffer: inBuffer, maxLength: inBufferSize)
                if (Int(z.total_in) + size) > compressedSize {
                    size = compressedSize - Int(z.total_in)
                }
                z.avail_in = UInt32(size)
                
                //uncompressedSize += size
            }
            status = Czlib.inflate(&z, Z_NO_FLUSH) /* 展開 */
            if status == Z_STREAM_END {
                isStreamEnd = true
                break
            }
            if status != Z_OK {   /* エラー */
                // TODO: エラーをスローする
                //let message = String(cString: z.msg)
                //throw NSError(domain: "", code: 0, userInfo: nil)
                return (-1, true)
            }
            if z.avail_out == 0 { /* 出力バッファが尽きれば */
                break
            }
        }
        
        let outBytes = outBufferSize - Int(z.avail_out)
        
        crc32 = Czlib.crc32(crc32, outBuffer.assumingMemoryBound(to: UInt8.self), UInt32(outBytes))
        
        return (outBytes, isStreamEnd)
    }
    
    func inflateEnd() {
        /* 後始末 */
        guard Czlib.inflateEnd(&z) == Z_OK else {
            // TODO:
            //let message = String(cString: z.msg)
            return
        }
    }
    
}

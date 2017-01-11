//
//  Compression.Deflate.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/10.
//  Copyright © 2017年 yaslab. All rights reserved.
//

import Foundation
import Czlib

private func deflateInit2(_ strm: z_streamp!, _ level: Int32, _ method: Int32, _ windowBits: Int32, _ memLevel: Int32, _ strategy: Int32) -> Int32 {
    let streamSize = Int32(MemoryLayout<z_stream>.size)
    return deflateInit2_(strm, level, method, windowBits, memLevel, strategy, ZLIB_VERSION, streamSize)
}

class DeflateHelper {
    
    private var z = z_stream()
    
    let outBufferSize = 1024
    let outBuffer: UnsafeMutablePointer<UInt8>
    
    var crc32: UInt = 0
    var compressedSize: UInt {
        return z.total_out
    }
    var uncompressedSize: UInt {
        return z.total_in
    }

    init?(compressionLevel: CompressionLevel) {
        outBuffer = malloc(outBufferSize).assumingMemoryBound(to: UInt8.self)
        
        z.zalloc = nil
        z.zfree = nil
        z.opaque = nil
        
        z.next_in = nil
        z.avail_in = 0
        
        guard deflateInit2(&z, compressionLevel.toRawValue(), Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY) == Z_OK else {
            // TODO:
            let message = String(cString: z.msg)
            return nil
        }
    }
    
    deinit {
        free(outBuffer)
    }
    
    func deflate(outStream: IOStream, crypt: ZipCrypto?, inBuffer: UnsafeRawPointer, inBufferSize: Int) -> (Int, Bool) {
        var isStreamEnd = false
        
        z.next_out = outBuffer /* 出力ポインタ */
        z.avail_out = UInt32(outBufferSize) /* 出力バッファ残量 */
        
        let mutableInBuffer = UnsafeMutableRawPointer(mutating: inBuffer).assumingMemoryBound(to: UInt8.self)
        z.next_in = mutableInBuffer  /* 入力ポインタを元に戻す */
        z.avail_in = UInt32(inBufferSize)
        
        crc32 = Czlib.crc32(crc32, mutableInBuffer, UInt32(inBufferSize))
        
        var status = Z_OK
        let flush = (inBufferSize == 0) ? Z_FINISH : Z_NO_FLUSH
        while true {
            status = Czlib.deflate(&z, flush); /* 圧縮する */
            if status == Z_STREAM_END {
                isStreamEnd = true
                break /* 完了 */
            }
            if status != Z_OK {   /* エラー */
                // TODO: エラーをスローする
                //let message = String(cString: z.msg)
                //throw NSError(domain: "", code: 0, userInfo: nil)
                return (-1, true)
            }
            if z.avail_out == 0 { /* 出力バッファが尽きれば */
                if let crypt = crypt {
                    for i in 0 ..< outBufferSize {
                        outBuffer[i] = crypt.encode(outBuffer[i])
                    }
                }
                guard outStream.write(buffer: outBuffer, maxLength: outBufferSize) == outBufferSize else {
                    // TODO: ERROR
                    return (-1, true)
                }
                
                z.next_out = outBuffer
                z.avail_out = UInt32(outBufferSize)
            }
            else {
                break
            }
        }
        
        let count = outBufferSize - Int(z.avail_out)
        if count != 0 {
            if let crypt = crypt {
                for i in 0 ..< count {
                    outBuffer[i] = crypt.encode(outBuffer[i])
                }
            }
            guard outStream.write(buffer: outBuffer, maxLength: count) == count else {
                // TODO: ERROR
                return (-1, true)
            }
        }
        
        let inBytes = inBufferSize - Int(z.avail_in)
        return (inBytes, isStreamEnd)
    }
    
    func deflateEnd() {
        guard Czlib.deflateEnd(&z) == Z_OK else {
            // TODO: ERROR
            return
        }
    }
    
}

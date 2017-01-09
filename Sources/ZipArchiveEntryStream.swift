//
//  ZipArchiveEntryStream.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/08.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation
import Czlib

func inflateInit2(_ strm: z_streamp!, _ windowBits: Int32) -> Int32 {
    let streamSize = Int32(MemoryLayout<z_stream>.size)
    return inflateInit2_(strm, windowBits, ZLIB_VERSION, streamSize)
}

func deflateInit2(_ strm: z_streamp!, _ level: Int32, _ method: Int32, _ windowBits: Int32, _ memLevel: Int32, _ strategy: Int32) -> Int32 {
    let streamSize = Int32(MemoryLayout<z_stream>.size)
    return deflateInit2_(strm, level, method, windowBits, memLevel, strategy, ZLIB_VERSION, streamSize)
}

class InflateHelper {
    
    //let stream: ZipArchiveStream
    private var z = z_stream()
    
    private let inBufferSize = 1024
    //let outBufferSize = 1024

    private let inBuffer: UnsafeMutablePointer<UInt8>
    //let outBuffer: UnsafeMutablePointer<UInt8>
    
    
    
    
    var crc32: UInt = 0
    var compressedSize = 0
    var uncompressedSize = 0
    
    init?() {
        //self.stream = stream
        
        inBuffer = malloc(inBufferSize).assumingMemoryBound(to: UInt8.self)
        //outBuffer = malloc(outBufferSize).assumingMemoryBound(to: UInt8.self)
        
        z.zalloc = nil
        z.zfree = nil
        z.opaque = nil
        
        z.next_in = nil
        z.avail_in = 0
        
        z.next_out = nil
        z.avail_out = 0

        guard inflateInit2(&z, -MAX_WBITS) == Z_OK else {
            // TODO:
            let message = String(cString: z.msg)
            return nil
        }
    }
    
    deinit {
        
    }

    func inflate(inStream: ZipArchiveStream, outBuffer: UnsafeMutableRawPointer, outBufferSize: Int) -> (Int, Bool) {
        var isStreamEnd = false
        
        z.next_out = outBuffer.assumingMemoryBound(to: UInt8.self) /* 出力ポインタ */
        z.avail_out = UInt32(outBufferSize)    /* 出力バッファ残量 */
        
        var status = Z_OK
        while status != Z_STREAM_END {
            if (z.avail_in == 0) {  /* 入力残量がゼロになれば */
                z.next_in = inBuffer;  /* 入力ポインタを元に戻す */
                /* データを読む */
                let size = inStream.read(buffer: inBuffer, maxLength: inBufferSize)
                z.avail_in = UInt32(size)
                
                uncompressedSize += size
            }
            status = Czlib.inflate(&z, Z_NO_FLUSH) /* 展開 */
            if status == Z_STREAM_END {
                isStreamEnd = true
                break
            }
            if status != Z_OK {   /* エラー */
                // TODO: エラーをスローする
                let message = String(cString: z.msg)
                //throw NSError(domain: "", code: 0, userInfo: nil)
                return (-1, true)
            }
            if z.avail_out == 0 { /* 出力バッファが尽きれば */
                /* まとめて書き出す */
//                if (fwrite(outbuf, 1, OUTBUFSIZ, fout) != OUTBUFSIZ) {
//                    fprintf(stderr, "Write error\n");
//                    exit(1);
//                }
//                z.next_out = outBuffer; /* 出力ポインタを元に戻す */
//                z.avail_out = UInt32(outBufferSize); /* 出力バッファ残量を元に戻す */
                break
            }
        }
        
        let outBytes = outBufferSize - Int(z.avail_out)
        
        crc32 = Czlib.crc32(crc32, outBuffer.assumingMemoryBound(to: UInt8.self), UInt32(outBytes))
        compressedSize += outBytes
        
        return (outBytes, isStreamEnd)
    }
    
    func inflateEnd() {

        free(inBuffer)
        
        /* 後始末 */
        guard Czlib.inflateEnd(&z) == Z_OK else {
            // TODO:
            let message = String(cString: z.msg)
            return
        }
    }
    
}





class DeflateHelper {
    
    //let stream: ZipArchiveStream
    private var z = z_stream()
    
    //private let inBufferSize = 1024
    let outBufferSize = 1024
    
    //private let inBuffer: UnsafeMutablePointer<UInt8>
    let outBuffer: UnsafeMutablePointer<UInt8>
    
    
    
    
    
    var crc32: UInt = 0
    var compressedSize = 0
    var uncompressedSize = 0
    
    
    init?(compressionLevel: CompressionLevel) {
        //self.stream = stream
        
        //inBuffer = malloc(inBufferSize).assumingMemoryBound(to: UInt8.self)
        outBuffer = malloc(outBufferSize).assumingMemoryBound(to: UInt8.self)
        
        z.zalloc = nil
        z.zfree = nil
        z.opaque = nil
        
        z.next_in = nil
        z.avail_in = 0
        
        z.next_out = outBuffer /* 出力ポインタ */
        z.avail_out = UInt32(outBufferSize) /* 出力バッファ残量 */
        
        guard deflateInit2(&z, compressionLevel.toRawValue(), Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY) == Z_OK else {
            // TODO:
            let message = String(cString: z.msg)
            return nil
        }
    }
    
    deinit {
        
    }
    
    func deflate(outStream: ZipArchiveStream, inBuffer: UnsafeRawPointer, inBufferSize: Int) -> (Int, Bool) {
        var isStreamEnd = false
        
        //z.next_out = outBuffer /* 出力ポインタ */
        //z.avail_out = UInt32(outBufferSize)    /* 出力バッファ残量 */

        //if (z.avail_in == 0) {  /* 入力残量がゼロになれば */
        let mutableInBuffer = UnsafeMutableRawPointer(mutating: inBuffer).assumingMemoryBound(to: UInt8.self)
            z.next_in = mutableInBuffer  /* 入力ポインタを元に戻す */
            /* データを読む */
            //let size = inStream.read(buffer: inBuffer, maxLength: inBufferSize)
            z.avail_in = UInt32(inBufferSize)
            
            crc32 = Czlib.crc32(crc32, mutableInBuffer, UInt32(inBufferSize))
            uncompressedSize += inBufferSize
            
            /* 入力が最後になったら deflate() の第2引数は Z_FINISH にする */
//            if z.avail_in < UInt32(inBufferSize) {
//                flush = Z_FINISH
//            }
        //}
        
        var status = Z_OK
        var flush = (inBufferSize == 0) ? Z_FINISH : Z_NO_FLUSH
        while true {

            status = Czlib.deflate(&z, flush); /* 圧縮する */
            if status == Z_STREAM_END {
                isStreamEnd = true
                break /* 完了 */
            }
            if status != Z_OK {   /* エラー */
//                fprintf(stderr, "deflate: %s\n", (z.msg) ? z.msg : "???");
//                exit(1);
                // TODO: エラーをスローする
                let message = String(cString: z.msg)
                //throw NSError(domain: "", code: 0, userInfo: nil)
                return (-1, true)
            }
            if z.avail_out == 0 { /* 出力バッファが尽きれば */
                /* まとめて書き出す */
//                if (fwrite(outbuf, 1, OUTBUFSIZ, fout) != OUTBUFSIZ) {
//                    fprintf(stderr, "Write error\n");
//                    exit(1);
//                }
                
                guard outStream.write(buffer: outBuffer, maxLength: outBufferSize) == outBufferSize else {
                    // TODO: ERROR
                    return (-1, true)
                }
                
                compressedSize += outBufferSize
                
                z.next_out = outBuffer; /* 出力バッファ残量を元に戻す */
                z.avail_out = UInt32(outBufferSize); /* 出力ポインタを元に戻す */
                
                continue
            }
            else {
                break
            }
            
//            if z.avail_out == 0 {
//                break
//            }
        }
        
        /* 残りを吐き出す */
        let count = outBufferSize - Int(z.avail_out)
        if count != 0 {
            guard outStream.write(buffer: outBuffer, maxLength: count) == count else {
                // TODO: ERROR
                return (-1, true)
            }
            
            compressedSize += outBufferSize
        }
//        if ((count = OUTBUFSIZ - z.avail_out) != 0) {
//            
//            
//            if (fwrite(outbuf, 1, count, fout) != count) {
//                fprintf(stderr, "Write error\n");
//                exit(1);
//            }
//        }
        
        
        let inBytes = inBufferSize - Int(z.avail_in)
        
        //compressedSize += outBytes
        
        return (inBytes, isStreamEnd)
    }
    
    func deflateEnd() {
        
        free(outBuffer)
        
        /* 後始末 */
//        guard inflateEnd(&z) == Z_OK else {
//            // TODO:
//            let message = String(cString: z.msg)
//            return
//        }
        
        
        /* 後始末 */
        if Czlib.deflateEnd(&z) != Z_OK {
            //fprintf(stderr, "deflateEnd: %s\n", (z.msg) ? z.msg : "???");
            //exit(1);
            
            //let message = String(cString: z.msg)
            return
        }
    }
    
}





// For zip
internal class ZipArchiveEntryZipStream: ZipArchiveStream {

    private weak var archiveEntry: ZipArchiveEntry?
    private let zip: Zip
    private let deflate: DeflateHelper
    //private let password: [CChar]?
    //private let crc32: UInt
    //private let isLargeFile: Bool

    //private var fp: zipFile? = nil
    
    private var localFileHeader: LocalFileHeader? = nil
    
    
    
    private var isStreamEnd = false

    internal init?(archiveEntry: ZipArchiveEntry/*, password: [CChar]? = nil, crc32: UInt = 0, isLargeFile: Bool = false*/) {
        self.archiveEntry = archiveEntry
        //self.password = password
        //self.crc32 = crc32
        //self.isLargeFile = isLargeFile

        let compressionLevel = archiveEntry.compressionLevel
        
        guard let zip = archiveEntry.archive?.zip else {
            return nil
        }
        self.zip = zip
        
        guard let deflate = DeflateHelper(compressionLevel: compressionLevel) else {
            return nil
        }
        self.deflate = deflate
        
        let success = open()
        if !success {
            return nil
        }
    }

    internal var canRead: Bool {
        return false
    }

    internal var canSeek: Bool {
        return false
    }

    internal var canWrite: Bool {
        return true
    }

    private var _position: UInt64 = 0
    internal var position: UInt64 {
        return _position
    }

    private func open() -> Bool {
        guard let archiveEntry = archiveEntry else {
            // ERROR
            return false
        }

        guard let archive = archiveEntry.archive else {
            // ERROR
            return false
        }

        //let tm = tmZip(fromDate: archiveEntry.lastWriteTime)
        let (date, time) = ZipUtility.convertDateTime(date: archiveEntry.lastWriteTime)
        
        guard let fileName = archiveEntry.fullName.cString(using: archive.entryNameEncoding) else {
            return false
        }
        let fileNameLength = UInt16(strlen(fileName))
        


        //var fileInfo = zip_fileinfo(tmz_date: tm, dosDate: 0, internal_fa: 0, external_fa: fa)

        //fp = archive.zipfp

//        let compressionLevel = archiveEntry.compressionLevel.toRawValue()

//        var pwd: UnsafePointer<CChar>? = nil
//        if let password = password {
//            pwd = UnsafePointer<CChar>(password)
//        }

//        let zip64: Int32 = isLargeFile ? 1 : 0
//
//        if zipOpenNewFileInZip3_64(fp, archiveEntry.fileNameInZip, &fileInfo, nil, 0, nil, 0, nil, Z_DEFLATED, compressionLevel, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY, pwd, crc32, zip64) != ZIP_OK {
//            return false
//        }
        
        let localFileHeader = LocalFileHeader(
            versionNeededToExtract: 20, // TODO:
            generalPurposeBitFlag: 0b0000_0000_0000_1000, // TODO:
            compressionMethod: 8, // TODO:
            lastModFileTime: time,
            lastModFileDate: date,
            crc32: 0,
            compressedSize: 0,
            uncompressedSize: 0,
            fileNameLength: fileNameLength,
            extraFieldLength: 0,
            fileName: fileName,
            extraField: [])
        self.localFileHeader = localFileHeader
        
        guard zip.openNewFile(localFileHeader: localFileHeader) == true else {
            return false
        }

        return true
    }

    internal func close() -> Bool {
        //if zipCloseFileInZip(fp) != ZIP_OK {
        //    return false
        //}
        
        
        
        guard let archiveEntry = archiveEntry else {
            // ERROR
            return false
        }
        guard let localFileHeader = localFileHeader else {
            // ERROR
            return false
        }
        
        
        var mode = archiveEntry.filePermissions
        if archiveEntry.fileType == .directory {
            mode = mode | S_IFDIR
        }
        else if archiveEntry.fileType == .symbolicLink {
            mode = mode | S_IFLNK
        }
        else {
            mode = mode | S_IFREG
        }
        let fileAttributes = UInt32(mode) << 16
        
        
        let dataDescriptor = DataDescriptor(
            crc32: UInt32(deflate.crc32),
            compressedSize: UInt32(deflate.compressedSize),
            uncompressedSize: UInt32(deflate.uncompressedSize))
        
        zip.closeFile(localFileHeader: localFileHeader, dataDescriptor: dataDescriptor, fileAttributes: fileAttributes)
        deflate.deflateEnd()
        
        return true
    }

    internal func read(buffer: UnsafeMutableRawPointer, maxLength len: Int) -> Int {
        return -1
    }

    internal func seek(offset: Int, origin: SeekOrigin) -> Int {
        return -1
    }

    internal func write(buffer: UnsafeRawPointer, maxLength len: Int) -> Int {
        //let err = zipWriteInFileInZip(fp, buffer, UInt32(len))
        //if err <= ZIP_ERRNO {
        //    return -1
        //}
        
        if self.isStreamEnd {
            return 0
        }
        
        let (inBytes, isStreamEnd) = deflate.deflate(outStream: zip.stream, inBuffer: buffer, inBufferSize: len)
        
        _position += UInt64(inBytes)
        
        self.isStreamEnd = isStreamEnd
        
        return inBytes
    }

}

// -----------------------------------------------------------------------------

// For unzip
internal class ZipArchiveEntryUnzipStream: ZipArchiveStream {

    private weak var archiveEntry: ZipArchiveEntry?
    private let unzip: Unzip
    private let inflate: InflateHelper
    
    private var isStreamEnd = false
    
    //private weak var archiveEntry: ZipArchiveEntry?
    //private let password: [CChar]?

    //private var fp: unzFile? = nil

    internal init?(archiveEntry: ZipArchiveEntry/*, password: [CChar]? = nil*/) {
        self.archiveEntry = archiveEntry
        //self.password = password

        guard let unzip = archiveEntry.archive?.unzip else {
            return nil
        }
        self.unzip = unzip
        
        guard let inflate = InflateHelper() else {
            return nil
        }
        self.inflate = inflate
        
        let success = open()
        if !success {
            return nil
        }
    }

    internal var canRead: Bool {
        return true
    }

    internal var canSeek: Bool {
        return false
    }

    internal var canWrite: Bool {
        return false
    }

    private var _position: UInt64 = 0
    internal var position: UInt64 {
        return _position
    }

    private func open() -> Bool {
        guard let archiveEntry = archiveEntry else {
            // ERROR
            return false
        }
//
//        guard let unzip = archiveEntry.archive?.unzip else {
//            // ERROR
//            return false
//        }

        //fp = archive.unzfp

//        if unzLocateFile(fp, archiveEntry.fileNameInZip, nil) != UNZ_OK {
//            return false
//        }
//
//        if let password = password {
//            if unzOpenCurrentFilePassword(fp, password) != UNZ_OK {
//                return false
//            }
//        }
//        else {
//            if unzOpenCurrentFile(fp) != UNZ_OK {
//                return false
//            }
//        }
        
        // unzip では必ず値が入っている
        guard let centralDirectoryHeader = archiveEntry.centralDirectoryHeader else {
            return false
        }

        guard let (localHeader, byteSize) = unzip.openFile(centralDirectoryHeader: centralDirectoryHeader) else {
            return false
        }
        
        return true
    }

    internal func close() -> Bool {
//        if unzCloseCurrentFile(fp) != UNZ_OK {
//            return false
//        }
//        guard let archiveEntry = archiveEntry else {
//            // ERROR
//            return false
//        }
//        
//        guard let unzip = archiveEntry.archive?.unzip else {
//            // ERROR
//            return false
//        }
        
        unzip.closeFile()
        inflate.inflateEnd()
        
        return true
    }

    internal func read(buffer: UnsafeMutableRawPointer, maxLength len: Int) -> Int {
        //let readBytes = unzReadCurrentFile(fp, buffer, UInt32(len))
        //let readBytes = unzip.stream.read(buffer: buffer, maxLength: len)

        if self.isStreamEnd {
            return 0
        }
        
        let (outBytes, isStreamEnd) = inflate.inflate(inStream: unzip.stream, outBuffer: buffer, outBufferSize: len)
    
        _position += UInt64(outBytes)
        
        self.isStreamEnd = isStreamEnd
        
        return outBytes
    }

    func seek(offset: Int, origin: SeekOrigin) -> Int {
        return -1
    }

    func write(buffer: UnsafeRawPointer, maxLength len: Int) -> Int {
        return -1
    }

}

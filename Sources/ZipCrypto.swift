//
//  ZipCrypto.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/11.
//  Copyright © 2017年 yaslab. All rights reserved.
//

//import Foundation

public class ZipCrypto {
    
    let headerSize = 12
    
    private let crc32Table: [UInt32]
    private var keys = [UInt32]()
    //private(set) var header: [UInt8]!
    
    init(crc32Table: [UInt32]) {
        self.crc32Table = crc32Table
        //self.header = makeHeader(password: password, crc32ForCrypting: crc32ForCrypting)
    }
    
    private func crc32(_ c: UInt32, _ b: UInt32) -> UInt32 {
        let index = Int((c ^ b) & 0xff)
        return crc32Table[index] ^ (c >> 8)
    }

    private func decryptByte() -> UInt8 {
        //let temp = UInt16(truncatingBitPattern: (keys[2] & 0xffff) | 2)
        let temp = (keys[2] & 0xffff) | 2
        let temp2 = ((temp &* (temp ^ 1)) >> 8) & 0xff
        return UInt8(truncatingBitPattern: temp2)
    }
    
    private func updateKeys(_ c: UInt8) {
        keys[0] = crc32(keys[0], UInt32(c))
        keys[1] += (keys[0] & 0xff)
        keys[1] = (keys[1] &* 134775813) &+ 1
        keys[2] = crc32(keys[2], keys[1] >> 24)
    }
    
    fileprivate func initKeys(password: [CChar]) {
        keys.removeAll()
        keys.append(305419896)
        keys.append(591751049)
        keys.append(878082192)
        
        for c in password {
            if c == 0 {
                break
            }
            updateKeys(UInt8(bitPattern: c))
        }
    }
    
    func decode(_ c: UInt8) -> UInt8 {
        let cc = c ^ decryptByte()
        updateKeys(cc)
        return cc
    }
    
    func encode(_ c: UInt8) -> UInt8 {
        let t = decryptByte()
        updateKeys(c)
        return t ^ c
    }
    
//    private func random() -> UInt8 {
//        return UInt8(truncatingBitPattern: arc4random() & 0xff)
//    }
    
    fileprivate func makeHeader(password: [CChar], crc32ForCrypting: UInt32) -> [UInt8] {
        //let headerSize = 12
        
//        initKeys(password: password)
        var header = [UInt8]()
//        for _ in 0 ..< (headerSize - 2) {
//            header.append(encode(UInt8(truncatingBitPattern: (arc4random() >> 7) & 0xff)))
//        }
        
        initKeys(password: password)
        for i in 0 ..< (headerSize - 1) {
            //header[i] = encode(header[i])
            let val = encode(UInt8(truncatingBitPattern: arc4random()))
            header.append(val)
        }
        
        //let a = UInt8(truncatingBitPattern: (crc32ForCrypting >> 16) & 0xff)
        let b = UInt8(truncatingBitPattern: (crc32ForCrypting >> 24) & 0xff)
        //header.append(encode(a))
        header.append(encode(b))
        
        return header
    }
    
}

class ZipCryptoStream: ZipArchiveEntryStream {
    
    private let stream: IOStream
    private let zipCrypto: ZipCrypto
    
    private let password: [CChar]
    private let crc32ForCrypting: UInt32
    
    var headerSize: Int {
        return zipCrypto.headerSize
    }
    
    private var writeBuffer: NSMutableData? = nil
    private var isFirst: Bool = true
    
    init(stream: IOStream, password: [CChar], crc32ForCrypting: UInt32, crc32Table: [UInt32]) {
        self.stream = stream
        self.zipCrypto = ZipCrypto(crc32Table: crc32Table)
        self.password = password
        self.crc32ForCrypting = crc32ForCrypting
    }

    var canRead: Bool {
        return stream.canRead
    }
    
    var canSeek: Bool {
        return stream.canSeek
    }
    
    var canWrite: Bool {
        return stream.canWrite
    }
    
    var position: UInt64 {
        return stream.position
    }
    
    func close() -> Bool {
        return stream.close()
    }
    
    func read(buffer: UnsafeMutableRawPointer, maxLength len: Int) -> Int {
        if isFirst {
            isFirst = false
            
            zipCrypto.initKeys(password: password)
            var header = [UInt8](repeating: 0, count: zipCrypto.headerSize)
            _ = stream.read(buffer: &header, maxLength: header.count)
            for b in header {
                _ = zipCrypto.decode(b)
            }
        }
        
        let count = stream.read(buffer: buffer, maxLength: len)
        if count > 0 {
            let bytes = buffer.assumingMemoryBound(to: UInt8.self)
            for i in 0 ..< count {
                bytes[i] = zipCrypto.decode(bytes[i])
            }
        }
        return count
    }
    
    func seek(offset: Int, origin: SeekOrigin) -> Int {
        return stream.seek(offset: offset, origin: origin)
    }
    
    func write(buffer: UnsafeRawPointer, maxLength len: Int) -> Int {
        if isFirst {
            isFirst = false
            
            var header = zipCrypto.makeHeader(password: password, crc32ForCrypting: crc32ForCrypting)
            _  = stream.write(buffer: &header, maxLength: zipCrypto.headerSize)
        }
        
        if len > 0 {
            let originalBytes = buffer.assumingMemoryBound(to: UInt8.self)
            
            if writeBuffer == nil {
                writeBuffer = NSMutableData()
            }
            writeBuffer!.length = len
            let bytes = writeBuffer!.mutableBytes.assumingMemoryBound(to: UInt8.self)
            
            for i in 0 ..< len {
                bytes[i] = zipCrypto.encode(originalBytes[i])
                //print("\(originalBytes[i]) ==> \(bytes[i])")
            }
            
            return stream.write(buffer: bytes, maxLength: len)
        } else {
            return stream.write(buffer: buffer, maxLength: len)
        }
    }
    
}

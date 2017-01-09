//
//  ZipArchiveInputStream.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2016/11/04.
//  Copyright © 2016 yaslab. All rights reserved.
//

import Foundation

extension ZipArchiveStream {
    
    @available(iOS 9.0, *)
    public func asInputStream() -> InputStream? {
        return ZipArchiveInputStream(stream: self)
    }
    
}

// Note: Subclass of InputStream, super.init(...) is unrecognized selector on iOS 8. (Bug??)
// See: http://stackoverflow.com/questions/28286608/failing-to-subclass-nsinputstream-from-swift-initwithdata-unrecognizer-selecto
@available(iOS 9.0, *)
internal class ZipArchiveInputStream: InputStream {
    
    private let innerStream: ZipArchiveStream

    init?(stream: ZipArchiveStream) {
        guard stream.canRead else {
            return nil
        }
        innerStream = stream
        _streamStatus = .open
        _streamError = nil
        super.init(data: Data())
    }

    deinit {
        
    }
    
    // MARK: - Stream
    
    private var _streamStatus: Stream.Status
    private var _streamError: Error?
    
    override func open() {
        
    }
    
    override func close() {
        if _streamStatus != .open {
            return
        }
        _ = innerStream.close()
        _streamStatus = .closed
    }
    
    override var streamStatus: Stream.Status {
        return _streamStatus
    }
    
    override var streamError: Error? {
        return _streamError
    }
    
    // MARK: - InputStream
    
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        if len <= 0 {
            // TODO: return -1??
            return 0
        }
        if _streamStatus != .open {
            // TODO: set error
            _streamStatus = .error
            return -1
        }
        let ret = innerStream.read(buffer: buffer, maxLength: len)
        if ret < 0 {
            // TODO: set error
            _streamStatus = .error
        }
        if ret == 0 {
            _streamStatus = .atEnd
        }
        return ret
    }
    
    override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
    override var hasBytesAvailable: Bool {
        if _streamStatus == .open {
            return true
        } else {
            return false
        }
    }

}

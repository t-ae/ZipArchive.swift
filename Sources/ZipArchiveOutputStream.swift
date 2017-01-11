//
//  ZipArchiveOutputStream.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2016/11/04.
//  Copyright © 2016 yaslab. All rights reserved.
//

import Foundation

extension IOStream {
    
    public func asOutputStream() -> OutputStream? {
        return ZipArchiveOutputStream(stream: self)
    }
    
}

internal class ZipArchiveOutputStream: OutputStream {

    private let innerStream: IOStream
    
    init?(stream: IOStream) {
        guard stream.canWrite else {
            return nil
        }
        innerStream = stream
        _streamStatus = .open
        _streamError = nil
        super.init(toMemory: ())
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
    
    // MARK: - OutputStream

    override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        if len <= 0 {
            // TODO: return -1??
            return 0
        }
        if _streamStatus != .open {
            // TODO: set error
            _streamStatus = .error
            return -1
        }
        let ret = innerStream.write(buffer: buffer, maxLength: len)
        if ret < 0 {
            // TODO: set error
            _streamStatus = .error
        }
        if ret == 0 {
            _streamStatus = .atEnd
        }
        return ret
    }
    
    override var hasSpaceAvailable: Bool {
        if _streamStatus == .open {
            return true
        } else {
            return false
        }
    }
    
}

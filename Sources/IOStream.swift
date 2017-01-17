//
//  IOStream.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2017/01/11.
//  Copyright © 2017 yaslab. All rights reserved.
//

import Foundation

public enum SeekOrigin {
    
    case begin
    case current
    case end
    
}

public protocol IOStream: class {
    
    var canRead: Bool { get }
    var canSeek: Bool { get }
    var canWrite: Bool { get }
    var position: UInt64 { get }
    
    func close() -> Bool
    func read(buffer: UnsafeMutableRawPointer, maxLength len: Int) -> Int
    func seek(offset: Int, origin: SeekOrigin) -> Int
    func write(buffer: UnsafeRawPointer, maxLength len: Int) -> Int
    
}

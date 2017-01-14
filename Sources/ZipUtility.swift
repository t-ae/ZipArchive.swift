//
//  ZipUtility.swift
//  ZipArchive
//
//  Created by Yasuhiro Hatta on 2015/11/08.
//  Copyright © 2015 yaslab. All rights reserved.
//

import Foundation
import Czlib

internal func getCRCTable() -> [UInt32] {
    let table = get_crc_table()!
    var array = [UInt32](repeating: 0, count: 0x0100)
    for i in 0 ..< array.count {
        array[i] = UInt32(truncatingBitPattern: table[i])
    }
    return array
}

enum ZipUtility {
    
    static func convertDateTime(date: UInt16, time: UInt16) -> Date {
        var components = DateComponents()
        
        components.year     = Int((date & 0b1111_1110_0000_0000) >> 9) + 1980
        components.month    = Int((date & 0b0000_0001_1110_0000) >> 5)
        components.day      = Int(date & 0b0000_0000_0001_1111)
        
        components.hour     = Int((time & 0b1111_1000_0000_0000) >> 11)
        components.minute   = Int((time & 0b0000_0111_1110_0000) >> 5)
        components.second   = Int(time & 0b0000_0000_0001_1111) * 2
        
        guard let date = Calendar.current.date(from: components) else {
            return Date(timeIntervalSince1970: 0)
        }
        return date
    }
    
    static func convertDateTime(date: Date) -> (UInt16, UInt16) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        
        var date: UInt16 = 0
        var year = components.year! - 1980
        if year < 0 {
            year = 0
        }
        date += UInt16(year) << 9
        date += UInt16(components.month!) << 5
        date += UInt16(components.day!)
        
        var time: UInt16 = 0
        time += UInt16(components.hour!) << 11
        time += UInt16(components.minute!) << 5
        time += UInt16(components.second! / 2)
        
        return (date, time)
    }
    
}

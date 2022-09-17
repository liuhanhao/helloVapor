//
//  Hexadecimal.swift
//  XYBLECentralClient
//
//  Created by Adsmart on 2017/6/13.
//  Copyright © 2017年 Adsmart. All rights reserved.
//

import Foundation

class ADSHexadecimal {
    
    // 十进制转BCD
    static func transformDecToBCD(num:Int) -> Int {
        
        return (num / 10 << 4) + num  % 10
        
    }
    
    // BCD转十进制
    static func transformBCDToDec(num:Int) -> Int {
        
        return (num & 0x0f) + (num >> 4) * 10
        
    }
    
    // 十六进制转十进制
    static func transformHexToDec(num:Int) -> Int {
        
        return (num >> 4 & 0x0f) * 16 + (num & 0x0f)
        
    }
    
    static func hexToBitString(char:Int) -> Character {
        
        switch (char) {
            case 0:
                return "0"
            case 1:
                return "1"
            case 2:
                return "2"
            case 3:
                return "3"
            case 4:
                return "4"
            case 5:
                return "5"
            case 6:
                return "6"
            case 7:
                return "7"
            case 8:
                return "8"
            case 9:
                return "9"
            case 10:
                return "a"
            case 11:
                return "b"
            case 12:
                return "c"
            case 13:
                return "d"
            case 14:
                return "e"
            case 15:
                return "f"
                
            default:
                return "0"
        }
        
    }
    
    static func bitStringToHex(char:Character) -> Int {
        
        switch char {
        case "0":
            return 0
        case "1":
            return 1
        case "2":
            return 2
        case "3":
            return 3
        case "4":
            return 4
        case "5":
            return 5
        case "6":
            return 6
        case "7":
            return 7
        case "8":
            return 8
        case "9":
            return 9
        case "a":
            return 10
        case "b":
            return 11
        case "c":
            return 12
        case "d":
            return 13
        case "e":
            return 14
        case "f":
            return 15
        case "A":
            return 10
        case "B":
            return 11
        case "C":
            return 12
        case "D":
            return 13
        case "E":
            return 14
        case "F":
            return 15
        default:
            return 0
        }
        
    }
    
    // 十六进制转字符串
    static func byteConversionStringWithDataByte(data:Data, isMac:Bool) -> String {

        let bytes = [UInt8](data)
        
        var mac:String = ""
        for index in 0..<data.count {
            let c:Int = Int(bytes[index])
            let character1:Character = self.hexToBitString(char: c >> 4)
            let character2:Character = self.hexToBitString(char: c & 0x0f)
            
            mac.append(character1)
            mac.append(character2)
            
            if (index < data.count - 1) && isMac {
                mac.append(":")
            }
            
        }
        
        return mac
    }

    // 字符串转十六进制
    static func stringConversionByteWithMacString(macString:String, isMac:Bool) -> Data {
        
        var hexString:String = macString
        if isMac {
            let array = macString.components(separatedBy: ":")
            hexString = array.joined(separator: "")
        }
        
        var bytes:[UInt8] = [UInt8]()
        for (i,lowChar) in hexString.enumerated() where i % 2 == 1 {
    
            let highChar_index = hexString.index(hexString.startIndex, offsetBy: i - 1) // 高四位字符的位置
            let highChar = hexString[highChar_index] // 高四位字符
            let byte:UInt8 = UInt8((self.bitStringToHex(char: highChar) << 4) + self.bitStringToHex(char: lowChar))
            
            bytes.append(byte)
        }
        
        let data = self.bytesArrayConversionData(bytesArray: bytes)
        
        return data
    }
    
    // data转数组
    static func dataConversionBytesArray(data:Data) -> [UInt8] {
        let bytes:[UInt8] = Array(data) // 直接转成byte数组
        return bytes
    }
    
    // data转数组
    /*
     var buffer:[UInt8] = [UInt8]()
     buffer.insert(0x01, at: 0)
     buffer.insert(0x01, at: 1)
     let data = Hexadecimal.bytesArrayConversionData(bytesArray: buffer)
     */
    static func bytesArrayConversionData(bytesArray:[UInt8]) -> Data {
        // 拿到数组的头指针
        let unsafePointer:UnsafeBufferPointer<UInt8> = bytesArray.withUnsafeBufferPointer({ pointerVal in
            return pointerVal
        })
        
        let data = Data.init(buffer: unsafePointer)
        return data
    }
    
}

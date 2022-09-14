//
//  File.swift
//  VaporChat
//
//  Created by admin on 2022/9/14.
//

import Foundation

extension Data {
    static func input_dataWithBase64EncodedString(string: String) -> Data? {
        if string.ts_length == 0 {
            return nil
        }
        
        let decoded: Data? = Data.init(base64Encoded: string , options: Base64DecodingOptions.ignoreUnknownCharacters)
        return decoded
    }
    
    func input_base64EncodedStringWithWrapWidth(wrapWidth: UInt) -> String? {
        if self.count == 0 {
            return nil
        }
        
        var encoded:String? = nil
        switch wrapWidth {
        case 64:
            return self.base64EncodedString(options: Base64EncodingOptions.lineLength64Characters)
        case 76:
            return self.base64EncodedString(options: Base64EncodingOptions.lineLength76Characters)
        default:
            encoded = self.base64EncodedString(options: Base64EncodingOptions.init(rawValue: 0))
        }
        
        if wrapWidth == 0 || wrapWidth >= encoded?.count ?? 0  {
            return encoded
        }
        
        let _wrapWidth:Int = Int((wrapWidth / 4) * 4)
        var result = ""
        var i:Int = 0
        while i < encoded!.count {
            if (i + _wrapWidth) >= encoded!.count {
                let substr = encoded!.dropFirst(i)
                result = result + substr
                break
            }
            
            // 但由于 Index 里记录了码位的偏移量，而每个 String 的 Index 对应的偏移量都会有差异，所以 Index 必须由 String 的实例生成：
            // 并且由于这种实现的特点，每个 String 的实例只应该使用自己生成的 Index ，使用其它实例生成的 Index 会导致意外情况的发生：
            let subStr = encoded![encoded!.index(encoded!.startIndex, offsetBy: i)...encoded!.index(encoded!.startIndex, offsetBy: i + _wrapWidth)]
            result = result + subStr
            result = result + "\r\n"
            
            i = i + _wrapWidth
        }
        
        return result
    }
    
    func input_base64EncodedString() -> String? {
        self.input_base64EncodedStringWithWrapWidth(wrapWidth: 0)
    }
    
}


extension String {
    
    static func input_stringWithBase64EncodedString(string: String) -> String? {
        
        guard let data:Data = Data.input_dataWithBase64EncodedString(string: string) else {
            return nil
        }
        
        return String.init(data: data, encoding: Encoding.utf8)
    }
    
    func input_base64EncodedStringWithWrapWidth(wrapWidth: UInt) -> String? {
        guard let data:Data = self.data(using: Encoding.utf8, allowLossyConversion: true) else {
            return nil
        }
        
        return data.input_base64EncodedStringWithWrapWidth(wrapWidth: wrapWidth)
    }
    
    func input_base64EncodedString() -> String? {
        guard let data:Data = self.data(using: Encoding.utf8, allowLossyConversion: true) else {
            return nil
        }
        
        return data.input_base64EncodedString()
    }
    
    func input_base64DecodedString() -> String? {
        return String.input_stringWithBase64EncodedString(string: self)
    }
    
    func input_base64DecodedData() -> Data? {
        return Data.input_dataWithBase64EncodedString(string: self)
    }
    
}

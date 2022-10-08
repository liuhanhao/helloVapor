//
//  ADSEmoticonManager.swift
//  VaporChat
//
//  Created by 刘汉浩 on 2022/9/25.
//

import UIKit

class ADSEmoticonManager: NSObject {

    static let shared: ADSEmoticonManager = ADSEmoticonManager.init()
    var chs: [String] = []
    var chsDic: [String:String] = [:]
    var cht: [String] = []
    var chtDic: [String:String] = [:]
    var emoticons: [[[String:String]]] = [[[:]]]
    
    static func manager() -> ADSEmoticonManager {
        return self.shared
    }
    
    override init() {
        super.init()
        self.loadEmoticons()
    }
    
    private func loadEmoticons() {
        //默认表情
        let path1 = Bundle.main.path(forResource: "WZMEmoticon1", ofType: "plist")
        let array1:[Dictionary] = NSArray.init(contentsOfFile: path1!) as! [Dictionary<String, String>]
        emoticons.append(array1)
        
        //浪小花
        let path2 = Bundle.main.path(forResource: "WZMEmoticon2", ofType: "plist")
        let array2 = NSArray.init(contentsOfFile: path2!) as! [Dictionary<String, String>]
        emoticons.append(array2)
        
        //emojis
        let emojisPath = Bundle.main.path(forResource: "WZMEmoticon2", ofType: "plist")
        let emojisDic = NSDictionary.init(contentsOfFile: emojisPath!)
        let emojis = emojisDic?["Default"];
        if emojis != nil {
            emoticons.append(emojis as! [[String : String]])
        }
        
        for item in array1 {
            let ch1 = item["chs"]!
            let ch2 = item["cht"]!
            let png = item["png"]!
            
            chs.append(ch1)
            cht.append(ch2)
            
            let key1 = ch1.input_base64EncodedString()
            let key2 = ch2.input_base64EncodedString()
            chsDic[png] = key1
            chtDic[png] = key2
        }
        
        for item in array2 {
            let ch1 = item["chs"]!
            let ch2 = item["cht"]!
            let png = item["png"]!
            
            chs.append(ch1)
            cht.append(ch2)
            
            let key1 = ch1.input_base64EncodedString()
            let key2 = ch2.input_base64EncodedString()
            chsDic[png] = key1
            chtDic[png] = key2
        }
        
    }
    
    ///匹配文本中的所有表情
    func matchEmoticons(aString: String) -> [Dictionary<String, Any>] {
        var emoticons:[[String: Any]] = [[:]]
        let regex: NSRegularExpression?
        do {
            try regex = NSRegularExpression.init(pattern: "\\[[^ \\[\\]]+?\\]", options: NSRegularExpression.Options.init(rawValue: 0))
            let matchs: [NSTextCheckingResult]? = regex?.matches(in: aString, range: NSRange.init(location: 0, length: aString.count))
            
            if matchs != nil {
                for match in matchs! {
                    let result = aString[aString.index(aString.startIndex, offsetBy: match.range.ts_startIndex)...aString.index(aString.startIndex, offsetBy: match.range.ts_endIndex)]
                    let dic = ["emoticon":result,"range":NSStringFromRange(match.range)] as [String : Any]
                    emoticons.append(dic)
                }
            }
        } catch let error {
            print(error)
        }
        
        return emoticons
    }
    ///匹配输入框将要删除的表情
    func willDeleteEmoticon(aString: String) -> String? {
        var string: String? = nil
        if aString.hasSuffix("]") {
            let regex: NSRegularExpression?
            do {
                try regex = NSRegularExpression.init(pattern: "\\[[^ \\[\\]]+?\\]", options: NSRegularExpression.Options.init(rawValue: 0))
                let matchs: [NSTextCheckingResult]? = regex?.matches(in: aString, range: NSRange.init(location: 0, length: aString.count))
                
                if matchs != nil {
                    for match in matchs! {
                        if match.range.location+match.range.length == aString.count {
                            let result = aString[aString.index(aString.startIndex, offsetBy: match.range.ts_startIndex)...aString.index(aString.startIndex, offsetBy: match.range.ts_endIndex)]
                            string = String(result)
                        }
                    }
                }
            } catch let error {
                print(error)
            }
        }
        
        return string
    }
    ///文本转富文本
    func attributedString(aString: String) -> NSMutableAttributedString {
        let attStr = NSMutableAttributedString.init(string: aString)
        let regex: NSRegularExpression?
        do {
            try regex = NSRegularExpression.init(pattern: "\\[[^ \\[\\]]+?\\]", options: NSRegularExpression.Options.init(rawValue: 0))
            let matchs: [NSTextCheckingResult]? = regex?.matches(in: aString, range: NSRange.init(location: 0, length: aString.count))
            
            let offset: Int = 0
            if matchs != nil {
                for match in matchs! {
                    let newLocation: Int = match.range.location + offset
                    let result = aString[aString.index(aString.startIndex, offsetBy: match.range.ts_startIndex)...aString.index(aString.startIndex, offsetBy: match.range.ts_endIndex)]
                    let imageName = self.chsDic[String(result).input_base64EncodedString()!]
                    let image = ADSInputHelper.emoticonImageNamed(name: imageName!)
                    if image != nil {
                        self.setAttributedString(attributedString: attStr, image: image!, rect: CGRect.init(x: 0, y: -4, width: 20, height: 20), range: NSRange.init(location: newLocation, length: match.range.length))
                    }
                }
            }
        } catch let error {
            print(error)
        }
        
        return attStr
    }
    
    func setAttributedString(attributedString: NSMutableAttributedString, image: UIImage, rect: CGRect, range: NSRange) {
        let attachment: NSTextAttachment = NSTextAttachment.init()
        attachment.image = image
        attachment.bounds = rect
        let attStr: NSAttributedString = NSAttributedString(attachment: attachment)
        attributedString.replaceCharacters(in: range, with: attStr)
    }
    
}

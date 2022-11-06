//
//  ADSChatHelper.swift
//  VaporChat
//
//  Created by admin on 2022/9/14.
//

import Foundation
import UIKit

extension NSObject {
    
    func CHAT_SCREEN_WIDTH() -> CGFloat {
        return ADSInputHelper.sharedHelper.screenW()
    }
    
    func CHAT_SCREEN_HEIGHT() -> CGFloat {
        return ADSInputHelper.sharedHelper.screenH()
    }
    
    func CHAT_IPHONEX() -> Bool {
        return ADSInputHelper.sharedHelper.iPhoneX()
    }

    func CHAT_NAV_BAR_H() -> CGFloat {
        return ADSInputHelper.sharedHelper.navBarH()
    }
    
    func CHAT_TAB_BAR_H() -> CGFloat {
        return ADSInputHelper.sharedHelper.tabBarH()
    }
    
    func CHAT_BOTTOM_H() -> CGFloat {
        return ADSInputHelper.sharedHelper.iPhoneXBottomH()
    }
    
    //默认图
    func CHAT_BAD_IMAGE() -> UIImage? {
        return ADSInputHelper.otherImageNamed(name: "wzm_chat_default")
    }

}

class ADSChatHelper: NSObject {
    
    static let sharedHelper:ADSChatHelper = ADSChatHelper.init()
    
    var maxCacheSize = 50.0
    var cacheSize: CGFloat = 0.0
    var memoryCache: [String:Data] = [:]
    lazy var cachePath: String = {
        let array = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, FileManager.SearchPathDomainMask.userDomainMask, true)
        var path = array.first
        if path != nil {
            return path!.appending("/chatCache")
        } else {
            return ""
        }
    }()
    lazy var senderBubbleImage: UIImage = {
        let image: UIImage = ADSInputHelper.otherImageNamed(name: "wzm_chat_bj2")!
        let size = image.size
        let _senderBubbleImage = image.stretchableImage(withLeftCapWidth: Int(size.width/2), topCapHeight: Int(size.height*0.8))
        return _senderBubbleImage
    }()
    lazy var receiverBubbleImage: UIImage = {
        let image: UIImage = ADSInputHelper.otherImageNamed(name: "wzm_chat_bj1")!
        let size = image.size
        let _receiverBubbleImage = image.stretchableImage(withLeftCapWidth: Int(size.width/2), topCapHeight: Int(size.height*0.8))
        return _receiverBubbleImage
    }()
    
    
    override init() {
        super.init()
        let _ = self.createDirectoryAtPath(path: self.cachePath)
    }
    
    class func senderBubble() -> UIImage {
        return ADSChatHelper.sharedHelper.senderBubbleImage
    }
    
    class func receiverBubble() -> UIImage {
        return ADSChatHelper.sharedHelper.receiverBubbleImage
    }
    
    //获取当前时间戳
    class func nowTimestamp() -> TimeInterval {
        let date = Date.init(timeIntervalSinceNow: 0)
        let time = date.timeIntervalSince1970 * 1000
        return time
    }
    //获取指定时间戳
    class func timestampFromDate(date: Date) -> TimeInterval {
        let time = date.timeIntervalSince1970 * 1000
        return time;
    }

    //获取指定日期
    class func dateFromTimeStamp(timeStamp: String) -> Date? {
        var scale: Double = 1.0
        if let double = Double(timeStamp) {
            if double > 999999999999 {
                scale = 1000.0
            }
            
            let time = Double(timeStamp)! / scale
            let date = Date(timeIntervalSince1970: time)
            return date
        }
        
        return nil
    }
    
    //时间格式化
    class func timeFromTimeStamp(timeStamp: String) -> String {
        let date = self.dateFromTimeStamp(timeStamp: timeStamp)
        if date != nil {
            return self.timeFromDate(date: date!)
        } else {
            return ""
        }
    }
    
    class func timeFromDate(date: Date) -> String {
        let calendar = Calendar.current
        // 1.获得当前时间的年月日
        let nowDate = Date.init(timeIntervalSinceNow: 0)
        let nowCmps = calendar.dateComponents([.year, .month, .day], from: nowDate)
        // 2.获得指定日期的年月日
        let sinceCmps = calendar.dateComponents([.year, .month, .day], from: date)
        
        let dateFormatter = DateFormatter.chat_dateFormatter(f: "HH:mm")
        let time = dateFormatter.string(from: date)
        if (sinceCmps.year == nowCmps.year) && (sinceCmps.month == nowCmps.month) {
            if (sinceCmps.day == nowCmps.day) {
                //今天
                return "今天" + time
            }
            if nowCmps.day! - sinceCmps.day! == 1 {
                //昨天
                return "昨天" + time
            }
        }
        return String(sinceCmps.year!) + "/" + String(sinceCmps.month!) + "/" + String(sinceCmps.day!) + " " + time
    }
    
    /// 图片缓存处理
    /**
     获取网络图片(同步)
     */
    func getImageWithUrl(urlString: String, isUseCatch: Bool) -> UIImage? {
        let data = self.getDataWithUrl(urlString: urlString, isUseCatch: isUseCatch)
        if data != nil {
            return UIImage.init(data: data!)
        } else {
            return nil
        }
    }

    /**
     获取网络图片(异步)
     */
    func getImageWithUrl(urlString: String, isUseCatch: Bool, completion: @escaping (_ image: UIImage?)->()?) -> UIImage? {
        let rd = self.getDataWithUrl(urlString: urlString, isUseCatch: isUseCatch) { data in
            if data != nil {
                return completion(UIImage.init(data: data!))
            } else {
                return completion(nil)
            }
        }
        
        if rd != nil {
            return UIImage.init(data: rd!)
        } else {
            return nil
        }
    }
    
    /**
     获取网络数据(同步)
     */
    func getDataWithUrl(urlString: String, isUseCatch: Bool) -> Data? {
        var data: Data? = nil
        if isUseCatch {
            data = self.getDataFromCacheWithUrl(urlString: urlString)
            if data == nil {
                data = self.getDataWithUrl(urlString: urlString)
            }
        } else {
            data = self.getDataWithUrl(urlString: urlString)
        }
        return data
    }

    /**
     获取网络数据(异步)
     */
    func getDataWithUrl(urlString: String, isUseCatch: Bool, completion: @escaping (_ data: Data?)->()?) -> Data? {
        
        if isUseCatch {
            let cd = self.getDataFromCacheWithUrl(urlString: urlString)
            if cd != nil {
                completion(cd)
                return cd
            }
            let global = DispatchQueue.global()
            global.async {
                let ud = self.getDataWithUrl(urlString: urlString)
                let main = DispatchQueue.main
                main.async {
                    completion(ud)
                }
            }
        } else {
            let global = DispatchQueue.global()
            global.async {
                let ud = self.getDataWithUrl(urlString: urlString)
                let main = DispatchQueue.main
                main.async {
                    completion(ud)
                }
            }
        }
        
        return nil
    }
    
    ///private method
    private func getDataFromCacheWithUrl(urlString: String) -> Data? {
        //1、从内存获取
        if let urlKey = self.wzmEncodeString(string: urlString) {
            var data = self.memoryCache[urlKey]
            if data != nil {
                return data
            } else {
                //2、从本地获取
                let cachePath = self.cachePath.appending("\\" + urlKey)
                if self.fileExistsAtPath(filePath: cachePath) {
                    data = try? Data.init(contentsOf: URL.init(fileURLWithPath: cachePath))
                    if data != nil {
                        //存到内存
                        self.cacheData(data: data!, forKey: urlKey)
                        return data
                    }
                }
            }
        }
        
        return nil
    }
    
    private func getDataWithUrl(urlString: String) -> Data? {
        //3、从网络获取
        if let urlKey = self.wzmEncodeString(string: urlString) {
            let cachePath = self.cachePath.appending("\\" + urlKey)
            if let url = URL.init(string: urlString) {
                if let urlData = try? Data.init(contentsOf: url) {
                    //存到内存
                    self.cacheData(data: urlData, forKey: urlKey)
                    //存到本地
                    try? self.writeFile(data: urlData, toPath: cachePath)
                    return urlData
                }
            }
            
        }
        return nil
    }

    ///other method
    func setObj(obj: Any, forKey key: String) -> String? {
        var data:Data? = nil
        if obj is UIImage {
            let hasAlpha = self.hasAlphaChannel(image: obj as! UIImage)
            if hasAlpha {
                data = (obj as! UIImage).pngData()
            } else {
                data = (obj as! UIImage).jpegData(compressionQuality: 1.0)
            }
        } else if (obj is Data) {
            data = (obj as! Data)
        }
        
        if data != nil {
            if let path = self.filePathForKey(key: key) {
                let _ = try? self.deleteFileAtPath(filePath: path)
                let _ = try? data?.write(to: URL.init(fileURLWithPath: path))
                return path
            }
        }
        
        return nil
    }
    
    func objForKey(key: String?) -> Data? {
        if key != nil {
            if let path = self.filePathForKey(key: key!) {
                return try? Data.init(contentsOf: URL.init(fileURLWithPath: path))
            }
        }
        return nil
    }
    
    func filePathForKey(key: String) -> String? {
        if let tureKey = self.wzmEncodeString(string: key) {
            return self.cachePath.appending("\\" + tureKey)
        } else {
            return nil
        }
    }

    func cacheData(data: Data, forKey key: String) {
        let mainQueue = DispatchQueue.main
        mainQueue.async {
            let globleQueue = DispatchQueue.global()
            globleQueue.async {
                if self.cacheSize > self.maxCacheSize * 1000 * 1000 {
                    self.clearMemory()
                }
                self.cacheSize = self.cacheSize + CGFloat(data.count)
                self.memoryCache[key] = data
            }
        }
    }
    
    func clearMemory() {
        cacheSize = 0.0
        self.memoryCache.removeAll()
    }
    
    func clearImageCacheCompletion(completion: @escaping ()->()) {
        //获取全局并发队列
        let globleQueue = DispatchQueue.global()
        globleQueue.async {
            self.clearMemory()
            if let result = try? self.deleteFileAtPath(filePath: self.cachePath) {
                if result {
                    let _ = try? self.deleteFileAtPath(filePath: self.cachePath)
                }
                completion()
            }
        }
    }

    func wzmEncodeString(string: String) -> String? {
        return string.input_base64EncodedString()
    }

    func hasAlphaChannel(image: UIImage) -> Bool {
        if let alpha = image.cgImage?.alphaInfo {
            return alpha == .first ||
                   alpha == .last ||
                   alpha == .premultipliedFirst ||
                   alpha == .premultipliedLast
        }
        return false
    }
    
    /// 文件管理
    func fileExistsAtPath(filePath: String) -> Bool {
        if FileManager.default.fileExists(atPath: filePath) {
            return true
        } else {
            print("fileExistsAtPath:文件未找到")
            return false
        }
    }
    func createDirectoryAtPath(path: String) -> Bool {
        let pointer = UnsafeMutablePointer<ObjCBool>.allocate(capacity: 0)
        let isExists = FileManager.default.fileExists(atPath: path, isDirectory: pointer)
        let isDirectory = pointer[0]
        if isExists && isDirectory.boolValue {
            return true
        }
        
        var result = true
        do {
            try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        } catch {
            result = false
            print("创建文件夹失败 \(error)")
        }
        
        return result
    }

    func writeFile(data: Data, toPath path: String) throws {
        print("文件存储路径为 \(path)")
        return try data.write(to: URL.init(fileURLWithPath: path))
    }

    func deleteFileAtPath(filePath: String) throws -> Bool {
        let result = FileManager.default.fileExists(atPath: filePath)
        if result {
            try FileManager.default.removeItem(atPath: filePath)
        }
        return true
    }
    
}

//
//  aaa.swift
//  Pixen
//
//  Created by takagisou on 2017/11/12.
//  Copyright © 2017年 Pixen Project. All rights reserved.
//

import Cocoa

@objc
class GifImporter: NSObject {
    static func fileIsAnimated(url: URL) -> Bool {
        
        let image = NSImage(contentsOf: url)
        
        guard let rep = image?.representations.first as? NSBitmapImageRep else {
            return false
        }
        guard let frameCount = rep.value(forProperty: NSImageFrameCount) as? Int else {
            return false
        }
        return frameCount > 1
    }
}

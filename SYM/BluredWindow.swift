//
//  BluredWindow.swift
//  SYM
//
//  Created by zhangqq on 16/7/8.
//  Copyright © 2016年 zqqf16. All rights reserved.
//

import Cocoa

class BluredWindow: NSWindow {
    
    override func awakeFromNib() {
        let visualEffectView = NSVisualEffectView(frame: NSMakeRect(0, 0, 300, 180))
        visualEffectView.material = NSVisualEffectMaterial.Light
        visualEffectView.blendingMode = NSVisualEffectBlendingMode.BehindWindow
        visualEffectView.state = NSVisualEffectState.Active
        
        self.styleMask = self.styleMask | NSFullSizeContentViewWindowMask
        self.titlebarAppearsTransparent = true
        //self.appearance = NSAppearance(named: NSAppearanceNameVibrantDark)
        
        self.contentView!.addSubview(visualEffectView)
        self.contentView!.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-0-[visualEffectView]-0-|", options: NSLayoutFormatOptions.DirectionLeadingToTrailing, metrics: nil, views: ["visualEffectView":visualEffectView]))
        self.contentView!.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[visualEffectView]-0-|", options: NSLayoutFormatOptions.DirectionLeadingToTrailing, metrics: nil, views: ["visualEffectView":visualEffectView]))
    }

}

//
//  PlayerView.swift
//  alo7-student
//
//  Created by ken.zhang on 2017/12/13.
//  Copyright © 2017年 alo7. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerView: UIView {

    // MARK: Prtoperties
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        
        set {
            playerLayer.player = newValue
        }
    }
    
    // MARK: Methods
    
    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}

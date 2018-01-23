//
//  PlayerSliderView.swift
//  alo7-student
//
//  Created by ken.zhang on 2017/12/20.
//  Copyright © 2017年 alo7. All rights reserved.
//

import UIKit

class PlayerSliderView: UISlider {
    override func awakeFromNib() {
        self.setThumbImage(UIImage(named: "player_thumb") , for: .normal)
    }
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(x: bounds.origin.x, y: bounds.origin.y, width: bounds.size.width, height: 4)
    }
}

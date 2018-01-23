//
//  ViewController.swift
//  RotatePlayer
//
//  Created by ken.zhang on 2018/1/23.
//  Copyright © 2018年 ken.zhang. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    lazy var playVC: PlayerViewController = {
        let vc = PlayerViewController()

        vc.view.frame = CGRect(x: 0, y: 30, width: UIScreen.main.bounds.width, height: 200)

        return vc
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.


        self.view.backgroundColor = UIColor.white

        self.view.addSubview(playVC.view)

        let url = Bundle.main.url(forResource: "20180111044707", withExtension: "mp4")
        playVC.playUrl = url

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}


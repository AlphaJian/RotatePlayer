  //
//  PlayerViewController.swift
//  alo7-student
//
//  Created by ken.zhang on 2017/12/13.
//  Copyright © 2017年 alo7. All rights reserved.
//

import UIKit
import AVFoundation

typealias SubtitleBlock = (CMTime) -> String
typealias TapBlock = () -> Void

enum PlayScreenStatus: Int {
    case Full = 0       //全屏
    case Normal = 1     //正常
}

enum PlayStatus: Int {
    case Play = 0       //播放
    case Pause = 1      //暂停
}

// 用于配音界面隐藏一些不需要的控件
enum PlayingStatus: Int {
    case Playing = 0    //  播放状态
    case Dubbing = 1    //  配音状态
}

  enum VideoLoadingStatus: Int {
    case loading
    case failed
    case loaded
  }

class PlayerViewController: UIViewController {
    
    // MARK: Properties
    lazy var player = AVPlayer()
    
    //  KVO Indentifier
    var playerKVOContext = 0
    
    //  Player Observer Identifier
    var timeObserverId: Any?
    
    var backHandler: TapBlock?
    var subtitleHandler: SubtitleBlock?
    var errorHandler: TapBlock?

    var playItem: AVPlayerItem? = nil {
        didSet {
            if playItem != nil {
                removeObserverFromPlayerItem()
            }

            player.replaceCurrentItem(with: playItem)

            addObserverToPlayerItem()

            DispatchQueue.main.async {
                self.cancelAutoFadeOutControlBar()
            }
        }
    }
    
    var playAsset: AVAsset? = nil {
        didSet {

            playItem = AVPlayerItem(asset: playAsset!, automaticallyLoadedAssetKeys: ["playable"])
        }
    }
    
    var playModel: PlayerModel? = nil {
        didSet {
            DispatchQueue.main.async {
                self.playAsset = AVAsset(url: (self.playModel?.videoUrl)!)
                self.videoTitleLabel.text = self.playModel?.videoTitle
            }
        }
    }

    var playUrl: URL? = nil {
        didSet {
            DispatchQueue.main.async {
                self.playAsset = AVAsset(url: self.playUrl!)
            }
        }
    }
    
    var loadStatus: VideoLoadingStatus? {
        didSet {
            switch loadStatus! {
            case .loading:
                bottomContainerView.isHidden = true
                playButton.isHidden = true
                break
            case .failed:
                bottomContainerView.isHidden = true
                playButton.isHidden = true
                break
            case .loaded:
                bottomContainerView.isHidden = false
                playButton.isHidden = false
                break
            }
        }
    }
    
    var screenStatus: PlayScreenStatus = .Normal {
        didSet {
            func animateToggleScreen() {
                switch screenStatus {
                case .Normal:
                    UIView.animate(withDuration: 0.2, animations: {
                        self.view.transform = CGAffineTransform.identity
                        self.view.frame = self.oldFrame!
                    })
                    break
                case .Full:
                        self.oldFrame = self.view.frame
                        UIView.animate(withDuration: 0.5, animations: {
                            self.view.transform = CGAffineTransform(rotationAngle: CGFloat(M_PI_2))
                            self.view.frame = UIScreen.main.bounds
                        })
                    break
                }
            }
            
            animateToggleScreen()
        }
    }
    
    var playStatus: PlayStatus = .Pause {
        didSet {
            switch playStatus {
            case .Play:
                self.player.play()
                self.playButton.isSelected = true
                self.autoFadeOutControlBar()
                break
            case .Pause:
                self.player.pause()
                self.playButton.isSelected = false
                self.cancelAutoFadeOutControlBar()
            }
        }
    }
    
    var playingStatus: PlayingStatus = .Playing {
        didSet {
            switch playingStatus {
            case .Playing:
                fullscreenButton.isHidden = false
                playButton.isHidden = false
                totalTimeTrailConstant.constant = 52
                timeSlider.isUserInteractionEnabled = true
                break
            case .Dubbing:
                fullscreenButton.isHidden = true
                playButton.isHidden = true
                totalTimeTrailConstant.constant = 16
                timeSlider.isUserInteractionEnabled = false
                break
            }
        }
    }
    
    var subtitle: String? {
        didSet {
            if subtitle == nil {
                self.subtitleLabel.text = nil
            } else if subtitle != oldValue {
                self.subtitleLabel.text = subtitle
            }
        }
    }
    
    //  Save the normal frame
    var oldFrame: CGRect?
    
    var currentTime: Double {
        get {
            return CMTimeGetSeconds(player.currentTime())
        }
        
        set {
            let newTime = CMTimeMakeWithSeconds(Double(Int(newValue)), 1)
            player.seek(to: newTime) { (finished) in
                self.playStatus = .Play
                self.autoFadeOutControlBar()
            }
        }
    }
    
    var duration:Double {
        get {
            guard let currentItem = player.currentItem else {
                return 0
            }
            
            return CMTimeGetSeconds(currentItem.asset.duration)
        }
    }
    
    // MARK: UI Element

    @IBOutlet weak var playerView: PlayerView!
    @IBOutlet weak var maskView: UIView!
    @IBOutlet weak var topContainerView: UIView!
    @IBOutlet weak var bottomContainerView: UIView!
    @IBOutlet weak var videoTitleLabel: UILabel!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var totalTimeLabel: UILabel!
    @IBOutlet weak var timeSlider: PlayerSliderView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var totalTimeTrailConstant: NSLayoutConstraint!
    @IBOutlet weak var fullscreenButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        playerView.playerLayer.player = player
        playerView.playerLayer.fillMode = AVLayerVideoGravityResizeAspectFill

        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(videoTapped))
        view.addGestureRecognizer(tapGesture)
        
        
        //设置完播放实例后，添加AV通知
        NotificationCenter.default.addObserver(self, selector: #selector(PlayerViewController.playerDidFinishPlaying(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.playItem)

        setupTimeObserver()
        
        // Do any additional setup after loading the view.
    }
    
    // MARK: UI Funcitons
    
    @IBAction func fullScreenTapped(_ sender: Any) {
        //  Status change by 0, 1
        screenStatus = PlayScreenStatus(rawValue: (screenStatus.rawValue + 1) % 2)!
    }
    
    @IBAction func backButtonTapped(_ sender: Any) {
        if (screenStatus == .Full) {
            fullScreenTapped(NSNull.self)
        } else {
            if (backHandler != nil) {
                backHandler!()
            }
        }
    }
    @IBAction func timeSliderTouchedDown(_ sender: Any) {
        playStatus = .Pause
    }

    
    @IBAction func timeSliderTouchedUp(_ sender: UISlider) {
        currentTime = Double(sender.value) * duration
    }
    
    @IBAction func playButtonTapped(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        if (sender.isSelected) {
            playStatus = .Play
        } else {
            playStatus = .Pause
        }
    }

    // MARK: Time Observer
    func setupTimeObserver() {
        guard timeObserverId == nil else {
            return
        }
        
        let timeInterval = CMTimeMake(1, 60)
        timeObserverId = player.addPeriodicTimeObserver(forInterval: timeInterval, queue: DispatchQueue.main, using: { [weak self] (time) in
            if let weakSelf = self {
                if weakSelf.duration != 0 {
                    weakSelf.updateTimeLabel()
                    weakSelf.timeSlider.value = Float(CMTimeGetSeconds(time) / weakSelf.duration)
                    
                    if weakSelf.subtitleHandler != nil {
                        weakSelf.subtitle = weakSelf.subtitleHandler!(time)
                    }
                }
            }
        })
    }

//    func removePlayItem() {
//        removeObserverFromPlayerItem()
////        playItem = nil问题在这里
//    }

    func addObserverToPlayerItem() {
        player.currentItem?.addObserver(self, forKeyPath: "status", options: .new, context: nil)
    }

    func removeObserverFromPlayerItem() {
        player.currentItem?.removeObserver(self, forKeyPath: "status")
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
            let status: AVPlayerStatus = self.player.status
            switch (status) {
            case AVPlayerStatus.readyToPlay:
                if CMTimeGetSeconds((playAsset?.duration)!) == 0 {
                    if errorHandler != nil {
                        errorHandler!()
                    }
                }
            case AVPlayerStatus.unknown, AVPlayerStatus.failed: break
            }
        }
    }
    
    func clearTimeObserver() {
        if (timeObserverId != nil) {
            player.removeTimeObserver(timeObserverId!)
            timeObserverId = nil
        }
    }
    
    func updateTimeLabel() {
        currentTimeLabel.text = String(format: "%02d:", Int(currentTime) / 60) + String(format: "%02d", Int(currentTime) % 60)
        
        guard duration.isFinite else {
            return
        }
        
        totalTimeLabel.text = String(format: "%02d:", Int(duration) / 60) + String(format: "%02d", Int(duration) % 60)
    }
    
    func videoTapped() {
        switch playingStatus {
        case .Playing:
            if playStatus == .Pause {
                break
            }
            if maskView.alpha == 0 {
                animateShow()
            } else {
                animateHide()
            }
            break
        case .Dubbing:
            if bottomContainerView.alpha == 0 {
                animateShow()
            } else {
                animateHide()
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        clearTimeObserver()
    }
}

// MARK: AV Notofication

extension PlayerViewController {
    func playerDidFinishPlaying(_ noti: NSNotification) {
        if playingStatus == .Playing {
            player.seek(to: CMTimeMakeWithSeconds(0, 1))
            self.maskView.alpha = 1
            playStatus = .Pause
        }
    }
}

// MARK: Control Bar Manipulation

extension PlayerViewController {
    func autoFadeOutControlBar() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(PlayerViewController.animateHide), object: nil)
        self.perform(#selector(PlayerViewController.animateHide), with: nil, afterDelay: 3)
    }
    
    func cancelAutoFadeOutControlBar() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(PlayerViewController.animateHide), object: nil)
    }
    
    func animateHide() {
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.layoutSubviews, .allowUserInteraction],
                       animations: { () -> Void in
                        switch self.playingStatus {
                        case .Playing:
                            self.maskView.alpha = 0
                            break
                        case .Dubbing:
                            self.bottomContainerView.alpha = 0
                            self.videoTitleLabel.alpha = 0
                        }        })
        { (finished) -> Void in }
    }
    
    func animateShow() {
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.layoutSubviews, .allowUserInteraction],
                       animations: { () -> Void in
                        switch self.playingStatus {
                        case .Playing:
                            self.maskView.alpha = 1.0
                            break
                        case .Dubbing:
                            self.bottomContainerView.alpha = 1
                            self.videoTitleLabel.alpha = 1
                        }
        })
        { (finished) -> Void in
            DispatchQueue.main.async {
                self.autoFadeOutControlBar()
            }
        }
    }
}


struct PlayerModel {
    var videoUrl: URL
    var voiceTrackUrl: URL
    var backgroundTrackUrl: URL
    var subtitleUrl: URL
    var videoTitle: String
    
    init (videoUrl: URL, videoTitle: String) {
        self.videoUrl = videoUrl
        self.voiceTrackUrl = videoUrl
        self.backgroundTrackUrl = videoUrl
        self.subtitleUrl = videoUrl
        self.videoTitle = videoTitle
    }
}

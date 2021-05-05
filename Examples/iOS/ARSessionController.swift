//
//  ARSessionController.swift
//  HaishinKit iOS
//
//  Created by bytedance on 2021/1/30.
//  Copyright © 2021 Shogo Endo. All rights reserved.
//

import Foundation
import ARKit

public class  ARSessionCotroller: ARSession{
    public static var ARController = ARSessionCotroller()
    public var ArIsRunning = false
    var arSession = ARSession()
    var _arConfiguration: ARWorldTrackingConfiguration?
    public var arConfiguration: ARWorldTrackingConfiguration{
        if _arConfiguration == nil {
            _arConfiguration = ARWorldTrackingConfiguration()
            _arConfiguration!.worldAlignment = .gravity;
            _arConfiguration!.videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats[self.format]
            print("[INFO] Used Video format: ",  _arConfiguration!.videoFormat)
            // 0--1440, 1080  1--1280, 720
        }
        return _arConfiguration!
    }
    
    let Arkit_queue = DispatchQueue(label: "com.mylogger.arkit.queen")
    
    
    override init() {
        super.init()
    }
    
    private var _format = 1
    
    public var format: Int {
        get{
            return self._format
        }
        set{
            self._format = newValue
            stopRunning()
            print("[GEBUG] configuration", ARWorldTrackingConfiguration.supportedVideoFormats)
            arConfiguration.videoFormat = ARWorldTrackingConfiguration.supportedVideoFormats[self._format]
            startRunning()
        }
    }
    
    public var fps: Double{
        get{
            return Double(arConfiguration.videoFormat.framesPerSecond)
        }
        set{
            //haha, cannot set
        }
    }
    
    func startRunning() {
        ArIsRunning = true
        arSession.run(arConfiguration)
        print("AR start running", arConfiguration)
    }
    
    func stopRunning() {
        ArIsRunning = false
        arSession.pause()
        print("AR stopped!")
    }
    
    func FPSchange(newFPS: Double) {
        fps = newFPS
        arSession.pause()
    }
}

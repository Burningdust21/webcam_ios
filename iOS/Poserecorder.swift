//
//  Poserecorder.swift
//  HaishinKit iOS
//
//  Created by bytedance on 2021/1/30.
//  Copyright © 2021 Shogo Endo. All rights reserved.
//

import Foundation

public class PoseRecorder {
    public static var PoseRecordes = PoseRecorder()
    var ArPoses = NSMutableString("")
    var counter = 0
    
    let startSignal = "Start"
    let stopSignal = "Stopped"
    
    private var queue = DispatchQueue(label: "messages.queue")
    
    func AddRecord(record: String) {
        queue.sync(flags: .barrier) {
            if self.counter == 10000 {
                self.Clear()
            }
            self.ArPoses.append(record)
            self.counter += 1
        }
    }
    
    public func Start() {
        self.Clear()
        self.AddRecord(record: String(format: "%@\n", ["Start"]))
    }
    
    public func Stop() {
        self.Clear()
        self.AddRecord(record: String(format: "%@\n", ["Stopped"]))
    }
    
    public func PublicRecord() -> String {
        var _ArPoses: String = ""
        
        queue.sync() {
            _ArPoses = ArPoses as String
       }
        
        queue.async(flags: .barrier) {
            self.Clear()
       }
        return _ArPoses
    }
    
    public func Clear()
    {
        ArPoses = NSMutableString("")
        counter = 0
    }
}

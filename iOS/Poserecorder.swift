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
    
    private var queue = DispatchQueue(label: "messages.queue", attributes: .concurrent)
    
    func AddRecord(record: String) {
        queue.async(flags: .barrier) {
            if self.counter == 10000 {
                self.Clear()
            }
            self.ArPoses.append(record)
            self.counter += 1
        }
    }
    
    public func PublicRecord()->String {
         queue.sync {
            let _ArPoses = ArPoses
            Clear()
            return _ArPoses as String
        }
    }
    
    public func Clear()
    {
        ArPoses = NSMutableString("")
        counter = 0
    }
}

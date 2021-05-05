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
    
    let lock = NSLock()
    
    func AddRecord(record: String) {
        if counter == 10000 {
            Clear()
        }
        ArPoses.append(record)
    }
    
    public func PublicRecord()->String {
        let _ArPoses = ArPoses
        Clear()
        return _ArPoses as String
    }
    
    public func Clear()
    {
        ArPoses = NSMutableString("")
        counter = 0
    }
}

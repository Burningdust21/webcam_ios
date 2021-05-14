//
//  PoseServer.swift
//  HaishinKit iOS
//
//  Created by bytedance on 2021/5/14.
//  Copyright © 2021 Shogo Endo. All rights reserved.
//

import Foundation
import HaishinKit


public class PoseServer {
    public static var PoseGCDWebServer = PoseServer()
    public var webServer:GCDWebServer?
    public func initWebServer() {

        webServer = GCDWebServer()

        webServer!.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self, processBlock: {
            request in return GCDWebServerDataResponse(text:PoseRecorder.PoseRecordes.PublicRecord())
                
            })
        webServer!.start(withPort: 8080, bonjourName: "GCD Web Server")
        
        print("Visit \(String(describing: webServer!.serverURL)) in your web browser")
    }
    public init() {
        Timer.scheduledTimer(timeInterval: 15, target: self, selector: #selector(self.healthCheck), userInfo: nil, repeats: true)
    }
    @objc func healthCheck() {
        webServer?.stop()
        initWebServer()
    }
}

//
//  PoseServer.swift
//  HaishinKit iOS
//
//  Created by bytedance on 2021/5/14.
//  Copyright © 2021 Shogo Endo. All rights reserved.
//

import Foundation
import HaishinKit
import Telegraph

public class PoseServer {
    public var webServer:Server?
    public func initWebServer() {
        webServer = Server()
        webServer!.route(.GET, "pose", self.serverHandlePoseRequest)
        webServer!.serveBundle(.main, "/")
        try! webServer?.start(port: 9000)
    }

    public func stop() {
        webServer?.stop()
    }

    private func poseHandler() -> String {
        return PoseRecorder.PoseRecordes.PublicRecord()
    }
    
    private func serverHandlePoseRequest(request: Telegraph.HTTPRequest) -> Telegraph.HTTPResponse {
      return HTTPResponse(content: poseHandler())
    }
    
}

extension PoseServer: ServerDelegate {
  // Raised when the server gets disconnected.
  public func serverDidStop(_ server: Server, error: Error?) {
    print("[SERVER]", "Server stopped:", error?.localizedDescription ?? "no details")
  }
}

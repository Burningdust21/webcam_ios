import AVFoundation
import HaishinKit
import Photos
import UIKit
import VideoToolbox
import ARKit
final class LiveViewController: UIViewController, ARSessionDelegate {
    private static let maxRetryCount: Int = 5
    @IBOutlet private weak var lfView: MTHKView!
    @IBOutlet private weak var currentFPSLabel: UILabel!
    @IBOutlet private weak var publishButton: UIButton!
    @IBOutlet weak var currentResoLabel: UILabel!
    @IBOutlet private weak var zoomSlider: UISlider!
    @IBOutlet weak var sentResoLabel: UILabel!
    
    private var rtmpConnection = RTMPConnection()
    private var rtmpStream: RTMPStream!
    private var sharedObject: RTMPSharedObject!
    private var currentEffect: VideoEffect?
    private var currentPosition: AVCaptureDevice.Position = .back
    private var retryCount: Int = 0
    public var capWidth: Double?
    public var capHeight: Double?
    
    
    private var webServer:GCDWebServer?

    func initWebServer() {

        let webServer = GCDWebServer()

        webServer.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self, processBlock: {request in
            return GCDWebServerDataResponse(text:PoseRecorder.PoseRecordes.PublicRecord())
                
            })
            
        webServer.start(withPort: 8080, bonjourName: "GCD Web Server")
        
        print("Visit \(String(describing: webServer.serverURL)) in your web browser")
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        rtmpStream = RTMPStream(connection: rtmpConnection)
        if let orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation) {
            rtmpStream.orientation = orientation
        }
        rtmpStream.captureSettings = [
            .sessionPreset: AVCaptureSession.Preset.hd1280x720,
            .continuousAutofocus: true,
            .continuousExposure: true,
            .preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode.auto
        ]
        //rtmpStream.videoSettings = [
        //    .width: 854,
        ///    .height: 480
        //]
        

        NotificationCenter.default.addObserver(self, selector: #selector(on(_:)), name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    func loadLabels() {
        capWidth = Double(ARSessionCotroller.ARController.arConfiguration.videoFormat.imageResolution.width)
        capHeight = Double(ARSessionCotroller.ARController.arConfiguration.videoFormat.imageResolution.height)
        print("[DEBUGER] \(String(capWidth!)) x \(String(capHeight!))")
        currentResoLabel?.text =
            "\(String(capWidth!)) x \(String(capHeight!))"
        
        print("[INFO] width ", (Preference.defaultInstance.encodeScale)!)
        let sentWidth = capWidth! / Double((Preference.defaultInstance.encodeScale)!)!
        let sentHeight = capHeight! / Double((Preference.defaultInstance.encodeScale)!)!
        
        rtmpStream.videoSettings = [
            .width: sentWidth,
            .height: sentHeight
        ]
        
        sentResoLabel?.text =
            "\(String(sentWidth)) x \(String(sentHeight))"
        
        ARSessionCotroller.ARController.format = Int(Preference.defaultInstance.captureMode!)!
        rtmpStream.captureSettings[.fps] = ARSessionCotroller.ARController.fps
    }

    override func viewWillAppear(_ animated: Bool) {
        
        logger.info("viewWillAppear")
        super.viewWillAppear(animated)
        
        rtmpStream.addObserver(self, forKeyPath: "currentFPS", options: .new, context: nil)
        lfView?.attachStream(rtmpStream)
         
        if ARSessionCotroller.ARController.ArIsRunning {
            loadLabels()
        }
        else{
            rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
                logger.warn(error.description)
            }
            rtmpStream.attachCamera(DeviceUtil.device(withPosition: currentPosition)) { error in
                logger.warn(error.description)
            }
        }

        print("[info] viewWillAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        logger.info("viewWillDisappear")
        super.viewWillDisappear(animated)
        rtmpStream.removeObserver(self, forKeyPath: "currentFPS")
        rtmpStream.close()
        //rtmpStream.dispose()
    }

    @IBAction func rotateCamera(_ sender: UIButton) {
        logger.info("rotateCamera")
        let position: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        rtmpStream.captureSettings[.isVideoMirrored] = position == .front
        rtmpStream.attachCamera(DeviceUtil.device(withPosition: position)) { error in
            logger.warn(error.description)
        }
        currentPosition = position
    }

    
    @IBAction func on(slider: UISlider) {
        if slider == zoomSlider {
            rtmpStream.setZoomFactor(CGFloat(slider.value), ramping: true, withRate: 5.0)
        }
    }


    @IBAction func on(close: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func on(publish: UIButton) {
        print("[Button select] viewWillAppear")
        if publish.isSelected {
            rtmpConnection.close()
            rtmpConnection.removeEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.removeEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            publish.setTitle("●", for: [])
        } else {
            UIApplication.shared.isIdleTimerDisabled = true
            rtmpConnection.addEventListener(.rtmpStatus, selector: #selector(rtmpStatusHandler), observer: self)
            rtmpConnection.addEventListener(.ioError, selector: #selector(rtmpErrorHandler), observer: self)
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            publish.setTitle("■", for: [])
        }
        publish.isSelected.toggle()
    }

    @objc
    private func rtmpStatusHandler(_ notification: Notification) {
        let e = Event.from(notification)
        guard let data: ASObject = e.data as? ASObject, let code: String = data["code"] as? String else {
            return
        }
        logger.info(code)
        switch code {
        case RTMPConnection.Code.connectSuccess.rawValue:
            retryCount = 0
            rtmpStream!.publish(Preference.defaultInstance.streamName!)
            // sharedObject!.connect(rtmpConnection)
        case RTMPConnection.Code.connectFailed.rawValue, RTMPConnection.Code.connectClosed.rawValue:
            guard retryCount <= LiveViewController.maxRetryCount else {
                return
            }
            Thread.sleep(forTimeInterval: pow(2.0, Double(retryCount)))
            rtmpConnection.connect(Preference.defaultInstance.uri!)
            retryCount += 1
        default:
            break
        }
    }

    @objc
    private func rtmpErrorHandler(_ notification: Notification) {
        logger.error(notification)
        rtmpConnection.connect(Preference.defaultInstance.uri!)
    }

    func tapScreen(_ gesture: UIGestureRecognizer) {
        if let gestureView = gesture.view, gesture.state == .ended {
            let touchPoint: CGPoint = gesture.location(in: gestureView)
            let pointOfInterest = CGPoint(x: touchPoint.x / gestureView.bounds.size.width, y: touchPoint.y / gestureView.bounds.size.height)
            print("pointOfInterest: \(pointOfInterest)")
            rtmpStream.setPointOfInterest(pointOfInterest, exposure: pointOfInterest)
        }
    }

    @objc
    private func on(_ notification: Notification) {
        guard let orientation = DeviceUtil.videoOrientation(by: UIApplication.shared.statusBarOrientation) else {
            return
        }
        rtmpStream.orientation = orientation
    }

    @objc
    private func didEnterBackground(_ notification: Notification) {
        print("[INFO] Enter background")
        
        if webServer != nil {
            webServer!.stop()
        }
        // rtmpStream.receiveVideo = false
    }

    @objc
    private func didBecomeActive(_ notification: Notification) {
        print("[INFO] Enter foreground")
        if webServer == nil {
            initWebServer()
        }
        else {
            webServer!.start(withPort: 8080, bonjourName: "GCD Web Server")
        }
        // rtmpStream.receiveVideo = true
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if Thread.isMainThread {
            currentFPSLabel?.text = "\(rtmpStream.currentFPS)"
        }
    }
}

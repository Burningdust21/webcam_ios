import CoreImage
import ARKit
final class VideoIOComponent: IOComponent, ARSessionDelegate {
    let Arkit_queue = DispatchQueue(label: "com.mylogger.arkit.queen")

    var prevtime: Double = 0
    var curtime: Double = 0
    var TotalTime: Atomic<Double> = .init(0.0)
    let delta: Double = 1.0
    
    let debugMode: Bool = false
    
    var assetWriterInput: AVAssetWriterInput?
    var assetWriter: AVAssetWriter?
    var assetWriterInputPixelBufferAdaptorWithAssetWriterInput: AVAssetWriterInputPixelBufferAdaptor?
    var nowDate: String?
    let FPS:Int32 = 30
    var dateFormat: DateFormatter = DateFormatter()
    var localSavePose: String = ""
    // times of commection attemps
    private var reduceFPS: Int = 1
    
    
    private func CVPtoCMS(pixelBuffer : CVPixelBuffer, timestamp: TimeInterval)->CMSampleBuffer{
        
        var newSampleBuffer: CMSampleBuffer? = nil
        let scale = CMTimeScale(NSEC_PER_SEC)
        let pts = CMTime(value: CMTimeValue(timestamp * Double(scale)),
                         timescale: scale)
        var timimgInfo = CMSampleTimingInfo(duration: CMTime.invalid,
                                            presentationTimeStamp: pts,
                                            decodeTimeStamp: CMTime.invalid)
        var videoInfo: CMVideoFormatDescription? = nil
 
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &videoInfo)
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: videoInfo!, sampleTiming: &timimgInfo, sampleBufferOut: &newSampleBuffer)

        curtime = pts.seconds
        return newSampleBuffer!
        
    }

        
    public func session(_ session: ARSession, didUpdate frame: ARFrame)
    {
        let Pixbuffer = frame.capturedImage
        let CMSbuffer = CVPtoCMS(pixelBuffer: Pixbuffer, timestamp: frame.timestamp)
        // do encoding and sent pose
        // sent only if this video frame starts to encode, make sure pose and video are synchronized
        switch encodeSampleBuffer(CMSbuffer) {
        case .sessionStopped:
            if debugMode {
                endRecorder()
            }
            TotalTime.mutate { $0 = 0 }
        case .lockInvalid:
            TotalTime.mutate { $0 += 0 }
        case .sentPose:
            sendPose(frame: frame)
        }
    }
    
    func sendPose(frame: ARFrame) {
        // print("[INFO] Pose has sent ", TotalTime)
        let trans = frame.camera.transform
        let quat = (simd_quaternion(trans))
        let intrinsics = frame.camera.intrinsics
        let poseOutput = String(format: "%d,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%d,%d\r\n",
                                UInt32(TotalTime.value),
                                   
                                intrinsics[0][0], intrinsics[1][1],
                                intrinsics[2][0], intrinsics[2][1],

                                trans[3][0], trans[3][1], trans[3][2],
                                quat.vector[3], quat.vector[0], quat.vector[1], quat.vector[2],
                                frame.capturedImage.width, frame.capturedImage.height)
        PoseRecorder.PoseRecordes.AddRecord(record: poseOutput)
        // in debug mode, save output to device
        if debugMode {
            saveToFile(pixelBuffer: frame.capturedImage, pose: poseOutput, frameNum: Int64(TotalTime.value))
        }
        TotalTime.mutate { $0 += delta }
    }
    
    func endRecorder() {
        if TotalTime.value != 0 {
            // stopped
            assetWriterInput!.markAsFinished()
            assetWriter!.finishWriting {
                print("finished writing")
            }
            assetWriterInput = nil
            assetWriter = nil
            assetWriterInputPixelBufferAdaptorWithAssetWriterInput = nil

            let fileURL = String(format: "%@/Documents/%@/pose_intrinsics.txt", arguments: [NSHomeDirectory(), nowDate!])
            //writing
            do {
                try localSavePose.write(toFile: fileURL, atomically: false, encoding: String.Encoding.utf8)
            }
            catch {
                print("Write error")
            }
            localSavePose = ""
            nowDate = nil
        }
    }
    func saveToFile(pixelBuffer: CVPixelBuffer, pose: String, frameNum: Int64) {
        // save video
        if frameNum == 0 {
            dateFormat.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
            nowDate = dateFormat.string(from: NSDate.init() as Date)
            let dirPath =  String(format: "%@/Documents/%@", arguments: [NSHomeDirectory(), nowDate!])
            let filePath = dirPath + "/Frames.m4v"
            let outputURL = NSURL(fileURLWithPath: filePath as String)
            do {
                let fileManager = FileManager.default
                try! fileManager.createDirectory(atPath: dirPath,
                                        withIntermediateDirectories: true, attributes: nil)

                assetWriter = try AVAssetWriter(outputURL:outputURL as URL, fileType:AVFileType.m4v)

                let writerInputParams: NSDictionary = [AVVideoCodecKey:AVVideoCodecType.hevc,
                                                       AVVideoWidthKey:Int(CVPixelBufferGetWidthOfPlane(pixelBuffer,0)),
                                                       AVVideoHeightKey:Int(CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)),
                                                       AVVideoScalingModeKey:AVVideoScalingModeResizeAspectFill]

                // thsi is for debug only
                assetWriterInput = AVAssetWriterInput(mediaType:AVMediaType.video, outputSettings:writerInputParams as? [String : Any])
                if (assetWriter!.canAdd(assetWriterInput!)) {
                    assetWriter!.add(assetWriterInput!)
                }

                assetWriterInputPixelBufferAdaptorWithAssetWriterInput = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput!)


                assetWriter!.startWriting()
                assetWriter!.startSession(atSourceTime: CMTime.zero)

            } catch {
                print("something wrong!!")
            }
        }

        let timePresent = CMTimeMake(value: frameNum, timescale: FPS)
        while(!assetWriterInputPixelBufferAdaptorWithAssetWriterInput!.assetWriterInput.isReadyForMoreMediaData) {}
        assetWriterInputPixelBufferAdaptorWithAssetWriterInput!.append(pixelBuffer, withPresentationTime:timePresent)

        // save pose
        localSavePose += pose
    }
    
    #if os(macOS)
    static let defaultAttributes: [NSString: NSObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferOpenGLCompatibilityKey: kCFBooleanTrue
    ]
    #else
    static let defaultAttributes: [NSString: NSObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
        kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferOpenGLESCompatibilityKey: kCFBooleanTrue
    ]
    #endif

    let lockQueue = DispatchQueue(label: "com.haishinkit.HaishinKit.VideoIOComponent.lock")

    var context: CIContext? {
        didSet {
            for effect in effects {
                effect.ciContext = context
            }
        }
    }

    #if os(iOS) || os(macOS)
    weak var renderer: NetStreamRenderer? = nil {
        didSet {
            renderer?.orientation = orientation
        }
    }
    #else
    weak var renderer: NetStreamRenderer?
    #endif

    var formatDescription: CMVideoFormatDescription? {
        didSet {
            decoder.formatDescription = formatDescription
        }
    }
    lazy var encoder = H264Encoder()
    lazy var decoder = H264Decoder()
    lazy var queue: DisplayLinkedQueue = {
        let queue = DisplayLinkedQueue()
        queue.delegate = self
        return queue
    }()

    private(set) var effects: Set<VideoEffect> = []

    private var extent = CGRect.zero {
        didSet {
            guard extent != oldValue else {
                return
            }
            pixelBufferPool = nil
        }
    }

    private var attributes: [NSString: NSObject] {
        var attributes: [NSString: NSObject] = VideoIOComponent.defaultAttributes
        attributes[kCVPixelBufferWidthKey] = NSNumber(value: Int(extent.width))
        attributes[kCVPixelBufferHeightKey] = NSNumber(value: Int(extent.height))
        return attributes
    }

    private var _pixelBufferPool: CVPixelBufferPool?
    private var pixelBufferPool: CVPixelBufferPool! {
        get {
            if _pixelBufferPool == nil {
                var pixelBufferPool: CVPixelBufferPool?
                CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary?, &pixelBufferPool)
                _pixelBufferPool = pixelBufferPool
            }
            return _pixelBufferPool!
        }
        set {
            _pixelBufferPool = newValue
        }
    }

    #if os(iOS) || os(macOS)
    var fps: Float64 = AVMixer.defaultFPS {
        didSet {
            guard
                let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                let data = device.actualFPS(fps) else {
                    return
            }

            fps = mixer?.session.fps ?? 0
            encoder.expectedFPS = mixer?.session.fps ?? 30
            logger.info("\(data)")
 
            do {
                try device.lockForConfiguration()
                device.activeVideoMinFrameDuration = data.duration
                device.activeVideoMaxFrameDuration = data.duration
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for fps: \(error)")
            }
        }
    }

    var position: AVCaptureDevice.Position = .back

    var videoSettings: [NSObject: AnyObject] = AVMixer.defaultVideoSettings {
        didSet {
            output.videoSettings = videoSettings as? [String: Any]
        }
    }

    var isVideoMirrored = false {
        didSet {
            guard isVideoMirrored != oldValue else {
                return
            }
            for connection in output.connections where connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isVideoMirrored
            }
        }
    }

    var orientation: AVCaptureVideoOrientation = .portrait {
        didSet {
            renderer?.orientation = orientation
            guard orientation != oldValue else {
                return
            }
            for connection in output.connections where connection.isVideoOrientationSupported {
                connection.videoOrientation = orientation
                if torch {
                    setTorchMode(.on)
                }
                #if os(iOS)
                connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
                #endif
            }
        }
    }

    var torch: Bool = false {
        didSet {
            guard torch != oldValue else {
                return
            }
            setTorchMode(torch ? .on : .off)
        }
    }

    var continuousAutofocus: Bool = false {
        didSet {
            guard continuousAutofocus != oldValue else {
                return
            }
            let focusMode: AVCaptureDevice.FocusMode = continuousAutofocus ? .continuousAutoFocus : .autoFocus
            guard let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                device.isFocusModeSupported(focusMode) else {
                    logger.warn("focusMode(\(focusMode.rawValue)) is not supported")
                    return
            }
            do {
                try device.lockForConfiguration()
                device.focusMode = focusMode
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for autofocus: \(error)")
            }
        }
    }

    var focusPointOfInterest: CGPoint? {
        didSet {
            guard
                let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                let point: CGPoint = focusPointOfInterest,
                device.isFocusPointOfInterestSupported else {
                    return
            }
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = .continuousAutoFocus
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for focusPointOfInterest: \(error)")
            }
        }
    }

    var exposurePointOfInterest: CGPoint? {
        didSet {
            guard
                let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                let point: CGPoint = exposurePointOfInterest,
                device.isExposurePointOfInterestSupported else {
                    return
            }
            do {
                try device.lockForConfiguration()
                device.exposurePointOfInterest = point
                device.exposureMode = .continuousAutoExposure
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for exposurePointOfInterest: \(error)")
            }
        }
    }

    var continuousExposure: Bool = false {
        didSet {
            guard continuousExposure != oldValue else {
                return
            }
            let exposureMode: AVCaptureDevice.ExposureMode = continuousExposure ? .continuousAutoExposure : .autoExpose
            guard let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device,
                device.isExposureModeSupported(exposureMode) else {
                    logger.warn("exposureMode(\(exposureMode.rawValue)) is not supported")
                    return
            }
            do {
                try device.lockForConfiguration()
                device.exposureMode = exposureMode
                device.unlockForConfiguration()
            } catch let error as NSError {
                logger.error("while locking device for autoexpose: \(error)")
            }
        }
    }

    #if os(iOS)
    var preferredVideoStabilizationMode: AVCaptureVideoStabilizationMode = .off {
        didSet {
            guard preferredVideoStabilizationMode != oldValue else {
                return
            }
            for connection in output.connections {
                connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            }
        }
    }
    #endif

    private var _output: AVCaptureVideoDataOutput?
    var output: AVCaptureVideoDataOutput! {
        get {
            if _output == nil {
                _output = AVCaptureVideoDataOutput()
                _output?.alwaysDiscardsLateVideoFrames = true
                _output?.videoSettings = videoSettings as? [String: Any]
            }
            return _output!
        }
        set {
            if _output == newValue {
                return
            }
            if let output: AVCaptureVideoDataOutput = _output {
                output.setSampleBufferDelegate(nil, queue: nil)
            }
            _output = newValue
        }
    }

    var input: AVCaptureInput? = nil {
        didSet {
            guard let mixer: AVMixer = mixer, oldValue != input else {
                return
            }
            if let oldValue: AVCaptureInput = oldValue {
            }
            if let input: AVCaptureInput = input, true {
            }
        }
    }
    #endif

    #if os(iOS)
    var screen: CustomCaptureSession? = nil {
        didSet {
            if let oldValue: CustomCaptureSession = oldValue {
                oldValue.delegate = nil
            }
            if let screen: CustomCaptureSession = screen {
                screen.delegate = self
            }
        }
    }
    #endif

    override init(mixer: AVMixer) {
        super.init(mixer: mixer)
        mixer.session.arSession.delegate = self
        mixer.session.arSession.delegateQueue = self.lockQueue
        encoder.lockQueue = lockQueue
        decoder.delegate = self
    }

    #if os(iOS) || os(macOS)
    func attachCamera(_ camera: AVCaptureDevice?) throws {
        guard let mixer: AVMixer = mixer else {
            return
        }

        output = nil
        guard let camera: AVCaptureDevice = camera else {
            input = nil
            return
        }
        #if os(iOS)
        screen = nil
        #endif

        input = try AVCaptureDeviceInput(device: camera)

        for connection in output.connections {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = orientation
            }
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = isVideoMirrored
            }
            #if os(iOS)
            connection.preferredVideoStabilizationMode = preferredVideoStabilizationMode
            #endif
        }

        output.setSampleBufferDelegate(self, queue: lockQueue)

        fps *= 1
        position = camera.position
        renderer?.position = camera.position
    }

    func setTorchMode(_ torchMode: AVCaptureDevice.TorchMode) {
        guard let device: AVCaptureDevice = (input as? AVCaptureDeviceInput)?.device, device.isTorchModeSupported(torchMode) else {
            logger.warn("torchMode(\(torchMode)) is not supported")
            return
        }
        do {
            try device.lockForConfiguration()
            device.torchMode = torchMode
            device.unlockForConfiguration()
        } catch let error as NSError {
            logger.error("while setting torch: \(error)")
        }
    }

    func dispose() {
        if Thread.isMainThread {
            self.renderer?.attachStream(nil)
        } else {
            DispatchQueue.main.sync {
                self.renderer?.attachStream(nil)
            }
        }

        input = nil
        output = nil
    }
    #else
    func dispose() {
        if Thread.isMainThread {
            self.renderer?.attachStream(nil)
        } else {
            DispatchQueue.main.sync {
                self.renderer?.attachStream(nil)
            }
        }
    }
    #endif

    @inline(__always)
    func effect(_ buffer: CVImageBuffer, info: CMSampleBuffer?) -> CIImage {
        var image = CIImage(cvPixelBuffer: buffer)
        for effect in effects {
            image = effect.execute(image, info: info)
        }
        return image
    }

    func registerEffect(_ effect: VideoEffect) -> Bool {
        effect.ciContext = context
        return effects.insert(effect).inserted
    }

    func unregisterEffect(_ effect: VideoEffect) -> Bool {
        effect.ciContext = nil
        return effects.remove(effect) != nil
    }
}

extension VideoIOComponent {
    func encodeSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> ARSessionCotroller.poseStatus{
        guard let buffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return .sessionStopped
        }

        var imageBuffer: CVImageBuffer?

        CVPixelBufferLockBaseAddress(buffer, [])
        defer {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            if let imageBuffer = imageBuffer {
                CVPixelBufferUnlockBaseAddress(imageBuffer, [])
            }
        }

        if renderer != nil || !effects.isEmpty {
            let image: CIImage = effect(buffer, info: sampleBuffer)
            extent = image.extent
            if !effects.isEmpty {
                #if os(macOS)
                CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &imageBuffer)
                #else
                if buffer.width != Int(extent.width) || buffer.height != Int(extent.height) {
                    CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &imageBuffer)
                }
                #endif
                if let imageBuffer = imageBuffer {
                    CVPixelBufferLockBaseAddress(imageBuffer, [])
                }
                context?.render(image, to: imageBuffer ?? buffer)
            }
            renderer?.render(image: image)
        }
        if reduceFPS == 1 {
            reduceFPS = 0
        }
        else {
            reduceFPS = 1
            return .lockInvalid
        }

        let EncodingStart: ARSessionCotroller.poseStatus = encoder.encodeImageBuffer(
            imageBuffer ?? buffer,
            presentationTimeStamp: sampleBuffer.presentationTimeStamp,
            duration: sampleBuffer.duration
        )

        mixer?.recorder.appendPixelBuffer(imageBuffer ?? buffer, withPresentationTime: sampleBuffer.presentationTimeStamp)
        
        return EncodingStart
    }
}

extension VideoIOComponent {
    func startDecoding() {
        queue.startRunning()
        decoder.startRunning()
    }

    func stopDecoding() {
        decoder.stopRunning()
        queue.stopRunning()
        renderer?.render(image: nil)
    }

    func decodeSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        _ = decoder.decodeSampleBuffer(sampleBuffer)
    }
}
//MARK: AR session Started
extension VideoIOComponent: AVCaptureVideoDataOutputSampleBufferDelegate {
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // This function should never be executed!!
    }
}

extension VideoIOComponent: VideoDecoderDelegate {
    // MARK: VideoDecoderDelegate
    func sampleOutput(video sampleBuffer: CMSampleBuffer) {
        queue.enqueue(sampleBuffer)
    }
}

extension VideoIOComponent: DisplayLinkedQueueDelegate {
    // MARK: DisplayLinkedQueue
    func queue(_ buffer: CMSampleBuffer) {
        renderer?.render(image: CIImage(cvPixelBuffer: buffer.imageBuffer!))
        mixer?.delegate?.didOutputVideo(buffer)
    }

    func empty() {
        mixer?.didBufferEmpty(self)
    }
}


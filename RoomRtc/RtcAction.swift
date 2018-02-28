import Foundation
import WebRTC


/**
Status wrapper for RTCIceConnectionState
 * checking - The ICE agent has been given one or more remote candidates and is checking pairs of local and remote candidates against one another to try to find a compatible match, but has not yet found a pair which will allow the peer connection to be made. It's possible that gathering of candidates is also still underway.
 * failed - The ICE candidate has checked all candidates pairs against one another and has failed to find compatible matches for all components of the connection. It is, however, possible that the ICE agent did find compatible connections for some components.
 * connected - A usable pairing of local and remote candidates has been found for all components of the connection, and the connection has been established. It's possible that gathering is still underway, and it's also possible that the ICE agent is still checking candidates against one another looking for a better connection to use.
 * completed - The ICE agent has finished gathering candidates, has checked all pairs against one another, and has found a connection for all components.
 * disconnected - Checks to ensure that components are still connected failed for at least one component of the RTCPeerConnection. This is a less stringent test than "failed" and may trigger intermittently and resolve just as spontaneously on less reliable networks, or during temporary disconnections. When the problem resolves, the connection may return to the "connected" state.
 * closed - The ICE agent for this RTCPeerConnection has shut down and is no longer handling requests.
 */
enum CallState {
    case checking,
        completed,
        failed,
        connected,
        disconnected,
        closed
}


/// Delegate for adding renderer for local and remote stream
protocol RendererDelegate {

    func onLocalStreamReadyForRender()
    
    func onRemoteStreamReadyForRender(remoteVideoTracks: [RTCVideoTrack])
}

/// Delegate for sdp offer and answer creation
protocol SdpCreatedDelegate {
    
    // Callback when sdp offer created after initiating call which will be send to the one you're calling
    func onSdpOfferCreated(sdpOffer: String)
    
    // Callback when sdp answer created after receiving call which will send to the one who called
    func onSdpAnswerCreated(sdpAnswer: String)
    
    // Callback when sdp answer from the one you're calling has been set to your remote description
    func onSdpAnswerSet()
}


/// Delegate when all sdp are send and receive, peer connection is now evaluated
protocol CallStateDelegate {
    
    func onCallStateChange(_ callState: CallState)
}

// Delegate when new ICECandidate created
protocol IceStateDelegate {
    
    func onIceStateCreated(_ ice: RTCIceCandidate)
}

// Delegate when RTCSignalingState changes
protocol SignalingStateDelegate {
    
    func onSignalingStateChange(_ signalingState: RTCSignalingState)
}

fileprivate protocol MediaTrackDelegate {
    
    func onVideoTrackCreated(_ videoTrack: RTCVideoTrack?, _ videoSource: RTCVideoSource?, _ videoCaptureSession: AVCaptureSession?)
    
    func onAudioTrackCreated(_ audioTrack: RTCAudioTrack?, _ audioSource: RTCAudioSource?)
}


class RtcAction: MediaTrackDelegate, RendererDelegate, SignalingStateDelegate {

    /// The sdp offer/answer created which will be used when new ICE candidate generated passing to other party
    var sdp: String?
    
    private var rtcManager: RtcManager
    
    private var currVideoTrack: RTCVideoTrack?
    private var currVideoSource: RTCVideoSource?
    private var currVideoCaptureSession: AVCaptureSession?
    
    private var currAudioTrack: RTCAudioTrack?
    private var currAudioSource: RTCAudioSource?
    
    private var localStream: RTCMediaStream?
    
    private var peerConn: RTCPeerConnection?

    private var sdpCreateDelegate: SdpCreatedDelegate?
    private var callStateDelegate: CallStateDelegate?
    private var iceStateDelegate: IceStateDelegate?
    
    private var localVideoView: UIView?
    private var remoteVideoView: UIView?
    private var iceCandidates: [RTCIceCandidate]?
    
    
    init() {
        self.rtcManager = RtcManager()
    }

    func initRtcAction(localVideoView: UIView,
                       remoteVideoView: UIView,
                       sdpCreateDelegate: SdpCreatedDelegate,
                       callStateDelegate: CallStateDelegate,
                       iceStateDelegate: IceStateDelegate) {
        
        self.localVideoView = localVideoView
        self.remoteVideoView = remoteVideoView
        self.sdpCreateDelegate = sdpCreateDelegate
        self.callStateDelegate = callStateDelegate
        self.iceStateDelegate = iceStateDelegate
        self.rtcManager.initDelegates(mediaTrackDelegate: self,
                                      callStateDelegate: callStateDelegate,
                                      iceStateDelegate: iceStateDelegate,
                                      rendererDelegate: self,
                                      signalingStateDelegate: self)
    }
    
    func setup() {
        RTCSetMinDebugLogLevel(.error)
        peerConn = rtcManager.createPeerConnection()
        
        localStream = rtcManager.createLocalMediaStream(mediaStreamId: Config.mediaTrackLabel)
        
        rtcManager.createAudioTrack()
        rtcManager.createLocalVideoTrack(position: .front)
    }
    
    func addIceCandidate(_ ice: RTCIceCandidate) {
        peerConn!.add(ice)
    }
    
    /// Clean renderer which will remove existing renderer view from existingremote RTCMediaStream.
    func resetRemoteRenderer() {
        for stream in rtcManager.remoteRtcMediaStream {
            
            for remoteVideoTrack in stream.videoTracks {
                
                DispatchQueue.main.async {
                    if let renderView = self.remoteVideoView?.subviews.last {
                        self.removeRenderer(videoTrack: remoteVideoTrack, renderView: renderView)
                        renderView.removeFromSuperview()
                    }
                }
            }
        }
    }

    func startCall() {
        createOffer()
    }
    
    func acceptIncomingCall(sdpOffer: String) {
        print("handleReceiveOffer")
        let sdpOffer: RTCSessionDescription = RTCSessionDescription.init(type: .offer, sdp: sdpOffer)
        peerConn!.setRemoteDescription(sdpOffer, completionHandler: {
            err in
            guard err == nil else {
                print("Error setting remote offer description: \(err?.localizedDescription ?? "")")
                return
            }
        })
    }
    
    // MARK: - SignalingStateDelegate
    internal func onSignalingStateChange(_ signalingState: RTCSignalingState) {
        if signalingState == .haveLocalOffer {
            self.sdpCreateDelegate?.onSdpOfferCreated(sdpOffer: sdp!)
        }
        else if signalingState == .haveRemoteOffer {
            self.createAnswer()
        }
    }
    
    fileprivate func setLocalDescription(sdp: RTCSessionDescription) {
        peerConn!.setLocalDescription(sdp, completionHandler: {
            error in
            if let err = error {
                print("Error setLocalDescription. \(err.localizedDescription)")
            }
        })
    }
    
    fileprivate func createOffer() {
        peerConn!.offer(for: rtcManager.defaultPeerOfferConstraints(), completionHandler: {
            (rtcSessionDesc, error) in
            guard error == nil, let sdpOffer = rtcSessionDesc?.sdp else {
                print("Error creating sdp offer: \(error!.localizedDescription)")
                return
            }
            self.sdp = sdpOffer
            self.setLocalDescription(sdp: rtcSessionDesc!)
        })
    }
    
    fileprivate func createAnswer() {
        print("createAnswer")
        peerConn!.answer(for: rtcManager.defaultPeerAnswerConstraints(), completionHandler:
            {
                (rtcSessionDesc, error) in
                guard error == nil, let sdpAnswer = rtcSessionDesc?.sdp else {
                    print("Error creating sdp answer: \(error!.localizedDescription)")
                    return
                }
                self.sdp = sdpAnswer
                self.setLocalDescription(sdp: rtcSessionDesc!)
                self.sdpCreateDelegate?.onSdpAnswerCreated(sdpAnswer: sdpAnswer)
                
                self.printRtcStatsReport()
            }
        )
    }
    
    // MARK: - Called when sdp answer is received. Use by caller.
    func receiveCallAccepted(sdpAnswer: String) {
        let sdpAnswerReceived: RTCSessionDescription = RTCSessionDescription.init(type: .answer, sdp: sdpAnswer)
        peerConn!.setRemoteDescription(sdpAnswerReceived, completionHandler: {
            err in
            guard err == nil else {
                print("Error setting remote answer description: \(err!.localizedDescription)")
                return
            }
            self.sdpCreateDelegate?.onSdpAnswerSet()
            self.printRtcStatsReport()
        })
    }
    
    /// Called when caller or callee hangup or one of the party ends the ongoing call.
    func endCall() {
        peerConn!.close()
    }
    
    // MARK: - Manage renderer
    
    func removeRenderer(videoTrack: RTCVideoTrack?, renderView: UIView?) {
        if let vidTrack = videoTrack, let videoView = renderView as? RTCVideoRenderer {
            vidTrack.remove(videoView)
        }
    }
    
    // MARK: - Print stats and rtp senders
    
    private func printRtcRtpSenders() {
        for rtcRtpSender in peerConn!.senders {
            let mediaTrack = rtcRtpSender.track!
            print("RTCRTPSender kind:\(mediaTrack.kind) trackId:\(mediaTrack.trackId) enabled:\(mediaTrack.isEnabled) readyState:\(mediaTrack.readyState == RTCMediaStreamTrackState.live ? "live": "ended")")
            
            for rtcRtpCodecParameterCodec in rtcRtpSender.parameters.codecs {
                print("codec name: \(rtcRtpCodecParameterCodec.name)")
                print("codec kind: \(rtcRtpCodecParameterCodec.kind)")
            }
            for rtcRtpCodecParameterEncoding in rtcRtpSender.parameters.encodings {
                print("encoding isActive: \(rtcRtpCodecParameterEncoding.isActive)")
                print("encoding ssrc: \(String(describing: rtcRtpCodecParameterEncoding.ssrc))")
            }
        }
    }
    
    // Print RTC audio stats
    private func printAudioStats() {
        peerConn!.stats(for: currAudioTrack, statsOutputLevel: RTCStatsOutputLevel.debug, completionHandler:
            {
                reports in
                print("RTCLegacyStatsReport")
                for report in reports {
                    print("---------- audio stats ----------")
                    print("reportId: \(report.reportId)")
                    print("type: \(report.type)")
                    for (kind, value) in report.values {
                        print("\(kind): \(value)")
                    }
                }
        })
    }
    
    // Print RTC video stats
    private func printVideoStats() {
        self.peerConn!.stats(for: self.currVideoTrack, statsOutputLevel: RTCStatsOutputLevel.debug, completionHandler:
            {
                reports in
                print("RTCLegacyStatsReport")
                for report in reports {
                    print("---------- video stats ----------")
                    print("reportId: \(report.reportId)")
                    print("type: \(report.type)")
                    for (kind, value) in report.values {
                        print("\(kind): \(value)")
                    }
                }
        })
    }
    
    func printRtcStatsReport() {
        printAudioStats()
        printVideoStats()
    }
    
    // MARK: - MediaTrackDelegate
    
    fileprivate func onAudioTrackCreated(_ audioTrack: RTCAudioTrack?, _ audioSource: RTCAudioSource?) {
        print("onAudioTrackCreated")
        currAudioTrack = audioTrack
        currAudioSource = currAudioTrack?.source
        
        if let _ = audioTrack {
            localStream!.addAudioTrack(audioTrack!)
            print("localstream added audio track with track id \(currAudioTrack?.trackId ?? nil)")
            
            //if let _ = localStream {
            //    //peerConn?.remove(stream)
            //    if peerConn?.localStreams.contains(localStream!)
            //    peerConn?.add(localStream)
            //    print("peerconnection added stream in audio")
            //}
        }
    }
    
    fileprivate func onVideoTrackCreated(_ videoTrack: RTCVideoTrack?, _ videoSource: RTCVideoSource?, _ videoCaptureSession: AVCaptureSession?) {
        print("onVideoTrackCreated")

        currVideoTrack = videoTrack
        currVideoSource = videoSource
        currVideoCaptureSession = videoCaptureSession
        videoCaptureSession?.startRunning()

        if let _ = currVideoTrack {
            localStream!.addVideoTrack(videoTrack!)
            print("localstream added video track with track id \(String(describing: currVideoTrack?.trackId))")
            
            //if let _ = localStream {
            //    //peerConn?.remove(stream)
            //    peerConn?.add(localStream!)
            //    print("peerconnection added stream in video")
            //}
            
            onLocalStreamReadyForRender()
            
            printRtcRtpSenders()
        }

        for stream in peerConn!.localStreams {
            if stream.streamId == Config.mediaTrackLabel {
                peerConn!.remove(localStream!)
            }
        }
        
        peerConn!.add(localStream!)
    }
    
    // MARK: - RendererDelegate
    
    func onLocalStreamReadyForRender() {
        print("onLocalStreamReadyForRender")
        let frame = localVideoView!.frame

        let rtcVideoView = RTCCameraPreviewView.init(frame: CGRect.init())
        rtcVideoView.frame = frame
        rtcVideoView.frame.origin.x = 0
        rtcVideoView.frame.origin.y = 0
        self.localVideoView?.addSubview(rtcVideoView)
        
        rtcVideoView.captureSession = currVideoCaptureSession
    }
    
    func onRemoteStreamReadyForRender(remoteVideoTracks: [RTCVideoTrack]) {
        print("onRemoteStreamReadyForRender")
        resetRemoteRenderer()
        DispatchQueue.main.async {
            let rtcVideoView: RTCEAGLVideoView = RTCEAGLVideoView(frame: self.remoteVideoView!.frame)
            rtcVideoView.frame.origin.x = 0
            rtcVideoView.frame.origin.y = 0
            self.remoteVideoView?.addSubview(rtcVideoView)
            remoteVideoTracks.last?.add(rtcVideoView)
        }
    }
    
    // MARK: - Video controls
    
    func swapCamera(isFront: Bool) {
        guard localStream!.videoTracks[0] != nil else {
            print("Error trying to swap camera, video track index 0 null")
            return
        }
        //localStream?.removeVideoTrack(videoTrack)
        
        let camPosition: AVCaptureDevice.Position = isFront ? .front : .back
        rtcManager.createLocalVideoTrack(position: camPosition)
    }

    func muteVideoIn() {
        //let currMediaStream = peerConn!.localStreams[0]
        //self.currVideoTrack = currMediaStream.videoTracks[0];
        //currMediaStream.removeVideoTrack(currMediaStream.videoTracks[0])
        //peerConn?.remove(currMediaStream)
        //peerConn?.add(currMediaStream)
        currVideoTrack?.isEnabled = false
        currVideoCaptureSession?.stopRunning()
    }
    
    func unmuteVideoIn() {
        //let currMediaStream = peerConn!.localStreams[0]
        //currMediaStream.addVideoTrack(self.currVideoTrack!)
        //peerConn?.remove(currMediaStream)
        //peerConn?.add(currMediaStream)
        currVideoTrack?.isEnabled = true
        currVideoCaptureSession?.startRunning()
    }
    
    // MARK: - Audio controls
    
    func muteAudioOut() {
    }
    
    func unmuteAudioOut() {
    }
    
    func muteAudioIn() {
        //let currMediaStream = peerConn!.localStreams[0]
        //self.currAudioTrack = currMediaStream.audioTracks[0];
        //currMediaStream.removeAudioTrack(currMediaStream.audioTracks[0])
        //peerConn?.remove(currMediaStream)
        //peerConn?.add(currMediaStream)
        currAudioTrack?.isEnabled = false
    }
    
    func unmuteAudioIn() {
        //let currMediaStream = peerConn!.localStreams[0]
        //currMediaStream.addAudioTrack(self.currAudioTrack!)
        //peerConn?.remove(currMediaStream)
        //peerConn?.add(currMediaStream)
        currAudioTrack?.isEnabled = true
    }
}


fileprivate class RtcManager: NSObject, RTCPeerConnectionDelegate {
    
    let peerConnFactory: RTCPeerConnectionFactory = RTCPeerConnectionFactory.init()
    
    var mediaTrackDelegate: MediaTrackDelegate?
    var callStateDelegate: CallStateDelegate?
    var iceStateDelegate: IceStateDelegate?
    var rendererDelegate: RendererDelegate?
    var signalingStateDelegate: SignalingStateDelegate?
    
    var remoteRtcMediaStream = [RTCMediaStream]()
    
    func initDelegates(mediaTrackDelegate: MediaTrackDelegate,
                       callStateDelegate: CallStateDelegate,
                       iceStateDelegate: IceStateDelegate,
                       rendererDelegate: RendererDelegate,
                       signalingStateDelegate: SignalingStateDelegate) {
        self.mediaTrackDelegate = mediaTrackDelegate
        self.callStateDelegate = callStateDelegate
        self.iceStateDelegate = iceStateDelegate
        self.rendererDelegate = rendererDelegate
        self.signalingStateDelegate = signalingStateDelegate
    }
    
    // MARK: - Creation of PeerConnection object
    
    func defaultICEServer() -> RTCIceServer {
        let urlStrings = [Config.defaultSTUNServerUrl]
        let iceServer = RTCIceServer.init(urlStrings: urlStrings)
        return iceServer
    }

    func defaultRtcConfiguration() -> RTCConfiguration {
        let rtcConfig = RTCConfiguration.init()
        rtcConfig.bundlePolicy = RTCBundlePolicy.maxCompat
        return rtcConfig
    }
    
    func defaultPeerConnectionConstraints() -> RTCMediaConstraints {
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        return constraints
    }

    func defaultPeerOfferConstraints() -> RTCMediaConstraints {
        let mandatoryConstraints = [
            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue]
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)
        return constraints
    }
    
    func defaultPeerAnswerConstraints() -> RTCMediaConstraints {
        let mandatoryConstraints = [
            kRTCMediaConstraintsOfferToReceiveAudio: kRTCMediaConstraintsValueTrue,
            kRTCMediaConstraintsOfferToReceiveVideo: kRTCMediaConstraintsValueTrue]
        let constraints = RTCMediaConstraints(mandatoryConstraints: mandatoryConstraints, optionalConstraints: nil)
        return constraints
    }
    
    func defaultCameraRtcMediaConstraints() -> RTCMediaConstraints {
        let cameraConstraints = RTCMediaConstraints(mandatoryConstraints:nil,
                                                    optionalConstraints:nil)
        return cameraConstraints
    }
    
    func defaultAudioRtcMediaConstraints() -> RTCMediaConstraints {
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints:nil,
                                                   optionalConstraints:nil)
        return audioConstraints
    }
    
    
    func createPeerConnection() -> RTCPeerConnection {
        let peerConnection = peerConnFactory.peerConnection(with: defaultRtcConfiguration(), constraints: defaultPeerConnectionConstraints(), delegate: self)
        
        return peerConnection
    }
    
    // MARK: - Creation of local media stream
    
    func createLocalMediaStream(mediaStreamId: String) -> RTCMediaStream {
        let localStream: RTCMediaStream = peerConnFactory.mediaStream(withStreamId: Config.mediaTrackLabel)
        return localStream
    }

    func createAudioTrack() {
        let audioSource = peerConnFactory.audioSource(with: defaultAudioRtcMediaConstraints())
        let localAudioTrack = peerConnFactory.audioTrack(with: audioSource, trackId: Config.mediaTrackAudioLabel)
        mediaTrackDelegate?.onAudioTrackCreated(localAudioTrack, audioSource)
    }
    
    func createLocalVideoTrack(position: AVCaptureDevice.Position) {
        if let captureDevice = getCaptureDevice(position: position) {
            print("createLocalVideoTrack")

            let videoSource = peerConnFactory.videoSource()
            let rtcCamVidCapturer = RTCCameraVideoCapturer(delegate: videoSource)

            // Set preset to medium suitable for audio and video calling
            if rtcCamVidCapturer.captureSession.canSetSessionPreset(.medium) {
                rtcCamVidCapturer.captureSession.sessionPreset = .medium
            }
            
            var avCaptureDeviceInput: AVCaptureDeviceInput? = nil
            do {
                avCaptureDeviceInput = try AVCaptureDeviceInput(device: captureDevice.device)
            } catch {
                print("Error setting device to AVCaptureDeviceInput")
            }
            
            // Add input to capture session
            if let captureDeviceInput = avCaptureDeviceInput {
                rtcCamVidCapturer.captureSession.addInput(captureDeviceInput)
            }

            rtcCamVidCapturer.startCapture(
                with: captureDevice.device,
                format: captureDevice.format,
                fps: captureDevice.fps,
                completionHandler:
                {
                    (error: Error?) in
                    if let captureError = error {
                        print("Error RTCCameraVideoCapturer startCapture \(captureError)")
                    }
                    else {
                        print("RTCCameraVideoCapturer startCapture success")
                        let videoTrack = self.peerConnFactory.videoTrack(with: videoSource, trackId: Config.mediaTrackVideoLabel)
                        DispatchQueue.main.async {
                            self.mediaTrackDelegate?.onVideoTrackCreated(videoTrack, videoSource, rtcCamVidCapturer.captureSession)
                        }
                    }
                })
        }
    }
    
    // MARK: - Camera to use
    func getCaptureDevice(position: AVCaptureDevice.Position) -> (device: AVCaptureDevice, format: AVCaptureDevice.Format, fps: Int)? {
        for avCaptureDevice in RTCCameraVideoCapturer.captureDevices() {
            if avCaptureDevice.position == position {
                let supportedActiveFormat = avCaptureDevice.activeFormat
                let maxFrameRate = supportedActiveFormat.videoSupportedFrameRateRanges[0].maxFrameRate
                let minFrameRate = supportedActiveFormat.videoSupportedFrameRateRanges[0].minFrameRate
                let midFrameRate = minFrameRate + ((maxFrameRate - minFrameRate)/2)
                let fps = maxFrameRate
                
                print("getCaptureDevice uniqueId:\(avCaptureDevice.uniqueID), supportedActiveFormat:\(supportedActiveFormat), fps:\(fps), deviceType:\(avCaptureDevice.deviceType), isConnected:\(avCaptureDevice.isConnected), localizedName:\(avCaptureDevice.localizedName)")
                
                return (device: avCaptureDevice, format: supportedActiveFormat, fps: Int(fps))
            }
        }

        print("Error no capture device returned")
        return nil
    }
    
    // MARK: - RTCPeerConnectionDelegate
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        signalingStateDelegate?.onSignalingStateChange(stateChanged)
    }
    
    // Called when media is received on a new stream from remote peer.
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("PEERCONNECTION didAdd stream: \(stream)")
        remoteRtcMediaStream.append(stream)
        rendererDelegate?.onRemoteStreamReadyForRender(remoteVideoTracks: stream.videoTracks)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        var callState = CallState.checking
        
        switch newState {
        case .checking:
            callState = .checking
            break
        case .failed:
            callState = .failed
            break
        case .completed:
            callState = .completed
            break
        case .connected:
            callState = .connected
            break
        case .disconnected:
            callState = .disconnected
            break
        case .closed:
            callState = .closed
            break
        default:
            callState = .checking
            break
        }

        print("PEERCONNECTION RTCIceConnectionState newState: \(callState)")

        callStateDelegate?.onCallStateChange(callState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
    }

    // TODO Send to server to relay the newly gathered ICE candidate to other party
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        iceStateDelegate?.onIceStateCreated(candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
    }
}

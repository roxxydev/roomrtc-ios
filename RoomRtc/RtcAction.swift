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


fileprivate protocol MediaTrackDelegate {
    
    func onVideoTrackCreated(_ videoTrack: RTCVideoTrack?, _ videoSource: RTCVideoSource?, _ videoCaptureSession: AVCaptureSession?)
    
    func onAudioTrackCreated(_ audioTrack: RTCAudioTrack?, _ audioSource: RTCAudioSource?)
}


class RtcAction: MediaTrackDelegate, RendererDelegate {

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
    
    private var localVideoView: UIView?
    private var remoteVideoView: UIView?
    
    init() {
        self.rtcManager = RtcManager()
    }

    func initRtcAction(localVideoView: UIView,
                       remoteVideoView: UIView,
                       sdpCreateDelegate: SdpCreatedDelegate,
                       callStateDelegate: CallStateDelegate) {
        
        self.localVideoView = localVideoView
        self.remoteVideoView = remoteVideoView
        self.sdpCreateDelegate = sdpCreateDelegate
        self.callStateDelegate = callStateDelegate
        self.rtcManager.initDelegates(mediaTrackDelegate: self, callStateDelegate: callStateDelegate, rendererDelegate: self)
    }
    
    func setup() {
        peerConn = rtcManager.createPeerConnection()
        localStream = rtcManager.createLocalMediaStream(mediaStreamId: "id_local_media_stream")
    }

    // Initialize stream which will start local video capturer and audio listening
    func startLocalStream() {
        rtcManager.createLocalVideoTrack(position: .front)
        rtcManager.createAudioTrack()
    }
    
    /// Clean renderer which will remove existing renderer view from existingremote RTCMediaStream.
    func resetRemoteRenderer() {
        for stream in rtcManager.remoteRtcMediaStream {
            
            for remoteVideoTrack in stream.videoTracks {
                
                if let renderView = remoteVideoView?.subviews.last {
                    removeRenderer(videoTrack: remoteVideoTrack, renderView: renderView)
                    renderView.removeFromSuperview()
                }
            }
        }
    }
    
    fileprivate func setLocalDescription(sdp: RTCSessionDescription) {
        peerConn?.setLocalDescription(sdp, completionHandler: {
            error in
            if let err = error {
                print("Error setLocalDescription. \(err.localizedDescription)")
            }
        })
    }

    // MARK: - Caller start call

    func startCall() {
        sendOffer()
    }
    
    private func sendOffer() {
        peerConn?.offer(for: rtcManager.defaultPeerConnectionConstraints(), completionHandler:
            {
                (rtcSessionDesc, error) in
                guard error == nil, let sdpOffer = rtcSessionDesc?.sdp else {
                    print("Error creating sdp offer: \(error!.localizedDescription)")
                    return
                }
                print("sendOffer: \(sdpOffer)")
                self.setLocalDescription(sdp: rtcSessionDesc!)
                self.sdpCreateDelegate?.onSdpOfferCreated(sdpOffer: sdpOffer)
            }
        )
    }
    
    // MARK: - Called when someone is calling. Use by callee.
    
    func acceptIncomingCall(sdpOffer: String) {
        handleReceiveOffer(sdpOffer: sdpOffer)
    }
    
    private func handleReceiveOffer(sdpOffer: String) {
        let sdpOffer: RTCSessionDescription = RTCSessionDescription.init(type: .offer, sdp: sdpOffer)
        peerConn?.setRemoteDescription(sdpOffer, completionHandler: {
            err in
                print("Error setting remote offer description: \(err!.localizedDescription)")
                self.createAnswer()
        })
    }
    
    private func createAnswer() {
        peerConn?.answer(for: rtcManager.defaultPeerAnswerConstraints(), completionHandler:
            {
                (rtcSessionDesc, error) in
                guard error == nil, let sdpAnswer = rtcSessionDesc?.sdp else {
                    print("Error creating sdp answer: \(error!.localizedDescription)")
                    return
                }
                self.setLocalDescription(sdp: rtcSessionDesc!)
                self.sdpCreateDelegate?.onSdpAnswerCreated(sdpAnswer: sdpAnswer)
            }
        )
    }
    
    // MARK: - Called when sdp answer is received. Use by caller.
    func receiveCallAccepted(sdpAnswer: String) {
        let sdpAnswerReceived: RTCSessionDescription = RTCSessionDescription.init(type: .answer, sdp: sdpAnswer)
        peerConn?.setRemoteDescription(sdpAnswerReceived, completionHandler: {
            err in
            guard err == nil else {
                print("Error setting remote answer description: \(err!.localizedDescription)")
                return
            }
            self.sdpCreateDelegate?.onSdpAnswerSet()
        })
    }
    
    /// Called when caller or callee hangup or one of the party ends the ongoing call.
    func endCall() {
        peerConn?.close()
    }
    
    // MARK: - Manage renderer
    
    func removeRenderer(videoTrack: RTCVideoTrack?, renderView: UIView?) {
        if let vidTrack = videoTrack, let videoView = renderView as? RTCVideoRenderer {
            vidTrack.remove(videoView)
        }
    }
    
    // MARK: - MediaTrackDelegate
    
    fileprivate func onVideoTrackCreated(_ videoTrack: RTCVideoTrack?, _ videoSource: RTCVideoSource?, _ videoCaptureSession: AVCaptureSession?) {
        print("onVideoTrackCreated")

        if let currVidTrack = localStream?.videoTracks.last {
            localStream?.removeVideoTrack(currVidTrack)
        }
        
        currVideoTrack = videoTrack
        currVideoSource = videoSource
        currVideoCaptureSession = videoCaptureSession

        if let track = currVideoTrack {
            localStream?.addVideoTrack(track)
            
            if let stream = localStream {
                peerConn?.remove(stream)
                peerConn?.add(stream)
            }
            
            onLocalStreamReadyForRender()
        }
    }
    
    fileprivate func onAudioTrackCreated(_ audioTrack: RTCAudioTrack?, _ audioSource: RTCAudioSource?) {
        print("onAudioTrackCreated")
        currAudioTrack = audioTrack
        currAudioSource = currAudioTrack?.source
        
        if let track = audioTrack {
            localStream?.addAudioTrack(track)
            
            if let stream = localStream {
                peerConn?.remove(stream)
                peerConn?.add(stream)
            }
        }
    }
    
    // MARK: - RendererDelegate
    
    func onLocalStreamReadyForRender() {
        print("onLocalStreamReadyForRender")
        let frame = localVideoView!.frame
        let rtcVideoView = RTCCameraPreviewView.init(frame: CGRect(x: 0.0, y: 0.0, width: frame.width, height: frame.height))
        rtcVideoView.captureSession = currVideoCaptureSession
        localVideoView?.addSubview(rtcVideoView)
    }
    
    func onRemoteStreamReadyForRender(remoteVideoTracks: [RTCVideoTrack]) {
        print("onRemoteStreamReadyForRender")
        resetRemoteRenderer()
        let rtcVideoView: RTCEAGLVideoView = RTCEAGLVideoView(frame: remoteVideoView!.frame)
        remoteVideoView?.addSubview(rtcVideoView)
        remoteVideoTracks.last?.add(rtcVideoView)
    }
    
    // MARK: - Video controls
    
    func swapCameraToFront() {
        let currMediaStream = peerConn!.localStreams[0]
        currMediaStream.removeVideoTrack(currMediaStream.videoTracks[0])
        rtcManager.createLocalVideoTrack(position: .front)
    }
    
    func swapCameraToBack() {
        let currMediaStream = peerConn!.localStreams[0]
        currMediaStream.removeVideoTrack(currMediaStream.videoTracks[0])
        rtcManager.createLocalVideoTrack(position: .front)
    }
    
    func muteVideoIn() {
//        let currMediaStream = peerConn!.localStreams[0]
//        self.currVideoTrack = currMediaStream.videoTracks[0];
//        currMediaStream.removeVideoTrack(currMediaStream.videoTracks[0])
//        peerConn?.remove(currMediaStream)
//        peerConn?.add(currMediaStream)
        currVideoTrack?.isEnabled = false
        currVideoCaptureSession?.stopRunning()
    }
    
    func unmuteVideoIn() {
//        let currMediaStream = peerConn!.localStreams[0]
//        currMediaStream.addVideoTrack(self.currVideoTrack!)
//        peerConn?.remove(currMediaStream)
//        peerConn?.add(currMediaStream)
        currVideoTrack?.isEnabled = true
        currVideoCaptureSession?.startRunning()
    }
    
    // MARK: - Audio controls
    
    func enableSpeaker() {
    }
    
    func disableSpeaker() {
    }
    
    func muteAudioIn() {
        let currMediaStream = peerConn!.localStreams[0]
        self.currAudioTrack = currMediaStream.audioTracks[0];
        currMediaStream.removeAudioTrack(currMediaStream.audioTracks[0])
        peerConn?.remove(currMediaStream)
        peerConn?.add(currMediaStream)
    }
    
    func unmuteAudioIn() {
        let currMediaStream = peerConn!.localStreams[0]
        currMediaStream.addAudioTrack(self.currAudioTrack!)
        peerConn?.remove(currMediaStream)
        peerConn?.add(currMediaStream)
    }
}


fileprivate class RtcManager: NSObject, RTCPeerConnectionDelegate {
    
    let peerConnFactory: RTCPeerConnectionFactory = RTCPeerConnectionFactory.init()
    
    var mediaTrackDelegate: MediaTrackDelegate?
    var callStateDelegate: CallStateDelegate?
    var rendererDelegate: RendererDelegate?
    
    var remoteRtcMediaStream = [RTCMediaStream]()
    
    func initDelegates(mediaTrackDelegate: MediaTrackDelegate, callStateDelegate: CallStateDelegate, rendererDelegate: RendererDelegate) {
        self.mediaTrackDelegate = mediaTrackDelegate
        self.callStateDelegate = callStateDelegate
        self.rendererDelegate = rendererDelegate
    }
    
    // MARK: - Creation of PeerConnection object
    
    func defaultICEServer() -> RTCIceServer {
        let urlStrings = [Config.defaultSTUNServerUrl, Config.defaultTURNServerUrl]
        let iceServer = RTCIceServer(urlStrings: urlStrings, username: "", credential: "")
        return iceServer
    }
    
    func defaultPeerConnectionConstraints() -> RTCMediaConstraints {
        let optionalConstraints = ["DtlsSrtpKeyAgreement": "true"]
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: optionalConstraints)
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
    
    func defaultPeerAnswerConstraints() -> RTCMediaConstraints {
        return defaultPeerConnectionConstraints()
    }
    
    func defaultRtcConfiguration() -> RTCConfiguration {
        let rtcConfig = RTCConfiguration.init()
        return rtcConfig
    }
    
    func createPeerConnection() -> RTCPeerConnection {
        let peerConnection = peerConnFactory.peerConnection(with: defaultRtcConfiguration(), constraints: defaultPeerConnectionConstraints(), delegate: self)
        
        return peerConnection
    }
    
    // MARK: - Creation of local media stream
    
    func createLocalMediaStream(mediaStreamId: String) -> RTCMediaStream {
        let localStream: RTCMediaStream = peerConnFactory.mediaStream(withStreamId: "id_local_media_stream")
        return localStream
    }

    func createAudioTrack() {
        let audioSource = peerConnFactory.audioSource(with: defaultAudioRtcMediaConstraints())
        let localAudioTrack = peerConnFactory.audioTrack(with: audioSource, trackId: "id_local_audio_track")
        mediaTrackDelegate?.onAudioTrackCreated(localAudioTrack, audioSource)
    }
    
    func createLocalVideoTrack(position: AVCaptureDevice.Position) {
        print("createLocalVideoTrack")
        if let captureDevice = getCaptureDevice(position: .front) {
            let videoSource = peerConnFactory.videoSource()
            let rtcCamVidCapturer = RTCCameraVideoCapturer(delegate: videoSource)
            let videoTrack = peerConnFactory.videoTrack(with: videoSource, trackId: "id_local_video_track")
            mediaTrackDelegate?.onVideoTrackCreated(videoTrack, videoSource, rtcCamVidCapturer.captureSession)
            rtcCamVidCapturer.startCapture(with: captureDevice.device, format: captureDevice.format, fps: captureDevice.fps)
        }
        
//        let videoSource = peerConnFactory.avFoundationVideoSource(with: defaultCameraRtcMediaConstraints())
//        let localVideoTrack = peerConnFactory.videoTrack(with: videoSource, trackId: "id_local_video_track")
//        mediaTrackDelegate?.onVideoTrackCreated(localVideoTrack, videoSource, videoSource.captureSession)
    }
    
    // MARK: - Camera to use
    func getCaptureDevice(position: AVCaptureDevice.Position) -> (device: AVCaptureDevice, format: AVCaptureDevice.Format, fps: Int)? {
        /*
        var defaultVideoDevice: AVCaptureDevice?

        switch position {
        case .back:
            /*if #available(iOS 10.2, *), let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: AVMediaType.video, position: .back) {
                defaultVideoDevice = dualCameraDevice
            }
            else*/
            if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) {
                defaultVideoDevice = backCameraDevice
            }
            break
        case .front, .unspecified:
            if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .front) {
                defaultVideoDevice = frontCameraDevice
            }
            break
        }
         
        return defaultVideoDevice
        */
        
        for avCaptureDevice in RTCCameraVideoCapturer.captureDevices() {
            if avCaptureDevice.position == position {
                let supportedActiveFormat = avCaptureDevice.activeFormat
                let fps = supportedActiveFormat.videoSupportedFrameRateRanges[0].maxFrameRate
                return (device: avCaptureDevice, format: supportedActiveFormat, fps: Int(fps))
            }
        }
        
        return nil
    }
    
    // MARK: - RTCPeerConnectionDelegate
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        
    }
    
    // Called when media is received on a new stream from remote peer.
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
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
        case .failed:
            callState = .failed
        case .completed:
            callState = .completed
        case .connected:
            callState = .connected
        case .disconnected:
            callState = .disconnected
        case .closed:
            callState = .closed
        default:
            callState = .checking
        }

        callStateDelegate?.onCallStateChange(callState)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        
    }

    // TODO Send to server to relay the newly gathered ICE candidate to other party
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {

    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        
    }
}

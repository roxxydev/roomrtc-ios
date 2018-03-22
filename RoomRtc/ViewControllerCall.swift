import Foundation
import ReSwift
import WebRTC

class ViewControllerCall: ViewControllerWebsocket, StoreSubscriber {
    
    typealias StoreSubscriberStateType = StateRoom
    
    @IBOutlet weak var uiLabelParticipants: UILabel!
    @IBOutlet weak var videoViewA: UIView!
    @IBOutlet weak var videoViewB: UIView!
    @IBOutlet weak var btnStartCall: UIButton!
    @IBOutlet weak var btnEndCall: UIButton!
    @IBOutlet weak var btnSwitchCamera: UIButton!
    @IBOutlet weak var btnDisableVideo: UIButton!
    @IBOutlet weak var btnMuteAudio: UIButton!
    @IBOutlet weak var btnAcceptCall: UIButton!
    @IBOutlet weak var btnRejectCall: UIButton!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!

    let roomNo = UserDefaults.standard.string(forKey: Constants.userDefaultsRoom)
    let username = UserDefaults.standard.string(forKey: Constants.userDefaultsUsername)
    let rtcAction = RtcAction()
    var rtcStatsTimer: Timer?
    
    var isCamFront  = true
    var isVideoEnabled = true
    var isAudioInMuted = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let wsSessionId = UserDefaults.standard.string(forKey: Constants.userDefaultsUsername)
        setUpWsConnection(wsSessionId)

        rtcAction.initRtcAction(localVideoView: videoViewA, remoteVideoView: videoViewB, sdpCreateDelegate: self, callStateDelegate: self, iceStateDelegate: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        mainStore.subscribe(self)
        {
            $0.select { state in state.stateRoom }
            .skipRepeats(
                {
                    oldStateRoom, newStateRoom in
                    if newStateRoom.roomStatus == .entered || newStateRoom.roomStatus == .leave {
                        return false
                    }
                    else if newStateRoom.roomStatus == oldStateRoom.roomStatus {
                        return true
                    }
                    return false
                }
            )
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        mainStore.unsubscribe(self)
    }

    override func websocketDidReceiveMessage(_ text: String) {
        super.websocketDidReceiveMessage(text)

        let decoder = JSONDecoder()
        
        if let modelChatAppMsg = try? decoder.decode(ModelChatAppMsg.self, from: text.data(using: .utf8)!) {

            let sdpOffer: String? = modelChatAppMsg.sdpOffer
            let sdpAnswer: String? = modelChatAppMsg.sdpAnswer
            let participants: [String]? = modelChatAppMsg.participants
            let ice: ModelIceCandidate? = modelChatAppMsg.ice

            if let roomEvent = modelChatAppMsg.roomEvent {
                print("websocketDidReceiveMessage called")
                switch roomEvent {
                case .entered:
                    print("dispatch entered")
                    mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .entered, sdpOffer: nil, sdpAnswer: nil, participants: participants))
                    break
                case .leave:
                    print("dispatch leave")
                    mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .leave, sdpOffer: nil, sdpAnswer: nil, participants: participants))
                    break
                case .calling:
                    mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .incomingCall, sdpOffer: sdpOffer, sdpAnswer: sdpAnswer, participants: participants))
                    break
                case .rejected:
                    mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .receiveRejected, sdpOffer: nil, sdpAnswer: nil, participants: participants))
                    break
                case .accepted:
                    mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .receiveAccepted, sdpOffer: sdpOffer, sdpAnswer: sdpAnswer, participants: participants))
                    break
                case .hangup:
                    mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .ended, sdpOffer: nil, sdpAnswer: nil, participants: participants))
                    break
                case .iceCandidate:
                    mainStore.dispatch(ActionRoomIceUpdate(roomStatus: .iceUpdate, ice: ice))
                    break
                }
            }
        }
    }
    
    @IBAction func onBtnSwitchCameraClicked(_ sender: Any) {
        if isCamFront {
            rtcAction.swapCamera(isFront: false)
        }
        else {
            rtcAction.swapCamera(isFront: true)
        }
        isCamFront = !isCamFront
    }

    @IBAction func onBtnDisableVideoClicked(_ sender: Any) {
        if isVideoEnabled {
            rtcAction.muteVideoIn()
            btnDisableVideo.setTitle(Constants.btnLabelEnableVideo, for: UIControlState.normal)
        }
        else {
            rtcAction.unmuteVideoIn()
            btnDisableVideo.setTitle(Constants.btnLabelDisableVideo, for: UIControlState.normal)
        }
        isVideoEnabled = !isVideoEnabled
    }
    
    @IBAction func onBtnMuteAudioClicked(_ sender: Any) {
        if isAudioInMuted {
            rtcAction.unmuteAudioIn()
            btnMuteAudio.setTitle(Constants.btnLabelMuteAudio, for: UIControlState.normal)
        }
        else {
            rtcAction.muteAudioIn()
            btnMuteAudio.setTitle(Constants.btnLabelUnmuteAudio, for: UIControlState.normal)
        }
        isAudioInMuted = !isAudioInMuted
    }
    
    @IBAction func onBtnStartCallClicked(_ sender: Any) {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .userCalling, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
    
    @IBAction func onBtnEndCallClicked(_ sender: Any) {
        rtcAction.endCall()
    }
    
    @IBAction func onBtnAcceptCallClicked(_ sender: Any) {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .acceptCall, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
    
    @IBAction func onBtnRejectCallClicked(_ sender: Any) {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .rejectCall, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
    
    func newState(state: StateRoom) {
        let roomParticipants: [String]? = state.participants
        let roomStatus = state.roomStatus
        let sdpOffer = state.sdpOffer
        let sdpAnswer = state.sdpAnswer
        let iceCandidate = state.ice
        
        print("roomStatus \(roomStatus)")

        switch roomStatus {
        case .standby:
            handleStateStandby()
            break
        case .userCalling:
            handleStateCalling()
            break
        case .incomingCall:
            handleStateIncoming()
            break
        case .acceptCall:
            guard let offer = sdpOffer else {
                print("Error accepting call, newState sdp offer empty")
                handleStateInitializationFailed()
                return
            }
            handleStateAcceptCall(offer)
            break
        case .receiveAccepted:
            guard let answer = sdpAnswer else {
                print("Error receiving accepted call, newState sdp answer empty")
                handleStateInitializationFailed()
                return
            }
            handleStateReceiveAccepted(answer)
            break
        case .rejectCall:
            handleStateRejectCall()
            break
        case .receiveRejected:
            handleStateReceiveRejected()
            break
        case .initializing:
            handleStateInitializing()
            break
        case .initializationFailed:
            handleStateInitializationFailed()
            break
        case .ongoingConnected:
            handleStateOnGoingConnected()
            break
        case .ongoingDisconnected:
            handleStateOnGoingDisconnected()
            break
        case .hangup, .ended:
            handleStateEnded()
            break
        case .entered, .leave:
            let totalParticipants: Int = roomParticipants != nil ? roomParticipants!.count : 0
            self.uiLabelParticipants.text? = Constants.txtlabelParticipants + String(totalParticipants)
            break
        case .iceUpdate:
            guard let ice = iceCandidate else {
                print("Error, received nil ICE candidate")
                return
            }
            rtcAction.addIceCandidate(RTCIceCandidate(sdp: ice.candidate!, sdpMLineIndex: ice.sdpMLineIndex!, sdpMid: ice.sdpMid!))
        case .sdpReset:
            handleStateStandby()
            break
        }
    }
    
    func handleStateStandby() {
        self.btnStartCall.isHidden = false
        self.btnEndCall.isHidden = true
        self.btnAcceptCall.isHidden = true
        self.btnRejectCall.isHidden = true
        self.indicatorView.stopAnimating()
        self.indicatorView.isHidden = true
        rtcAction.resetRemoteRenderer()
        rtcAction.setup()
        rtcStatsTimer?.invalidate()
    }
    
    func handleStateCalling() {
        print("handleStateCalling")
        self.btnStartCall.isHidden = true
        self.btnEndCall.isHidden = false
        self.btnAcceptCall.isHidden = true
        self.btnRejectCall.isHidden = true
        self.indicatorView.isHidden = true
        rtcAction.startCall()
    }
    
    func handleStateIncoming() {
        self.btnStartCall.isHidden = true
        self.btnEndCall.isHidden = true
        self.btnAcceptCall.isHidden = false
        self.btnRejectCall.isHidden = false
        self.indicatorView.isHidden = true
    }
    
    func handleStateRejectCall() {
        let modelChatAppMsg = ModelChatAppMsg(room: roomNo, roomEvent: nil, username: username, participants: nil, sdpOffer: nil, sdpAnswer: nil, ice: nil)
        ApiRoom.doApiCall(apiService: .rejectCall, modelChatAppMsg: modelChatAppMsg)
        {
            apiError, response in
            if let error = apiError {
                print("Failed rejecting the call. \(error.description ?? "")")
                return
            }
            mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .sdpReset, sdpOffer: nil, sdpAnswer: nil, participants: nil))
        }
    }
    
    func handleStateReceiveRejected() {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .sdpReset, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
    
    func handleStateAcceptCall(_ offer: String) {
        DispatchQueue.main.async {
            self.btnStartCall.isHidden = true
            self.btnEndCall.isHidden = true
            self.btnAcceptCall.isHidden = true
            self.btnRejectCall.isHidden = true
            self.indicatorView.isHidden = false
            self.indicatorView.startAnimating()
        }
        rtcAction.acceptIncomingCall(sdpOffer: offer)
    }
    
    func handleStateReceiveAccepted(_ answer: String) {
        DispatchQueue.main.async {
            self.btnStartCall.isHidden = true
            self.btnEndCall.isHidden = true
            self.btnAcceptCall.isHidden = true
            self.btnRejectCall.isHidden = true
            self.indicatorView.isHidden = false
            self.indicatorView.startAnimating()
        }
        rtcAction.receiveCallAccepted(sdpAnswer: answer)
    }
    
    func handleStateInitializing() {
        DispatchQueue.main.async {
            self.btnStartCall.isHidden = true
            self.btnEndCall.isHidden = true
            self.btnAcceptCall.isHidden = true
            self.btnRejectCall.isHidden = true
            self.indicatorView.isHidden = false
            self.indicatorView.startAnimating()
        }
        
        rtcStatsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true, block: {
            timer in
            self.rtcAction.printRtcStatsReport()
        })
    }
    
    func handleStateInitializationFailed() {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .sdpReset, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
    
    func handleStateOnGoingConnected() {
        DispatchQueue.main.async {
            self.btnStartCall.isHidden = true
            self.btnEndCall.isHidden = false
            self.btnAcceptCall.isHidden = true
            self.btnRejectCall.isHidden = true
            self.indicatorView.isHidden = true
        }
    }
    
    func handleStateOnGoingDisconnected() {
        DispatchQueue.main.async {
            self.btnStartCall.isHidden = true
            self.btnEndCall.isHidden = false
            self.btnAcceptCall.isHidden = true
            self.btnRejectCall.isHidden = true
            self.indicatorView.isHidden = false
            self.indicatorView.startAnimating()
        }
    }
    
    func handleStateEnded() {
        let modelChatAppMsg = ModelChatAppMsg(room: roomNo, roomEvent: nil, username: username, participants: nil, sdpOffer: nil, sdpAnswer: nil, ice: nil)
        ApiRoom.doApiCall(apiService: .endCall, modelChatAppMsg: modelChatAppMsg)
        {
            apiError, response in
            if let error = apiError {
                print("Failed ending the call. \(error.description ?? "")")
                return
            }
        }
        
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .sdpReset, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
}


extension ViewControllerCall: SdpCreatedDelegate, CallStateDelegate, IceStateDelegate {

    func onIceStateCreated(_ ice: RTCIceCandidate) {
        print("onIceStateCreated called, \ncandidate: \(ice.sdp)\nsdpMLineIndex: \(ice.sdpMLineIndex)\nsdpMid: \(String(describing: ice.sdpMid))")
        let iceCandidate = ModelIceCandidate(candidate: ice.sdp, sdpMLineIndex: ice.sdpMLineIndex, sdpMid: ice.sdpMid)
        
        let modelChatAppMsg = ModelChatAppMsg(room: roomNo, roomEvent: nil, username: username, participants: nil, sdpOffer: nil, sdpAnswer: nil, ice: iceCandidate)
        
        ApiRoom.doApiCall(apiService: .iceUpdate, modelChatAppMsg: modelChatAppMsg)
        {
            apiError, response in
            if let error = apiError {
                print("Failed sending ICE Candidate. \(error.description ?? "")")
            }
        }
    }
    
    
    // MARK - SdpCreateDelegate
    
    func onSdpOfferCreated(sdpOffer: String) {
        print("onSdpOfferCreated sdpOffer: \(sdpOffer)")
        let modelChatAppMsg = ModelChatAppMsg(room: roomNo, roomEvent: nil, username: username, participants: nil, sdpOffer: sdpOffer, sdpAnswer: nil, ice: nil)
        ApiRoom.doApiCall(apiService: .callRoom, modelChatAppMsg: modelChatAppMsg)
        {
            apiError, response in
            if let error = apiError {
                print("Failed sending sdp offer. \(error.description ?? "")")
                mainStore.dispatch(
                    ActionRoomStatusUpdate(roomStatus: .initializationFailed,
                                           sdpOffer: nil, sdpAnswer: nil,
                                           participants: nil))
            }
        }
    }
    
    func onSdpAnswerCreated(sdpAnswer: String) {
        let modelChatAppMsg = ModelChatAppMsg(room: roomNo, roomEvent: nil, username: username, participants: nil, sdpOffer: nil, sdpAnswer: sdpAnswer, ice: nil)
        ApiRoom.doApiCall(apiService: .answerCall, modelChatAppMsg: modelChatAppMsg)
        {
            apiError, response in
            if let error = apiError {
                print("Failed sending sdp answer. \(error.description ?? "")")
                mainStore.dispatch(
                    ActionRoomStatusUpdate(roomStatus: .initializationFailed,
                                           sdpOffer: nil, sdpAnswer: nil,
                                           participants: nil))
            }
        }
    }
    
    func onSdpAnswerSet() {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .initializing, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
    
    // MARK - CallStateDelegate
    
    func onCallStateChange(_ callState: CallState) {
        DispatchQueue.main.async {
            switch callState {
            case .checking:
                mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .initializing, sdpOffer: nil, sdpAnswer: nil, participants: nil))
                break
            case .failed:
                mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .initializationFailed, sdpOffer: nil, sdpAnswer: nil, participants: nil))
                break
            case .completed:
                mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .ongoingConnected, sdpOffer: nil, sdpAnswer: nil, participants: nil))
                break;
            case .connected:
                mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .ongoingConnected, sdpOffer: nil, sdpAnswer: nil, participants: nil))
                break;
            case .disconnected:
                mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .ongoingDisconnected, sdpOffer: nil, sdpAnswer: nil, participants: nil))
                break;
            case .closed:
                mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .ended, sdpOffer: nil, sdpAnswer: nil, participants: nil))
                break
            }
        }
    }
}

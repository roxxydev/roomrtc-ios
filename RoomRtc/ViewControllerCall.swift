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
    @IBOutlet weak var btnAcceptCall: UIButton!
    @IBOutlet weak var btnRejectCall: UIButton!
    @IBOutlet weak var indicatorView: UIActivityIndicatorView!

    let rtcAction = RtcAction()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let wsSessionId = UserDefaults.standard.string(forKey: "username")
        setUpWsConnection(wsSessionId)

        rtcAction.initRtcAction(localVideoView: videoViewA, remoteVideoView: videoViewB, sdpCreateDelegate: self, callStateDelegate: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        mainStore.subscribe(self) {
            $0.select { state in state.stateRoom }
                .skipRepeats()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        mainStore.unsubscribe(self)
    }

    override func websocketDidReceiveMessage(_ text: String) {
        super.websocketDidReceiveMessage(text)

        if let msg = try? JSONSerialization.jsonObject(with: text.data(using: .utf8)!) as? ModelChatAppMsg {

            let sdpOffer: String? = msg?.sdpOffer
            let sdpAnswer: String? = msg?.sdpAnswer
            let participants: [String]? = msg?.participants
            
            if let roomEvent = msg?.roomEvent {
                switch roomEvent {
                case .entered:
                    mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .entered, sdpOffer: nil, sdpAnswer: nil, participants: participants))
                    break
                case .leave:
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
                }
            }
        }
    }
    
    @IBAction func onBtnStartCallClicked(_ sender: Any) {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .userCalling, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
    
    @IBAction func onBtnEndCallClicked(_ sender: Any) {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .hangup, sdpOffer: nil, sdpAnswer: nil, participants: nil))
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
        
        print("stateRoom.roomStatus: \(roomStatus)")

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
            uiLabelParticipants.text? = Constants.txtlabelParticipants + String(totalParticipants)
            break
        case .sdpReset:
            handleStateStandby()
            break
        }
    }
    
    func handleStateStandby() {
        btnStartCall.isHidden = false
        btnEndCall.isHidden = true
        btnAcceptCall.isHidden = true
        btnRejectCall.isHidden = true
        indicatorView.stopAnimating()
        indicatorView.isHidden = true
        rtcAction.resetRemoteRenderer()
        rtcAction.setup()
        rtcAction.startLocalStream()
    }
    
    func handleStateCalling() {
        btnStartCall.isHidden = true
        btnEndCall.isHidden = false
        btnAcceptCall.isHidden = true
        btnRejectCall.isHidden = true
        indicatorView.isHidden = true
        rtcAction.startCall()
    }
    
    func handleStateIncoming() {
        btnStartCall.isHidden = true
        btnEndCall.isHidden = true
        btnAcceptCall.isHidden = false
        btnRejectCall.isHidden = false
        indicatorView.isHidden = true
    }
    
    func handleStateRejectCall() {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .sdpReset, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
    
    func handleStateReceiveRejected() {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .sdpReset, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
    
    func handleStateAcceptCall(_ offer: String) {
        btnStartCall.isHidden = true
        btnEndCall.isHidden = true
        btnAcceptCall.isHidden = true
        btnRejectCall.isHidden = true
        indicatorView.isHidden = false
        indicatorView.startAnimating()
        rtcAction.acceptIncomingCall(sdpOffer: offer)
    }
    
    func handleStateReceiveAccepted(_ answer: String) {
        btnStartCall.isHidden = true
        btnEndCall.isHidden = true
        btnAcceptCall.isHidden = true
        btnRejectCall.isHidden = true
        indicatorView.isHidden = false
        indicatorView.startAnimating()
        rtcAction.receiveCallAccepted(sdpAnswer: answer)
    }
    
    func handleStateInitializing() {
        btnStartCall.isHidden = true
        btnEndCall.isHidden = true
        btnAcceptCall.isHidden = true
        btnRejectCall.isHidden = true
        indicatorView.isHidden = false
        indicatorView.startAnimating()
    }
    
    func handleStateInitializationFailed() {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .sdpReset, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
    
    func handleStateOnGoingConnected() {
        btnStartCall.isHidden = true
        btnEndCall.isHidden = true
        btnAcceptCall.isHidden = true
        btnRejectCall.isHidden = true
        indicatorView.isHidden = true
    }
    
    func handleStateOnGoingDisconnected() {
        btnStartCall.isHidden = true
        btnEndCall.isHidden = true
        btnAcceptCall.isHidden = true
        btnRejectCall.isHidden = true
        indicatorView.isHidden = false
        indicatorView.startAnimating()
    }
    
    func handleStateEnded() {
        rtcAction.endCall()
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .sdpReset, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
}


extension ViewControllerCall: SdpCreatedDelegate, CallStateDelegate {
    
    // MARK - SdpCreateDelegate
    
    func onSdpOfferCreated(sdpOffer: String) {
        // TODO Send sdp_offer to server
    }
    
    func onSdpAnswerCreated(sdpAnswer: String) {
        // TODO Send sdp_answer to server
    }
    
    func onSdpAnswerSet() {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .initializing, sdpOffer: nil, sdpAnswer: nil, participants: nil))
    }
    
    // MARK - CallStateDelegate
    
    func onCallStateChange(_ callState: CallState) {
        switch callState {
        case .checking:
            mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .initializing, sdpOffer: nil, sdpAnswer: nil, participants: nil))
            break
        case .failed:
            mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .initializationFailed, sdpOffer: nil, sdpAnswer: nil, participants: nil))
            break
        case .completed:
            mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .initializing, sdpOffer: nil, sdpAnswer: nil, participants: nil))
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

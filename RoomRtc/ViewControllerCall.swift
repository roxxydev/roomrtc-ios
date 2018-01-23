import Foundation
import ReSwift
import WebRTC

class ViewControllerCall: ViewControllerWebsocket, StoreSubscriber {
    
    typealias StoreSubscriberStateType = AppState
    
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
        rtcAction.initRtcAction(localVideoView: videoViewA, remoteVideoView: videoViewB, sdpCreateDelegate: self, callStateDelegate: self)
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .standby))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        mainStore.subscribe(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        mainStore.unsubscribe(self)
    }

    override func websocketDidReceiveMessage(_ text: String) {
        if let msg = try? JSONSerialization.jsonObject(with: text.data(using: .utf8)!) as? ModelChatAppMsg {

            if let sdpOffer = msg?.sdpOffer {
                mainStore.dispatch(ActionSdpUpdate(sdpOffer: sdpOffer, sdpAnswer: nil))
            }
            
            if let sdpAnswer = msg?.sdpAnswer {
                mainStore.dispatch(ActionSdpUpdate(sdpOffer: nil, sdpAnswer: sdpAnswer))
            }

            if let roomEvent = msg?.roomEvent {
                switch roomEvent {
                case .entered:
                    mainStore.dispatch(ActionUpdateRoomParticipants(someoneJoined: true, someoneLeave: false))
                    break
                case .leave:
                    mainStore.dispatch(ActionUpdateRoomParticipants(someoneJoined: false, someoneLeave: true))
                    break;
                case .calling:
                    mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .incoming))
                    break;
                case .rejected:
                    mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .receiveRejected))
                    break;
                case .accepted:
                    mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .receiveAccepted))
                    break;
                case .hangup:
                    mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .ended))
                    break;
                }
            }
        }
    }
    
    @IBAction func onBtnStartCallClicked(_ sender: Any) {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .calling))
    }
    
    @IBAction func onBtnEndCallClicked(_ sender: Any) {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .hangup))
    }
    
    @IBAction func onBtnAcceptCallClicked(_ sender: Any) {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .acceptCall))
    }
    
    @IBAction func onBtnRejectCallClicked(_ sender: Any) {
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .rejectCall))
    }
    
    func newState(state: AppState) {
        let _ = state.stateWsConnection
        let stateRoomParticipants = state.stateRoomParticipants
        let stateRoom = state.stateRoom
        let stateSdp = state.stateSdp
        
        // Update Room Participants UILabel
        uiLabelParticipants.text? = labelRoomParticipants + String(stateRoomParticipants)
        
        switch stateRoom.roomStatus {
        case .standby:
            handleStateStandby()
            break
        case .calling:
            handleStateCalling()
            break
        case .incoming:
            handleStateIncoming()
            break
        case .acceptCall:
            if let offer = stateSdp.sdpOffer {
                handleStateAcceptCall(offer)
            }
            break
        case .receiveAccepted:
            if let answer = stateSdp.sdpAnswer {
                handleStateReceiveAccepted(answer)
            }
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
        }
    }
    
    func handleStateStandby() {
        btnStartCall.isHidden = false
        btnEndCall.isHidden = true
        btnAcceptCall.isHidden = true
        btnRejectCall.isHidden = true
        indicatorView.isHidden = true
        rtcAction.resetRenderer()
        rtcAction.setup()
        rtcAction.startLocalStream()
    }
    
    func handleStateCalling() {
        btnStartCall.isHidden = true
        btnEndCall.isHidden = false
        btnAcceptCall.isHidden = true
        btnRejectCall.isHidden = true
        indicatorView.isHidden = false
        indicatorView.startAnimating()
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
        mainStore.dispatch(ActionSdpReset())
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .standby))
    }
    
    func handleStateReceiveRejected() {
        mainStore.dispatch(ActionSdpReset())
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .standby))
    }
    
    func handleStateAcceptCall(_ offer: String) {
        btnStartCall.isHidden = true
        btnEndCall.isHidden = true
        btnAcceptCall.isHidden = true
        btnRejectCall.isHidden = true
        indicatorView.isHidden = false
        indicatorView.startAnimating()
        rtcAction.acceptIncomingCall(sdpOffer: offer)
        mainStore.dispatch(ActionSdpReset())
    }
    
    func handleStateReceiveAccepted(_ answer: String) {
        btnStartCall.isHidden = true
        btnEndCall.isHidden = true
        btnAcceptCall.isHidden = true
        btnRejectCall.isHidden = true
        indicatorView.isHidden = false
        indicatorView.startAnimating()
        rtcAction.receiveCallAccepted(sdpAnswer: answer)
        mainStore.dispatch(ActionSdpReset())
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
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .standby))
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
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .standby))
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
        mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .initializing))
    }
    
    // MARK - CallStateDelegate
    
    func onCallStateChange(_ callState: CallState) {
        switch callState {
        case .checking:
            mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .initializing))
            break
        case .failed:
            mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .initializationFailed))
            break
        case .completed:
            mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .initializing))
            break;
        case .connected:
            mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .ongoingConnected))
            break;
        case .disconnected:
            mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .ongoingDisconnected))
            break;
        case .closed:
            mainStore.dispatch(ActionRoomStatusUpdate(roomStatus: .ended))
            break
        }
    }
}

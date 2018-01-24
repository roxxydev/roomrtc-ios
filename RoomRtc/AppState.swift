import Foundation
import ReSwift

struct AppState: StateType {
    var stateWsConnection: StateWsConnection
    var stateRoom: StateRoom
    var stateSdp: StateSdp
    var stateRoomParticipants: Int
}

/// Websocket connection state
struct StateWsConnection {
    var connected: Bool
}

/**
 RoomStatus are statuses of app state for room.
 * standby      - state in which app is rendering local video but no call yet
 * userCalling  - app user initiated the call in which call button is pressed
 * incomingCall - callee receive an incoming call. This is from websocket broadcast message.
 * acceptCall   - calle accepted the incoming call, typically this is the event callee
                press the accept call button
 * receiveAccepted - caller receive event that callee has accepted the call. This is from
                websocket broadcast message.
 * receiveRejected - caller receive event that callee has rejected the call. This is from
                websocket broadcast message.
 * initializing - state in which both party has set the sdp and in ICE gathering state
 * initializingFailed - state where ICE failed, or call failed.
 * ongoingConnected - state in which ICE is connected or completed, call has started and
                temporary disconnect has been resolved(See ICE state disconnected).
 * ongoingDisconnected - state in which is is disconnected.
 * hangup       - state in which either caller or callee hangup the current ongoing call.
                Typically pressing end call button. This can be caller intiated action pressing
                hangup call button or a websocket broadcast message which the other party
                hangup the call already.
 * ended        - state in which the call ended, ICE state is closed. Return to standby state.
 */
enum RoomStatus {
    case standby,
    userCalling, incomingCall,
    rejectCall, receiveRejected,
    acceptCall, receiveAccepted,
    initializing,
    initializationFailed,
    ongoingConnected, ongoingDisconnected,
    hangup, ended
}

/// Describe state of the call.
struct StateRoom {
    var roomStatus: RoomStatus
}

/// State in which sdp are created for use.
struct StateSdp {
    var sdpOffer: String?
    var sdpAnswer: String?
}

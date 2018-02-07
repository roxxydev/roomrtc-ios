import Foundation
import ReSwift

struct AppState: StateType {
    var stateWsConnection: StateWsConnection
    var stateRoom: StateRoom
}

/// Websocket connection state
struct StateWsConnection: StateType {
    var connected: Bool
}

/**
 RoomStatus are statuses of app state for room.
 * standby      - State in which app is rendering local video but no call yet
 * userCalling  - App user initiated the call in which call button is pressed
 * incomingCall - Callee receive an incoming call. This is from websocket broadcast message.
 * acceptCall   - Callee accepted the incoming call, typically this is the event callee
                press the accept call button
 * receiveAccepted - Caller receive event that callee has accepted the call. This is from
                websocket broadcast message.
 * receiveRejected - Caller receive event that callee has rejected the call. This is from
                websocket broadcast message.
 * initializing - State in which both party has set the sdp and in ICE gathering state
 * initializingFailed - state where ICE failed, or call failed.
 * ongoingConnected - State in which ICE is connected or completed, call has started and
                temporary disconnect has been resolved(See ICE state disconnected).
 * ongoingDisconnected - State in which is is disconnected.
 * hangup       - State in which either caller or callee hangup the current ongoing call.
                Typically pressing end call button. This can be caller intiated action pressing
                hangup call button or a websocket broadcast message which the other party
                hangup the call already.
 * ended        - State in which the call ended, ICE state is closed. Return to standby state.
 * entered, leave - State in which no. of participants in room changed.
 * sdpReset     - State in which sdp offer and answer are reset from app state.
 */
enum RoomStatus {
    case standby,
    userCalling, incomingCall,
    rejectCall, receiveRejected,
    acceptCall, receiveAccepted,
    initializing,
    initializationFailed,
    ongoingConnected, ongoingDisconnected,
    hangup, ended,
    entered, leave,
    sdpReset
}

/// Describe state of the call.
struct StateRoom: StateType {
    var roomStatus: RoomStatus
    var sdpOffer: String?
    var sdpAnswer: String?
    var participants: [String]?
}

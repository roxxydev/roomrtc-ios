import Foundation
import ReSwift

func appReducer(action: Action, state: AppState?) -> AppState {
    return AppState(
        stateWsConnection: reducerWsConnection(state: state?.stateWsConnection, action: action),
        stateRoom: reducerStateRoom(state: state?.stateRoom, action: action)
    )
}

private func initialWsConnectionState() -> StateWsConnection {
    return StateWsConnection(connected: false)
}

private func initialRoomState() -> StateRoom {
    return StateRoom(roomStatus: .standby, sdpOffer: nil, sdpAnswer: nil, participants: [String](), ice: nil)
}

private func reducerWsConnection(state: StateWsConnection?, action: Action) -> StateWsConnection {
    var state = state ?? initialWsConnectionState()
    
    // ReSwiftInit is the initial Action that is dispatched as soon as the store is created. Reducers respond to this action by configuring their initial state.
    switch action {
    case _ as ReSwiftInit:
        break
    case let action as ActionWsConnUpdate:
        state.connected = action.isConnected
        break
    default:
        break
    }
    
    return state
}

private func reducerStateRoom(state: StateRoom?, action: Action) -> StateRoom {
    var state = state ?? initialRoomState()
    
    switch action {
    case _ as ReSwiftInit:
        break
    case let action as ActionRoomStatusUpdate:

        state.roomStatus = action.roomStatus
        if state.roomStatus == .entered || state.roomStatus == .leave {
            state.participants = action.participants
        }
        else if state.roomStatus == .sdpReset {
            state.sdpOffer = nil
            state.sdpAnswer = nil
        }
        else if state.roomStatus == .incomingCall {
            state.sdpOffer = action.sdpOffer
        }
        else if state.roomStatus == .receiveAccepted {
            state.sdpAnswer = action.sdpAnswer
        }
        
        break
    case let action as ActionRoomIceUpdate:
        state.roomStatus = action.roomStatus
        state.ice = action.ice
        break
    default:
        break
    }
    
    return state
}

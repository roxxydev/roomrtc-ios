import Foundation
import ReSwift

func appReducer(action: Action, state: AppState?) -> AppState {
    return AppState(
        stateWsConnection: wsconnectionReducer(state: state?.stateWsConnection, action: action),
        stateRoom: stateRoomReducer(state: state?.stateRoom, action: action),
        stateSdp: stateSdpReducer(state: state?.stateSdp, action: action),
        stateRoomParticipants: stateParticipantsReducer(state: state?.stateRoomParticipants, action: action)
    )
}

private func initialWsConnectionState() -> StateWsConnection {
    return StateWsConnection(connected: false)
}

private func initialRoomState() -> StateRoom {
    return StateRoom(roomStatus: .standby)
}

private func wsconnectionReducer(state: StateWsConnection?, action: Action) -> StateWsConnection {
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

private func stateRoomReducer(state: StateRoom?, action: Action) -> StateRoom {
    var state = state ?? initialRoomState()
    
    switch action {
    case _ as ReSwiftInit:
        break
    case let action as ActionRoomStatusUpdate:
        state.roomStatus = action.roomStatus
        break
    default:
        break
    }
    
    return state
}

private func stateSdpReducer(state: StateSdp?, action: Action) -> StateSdp {
    var newState = state ?? StateSdp(sdpOffer: nil, sdpAnswer: nil)
    
    switch action {
    case _ as ReSwiftInit:
        break
    case let sdpOfferAction as ActionSdpUpdate:
        if let offer = sdpOfferAction.sdpOffer {
            newState.sdpOffer? = offer
        }
        else if let answer = sdpOfferAction.sdpAnswer {
            newState.sdpAnswer? = answer
        }
        break
    case is ActionSdpReset:
        newState.sdpOffer = nil
        newState.sdpAnswer = nil
        break
    default:
        break
    }
    
    return newState
}

private func stateParticipantsReducer(state: Int?, action: Action) -> Int {
    var newState = state ?? 0
    
    switch action {
    case _ as ReSwiftInit:
        break
    case let action as ActionUpdateRoomParticipants:
        if action.someoneJoined {
            newState += 1
        }
        else if newState > 0 {
            newState -= 1
        }
        break
    default:
        break
    }
    
    return newState
}

import Foundation
import ReSwift

struct ActionWsConnUpdate: Action {
    var isConnected: Bool
}

struct ActionRoomStatusUpdate: Action {
    var roomStatus: RoomStatus
}

struct ActionSdpUpdate: Action {
    var sdpOffer: String?
    var sdpAnswer: String?
}

struct ActionSdpReset: Action {
}

struct ActionUpdateRoomParticipants: Action {
    var someoneJoined: Bool
    var someoneLeave: Bool
}


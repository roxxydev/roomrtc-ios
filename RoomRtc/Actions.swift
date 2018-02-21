import Foundation
import ReSwift

struct ActionWsConnUpdate: Action {
    var isConnected: Bool
}

struct ActionRoomStatusUpdate: Action {
    var roomStatus: RoomStatus = .standby
    var sdpOffer: String?
    var sdpAnswer: String?
    var participants: [String]?
}

struct ActionRoomIceUpdate: Action {
    var roomStatus: RoomStatus = .iceUpdate
    var ice: ModelIceCandidate?
}

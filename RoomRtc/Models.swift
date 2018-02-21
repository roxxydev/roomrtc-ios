import Foundation

struct ModelChatAppMsg: Codable {

    /// These are the room event message broadcasted from websocket
    enum RoomEvent: String, Codable {
        case entered, leave, calling, rejected, accepted, hangup, iceCandidate
    }
    
    var room: String?
    var roomEvent: RoomEvent?
    var username: String?
    var participants: [String]?
    var sdpOffer: String?
    var sdpAnswer: String?
    var ice: ModelIceCandidate?
}

struct ModelIceCandidate: Codable {
    
    var candidate: String?
    var sdpMLineIndex: Int32?
    var sdpMid: String?
}

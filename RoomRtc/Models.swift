import Foundation

struct ModelChatAppMsg: Codable {

    /// These are the room event message broadcasted from websocket
    enum RoomEvent: String, Codable {
        case entered, leave, calling, rejected, accepted, hangup
    }
    
    var room: String?
    var roomEvent: RoomEvent?
    var username: String?
    var participants: [String]?
    var sdpOffer: String?
    var sdpAnswer: String?
}

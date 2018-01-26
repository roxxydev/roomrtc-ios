import Foundation

struct ModelChatAppMsg {

    /// These are the room event message broadcasted from websocket
    enum RoomEvent {
        case entered, leave, calling, rejected, accepted, hangup
    }
    
    var roomEvent: RoomEvent?
    var sdpOffer: String?
    var sdpAnswer: String?
    var participants: [String]?
    
    init() {}
    
    init(json: [String: Any]) {
        self.roomEvent = json["roomEvent"] as? RoomEvent
        self.sdpOffer = json["sdpOffer"] as? String
        self.sdpAnswer = json["sdpAnswer"] as? String
        self.participants = json["participants"] as? [String]
    }
}

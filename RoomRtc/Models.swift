import Foundation

struct ModelChatAppMsg {

    enum RoomEvent {
        case entered, leave, calling, rejected, accepted, hangup
    }
    
    var roomEvent: RoomEvent?
    var sdpOffer: String?
    var sdpAnswer: String?
    
    init() {}
    
    init(json: [String: Any]) {
        self.roomEvent = json["roomEvent"] as? RoomEvent
        self.sdpOffer = json["sdpOffer"] as? String
        self.sdpAnswer = json["sdpAnswer"] as? String
    }
    
    mutating func setValues(roomEvent: RoomEvent?, sdpOffer: String?, sdpAnswer: String?) {
        self.roomEvent = roomEvent
        self.sdpOffer = sdpOffer
        self.sdpAnswer = sdpAnswer
    }
    
    mutating func setValues(modelChatAppMsg: ModelChatAppMsg) {
        let _roomEvent = modelChatAppMsg.roomEvent
        let _sdpOffer = modelChatAppMsg.sdpOffer
        let _sdpAnswer = modelChatAppMsg.sdpAnswer
        setValues(roomEvent: _roomEvent, sdpOffer: _sdpOffer, sdpAnswer: _sdpAnswer)
    }
}

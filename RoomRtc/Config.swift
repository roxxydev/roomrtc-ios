import Foundation

struct Config {
    static let host                         = "192.168.254.114"
    static let websocketServer              = "ws://\(host):8088/"
    static let websocketSessionHeaderName   = "session_id"
    static let websocketProtocol            = "chat"
    static let defaultSTUNServerUrl         = "stun:stun.l.google.com:19302"
    static let defaultSTUNServerUrlB        = "stun:stun.sipgate.net"
    static let defaultSTUNServerUrlC        = "stun:stun1.voiceeclipse.net"
    static let defaultTURNServerUrl         = ""
    
    static let mediaTrackLabel          = "RTCmS"
    static let mediaTrackVideoLabel     = "RTCvS0"
    static let mediaTrackAudioLabel     = "RTCaS0"
    
    static let vidResMinWidth   = 400
    static let vidResMaxWidth   = 600
    static let vidResMinHeight  = 300
    static let vidResMaxHeight  = 500
    
    static let serverUrl        = "http://\(host):8088"
    static let pathRoomEnter    = "/room/enter"
    static let pathRoomLeave    = "/room/enter"
    static let pathCallRoom     = "/call"
    static let pathCallAnswer   = "/call/answer"
    static let pathCallReject   = "/call/reject"
    static let pathCallEnd      = "/call/end"
    static let pathIceUpdate      = "/iceCandidate"
}

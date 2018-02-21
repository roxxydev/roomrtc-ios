import Foundation

struct Config {
    static let websocketServer              = "ws://192.168.254.104:8088/"
    static let websocketSessionHeaderName   = "session-id"
    static let websocketProtocol            = "chat"
    static let defaultSTUNServerUrl         = "stun.l.google.com:19302"
    static let defaultTURNServerUrl         = ""
    
    static let serverUrl        = "http://192.168.254.107:8088"
    static let pathRoomEnter    = "/room/enter"
    static let pathRoomLeave    = "/room/enter"
    static let pathCallRoom     = "/call"
    static let pathCallAnswer   = "/call/answer"
    static let pathCallReject   = "/call/reject"
    static let pathCallEnd      = "/call/end"
    static let pathIceUpdate      = "/iceCandidate"
}

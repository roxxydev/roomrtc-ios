import Foundation

struct Config {
    static let host                         = "192.168.254.103"
    static let websocketServer              = "ws://\(host):8088/"
    static let websocketSessionHeaderName   = "session_id"
    static let websocketProtocol            = "chat"
    static let defaultSTUNServerUrl         = "stun:stun.l.google.com:19302"
    static let defaultTURNServerUrl         = ""
    
    static let mediaTrackLabel          = "ios_local_media_stream"
    static let mediaTrackVideoLabel     = "ios_local_video_stream"
    static let mediaTrackAudioLabel     = "ios_local_audio_stream"
    
    static let serverUrl        = "http://\(host):8088"
    static let pathRoomEnter    = "/room/enter"
    static let pathRoomLeave    = "/room/enter"
    static let pathCallRoom     = "/call"
    static let pathCallAnswer   = "/call/answer"
    static let pathCallReject   = "/call/reject"
    static let pathCallEnd      = "/call/end"
    static let pathIceUpdate      = "/iceCandidate"
}

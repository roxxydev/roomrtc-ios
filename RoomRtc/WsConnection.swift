import Foundation
import Starscream

class WsConnection {
    
    private var socket: WebSocket?
    private var wsDelegate: WsDelegate?
    private var wsMsgDelegate: WsSocketMsgDelegate?
    
    func assignSocketDelegate(_ delegate: WsDelegate?) -> WsConnection {
        guard let socketDelegate = delegate else {
            print("Error trying to assign nil to socket delegate")
            return self
        }
        wsDelegate = socketDelegate
        socket?.delegate = wsDelegate
        return self
    }
    
    func assignSocketMsgDelegate(_ socketMsgDelegate: WsSocketMsgDelegate?) -> WsConnection {
        guard let socketDelegate = wsDelegate else {
            print("Error trying to assign message delegate to nil socket delegate")
            return self
        }
        wsMsgDelegate = socketMsgDelegate
        socketDelegate.socketMsgDelegate = wsMsgDelegate
        return self
    }
    
    func removeSocketDelegate() -> WsConnection {
        guard socket != nil else {
            print("Error trying to remove socket.delegate from nil socket")
            return self
        }
        socket?.delegate = nil
        return self
    }
    
    func connect(sessionId: String?) {
        var request = URLRequest(url: URL(string: Config.websocketServer)!)
        
        if let id = sessionId {
            request.setValue(id, forHTTPHeaderField: Config.websocketSessionHeaderName)
        }
        socket = WebSocket(request: request)
        
        // Reassign default socket delegate each connect
        let _ = assignSocketDelegate(wsDelegate)
                .assignSocketMsgDelegate(wsMsgDelegate)
        
        if let isConnected = socket?.isConnected, isConnected == false {
            socket?.connect()
        }
    }
    
    func disconnect() {
        guard socket != nil else {
            print("Error trying to disconnect nil socket")
            return
        }
        socket?.disconnect(forceTimeout: 0)
        socket = nil
    }
    
    func sendMsg(_ text: String) {
        guard socket != nil else {
            print("Error sending message, socket is nil")
            return
        }
        
        if let _ = socket?.isConnected {
            socket?.write(string: text)
        } else {
            print("Failed sending message, socket not connected")
        }
    }
}

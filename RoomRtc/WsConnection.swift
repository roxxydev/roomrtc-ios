import Foundation
import Starscream

class WsConnection {
    
    let socket: WebSocket? = WebSocket(url: URL(string: Config.websocketServer)!)
    
    func assignSocketDelegate(_ delegate: WsDelegate?) -> WsConnection {
        guard delegate != nil else {
            print("Error trying to assign nil to socket delegate")
            return self
        }
        socket?.delegate = delegate
        return self
    }
    
    func assignSocketMsgDelegate(_ socketMsgDelegate: WsSocketMsgDelegate?) -> WsConnection {
        guard socketMsgDelegate != nil else {
            print("Error trying to assign nil to socket delegate")
            return self
        }
        let delegate = socket?.delegate as? WsDelegate
        
        guard delegate != nil, let socketDelegate = delegate else {
            print("Error trying to assign message delegate to nil socket delegate")
            return self
        }
        socketDelegate.socketMsgDelegate = socketMsgDelegate

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
    
    func connect() {
        guard socket != nil else {
            print("Error socket not initialized yet")
            return
        }
        socket?.connect()
    }
    
    func disconnect() {
        guard socket != nil else {
            print("Error trying to disconnect nil socket")
            return
        }
        socket?.disconnect(forceTimeout: 0)
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

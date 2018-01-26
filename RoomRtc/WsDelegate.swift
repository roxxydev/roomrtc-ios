import Foundation
import Starscream

class WsDelegate: WebSocketDelegate {
    
    var socketMsgDelegate: WsSocketMsgDelegate?

    func websocketDidConnect(socket: WebSocketClient) {
        print("websocket connected")
        mainStore.dispatch(ActionWsConnUpdate(isConnected: true))
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("websocket disconnected")
        mainStore.dispatch(ActionWsConnUpdate(isConnected: false))
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        socketMsgDelegate?.websocketDidReceiveMessage(text)
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("websocket received data")
    }
}

protocol WsSocketMsgDelegate {

    func websocketDidReceiveMessage(_ text: String)
}

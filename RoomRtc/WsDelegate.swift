import Foundation
import Starscream

class WsDelegate: WebSocketDelegate {
    
    var socketMsgDelegate: WsSocketMsgDelegate?

    func websocketDidConnect(socket: WebSocketClient) {
        print("Websocket connected")
        mainStore.dispatch(ActionWsConnUpdate(isConnected: true))
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("Websocket disconnected")
        mainStore.dispatch(ActionWsConnUpdate(isConnected: false))
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        socketMsgDelegate?.websocketDidReceiveMessage(text)
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("Websocket receive data")
    }
}

protocol WsSocketMsgDelegate {

    func websocketDidReceiveMessage(_ text: String)
}

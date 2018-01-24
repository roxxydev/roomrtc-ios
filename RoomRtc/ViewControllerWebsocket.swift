import Foundation
import UIKit

class ViewControllerWebsocket: UIViewController, WsSocketMsgDelegate {
    
    private var wsConnection: WsConnection?

    final func setUpWsConnection (_ wsSessionId: String?) {
        guard
            let appDelegate = UIApplication.shared.delegate as? AppDelegate,
            let sessionId = wsSessionId
        else {
            print("Error mission websocket session id")
            return
        }

        wsConnection = appDelegate.wsConnection

        wsConnection?
            .assignSocketMsgDelegate(self)
            .connect(sessionId: sessionId)
    }
    
    func websocketDidReceiveMessage(_ text: String) {
        print("websocketDidReceiveMessage: \(text)")
    }
    
    func websocketSendMsg(_ text: String) {
        wsConnection?.sendMsg(text)
    }
}

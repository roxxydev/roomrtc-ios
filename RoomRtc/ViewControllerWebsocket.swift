import Foundation
import UIKit

class ViewControllerWebsocket: UIViewController, WsSocketMsgDelegate {
    
    var wsConnection: WsConnection?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
            return
        }
        
        wsConnection = appDelegate.wsConnection
        let _ = wsConnection?.assignSocketMsgDelegate(self)
    }
    
    func websocketDidReceiveMessage(_ text: String) {
    }
    
    func websocketSendMsg(_ text: String) {
        wsConnection?.sendMsg(text)
    }
}

import UIKit
import ReSwift

class ViewController: ViewControllerWebsocket, StoreSubscriber {

    typealias StoreSubscriberStateType = StateWsConnection
    
    @IBOutlet weak var txtFieldRoomNo: UITextField!
    
    @IBAction func btnSubmit(_ sender: Any) {
        if let roomNo = txtFieldRoomNo.text {
            UserDefaults.standard.set(roomNo, forKey: "id")

            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let vsCall = storyBoard.instantiateViewController(withIdentifier: "ViewControllerCall") as! ViewControllerCall
            self.present(vsCall, animated: true, completion: nil)
        }
    }
    
    func newState(state: StateWsConnection) {
        print("newState state.connected: \(state.connected)")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        mainStore.subscribe(self, transform: { subscription in

            let sub = subscription as Subscription
            
            return sub.select({ state in
                state.stateWsConnection
            })
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        mainStore.unsubscribe(self)
    }
}

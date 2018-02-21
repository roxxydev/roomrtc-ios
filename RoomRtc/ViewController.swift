import UIKit
import ReSwift

class ViewController: UIViewController {
    
    @IBOutlet weak var txtFieldUsername: UITextField!
    @IBOutlet weak var txtFieldRoomNo: UITextField!
    
    @IBAction func btnSubmit(_ sender: Any) {
        if let roomNo = txtFieldRoomNo.text, let username = txtFieldUsername.text {
            UserDefaults.standard.set(roomNo, forKey: Constants.userDefaultsRoom)
            UserDefaults.standard.set(username, forKey: Constants.userDefaultsUsername)

            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let vsCall = storyBoard.instantiateViewController(withIdentifier: "ViewControllerCall") as! ViewControllerCall
            
            let modelChatAppMsg = ModelChatAppMsg(room: roomNo, roomEvent: nil, username: username, participants: nil, sdpOffer: nil, sdpAnswer: nil, ice: nil)
            ApiRoom.doApiCall(apiService: .roomEnter, modelChatAppMsg: modelChatAppMsg)
            {
                apiError, response in

                if let error = apiError {
                    print("Failed sending sdp offer. \(error.description ?? "")")
                }
                else {
                    self.present(vsCall, animated: true, completion: nil)
                }
            }
        }
    }
}

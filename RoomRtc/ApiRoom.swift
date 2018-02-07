import Foundation
import Alamofire

struct ApiError: Error {
    
    enum ErrorKind {
        case api, json
    }

    let kind: ErrorKind
    let description: String?
}

struct ApiRoom {
    
    enum ApiService {
        case roomEnter,
        roomLeave,
        callRoom,
        answerCall,
        rejectCall,
        endCall
        
        func getHttpMethod() -> HTTPMethod {
            return HTTPMethod.post
        }
    }
    
    /// Get the endpoint for specific api service
    static func getEndpoint(_ apiService: ApiService) -> String {
        var path = Config.serverUrl
        switch apiService {
        case .roomEnter:
            path += Config.pathRoomEnter
            break
        case .roomLeave:
            path += Config.pathRoomLeave
            break
        case .callRoom:
            path += Config.pathCallRoom
            break
        case .answerCall:
            path += Config.pathCallAnswer
            break
        case .rejectCall:
            path += Config.pathCallReject
            break
        case .endCall:
            path += Config.pathCallEnd
            break
        }
        
        return path
    }

    static func doApiCall(apiService: ApiService, modelChatAppMsg: ModelChatAppMsg?, _ callback: @escaping (ApiError?, String?) -> Void) {
        let endpoint = ApiRoom.getEndpoint(apiService)
        let httpMethod = apiService.getHttpMethod()
        var parameters: [String:Any]? = nil
        
        if let _ = modelChatAppMsg, let jsonData = try? JSONEncoder().encode(modelChatAppMsg) {
            parameters =  try? JSONSerialization.jsonObject(with: jsonData, options: .mutableContainers) as! [String: Any]
        }
        else {
            callback(ApiError(kind: .json, description: nil), nil)
            return
        }

        Alamofire.request(endpoint, method: httpMethod, parameters: parameters, encoding: JSONEncoding.default, headers: nil)
            .responseJSON { response in
                
                guard response.result.error == nil else {
                    callback(ApiError(kind: .api, description: response.result.error?.localizedDescription), nil)
                    return
                }
                
                guard let _ = response.result.value as? [String: Any] else {
                    callback(ApiError(kind: .json, description: nil), nil)
                    return
                }
                
                callback(nil, response.result.value as? String)
        }
    }
}

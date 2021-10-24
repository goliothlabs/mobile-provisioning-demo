//
//  GoliothAPI.swift
//  nRF Connect Device Manager
//
//  Created by Alvaro Viebrantz on 10/23/21.
//  Copyright © 2021 Nordic Semiconductor ASA. All rights reserved.
//

import Foundation
import Alamofire

let PROJECT_ID = "YOUR_PROJECT_ID"
let API_KEY = "YOUR_API_KEY"
let baseURL = "https://api.golioth.io/v1/projects/" + PROJECT_ID
let headers: HTTPHeaders = [
    "X-API-Key": "" + API_KEY,
    "Accept": "application/json"
]

struct SingleResponse<Element: Decodable>: Decodable { let data: Element }
struct ListResponse<Element: Decodable>: Decodable { let list: Array<Element> }
struct GoliothDevice: Decodable {
    let id: String
    let name: String
}

struct GoliothCredential:Decodable {
    let id: String
    let identity: String
    var preSharedKey: String?
}

struct CreateDeviceParam: Encodable {
    let name: String
    let hardwareIds: Array<String>
}

struct CreateCredentialParam: Encodable {
    let type: String
    let identity: String
    let preSharedKey: String
}

class GoliothAPI {
    static func listDevices(completionHandler: @escaping (_ devices: Array<GoliothDevice>? )  -> Void) {
        let url = baseURL + "/devices"
        AF.request(url, headers: headers).responseDecodable(of: ListResponse<GoliothDevice>.self) { response in
            debugPrint(response)
            switch response.result {
            case .success:
                completionHandler(response.value?.list)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }

    static func findOrCreateDeviceByHardwareId(deviceName: String, hwId: String, completionHandler: @escaping (_ device: GoliothDevice? )  -> Void ) {
        let url = baseURL + "/devices?hardwareId="+hwId
        AF.request(url, headers: headers).responseDecodable(of: ListResponse<GoliothDevice>.self) { response in
            debugPrint(response)
            switch response.result {
            case .success:
                if response.value!.list.count > 0 {
                    completionHandler(response.value!.list[0])
                    return
                }
                createDevice(deviceName: deviceName, hwId: hwId, completionHandler: completionHandler)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    static func createDevice(deviceName: String, hwId: String, completionHandler: @escaping (_ device: GoliothDevice? ) -> Void ) {
        let param = CreateDeviceParam(name: deviceName, hardwareIds: [hwId])
        let url = baseURL + "/devices?hardwareId="+hwId
        AF.request(url, method: .post, parameters: param, encoder: JSONParameterEncoder.default, headers: headers).responseDecodable(of: SingleResponse<GoliothDevice>.self) { response in
            debugPrint(response)
            switch response.result {
            case .success:
                completionHandler(response.value!.data)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    static func createCredentialForDevice(deviceId: String, pskId: String, psk: String, completionHandler: @escaping (_ credential: GoliothCredential? ) -> Void ) {
        let param = CreateCredentialParam(type: "PRE_SHARED_KEY", identity: pskId, preSharedKey: psk)
        let url = baseURL + "/devices/"+deviceId+"/credentials"
        AF.request(url, method: .post, parameters: param, encoder: JSONParameterEncoder.default, headers: headers).responseDecodable(of: SingleResponse<GoliothCredential>.self) { response in
            debugPrint(response)
            switch response.result {
            case .success:
                completionHandler(response.value!.data)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    static func listDeviceCredentials(deviceId: String, completionHandler: @escaping (_ credentials: Array<GoliothCredential>?) -> Void) {
        let url = baseURL + "/devices/"+deviceId+"/credentials"
        AF.request(url, headers: headers).responseDecodable(of: ListResponse<GoliothCredential>.self) { response in
            debugPrint(response)
            switch response.result {
            case .success:
                completionHandler(response.value?.list)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    static func deleteAllDeviceCredentials(deviceId: String, completionHandler: @escaping () -> Void) {
        listDeviceCredentials(deviceId: deviceId) { credentials in
            let deleteGroup = DispatchGroup()
            for cred in credentials! {
                deleteGroup.enter()
                let url = baseURL + "/devices/"+deviceId+"/credentials/" + cred.id
                print("deleting +", url)
                AF.request(url, method: .delete, headers: headers).responseString { response in
                    debugPrint(response)
                    deleteGroup.leave()
                }
            }
            deleteGroup.notify(queue: .main) {
                completionHandler()
            }
        }
    }

    static func getDeviceLogs(deviceId: String, completionHandler: @escaping (_ devices: Array<GoliothDevice>? )  -> Void) {
        let url = baseURL + "/logs?deviceId="+deviceId
        AF.request(url, headers: headers).responseDecodable(of: ListResponse<GoliothDevice>.self) { response in
            debugPrint(response)
            switch response.result {
            case .success:
                completionHandler(response.value?.list)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
}

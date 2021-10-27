/*
 * Copyright (c) 2018 Nordic Semiconductor ASA.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import UIKit
import Slugify
import CoreBluetooth
import SwiftCBOR
import McuManager

class DeviceController: UITableViewController, UITextFieldDelegate, PeripheralDelegate {

    @IBOutlet weak var connectionStatus: ConnectionStateLabel!
    @IBOutlet weak var actionSend: UIButton!
        
    @IBOutlet weak var connectResponse: UILabel!
    @IBOutlet weak var connectResponseBackground: UIImageView!
    
    @IBOutlet weak var goliothResponse: UILabel!
    @IBOutlet weak var goliothResponseBackground: UIImageView!
    
    @IBOutlet weak var wifiSSID: UITextField!
    @IBOutlet weak var wifiSSIDReceived: UILabel!
    @IBOutlet weak var wifiSSIDReceivedBackground: UIImageView!
    
    @IBOutlet weak var wifiPSK: UITextField!
    @IBOutlet weak var wifiPSKReceived: UILabel!
    @IBOutlet weak var wifiPSKReceivedBackground: UIImageView!
    
    @IBOutlet weak var goliothPSKId: UITextField!
    @IBOutlet weak var goliothPSKIdReceived: UILabel!
    @IBOutlet weak var goliothPSKIdBackground: UIImageView!
    
    @IBOutlet weak var goliothPSK: UITextField!
    @IBOutlet weak var goliothPSKReceived: UILabel!
    @IBOutlet weak var goliothPSKBackground: UIImageView!
    
    private var currentPeripheral: CBPeripheral?
    private var currentGoliothDevice: GoliothDevice?
    private var currentHwId: String?
    
    @IBAction func findOrCreateTapped(_ sender: UIButton) {
        readDeviceInfo()
        if (self.currentHwId != nil && self.currentPeripheral != nil){
            let name = self.currentPeripheral!.name!
            let hwId = self.currentHwId!
            GoliothAPI.findOrCreateDeviceByHardwareId(deviceName: name, hwId: hwId) { device in
                if device != nil {
                    self.currentGoliothDevice = device
                    let deviceId = device!.id
                    self.goliothResponseBackground.isHidden = false
                    self.goliothResponse.isHidden = false                    
                    self.goliothResponse.text = "Found/Created golioth device with id " + deviceId
                    GoliothAPI.listDeviceCredentials(deviceId: deviceId) { credentials in
                        if credentials != nil && credentials!.count > 0 {
                            self.goliothResponse.text = "Found credentials for golioth device"
                            self.handleCredentialFound(credentials![0])
                        }
                    }
                }
            }
        }
    }
    
    @IBAction func recreateCredentialsTapped(_ sender: UIButton) {
        //sendEcho(message: "hello")
        if (self.currentGoliothDevice != nil && self.currentHwId != nil) {
            let deviceId = self.currentGoliothDevice!.id
            GoliothAPI.deleteAllDeviceCredentials(deviceId: deviceId) {
                let pskId = self.currentHwId! + self.randomAlphaNumericString(length: 8)
                let psk = self.randomAlphaNumericString(length: 8)
                GoliothAPI.createCredentialForDevice(deviceId: deviceId, pskId: pskId, psk: psk) { credential in
                    if credential != nil {
                        var cred = credential!
                        self.goliothResponseBackground.isHidden = false
                        self.goliothResponse.isHidden = false
                        self.goliothResponse.text = "Created device credentials " + cred.id
                        cred.preSharedKey = psk
                        self.handleCredentialFound(cred)
                    }
                }
            }
        }
    }
    
    func randomAlphaNumericString(length: Int) -> String {
        let allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let allowedCharsCount = UInt32(allowedChars.count)
        var randomString = ""

        for _ in 0 ..< length {
            let randomNum = Int(arc4random_uniform(allowedCharsCount))
            let randomIndex = allowedChars.index(allowedChars.startIndex, offsetBy: randomNum)
            let newCharacter = allowedChars[randomIndex]
            randomString += String(newCharacter)
        }

        return randomString
    }
    
    func handleCredentialFound(_ credential: GoliothCredential) {
        self.goliothPSKId.text = credential.identity
        self.goliothPSK.text = credential.preSharedKey
    }
    
    @IBAction func connectTapped(_ sender: UIButton) {
        readDeviceInfo()
    }
    
    @IBAction func sendWifiSsidTapped(_ sender: UIButton) {
        wifiSSID.resignFirstResponder()
        
        let text = wifiSSID.text!
        send(key: "wifi/ssid", message: text, received:wifiSSIDReceived, receivedBackground: wifiSSIDReceivedBackground)
    }
    
    @IBAction func sendWifiPskTapped(_ sender: UIButton) {
        wifiPSK.resignFirstResponder()
        
        let text = wifiPSK.text!
        send(key: "wifi/psk", message: text, received:wifiPSKReceived, receivedBackground: wifiPSKReceivedBackground)
    }
    
    @IBAction func sendPskIdTapped(_ sender: UIButton) {
        goliothPSKId.resignFirstResponder()
        
        let text = goliothPSKId.text!
        send(key: "golioth/psk-id", message: text, received:goliothPSKIdReceived, receivedBackground: goliothPSKIdBackground)
    }
    
    @IBAction func sendPskTapped(_ sender: UIButton) {
        goliothPSK.resignFirstResponder()
        
        let text = goliothPSK.text!
        send(key: "golioth/psk", message: text, received:goliothPSKReceived, receivedBackground: goliothPSKBackground)
    }
    
    private var defaultManager: DefaultManager!
    private var configManager: ConfigManager!
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let baseController = parent as! BaseViewController
        let transporter = baseController.transporter!
        
        var destination = segue.destination as? McuMgrViewController
        destination?.transporter = transporter
    }
    
    func peripheral(_ peripheral: CBPeripheral, didChangeStateTo state: PeripheralState) {
        switch state {
        case .connected:
            self.currentPeripheral = peripheral
        case .connecting:
            break;
        case .initializing:
            break;
        case .disconnected:
            break;
        case .disconnecting:
            break;
        }
        self.connectionStatus.peripheral(peripheral, didChangeStateTo: state)
    }
    
    override func viewDidLoad() {
        goliothPSK.delegate = self
        goliothPSKId.delegate = self
        wifiPSK.delegate = self
        wifiSSID.delegate = self
                
        let receivedBackground = #imageLiteral(resourceName: "bubble_received")
            .resizableImage(withCapInsets: UIEdgeInsets(top: 17, left: 21, bottom: 17, right: 21),
                            resizingMode: .stretch)
            .withRenderingMode(.alwaysTemplate)
        
        connectResponseBackground.image = receivedBackground
        wifiSSIDReceivedBackground.image = receivedBackground
        wifiPSKReceivedBackground.image = receivedBackground
        goliothPSKIdBackground.image = receivedBackground
        goliothPSKBackground.image = receivedBackground
        goliothResponseBackground.image = receivedBackground
        
        let baseController = parent as! BaseViewController
        let transporter = baseController.transporter!
        configManager = ConfigManager(transporter: transporter)
        configManager.logDelegate = UIApplication.shared.delegate as? McuMgrLogDelegate
        defaultManager = DefaultManager(transporter: transporter)
        defaultManager.logDelegate = UIApplication.shared.delegate as? McuMgrLogDelegate
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Set the connection status label as transport delegate.
        let bleTransporter = configManager.transporter as? McuMgrBleTransport
        bleTransporter?.delegate = connectionStatus        
        bleTransporter?.delegate = self
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case wifiSSID:
            sendWifiSsidTapped(actionSend)
        case wifiPSK:
            sendWifiPskTapped(actionSend)
        case goliothPSKId:
            sendPskIdTapped(actionSend)
        case goliothPSK:
            sendPskTapped(actionSend)
        default:
            return true
        }
        return true
    }
    
    private func readDeviceInfo() {
        self.connectResponse.isHidden = true
        self.connectResponseBackground.isHidden = true
                
        configManager.read(name: "hwinfo/devid") { response, error in
            if let response = response {
                if case let CBOR.byteString(val)? = response.payload?["val"] {
                    let val = String(bytes: val, encoding: String.Encoding.utf8)                    
                    self.connectResponse.text = "Device connected, replied with: " + ( val ?? "-" )
                    self.currentHwId = val
                    self.connectResponseBackground.tintColor = .zephyr
                }
            }
            if let error = error {
                self.connectResponse.text = "\(error.localizedDescription)"
                self.connectResponseBackground.tintColor = .systemRed
            }
            self.connectResponse.isHidden = false
            self.connectResponseBackground.isHidden = false
        }
    }
    
    private func send(key: String, message: String, received: UILabel, receivedBackground: UIImageView) {
        received.isHidden = true
        receivedBackground.isHidden = true
        
        configManager.write(name: key, value: message) { (response, error) in
            if let response = response {
                received.text = response.returnCode.description
                receivedBackground.tintColor = .zephyr
            }
            if let error = error {
                received.text = "\(error.localizedDescription)"
                receivedBackground.tintColor = .systemRed
            }
            received.isHidden = false
            receivedBackground.isHidden = false
        }
    }
}

import Foundation
import SwiftUI
import UIKit
import CoreBluetooth

struct RCNotifications {
    static let BluetoothReady = "org.elkhorn-creek.simpleledcapsense.bluetoothReady"
    static let FoundDevice = "org.elkhorn-creek.simpleledcapsense.founddevice"
    static let ConnectionComplete = "org.elkhorn-creek.simpleledcapsense.connectioncomplete"
    static let ServiceScanComplete = "org.elkhorn-creek.simpleledcapsense.servicescancomplete"
    static let CharacteristicScanComplete = "org.elkhorn-creek.simpleledcapsense.characteristicsscancomplete"
    static let DisconnectedDevice = "org.elkhorn-creek.simpleledcapsense.disconnecteddevice"
    static let UpdatedCapsense = "org.elkhorn-creek.simpleledcapsense.updatedcapsense"
}

struct ContentView: View {
    @StateObject private var bleLand = BlueToothNeighborhood()
    @State private var capsenseLabel: String = ""
    @State var isBluetoothReady = false
    @State private var ledSwitchIsOn: Bool = false
    @State private var capsenseNotifySwitchIsOn: Bool = false
    @State private var isConnectButtonEnabled = true
    @State private var isDiscoverServicesButtonEnabled = true
    @State private var isConnectionComplete = false
    @State private var isDeviceFound = false
    @State private var isServiceScanComplete = false
    @State private var isCharacteristicScanComplete = false
    
    var body: some View {
        VStack {
            //MARK: TITLE
            Text("BleApp")
                .font(.largeTitle)
                .padding()
            
            //MARK: START BLUETOOTH
            Button(action: {
                bleLand.startUpCentralManager()
            }) {
                Text("Start Bluetooth")
            }
            .disabled(isBluetoothReady || bleLand.isBluetoothReady || isConnectionComplete)
            
            //MARK: SEARCH FOR SERVICE
            Button(action: {
                bleLand.discoverDevice()
            }) {
                Text("Search for Device")
            }
            .disabled(bleLand.isDeviceFound || bleLand.isDisconnected)
            .padding()

            
            //MARK: CONNECT
            Button(action: {
                if bleLand.isDeviceFound {
                    bleLand.connectToDevice()
                }
            }) {
                Text("Connect")
            }
            .disabled(!bleLand.isDeviceFound)
            .padding()
            
            //MARK: DISCOVER SERVICES
            Button(action: {
                bleLand.discoverServices()
                //isDiscoverCharacteristicsButtonEnabled = false
            }) {
                Text("Discover Services")
            }
            .disabled(!bleLand.isConnectionComplete || !isDiscoverServicesButtonEnabled)
            .padding()
            
            //MARK: DISCOVER CHARACTERISTICS
            Button(action: {
                bleLand.discoverCharacteristics()
            }) {
                Text("Discover Characteristics")
            }
            .disabled(!bleLand.isServiceScanComplete || !bleLand.isDiscoverCharacteristicsButtonEnabled)
            .padding()
            
            //MARK: TOGGLE LED
            
            Toggle("Toggle LED", isOn: $ledSwitchIsOn.animation())
                .onChange(of: ledSwitchIsOn) { newValue in
                    let value = newValue ? 1 : 0
                    bleLand.writeLedCharacteristic(val: Int8(value))
                }
                .disabled(!bleLand.isCharacteristicScanComplete || !bleLand.isLedCharacteristicAvailable)
                .padding(.horizontal, 100)
                .padding()
            
            //MARK: TOGGLE NOTIFICATIONS
            Toggle("Notify", isOn: $capsenseNotifySwitchIsOn)
                .onChange(of: capsenseNotifySwitchIsOn) { newValue in
                    bleLand.writeCapsenseNotify(state: newValue)
                }
                .disabled(!bleLand.isCharacteristicScanComplete)
                .padding(.horizontal, 100)
                .padding()
            
            //MARK: CAPSENSE VALUE
            Text(capsenseLabel)
                .onReceive(bleLand.$capsenseValue) { value in
                    capsenseLabel = "Capsense value = \(value)"
                }
                .padding()
            
            //MARK: DISCONNECT
            Button(action: {
                bleLand.disconnectDevice()
            }) {
                Text("Disconnect")
            }
            .disabled(!bleLand.isDisconnectButtonEnabled)
            .padding()
        }
        
        .onAppear {
                    bleLand.startUpCentralManager()
                }
        .onReceive(bleLand.$isBluetoothReady) { newValue in
            isBluetoothReady = newValue
        }
        .onReceive(bleLand.$isDeviceFound) { newValue in
            isDeviceFound = newValue
        }
        .onReceive(bleLand.$isConnectionComplete) { newValue in
            isConnectionComplete = newValue
        }
        .onReceive(bleLand.$isServiceScanComplete) { newValue in
            isServiceScanComplete = newValue
        }
        .onReceive(bleLand.$isCharacteristicScanComplete) { newValue in
            isCharacteristicScanComplete = newValue
        }
    }
}
        struct ContentView_Previews: PreviewProvider {
            static var previews: some View {
                ContentView()
    }
}

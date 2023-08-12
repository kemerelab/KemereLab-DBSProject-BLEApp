import Foundation
import CoreBluetooth
import Combine

private struct BLEParameters {
    static let capsenseLedService = CBUUID(string: "00000000-0000-1000-8000-00805F9B34F0")
    static let ledCharactersticUUID = CBUUID(string:"00000000-0000-1000-8000-00805F9B34F1")
    static let capsenseCharactersticUUID = CBUUID(string:"00000000-0000-1000-8000-00805F9B34F2")
}

class BlueToothNeighborhood: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, ObservableObject {
    @Published var isBluetoothReady = false
    @Published var isDeviceFound = false
    @Published var isConnectionComplete = false
    @Published var isServiceScanComplete = false
    @Published var isCharacteristicScanComplete = false
    @Published var capsenseValue = 0
    @Published var capsenseNotifySwitchIsOn = false
    @Published var isDiscoverCharacteristicsButtonEnabled = false
    @Published var isDisconnected = false
    var isLedCharacteristicAvailable: Bool {
        return ledCharacteristic != nil
    }
    @Published var isCharacteristicScanEnabled = false {
        didSet {
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    private var centralManager: CBCentralManager!
    private var capsenseLedBoard: CBPeripheral?
    private var capsenseLedService: CBService?
    private var ledCharacteristic: CBCharacteristic?
    private var capsenseCharacteristic: CBCharacteristic?
    private var capsenseValueSubject = CurrentValueSubject<Int, Never>(0)
        
        var capsenseValuePublisher: AnyPublisher<Int, Never> {
            capsenseValueSubject.eraseToAnyPublisher()
        }
    
        var isConnectButtonEnabled: Bool {
            !isConnectionComplete
        }

        var isDisconnectButtonEnabled: Bool {
            isConnectionComplete
        }
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startUpCentralManager() {
        isBluetoothReady.toggle()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            isBluetoothReady = true
            print("Bluetooth is on")
        default:
            break
        }
    }
    
    func discoverDevice() {
        print("Starting scan")
        centralManager.scanForPeripherals(withServices: [BLEParameters.capsenseLedService], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if capsenseLedBoard == nil {
            print("Found a new Peripheral advertising capsense led service")
            capsenseLedBoard = peripheral
            isDeviceFound = true
            centralManager.stopScan()
        }
    }
    
    func connectToDevice() {
        guard let capsenseLedBoard = capsenseLedBoard else {
            print("No capsenseLedBoard found")
            return
        }
        
        centralManager.connect(capsenseLedBoard, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let capsenseLedBoard = capsenseLedBoard {
            print("Connection complete \(capsenseLedBoard) \(peripheral)")
            capsenseLedBoard.delegate = self
            DispatchQueue.main.async {
                self.isConnectionComplete = true
            }
        }
    }
    
    func discoverServices() {
        guard let capsenseLedBoard = capsenseLedBoard else {
            print("Error: capsenseLedBoard is nil")
            return
        }
        
        capsenseLedBoard.discoverServices(nil)
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("Discovered services")
        if let services = peripheral.services {
            for service in services {
                print("Found service \(service)")
                if service.uuid == BLEParameters.capsenseLedService {
                    capsenseLedService = service
                }
            }
        }
        isServiceScanComplete = true
        isDiscoverCharacteristicsButtonEnabled = true
    }
    
    func discoverCharacteristics() {
        guard let capsenseLedBoard = capsenseLedBoard, let capsenseLedService = capsenseLedService else {
            print("Error: capsenseLedBoard or capsenseLedService is nil")
            return
        }
        
        capsenseLedBoard.discoverCharacteristics(nil, for: capsenseLedService)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard service.characteristics != nil else {
            print("No characteristics found for service: \(service)")
            return
        }
        
        print("Discovered characteristics for service: \(service)")
        
        for characteristic in service.characteristics ?? [] {
            print("Found characteristic: \(characteristic)")
            
            switch characteristic.uuid {
            case BLEParameters.capsenseCharactersticUUID:
                capsenseCharacteristic = characteristic
            case BLEParameters.ledCharactersticUUID:
                ledCharacteristic = characteristic
            default:
                break
            }
        }
        isCharacteristicScanComplete = true
    }
    
    func disconnectDevice() {
        if let capsenseLedBoard = capsenseLedBoard {
            centralManager.cancelPeripheralConnection(capsenseLedBoard)
        }
        isDisconnected = true
        isDeviceFound = false
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected \(peripheral)")
        capsenseLedBoard = nil
        isConnectionComplete = false
        isDisconnected = false
    }
    
    func writeLedCharacteristic(val: Int8) {
        guard let capsenseLedBoard = capsenseLedBoard, let ledCharacteristic = ledCharacteristic else {
            print("Error: capsenseLedBoard or ledCharacteristic is nil")
            return
        }
        
        var value = val
        let ns = NSData(bytes: &value, length: MemoryLayout<Int8>.size)
        capsenseLedBoard.writeValue(ns as Data, for: ledCharacteristic, type: .withResponse)
    }
    
    
    func writeCapsenseNotify(state: Bool) {
        guard let capsenseCharacteristic = capsenseCharacteristic else {
            print("Error: capsenseCharacteristic is nil")
            return
        }
        capsenseNotifySwitchIsOn = state
        capsenseLedBoard?.setNotifyValue(state, for: capsenseCharacteristic)
    }
        func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
            if characteristic == capsenseCharacteristic {
                var out: Int = 0
                if let value = characteristic.value {
                    (value as NSData).getBytes(&out, length: MemoryLayout<Int>.size)
                    DispatchQueue.main.async {
                        self.capsenseValue = out
                    }
                }
            }
        }
}

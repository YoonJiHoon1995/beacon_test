import Flutter
import UIKit
import CoreBluetooth

@main
@objc class AppDelegate: FlutterAppDelegate, CBPeripheralManagerDelegate {
   var peripheralManager: CBPeripheralManager?
   let CHANNEL = "ble_advertiser_ios"

   let manufacturerId: UInt16 = 0x1377
   let manufacturerData = "b2tech".data(using: .utf8)!


  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: CHANNEL, binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { [weak self] (call, result) in
        switch call.method {
        case "startAdvertising":
            if let args = call.arguments as? [String: Any],
               let uuidString = args["uuid"] as? String {
                self?.startAdvertising(uuid: uuidString)
            }
            result(nil)

        case "stopAdvertising":
            self?.stopAdvertising()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func startAdvertising(uuid: String) {
      peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
      self.pendingUUID = uuid
  }

  func stopAdvertising() {
      peripheralManager?.stopAdvertising()
      print("🛑 Advertising stopped")
  }

  private var pendingUUID: String?

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
      if peripheral.state == .poweredOn, let uuidStr = pendingUUID {
          print("✅ Bluetooth ON, start advertising with uuid=\(uuidStr)")

          let serviceUUID = CBUUID(string: uuidStr)

          var manufacturerBytes = Data()
          manufacturerBytes.append(UInt8(manufacturerId & 0xFF))
          manufacturerBytes.append(UInt8((manufacturerId >> 8) & 0xFF))
          manufacturerBytes.append(manufacturerData)

          let advertisementData: [String: Any] = [
              CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
              CBAdvertisementDataManufacturerDataKey: manufacturerBytes
          ]

          peripheralManager?.startAdvertising(advertisementData)
      }
  }

}

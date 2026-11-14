import CryptoKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Huella del celular para la regla "un celular registra a un solo
    // estudiante por sesión": SHA-256 (con una sal de la app) del
    // identifierForVendor; nunca se envía el identificador real.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BioAsistenciaDeviceKey") {
      let channel = FlutterMethodChannel(
        name: "bioasistencia/device", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "deviceKey" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let id = UIDevice.current.identifierForVendor?.uuidString else {
          result(nil)
          return
        }
        let digest = SHA256.hash(data: Data("bioasistencia-udla:\(id)".utf8))
        result(digest.map { String(format: "%02x", $0) }.joined())
      }
    }
  }
}

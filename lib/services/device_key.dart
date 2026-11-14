import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Huella del celular para la regla "un celular registra a un solo
/// estudiante por sesión" (`sessionDevices` en las reglas).
///
/// La calcula el código nativo (`MainActivity.kt` / `AppDelegate.swift`):
/// SHA-256, con una sal de la app, de `ANDROID_ID` o `identifierForVendor`.
/// Nunca sale del teléfono el identificador real.
///
/// En web y escritorio no hay un identificador estable: devuelve null y no
/// se permite registrar asistencia desde ahí.
class DeviceKey {
  DeviceKey._();

  static const _channel = MethodChannel('bioasistencia/device');
  static String? _cached;

  static Future<String?> get() async {
    if (_cached != null) return _cached;
    if (kIsWeb) return null;
    try {
      final key = await _channel.invokeMethod<String>('deviceKey');
      if (key != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(key)) {
        _cached = key;
      }
      return _cached;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

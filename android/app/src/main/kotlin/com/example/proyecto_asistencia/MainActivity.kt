package com.example.proyecto_asistencia

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Huella del celular para la regla "un celular registra a un solo
        // estudiante por sesión". Se envía solo el SHA-256 (con una sal de la
        // app), nunca el identificador real del sistema.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bioasistencia/device")
            .setMethodCallHandler { call, result ->
                if (call.method != "deviceKey") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val id = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                if (id.isNullOrBlank()) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                val digest = MessageDigest.getInstance("SHA-256")
                    .digest("bioasistencia-udla:$id".toByteArray(Charsets.UTF_8))
                result.success(digest.joinToString("") { "%02x".format(it) })
            }
    }
}

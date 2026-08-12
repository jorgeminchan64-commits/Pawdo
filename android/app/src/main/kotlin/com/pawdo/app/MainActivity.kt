package com.pawdo.app

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.io.File
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val widgetChannel = "pawdo/android_widget"
    private val widgetPreferences = "pawdo_widget_preferences"
    private val callReadinessChannel = "pawdo/call_readiness"
    private val callPermissionRequestCode = 8102
    private var pendingCallPermissionResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val hardwareProbeExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetChannel)
            .setMethodCallHandler { call, result ->
                val preferences = getSharedPreferences(widgetPreferences, MODE_PRIVATE)
                when (call.method) {
                    "getPreferences" -> result.success(
                        mapOf(
                            "enabled" to preferences.getBoolean("enabled", true),
                            "showContent" to preferences.getBoolean("showContent", false),
                        ),
                    )
                    "setPreferences" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        val showContent = call.argument<Boolean>("showContent") ?: false
                        preferences.edit()
                            .putBoolean("enabled", enabled)
                            .putBoolean("showContent", showContent)
                            .apply()
                        PawdoWidgetProvider.updateAll(this)
                        result.success(null)
                    }
                    "updateWidget" -> {
                        val title = call.argument<String>("title")?.take(80).orEmpty()
                        val body = call.argument<String>("body")?.take(120).orEmpty()
                        val activity = call.argument<String>("activity")?.take(120).orEmpty()
                        val photo = call.argument<ByteArray>("photo")
                        val photoFile = File(filesDir, "pawdo_widget_photo.jpg")
                        val photoHash = photo?.contentHashCode() ?: preferences.getInt("photoHash", 0)
                        if (photo != null && photo.isNotEmpty() && photo.size <= 512 * 1024) {
                            photoFile.writeBytes(photo)
                        }
                        val changed = title != preferences.getString("title", "") ||
                            body != preferences.getString("body", "") ||
                            activity != preferences.getString("activity", "") ||
                            photoHash != preferences.getInt("photoHash", 0)
                        if (changed) {
                            preferences.edit()
                                .putString("title", title)
                                .putString("body", body)
                                .putString("activity", activity)
                                .putString("photoPath", if (photoFile.exists()) photoFile.absolutePath else null)
                                .putInt("photoHash", photoHash)
                                .apply()
                            PawdoWidgetProvider.updateAll(this)
                        }
                        result.success(null)
                    }
                    "clearWidget" -> {
                        File(filesDir, "pawdo_widget_photo.jpg").delete()
                        preferences.edit()
                            .remove("title")
                            .remove("body")
                            .remove("activity")
                            .remove("photoPath")
                            .remove("photoHash")
                            .putBoolean("pendingMissYou", false)
                            .putBoolean("showContent", false)
                            .apply()
                        PawdoWidgetProvider.updateAll(this)
                        result.success(null)
                    }
                    "takePendingAction" -> {
                        val pending = preferences.getBoolean("pendingMissYou", false)
                        result.success(if (pending) "miss_you" else null)
                    }
                    "completePendingAction" -> {
                        preferences.edit().putBoolean("pendingMissYou", false).apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, callReadinessChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capabilities" -> result.success(callCapabilities())
                    "requestPermissions" -> requestCallPermissions(result)
                    "probeMicrophone" -> probeMicrophone(result)
                    "probeCamera" -> probeCamera(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun callCapabilities(): Map<String, Boolean> {
        val manager = packageManager
        return mapOf(
            "cameraAvailable" to manager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY),
            "microphoneAvailable" to manager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE),
            "cameraPermission" to permissionGranted(Manifest.permission.CAMERA),
            "microphonePermission" to permissionGranted(Manifest.permission.RECORD_AUDIO),
        )
    }

    private fun permissionGranted(permission: String): Boolean =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun requestCallPermissions(result: MethodChannel.Result) {
        val permissions = mutableListOf<String>()
        if (packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY) &&
            !permissionGranted(Manifest.permission.CAMERA)
        ) permissions.add(Manifest.permission.CAMERA)
        if (packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE) &&
            !permissionGranted(Manifest.permission.RECORD_AUDIO)
        ) permissions.add(Manifest.permission.RECORD_AUDIO)
        if (permissions.isEmpty()) {
            result.success(callCapabilities())
            return
        }
        if (pendingCallPermissionResult != null) {
            result.error("request-in-progress", "Ya hay una solicitud de permisos activa.", null)
            return
        }
        pendingCallPermissionResult = result
        requestPermissions(
            permissions.toTypedArray(),
            callPermissionRequestCode,
        )
    }

    @SuppressLint("MissingPermission")
    private fun probeMicrophone(result: MethodChannel.Result) {
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE)) {
            result.error("microphone-unavailable", "Este dispositivo no informa un micrófono disponible.", null)
            return
        }
        if (!permissionGranted(Manifest.permission.RECORD_AUDIO)) {
            result.error("microphone-permission", "Autoriza el micrófono antes de ejecutar la prueba.", null)
            return
        }
        hardwareProbeExecutor.execute {
            var recorder: AudioRecord? = null
            try {
                val sampleRate = 16000
                val minimum = AudioRecord.getMinBufferSize(
                    sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                )
                if (minimum <= 0) throw IllegalStateException("Configuración de audio no compatible.")
                val bufferSize = maxOf(minimum, 2048)
                recorder = AudioRecord(
                    MediaRecorder.AudioSource.VOICE_COMMUNICATION,
                    sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    bufferSize,
                )
                if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                    throw IllegalStateException("El micrófono no pudo inicializarse.")
                }
                val buffer = ShortArray(bufferSize / 2)
                var squaredSum = 0.0
                var sampleCount = 0L
                recorder.startRecording()
                val deadline = System.nanoTime() + 1_200_000_000L
                while (System.nanoTime() < deadline) {
                    val read = recorder.read(buffer, 0, buffer.size)
                    if (read > 0) {
                        for (index in 0 until read) {
                            val normalized = buffer[index] / 32768.0
                            squaredSum += normalized * normalized
                        }
                        sampleCount += read
                    } else if (read < 0) {
                        throw IllegalStateException("Android no pudo leer el micrófono ($read).")
                    }
                }
                val level = if (sampleCount == 0L) 0.0 else sqrt(squaredSum / sampleCount)
                mainHandler.post {
                    result.success(
                        mapOf(
                            "success" to (sampleCount > 0),
                            "level" to level.coerceIn(0.0, 1.0),
                        ),
                    )
                }
            } catch (error: Exception) {
                mainHandler.post {
                    result.error("microphone-probe-failed", error.message ?: "Falló la prueba del micrófono.", null)
                }
            } finally {
                try {
                    recorder?.stop()
                } catch (_: Exception) {
                    // It may not have reached the recording state.
                }
                recorder?.release()
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun probeCamera(result: MethodChannel.Result) {
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)) {
            result.error("camera-unavailable", "Este dispositivo no informa una cámara disponible.", null)
            return
        }
        if (!permissionGranted(Manifest.permission.CAMERA)) {
            result.error("camera-permission", "Autoriza la cámara antes de ejecutar la prueba.", null)
            return
        }
        val manager = getSystemService(CAMERA_SERVICE) as CameraManager
        val cameraId = try {
            manager.cameraIdList.firstOrNull()
        } catch (error: Exception) {
            result.error("camera-list-failed", error.message ?: "No se pudo consultar la cámara.", null)
            return
        }
        if (cameraId == null) {
            result.error("camera-unavailable", "No se encontró una cámara utilizable.", null)
            return
        }
        val completed = AtomicBoolean(false)
        fun finishSuccess() {
            if (completed.compareAndSet(false, true)) {
                result.success(mapOf("success" to true))
            }
        }
        fun finishError(code: String, message: String) {
            if (completed.compareAndSet(false, true)) result.error(code, message, null)
        }
        mainHandler.postDelayed(
            { finishError("camera-timeout", "La cámara no respondió a tiempo.") },
            4000,
        )
        try {
            manager.openCamera(
                cameraId,
                object : CameraDevice.StateCallback() {
                    override fun onOpened(camera: CameraDevice) {
                        camera.close()
                        finishSuccess()
                    }

                    override fun onDisconnected(camera: CameraDevice) {
                        camera.close()
                        finishError("camera-disconnected", "La cámara se desconectó durante la prueba.")
                    }

                    override fun onError(camera: CameraDevice, error: Int) {
                        camera.close()
                        finishError("camera-probe-failed", "Android devolvió el error de cámara $error.")
                    }
                },
                mainHandler,
            )
        } catch (error: Exception) {
            finishError("camera-probe-failed", error.message ?: "Falló la prueba de la cámara.")
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == callPermissionRequestCode) {
            pendingCallPermissionResult?.success(callCapabilities())
            pendingCallPermissionResult = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val messages = NotificationChannel(
                "pawdo_messages",
                "Mensajes de Pawdo",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Mensajes y fotografías de tu pareja"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            }
            val quick = NotificationChannel(
                "pawdo_quick_messages",
                "Mensajes rápidos de Pawdo",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Avisos rápidos destacados de tu pareja"
                lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
                enableVibration(true)
            }
            manager.createNotificationChannels(listOf(messages, quick))
        }
    }
}

package com.pawdo.app

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.content.Intent
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
    private val localVoiceChannel = "pawdo/local_voice"
    private val unityRuntimeChannel = "pawdo/unity_runtime"
    private val unityPlayerActivity = "com.pawdo.app.PawdoUnityActivity"
    private val unityPlayerBaseActivity = "com.unity3d.player.UnityPlayerGameActivity"
    private val unityPlayerClass = "com.unity3d.player.UnityPlayer"
    private val unityBridgeHost = "PawdoBridgeHost"
    private val unityBridgeMethod = "ReceiveFromFlutter"
    private val unityInitializationExtra = "pawdo.bridge.initialization"
    private val unityQaSceneExtra = "pawdo.qa.scene"
    private val callPermissionRequestCode = 8102
    private val voicePermissionRequestCode = 8103
    private var pendingCallPermissionResult: MethodChannel.Result? = null
    private var pendingVoicePermissionResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val hardwareProbeExecutor = Executors.newSingleThreadExecutor()
    private val localVoiceController by lazy { LocalVoiceController(this) }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        maybeLaunchUnityQaScene(intent)
    }

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, localVoiceChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capabilities" -> result.success(localVoiceController.capabilities())
                    "requestPermission" -> requestVoicePermission(result)
                    "start" -> result.success(localVoiceController.start())
                    "level" -> result.success(localVoiceController.level())
                    "stopAndPlay" -> localVoiceController.stopAndPlay(
                        onSuccess = result::success,
                        onError = { code, message -> result.error(code, message, null) },
                    )
                    "cancel" -> {
                        localVoiceController.cancel()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, unityRuntimeChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capabilities" -> result.success(unityCapabilities())
                    "launch" -> {
                        val scene = call.argument<String>("scene")
                        val envelope = call.argument<String>("initializationEnvelope")
                        val validScene = scene in setOf("garden", "interior")
                        val validEnvelope = envelope != null && envelope.toByteArray().size <= 64 * 1024
                        if (!validScene || !validEnvelope) {
                            result.error(
                                "invalid-unity-launch",
                                "La solicitud de apertura 3D no cumple el contrato v1.",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        if (!unityRuntimeAvailable()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        try {
                            startActivity(
                                Intent().apply {
                                    setClassName(this@MainActivity, unityPlayerActivity)
                                    addFlags(
                                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                                            Intent.FLAG_ACTIVITY_SINGLE_TOP,
                                    )
                                    putExtra(unityInitializationExtra, envelope)
                                    putExtra("pawdo.scene", scene)
                                },
                            )
                            result.success(true)
                        } catch (error: Exception) {
                            result.error(
                                "unity-launch-failed",
                                error.message ?: "No se pudo iniciar el entorno 3D.",
                                null,
                            )
                        }
                    }
                    "send", "pause", "resume", "unload" -> {
                        val envelope = call.argument<String>("envelope")
                        if (envelope == null || envelope.toByteArray(Charsets.UTF_8).size > 64 * 1024) {
                            result.error(
                                "invalid-unity-message",
                                "El mensaje para Unity no cumple el contrato v1.",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        result.success(sendUnityMessage(envelope))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun unityRuntimeAvailable(): Boolean =
        try {
            Class.forName(unityPlayerActivity)
            Class.forName(unityPlayerBaseActivity)
            Class.forName(unityPlayerClass)
            true
        } catch (_: ReflectiveOperationException) {
            false
        }

    private fun maybeLaunchUnityQaScene(source: Intent?) {
        val debuggable =
            (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!debuggable) return
        val scene = source?.getStringExtra(unityQaSceneExtra)
        if (scene !in setOf("garden", "interior")) return
        source?.removeExtra(unityQaSceneExtra)
        val envelope =
            """{"schemaVersion":1,"messageId":"android-qa-$scene","type":"scene.open","issuedAtUtc":"2026-08-27T00:00:00Z","payload":{"scene":"$scene"}}"""
        mainHandler.postDelayed(
            {
                startActivity(
                    Intent().apply {
                        setClassName(this@MainActivity, unityPlayerActivity)
                        addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        putExtra(unityInitializationExtra, envelope)
                        putExtra("pawdo.scene", scene)
                    },
                )
            },
            500,
        )
    }

    private fun unityCapabilities(): Map<String, Any> {
        val available = unityRuntimeAvailable()
        return mapOf(
            "available" to available,
            "bridgeSchemaVersion" to 1,
            "supportedScenes" to if (available) listOf("garden", "interior") else emptyList<String>(),
            "reason" to if (available) "ready" else "unity-library-not-linked",
        )
    }

    private fun sendUnityMessage(envelope: String): Boolean =
        try {
            Class.forName(unityPlayerClass)
                .getMethod(
                    "UnitySendMessage",
                    String::class.java,
                    String::class.java,
                    String::class.java,
                )
                .invoke(null, unityBridgeHost, unityBridgeMethod, envelope)
            true
        } catch (_: ReflectiveOperationException) {
            false
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

    private fun requestVoicePermission(result: MethodChannel.Result) {
        if (permissionGranted(Manifest.permission.RECORD_AUDIO)) {
            result.success(true)
            return
        }
        if (pendingVoicePermissionResult != null) {
            result.error("voice-permission-busy", "Ya hay una solicitud de micrófono activa.", null)
            return
        }
        pendingVoicePermissionResult = result
        requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), voicePermissionRequestCode)
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
        if (requestCode == voicePermissionRequestCode) {
            pendingVoicePermissionResult?.success(permissionGranted(Manifest.permission.RECORD_AUDIO))
            pendingVoicePermissionResult = null
        }
    }

    override fun onStop() {
        localVoiceController.cancel()
        super.onStop()
    }

    override fun onDestroy() {
        localVoiceController.dispose()
        hardwareProbeExecutor.shutdownNow()
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        maybeLaunchUnityQaScene(intent)
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

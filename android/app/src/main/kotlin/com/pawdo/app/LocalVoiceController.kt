package com.pawdo.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.media.PlaybackParams
import android.os.Handler
import android.os.Looper
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.sqrt

class LocalVoiceController(private val context: Context) {
    companion object {
        private const val sampleRate = 22050
        private const val maxSeconds = 10
        private const val minimumSamples = sampleRate / 2
        private const val vadThreshold = 0.018
    }

    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var recording = false
    @Volatile private var playing = false
    @Volatile private var processing = false
    @Volatile private var rms = 0.0
    @Volatile private var peak = 0.0
    @Volatile private var voiceFrames = 0
    @Volatile private var pcm = ByteArray(0)
    private var player: MediaPlayer? = null
    private var temporaryFile: File? = null
    private val sessionGeneration = AtomicInteger(0)
    private var pendingPlaybackSuccess: ((Map<String, Any>) -> Unit)? = null
    private var pendingPlaybackError: ((String, String) -> Unit)? = null

    fun capabilities(): Map<String, Any> =
        mapOf(
            "available" to context.packageManager.hasSystemFeature(PackageManager.FEATURE_MICROPHONE),
            "permission" to permissionGranted(),
            "sampleRate" to sampleRate,
            "maximumDurationMs" to maxSeconds * 1000,
            "localOnly" to true,
        )

    fun permissionGranted(): Boolean =
        context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    @Synchronized
    fun start(): Map<String, Any> {
        if (!permissionGranted()) return mapOf("accepted" to false, "reason" to "permission-required")
        if (recording || playing || processing) {
            return mapOf("accepted" to false, "reason" to "voice-busy")
        }
        cleanupPlayerAndFile()
        val session = sessionGeneration.incrementAndGet()
        recording = true
        rms = 0.0
        peak = 0.0
        voiceFrames = 0
        pcm = ByteArray(0)
        worker.execute { recordLoop(session) }
        return mapOf("accepted" to true, "localOnly" to true)
    }

    fun level(): Map<String, Any> =
        mapOf(
            "recording" to recording,
            "playing" to playing,
            "processing" to processing,
            "rms" to rms.coerceIn(0.0, 1.0),
            "peak" to peak.coerceIn(0.0, 1.0),
            "voiceDetected" to (voiceFrames >= 2),
        )

    @Synchronized
    fun stopAndPlay(
        onSuccess: (Map<String, Any>) -> Unit,
        onError: (String, String) -> Unit,
    ) {
        // Reaching the duration cap stops AudioRecord before the user releases
        // the button. That completed buffer still belongs to this capture.
        if (playing || processing || (!recording && pcm.isEmpty())) {
            onError("voice-not-recording", "Mantén presionado el botón antes de soltarlo.")
            return
        }
        val operationSession = sessionGeneration.get()
        pendingPlaybackSuccess = onSuccess
        pendingPlaybackError = onError
        recording = false
        processing = true
        worker.execute {
            if (sessionGeneration.get() != operationSession) return@execute
            val samples = pcm.size / 2
            if (samples < minimumSamples || voiceFrames < 2) {
                pcm = ByteArray(0)
                processing = false
                mainHandler.post {
                    completeError("voice-not-detected", "No se detectó una voz clara. Inténtalo de nuevo.")
                }
                return@execute
            }
            try {
                val file = File.createTempFile("pawdo_voice_repeat_", ".wav", context.cacheDir)
                temporaryFile = file
                writeWave(file, pcm)
                pcm = ByteArray(0)
                if (sessionGeneration.get() != operationSession) {
                    cleanupPlayerAndFile()
                    return@execute
                }
                play(file, samples * 1000L / sampleRate, operationSession)
            } catch (error: Exception) {
                pcm = ByteArray(0)
                processing = false
                cleanupPlayerAndFile()
                mainHandler.post {
                    completeError(
                        "voice-playback-failed",
                        error.message ?: "No se pudo reproducir la voz.",
                    )
                }
            }
        }
    }

    @Synchronized
    fun cancel() {
        sessionGeneration.incrementAndGet()
        val cancellationCallback = pendingPlaybackError
        pendingPlaybackSuccess = null
        pendingPlaybackError = null
        recording = false
        processing = false
        pcm = ByteArray(0)
        cleanupPlayerAndFile()
        rms = 0.0
        peak = 0.0
        voiceFrames = 0
        if (cancellationCallback != null) {
            mainHandler.post {
                cancellationCallback(
                    "voice-cancelled",
                    "La grabación local se canceló al salir de Pawdo.",
                )
            }
        }
    }

    fun dispose() {
        cancel()
        worker.shutdownNow()
    }

    private fun recordLoop(session: Int) {
        var recorder: AudioRecord? = null
        val output = ByteArrayOutputStream(sampleRate * 2)
        try {
            val minimum = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            require(minimum > 0) { "Configuración de micrófono no compatible." }
            recorder = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                minimum * 2,
            )
            require(recorder.state == AudioRecord.STATE_INITIALIZED) { "El micrófono no pudo inicializarse." }
            val buffer = ShortArray(minimum / 2)
            recorder.startRecording()
            while (
                recording &&
                    sessionGeneration.get() == session &&
                    output.size() < sampleRate * 2 * maxSeconds
            ) {
                val count = recorder.read(buffer, 0, buffer.size)
                if (count <= 0) continue
                var squares = 0.0
                for (index in 0 until count) {
                    val sample = buffer[index].toInt()
                    squares += sample.toDouble() * sample
                    output.write(sample and 0xff)
                    output.write((sample shr 8) and 0xff)
                }
                val blockRms = sqrt(squares / count) / Short.MAX_VALUE
                rms = rms * 0.72 + blockRms * 0.28
                peak = maxOf(peak * 0.96, blockRms)
                if (blockRms >= vadThreshold) voiceFrames++
            }
        } catch (_: Exception) {
            recording = false
        } finally {
            try {
                recorder?.stop()
            } catch (_: Exception) {
                // The recorder may not have entered the recording state.
            }
            recorder?.release()
            if (sessionGeneration.get() == session) {
                pcm = output.toByteArray()
            }
            output.close()
            if (sessionGeneration.get() == session) {
                recording = false
            }
        }
    }

    private fun play(
        file: File,
        durationMs: Long,
        operationSession: Int,
    ) {
        mainHandler.post {
            if (sessionGeneration.get() != operationSession) {
                cleanupPlayerAndFile()
                return@post
            }
            try {
                val mediaPlayer = MediaPlayer()
                player = mediaPlayer
                mediaPlayer.setAudioAttributes(
                    AudioAttributes.Builder()
                        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                        .setUsage(AudioAttributes.USAGE_MEDIA)
                        .build(),
                )
                mediaPlayer.setDataSource(file.absolutePath)
                mediaPlayer.prepare()
                mediaPlayer.playbackParams = PlaybackParams().setSpeed(1.02f).setPitch(1.18f)
                mediaPlayer.setOnCompletionListener {
                    playing = false
                    processing = false
                    val deleted = cleanupPlayerAndFile()
                    if (deleted) {
                        completeSuccess(
                            mapOf(
                                "played" to true,
                                "durationMs" to durationMs,
                                "voiceDetected" to true,
                                "temporaryDeleted" to true,
                                "uploaded" to false,
                            ),
                        )
                    } else {
                        completeError(
                            "voice-cleanup-failed",
                            "No se pudo confirmar el borrado del audio temporal.",
                        )
                    }
                }
                mediaPlayer.setOnErrorListener { _, _, _ ->
                    playing = false
                    processing = false
                    cleanupPlayerAndFile()
                    completeError(
                        "voice-playback-failed",
                        "Android no pudo reproducir la voz procesada.",
                    )
                    true
                }
                playing = true
                processing = false
                mediaPlayer.start()
            } catch (error: Exception) {
                playing = false
                processing = false
                cleanupPlayerAndFile()
                completeError(
                    "voice-playback-failed",
                    error.message ?: "No se pudo reproducir la voz.",
                )
            }
        }
    }

    private fun completeSuccess(values: Map<String, Any>) {
        val callback = synchronized(this) {
            val value = pendingPlaybackSuccess
            pendingPlaybackSuccess = null
            pendingPlaybackError = null
            value
        }
        callback?.invoke(values)
    }

    private fun completeError(code: String, message: String) {
        val callback = synchronized(this) {
            val value = pendingPlaybackError
            pendingPlaybackSuccess = null
            pendingPlaybackError = null
            value
        }
        callback?.invoke(code, message)
    }

    @Synchronized
    private fun cleanupPlayerAndFile(): Boolean {
        try {
            player?.stop()
        } catch (_: Exception) {
            // The player may already be stopped.
        }
        player?.release()
        player = null
        val activeDeleted = temporaryFile?.let { !it.exists() || it.delete() } ?: true
        temporaryFile = null
        val staleDeleted = context.cacheDir
            .listFiles { file -> file.name.startsWith("pawdo_voice_repeat_") }
            ?.all { !it.exists() || it.delete() }
            ?: true
        playing = false
        return activeDeleted && staleDeleted
    }

    private fun writeWave(file: File, data: ByteArray) {
        val byteRate = sampleRate * 2
        FileOutputStream(file).use { output ->
            fun ascii(value: String) = output.write(value.toByteArray(Charsets.US_ASCII))
            fun little16(value: Int) {
                output.write(value and 0xff)
                output.write((value shr 8) and 0xff)
            }
            fun little32(value: Int) {
                output.write(value and 0xff)
                output.write((value shr 8) and 0xff)
                output.write((value shr 16) and 0xff)
                output.write((value shr 24) and 0xff)
            }
            ascii("RIFF")
            little32(36 + data.size)
            ascii("WAVEfmt ")
            little32(16)
            little16(1)
            little16(1)
            little32(sampleRate)
            little32(byteRate)
            little16(2)
            little16(16)
            ascii("data")
            little32(data.size)
            output.write(data)
        }
    }
}

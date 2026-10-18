package com.pawdo.app

import android.content.ContextWrapper
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.AbstractExecutorService
import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit

class LocalVoiceControllerTest {
    // Model the state published by AudioRecord at its duration cap. Only the
    // hardware worker is held back; stopAndPlay and level are production code.
    private fun controllerWithFinishedCapture(): Pair<LocalVoiceController, HeldWorker> {
        val controller = LocalVoiceController(ContextWrapper(null))
        val field = controller.javaClass.getDeclaredField("worker").apply { isAccessible = true }
        (field.get(controller) as ExecutorService).shutdownNow()
        val worker = HeldWorker()
        field.set(controller, worker)
        controller.javaClass.getDeclaredField("pcm").apply { isAccessible = true }
            .set(controller, ByteArray(441000))
        controller.javaClass.getDeclaredField("voiceFrames").apply { isAccessible = true }
            .setInt(controller, 20)
        return controller to worker
    }

    @Test fun completedTenSecondCaptureCanBePlayedAfterTheMicrophoneStops() {
        val (controller, worker) = controllerWithFinishedCapture()
        var error: String? = null
        controller.stopAndPlay({}, { code, _ -> error = code })
        assertNull("A completed capture must not be rejected as not recording", error)
        assertEquals(true, controller.level()["processing"])
        assertEquals(1, worker.queued.size)
        worker.shutdownNow()
    }

    @Test fun releasingTwiceDoesNotQueueTwoPlaybacks() {
        val (controller, worker) = controllerWithFinishedCapture()
        controller.stopAndPlay({}, { _, _ -> })
        var error: String? = null
        controller.stopAndPlay({}, { code, _ -> error = code })
        assertNotNull(error)
        assertEquals(1, worker.queued.size)
        worker.shutdownNow()
    }

    @Test fun idleControllerDoesNotReplayMissingAudio() {
        val controller = LocalVoiceController(ContextWrapper(null))
        var error: String? = null
        controller.stopAndPlay({}, { code, _ -> error = code })
        assertEquals("voice-not-recording", error)
        assertEquals(false, controller.level()["processing"])
        val field = controller.javaClass.getDeclaredField("worker").apply { isAccessible = true }
        (field.get(controller) as ExecutorService).shutdownNow()
    }

    private class HeldWorker : AbstractExecutorService() {
        val queued = mutableListOf<Runnable>()
        private var closed = false
        override fun execute(command: Runnable) { queued.add(command) }
        override fun shutdown() { closed = true }
        override fun shutdownNow(): MutableList<Runnable> {
            closed = true
            return queued.toMutableList().also { queued.clear() }
        }
        override fun isShutdown() = closed
        override fun isTerminated() = closed
        override fun awaitTermination(timeout: Long, unit: TimeUnit) = closed
    }
}

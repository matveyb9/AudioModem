package org.audiomodem.audio_modem

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioRouting
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Android foreground live-audio adapter v1 host.
 *
 * It carries only 48 kHz mono signed PCM16 LE frames that Flutter receives
 * from the Rust-owned carrier. It deliberately does not enumerate/select
 * devices, run in background, retain raw frames, or implement ADLP/DSP.
 */
class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private companion object {
        const val CHANNEL = "org.audiomodem.audio_modem/live_audio_v1"
        const val PERMISSION_REQUEST_CAPTURE = 73
        const val SAMPLE_RATE_HZ = 48_000
        const val CHANNELS = 1
        const val SAMPLE_FORMAT = "pcm_s16le"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val active = AtomicBoolean(false)
    private var captureSink: EventChannel.EventSink? = null
    private var audioTrack: AudioTrack? = null
    private var audioRecord: AudioRecord? = null
    private var playbackThread: Thread? = null
    private var captureThread: Thread? = null
    private var pendingCaptureResult: MethodChannel.Result? = null
    private var pendingPlaybackResult: MethodChannel.Result? = null
    private var focusRequest: AudioFocusRequest? = null

    private val audioManager: AudioManager
        get() = getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val focusListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        if (focusChange != AudioManager.AUDIOFOCUS_GAIN) {
            stopActiveRoute()
        }
    }

    private val routingListener = AudioRouting.OnRoutingChangedListener {
        stopActiveRoute()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler(this)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "$CHANNEL/capture_frames")
            .setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAvailability" -> result.success(availability())
            "startPlayback" -> startPlayback(call, result)
            "startCapture" -> startCapture(call, result)
            "stop" -> {
                stopActiveRoute()
                result.success(null)
            }
            "dispose" -> {
                stopActiveRoute()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        captureSink = events
    }

    override fun onCancel(arguments: Any?) {
        captureSink = null
        stopActiveRoute()
    }

    override fun onStop() {
        stopActiveRoute()
        super.onStop()
    }

    override fun onDestroy() {
        stopActiveRoute()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != PERMISSION_REQUEST_CAPTURE) return
        val result = pendingCaptureResult ?: return
        pendingCaptureResult = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            startCaptureAfterPermission(result)
        } else {
            result.error("permission_denied", "RECORD_AUDIO was not granted.", null)
        }
    }

    private fun availability(): Map<String, Any> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return mapOf(
                "available" to false,
                "reason" to "Android foreground live audio v1 requires API 26 or later.",
            )
        }
        return mapOf("available" to true)
    }

    private fun startPlayback(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureAvailable(result) || !validateFormat(call, result)) return
        val frames = call.argument<ByteArray>("pcmFrames")
        if (frames == null || frames.isEmpty() || frames.size % 2 != 0) {
            result.error("invalid_pcm", "Playback requires non-empty PCM16 LE frames.", null)
            return
        }
        if (!active.compareAndSet(false, true)) {
            result.error("route_active", "A live-audio operation is already active.", null)
            return
        }

        val focus = requestPlaybackFocus()
        if (focus != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
            active.set(false)
            result.error("focus_unavailable", "Audio focus was not granted for playback.", null)
            return
        }

        val minBuffer = AudioTrack.getMinBufferSize(
            SAMPLE_RATE_HZ,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuffer <= 0) {
            abandonPlaybackFocus()
            active.set(false)
            result.error("track_unavailable", "Android did not provide a PCM playback buffer.", null)
            return
        }
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(SAMPLE_RATE_HZ)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build(),
            )
            .setBufferSizeInBytes(maxOf(minBuffer, 4096))
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()
        if (track.state != AudioTrack.STATE_INITIALIZED) {
            track.release()
            abandonPlaybackFocus()
            active.set(false)
            result.error("track_unavailable", "Android could not initialize the requested PCM track.", null)
            return
        }
        if (!hasAudioModemV1Format(track.sampleRate, track.channelCount, track.audioFormat)) {
            track.release()
            abandonPlaybackFocus()
            active.set(false)
            result.error("format_mismatch", "Android track did not preserve 48000 Hz mono pcm_s16le.", null)
            return
        }
        track.addOnRoutingChangedListener(routingListener, mainHandler)
        audioTrack = track
        pendingPlaybackResult = result
        playbackThread = Thread {
            try {
                track.play()
                var offset = 0
                while (active.get() && offset < frames.size) {
                    val written = track.write(
                        frames,
                        offset,
                        frames.size - offset,
                        AudioTrack.WRITE_BLOCKING,
                    )
                    if (written <= 0) throw IllegalStateException("AudioTrack write failed: $written")
                    offset += written
                }
                if (active.get()) {
                    completePlaybackSuccess()
                } else {
                    completePlaybackError("playback_stopped", "Android playback was stopped before completion.")
                }
            } catch (error: Throwable) {
                completePlaybackError("playback_failed", error.message)
            } finally {
                stopActiveRoute(notifyPlaybackStop = false)
            }
        }.also { it.start() }
    }

    private fun startCapture(call: MethodCall, result: MethodChannel.Result) {
        if (!ensureAvailable(result) || !validateFormat(call, result)) return
        if (captureSink == null) {
            result.error("capture_listener_missing", "Capture frames listener is not attached.", null)
            return
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            pendingCaptureResult = result
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), PERMISSION_REQUEST_CAPTURE)
            return
        }
        startCaptureAfterPermission(result)
    }

    private fun startCaptureAfterPermission(result: MethodChannel.Result) {
        if (!active.compareAndSet(false, true)) {
            result.error("route_active", "A live-audio operation is already active.", null)
            return
        }
        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE_HZ,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        if (minBuffer <= 0) {
            active.set(false)
            result.error("record_unavailable", "Android did not provide a PCM capture buffer.", null)
            return
        }
        val record = AudioRecord.Builder()
            .setAudioSource(MediaRecorder.AudioSource.MIC)
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(SAMPLE_RATE_HZ)
                    .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build(),
            )
            .setBufferSizeInBytes(maxOf(minBuffer, 4096))
            .build()
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            active.set(false)
            result.error("record_unavailable", "Android could not initialize the requested PCM record.", null)
            return
        }
        if (!hasAudioModemV1Format(record.sampleRate, record.channelCount, record.audioFormat)) {
            record.release()
            active.set(false)
            result.error("format_mismatch", "Android record did not preserve 48000 Hz mono pcm_s16le.", null)
            return
        }
        record.addOnRoutingChangedListener(routingListener, mainHandler)
        audioRecord = record
        try {
            record.startRecording()
        } catch (error: Throwable) {
            record.release()
            audioRecord = null
            active.set(false)
            result.error("capture_failed", error.message, null)
            return
        }
        captureThread = Thread {
            val buffer = ByteArray(maxOf(minBuffer, 4096))
            try {
                while (active.get()) {
                    val read = record.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
                    if (read <= 0) throw IllegalStateException("AudioRecord read failed: $read")
                    captureSink?.success(buffer.copyOf(read))
                }
            } catch (error: Throwable) {
                mainHandler.post { captureSink?.error("capture_failed", error.message, null) }
            } finally {
                stopActiveRoute()
            }
        }.also { it.start() }
        result.success(null)
    }

    private fun ensureAvailable(result: MethodChannel.Result): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) return true
        result.error("api_unsupported", "Android foreground live audio v1 requires API 26 or later.", null)
        return false
    }

    private fun validateFormat(call: MethodCall, result: MethodChannel.Result): Boolean {
        val sampleRate = call.argument<Int>("sampleRateHz")
        val channels = call.argument<Int>("channels")
        val format = call.argument<String>("sampleFormat")
        if (sampleRate == SAMPLE_RATE_HZ && channels == CHANNELS && format == SAMPLE_FORMAT) {
            return true
        }
        result.error(
            "format_mismatch",
            "Android live-audio v1 requires 48000 Hz mono pcm_s16le.",
            null,
        )
        return false
    }

    private fun hasAudioModemV1Format(sampleRate: Int, channelCount: Int, encoding: Int): Boolean =
        sampleRate == SAMPLE_RATE_HZ &&
            channelCount == CHANNELS &&
            encoding == AudioFormat.ENCODING_PCM_16BIT

    private fun requestPlaybackFocus(): Int {
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .setOnAudioFocusChangeListener(focusListener)
            .build()
        focusRequest = request
        return audioManager.requestAudioFocus(request)
    }

    private fun abandonPlaybackFocus() {
        focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
        focusRequest = null
    }

    private fun completePlaybackSuccess() {
        val result = pendingPlaybackResult ?: return
        pendingPlaybackResult = null
        mainHandler.post { result.success(null) }
    }

    private fun completePlaybackError(code: String, message: String?) {
        val result = pendingPlaybackResult ?: return
        pendingPlaybackResult = null
        mainHandler.post { result.error(code, message, null) }
    }

    @Synchronized
    private fun stopActiveRoute(notifyPlaybackStop: Boolean = true) {
        active.set(false)
        if (notifyPlaybackStop) {
            completePlaybackError("playback_stopped", "Android playback was stopped or interrupted.")
        }
        audioTrack?.let { track ->
            try {
                if (track.playState == AudioTrack.PLAYSTATE_PLAYING) track.stop()
                track.flush()
            } catch (_: IllegalStateException) {
                // The route is already stopping or stopped.
            }
            track.removeOnRoutingChangedListener(routingListener)
            track.release()
        }
        audioTrack = null
        audioRecord?.let { record ->
            try {
                if (record.recordingState == AudioRecord.RECORDSTATE_RECORDING) record.stop()
            } catch (_: IllegalStateException) {
                // The route is already stopping or stopped.
            }
            record.removeOnRoutingChangedListener(routingListener)
            record.release()
        }
        audioRecord = null
        abandonPlaybackFocus()
    }
}

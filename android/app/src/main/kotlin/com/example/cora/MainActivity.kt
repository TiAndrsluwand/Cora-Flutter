package com.example.cora

import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.*

class MainActivity : FlutterActivity() {
    private val CHANNEL = "instant_metronome"
    private var audioTrack: AudioTrack? = null
    private val sampleRate = 44100
    private var volume = 0.8
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    try {
                        initializeAudio()
                        volume = call.argument<Double>("volume") ?: 0.8
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INIT_ERROR", "Failed to initialize audio: ${e.message}", null)
                    }
                }
                "playBeat" -> {
                    try {
                        val isStrong = call.argument<Boolean>("isStrong") ?: false
                        val frequency = call.argument<Double>("frequency") ?: 800.0
                        playInstantBeat(frequency, isStrong)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("PLAY_ERROR", "Failed to play beat: ${e.message}", null)
                    }
                }
                "setVolume" -> {
                    try {
                        volume = call.argument<Double>("volume") ?: 0.8
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("VOLUME_ERROR", "Failed to set volume: ${e.message}", null)
                    }
                }
                "stop" -> {
                    try {
                        stopAudio()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("STOP_ERROR", "Failed to stop audio: ${e.message}", null)
                    }
                }
                "dispose" -> {
                    try {
                        disposeAudio()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("DISPOSE_ERROR", "Failed to dispose audio: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun initializeAudio() {
        val bufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        
        audioTrack = AudioTrack(
            AudioManager.STREAM_MUSIC,
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufferSize,
            AudioTrack.MODE_STREAM
        )
        
        audioTrack?.play()
    }
    
    private fun playInstantBeat(frequency: Double, isStrong: Boolean) {
        if (audioTrack == null) return
        
        // Generar click ultra-corto (20ms) para mínima latencia
        val durationMs = if (isStrong) 20 else 15
        val samples = (sampleRate * durationMs / 1000.0).toInt()
        val buffer = ShortArray(samples)
        
        // Síntesis directa de onda sinusoidal con decay exponencial
        for (i in 0 until samples) {
            val t = i.toDouble() / sampleRate
            val envelope = exp(-t * 50) // Decay rápido para click nítido
            val signal = sin(2 * PI * frequency * t) * envelope * volume * Short.MAX_VALUE * 0.7
            buffer[i] = signal.toInt().coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt()).toShort()
        }
        
        // Reproducir inmediatamente sin buffering
        Handler(Looper.getMainLooper()).post {
            audioTrack?.write(buffer, 0, samples)
        }
    }
    
    private fun stopAudio() {
        audioTrack?.pause()
        audioTrack?.flush()
    }
    
    private fun disposeAudio() {
        audioTrack?.stop()
        audioTrack?.release()
        audioTrack = null
    }
}

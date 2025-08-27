import 'dart:typed_data';

class WavData {
  final Float32List samples;
  final double sampleRate;
  WavData(this.samples, this.sampleRate);
}

class WavDecoder {
  static WavData? decode(Uint8List bytes) {
    print('WAV Decoder: Processing ${bytes.length} bytes');
    if (bytes.length < 44) {
      print('WAV Decoder ERROR: File too small (${bytes.length} < 44 bytes)');
      return null;
    }
    final header = ByteData.sublistView(bytes, 0, 44);
    // 'RIFF'
    final riffId = header.getUint32(0, Endian.little);
    if (riffId != 0x46464952) {
      print('WAV Decoder ERROR: Invalid RIFF header: 0x${riffId.toRadixString(16)}');
      return null;
    }
    // 'WAVE'
    final waveId = header.getUint32(8, Endian.little);
    if (waveId != 0x45564157) {
      print('WAV Decoder ERROR: Invalid WAVE header: 0x${waveId.toRadixString(16)}');
      return null;
    }
    // 'fmt '
    final fmtId = header.getUint32(12, Endian.little);
    if (fmtId != 0x20746d66) {
      print('WAV Decoder ERROR: Invalid fmt header: 0x${fmtId.toRadixString(16)}');
      return null;
    }
    final audioFormat = header.getUint16(20, Endian.little);
    final numChannels = header.getUint16(22, Endian.little);
    final sampleRate = header.getUint32(24, Endian.little);
    final bitsPerSample = header.getUint16(34, Endian.little);
    print('WAV Format: ${audioFormat==1 ? 'PCM' : 'Unknown'}, ${numChannels}ch, ${sampleRate}Hz, ${bitsPerSample}bit');
    if (audioFormat != 1 || bitsPerSample != 16) {
      print('WAV Decoder ERROR: Unsupported format (need PCM 16-bit, got format=$audioFormat bits=$bitsPerSample)');
      return null; // PCM 16 only
    }
    // Find 'data' chunk by scanning chunks safely
    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0, Endian.little);
      final size = ByteData.sublistView(bytes, offset + 4, offset + 8).getUint32(0, Endian.little);
      offset += 8;
      if (id == 0x61746164) { // 'data'
        // Guard
        if (offset + size > bytes.length) {
          print('WAV Decoder ERROR: Data chunk size ${size} exceeds file bounds');
          return null;
        }
        print('WAV Decoder: Found data chunk, ${size} bytes');
        final bd = ByteData.sublistView(bytes, offset, offset + size);
        final totalSamples = size ~/ 2; // 16-bit samples across all channels
        if (numChannels <= 1) {
          final out = Float32List(totalSamples);
          for (int i = 0; i < totalSamples; i++) {
            final s = bd.getInt16(i * 2, Endian.little);
            out[i] = s / 32768.0;
          }
          print('WAV Decoder SUCCESS: ${out.length} mono samples');
          return WavData(out, sampleRate.toDouble());
        } else {
          // Downmix interleaved channels to mono: average across channels
          final frames = totalSamples ~/ numChannels;
          final out = Float32List(frames);
          int byteIndex = 0;
          for (int f = 0; f < frames; f++) {
            double sum = 0;
            for (int ch = 0; ch < numChannels; ch++) {
              final s = bd.getInt16(byteIndex, Endian.little);
              byteIndex += 2;
              sum += s / 32768.0;
            }
            out[f] = (sum / numChannels).clamp(-1.0, 1.0).toDouble();
          }
          print('WAV Decoder SUCCESS: ${out.length} downmixed samples from ${numChannels} channels');
          return WavData(out, sampleRate.toDouble());
        }
      } else {
        offset += size;
      }
    }
    print('WAV Decoder ERROR: No data chunk found');
    return null;
  }
}

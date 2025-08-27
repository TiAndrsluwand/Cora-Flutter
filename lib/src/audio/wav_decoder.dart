import 'dart:typed_data';

class WavData {
  final Float32List samples;
  final double sampleRate;
  WavData(this.samples, this.sampleRate);
}

class WavDecoder {
  static WavData? decode(Uint8List bytes) {
    if (bytes.length < 44) return null;
    final header = ByteData.sublistView(bytes, 0, 44);
    // 'RIFF'
    if (header.getUint32(0, Endian.little) != 0x46464952) return null;
    // 'WAVE'
    if (header.getUint32(8, Endian.little) != 0x45564157) return null;
    // 'fmt '
    if (header.getUint32(12, Endian.little) != 0x20746d66) return null;
    final audioFormat = header.getUint16(20, Endian.little);
    final numChannels = header.getUint16(22, Endian.little);
    final sampleRate = header.getUint32(24, Endian.little);
    final bitsPerSample = header.getUint16(34, Endian.little);
    if (audioFormat != 1 || bitsPerSample != 16) return null; // PCM 16 only
    // Find 'data' chunk by scanning chunks safely
    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = ByteData.sublistView(bytes, offset, offset + 4).getUint32(0, Endian.little);
      final size = ByteData.sublistView(bytes, offset + 4, offset + 8).getUint32(0, Endian.little);
      offset += 8;
      if (id == 0x61746164) { // 'data'
        // Guard
        if (offset + size > bytes.length) return null;
        final bd = ByteData.sublistView(bytes, offset, offset + size);
        final totalSamples = size ~/ 2; // 16-bit samples across all channels
        if (numChannels <= 1) {
          final out = Float32List(totalSamples);
          for (int i = 0; i < totalSamples; i++) {
            final s = bd.getInt16(i * 2, Endian.little);
            out[i] = s / 32768.0;
          }
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
          return WavData(out, sampleRate.toDouble());
        }
      } else {
        offset += size;
      }
    }
    return null;
  }
}

# Cora Flutter App

A Flutter rewrite of Cora with audio recording, pitch detection, and chord analysis.

## Features
- **Professional Audio Recording** - Record audio up to 20 seconds with optional metronome count-in
- **Advanced Music Analysis** - Analyze recordings for musical key detection and pitch analysis
- **Chord Progression Engine** - Generate intelligent chord progression suggestions based on detected melody
- **Interactive Piano Keyboard** - Visual chord display with responsive piano interface and orange highlighting
- **Professional Metronome System** - Real-time adjustable BPM (60-200), multiple time signatures, count-in functionality
- **Realistic Audio Playback** - Piano sound synthesis with harmonics and realistic envelopes
- **Progressive Disclosure UI** - Clean, expandable interface optimized for mobile recording workflow

## Setup Instructions

### Prerequisites
- Flutter SDK (3.0.0 or higher)
- Android Studio (for Android development)
- Android SDK (API level 21+)

### Installation Steps

1. **Navigate to the Flutter project directory:**
   ```bash
   cd Cora-Flutter
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **Create platform-specific files:**
   ```bash
   flutter create .
   ```

4. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   ```

## Running the App

### Android (Recommended)
1. Start an Android emulator or connect a device
2. Run:
   ```bash
   flutter run
   ```

### Windows Desktop
1. Enable Windows desktop support:
   ```bash
   flutter config --enable-windows-desktop
   ```
2. Run:
   ```bash
   flutter run -d windows
   ```

### Web
```bash
flutter run -d chrome
```

## Troubleshooting

### Common Issues

1. **Gradle build errors:**
   - Run `flutter clean` then `flutter pub get`
   - Ensure Android SDK is properly configured

2. **Permission errors:**
   - Grant microphone permission when prompted
   - Check that RECORD_AUDIO permission is in AndroidManifest.xml

3. **Plugin compatibility:**
   - The app now uses `flutter_sound` instead of the problematic `flutter_midi`
   - Chord playback uses simple tone synthesis

### Dependencies
- `record`: Professional audio recording functionality
- `just_audio`: High-quality audio playback engine  
- `permission_handler`: Microphone and system permissions
- `path_provider`: Temporary file management for audio
- `audio_session`: Cross-platform audio session management

## Project Structure
```
lib/
├── main.dart                 # App entry point
├── src/
│   ├── recorder/            # Recording UI with progressive disclosure design
│   ├── widgets/             # Interactive components (piano, metronome controls, count-in)
│   ├── audio/               # Audio processing (pitch detection, WAV decoding)
│   ├── analysis/            # Advanced key detection and chord analysis
│   ├── theory/              # Music theory utilities and constants
│   └── sound/               # Professional audio synthesis and metronome
```

## Recent Major Updates
- **Real-time Metronome Controls** - BPM and time signature adjustments during continuous playback
- **Professional Recording Workflow** - Count-in functionality with visual indicators
- **Enhanced Piano Interface** - Consistent orange highlighting with responsive design
- **UI Cleanup** - Removed redundant cards for streamlined, professional interface
- **Progressive Disclosure** - Expandable settings panels for optimal screen space usage

## Technical Notes
- **Audio Recording** - Professional 20-second WAV recording with optional metronome count-in
- **Pitch Detection** - Advanced autocorrelation algorithm with note consolidation
- **Key Detection** - Krumhansl-Schmuckler profiles for accurate musical key identification
- **Chord Engine** - Intelligent progression suggestions based on detected melody and key
- **Audio Synthesis** - Realistic piano sounds with harmonics and exponential decay envelopes
- **Metronome System** - Sharp click synthesis with strong/weak beat patterns (1200Hz/800Hz)

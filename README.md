# Cora Flutter App

A Flutter rewrite of Cora with audio recording, pitch detection, and chord analysis.

## Features
- Record audio up to 20 seconds
- Analyze recordings for musical key detection
- Generate chord progression suggestions
- Play chord sounds (simple tone synthesis)

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
- `record`: Audio recording
- `just_audio`: Audio playback
- `flutter_sound`: Sound generation
- `permission_handler`: Android permissions
- `http`: Network requests

## Project Structure
```
lib/
├── main.dart                 # App entry point
├── src/
│   ├── recorder/            # Recording UI and logic
│   ├── audio/               # Audio processing (pitch detection, WAV decoding)
│   ├── analysis/            # Key detection and chord analysis
│   ├── theory/              # Music theory helpers
│   └── sound/               # Chord playback
```

## Notes
- Audio recording is limited to 20 seconds
- Pitch detection uses autocorrelation algorithm
- Key detection uses Krumhansl-Schmuckler profiles
- Chord suggestions are generated based on detected melody
- Sound playback uses simple sine wave synthesis

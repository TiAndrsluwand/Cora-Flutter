# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status & Context (Updated: 2025)

### Recent Major Changes & Fixes
1. **Audio Playback System**: Migrated from flutter_sound to just_audio for reliable chord playback
2. **Piano Keyboard Component**: Added interactive piano with visual chord highlighting
3. **UI Improvements**: Removed debug info, test tone, pause button for cleaner interface
4. **Animation**: Added bouncing musical note during recording
5. **Chord Integration**: Fixed note parsing issues (F,A,C → F4,A4,C4)
6. **Hot Reload**: Fixed static resource management for proper hot reload support
7. **Piano Widget Refactor**: Simplified interface by removing dropdown selector for minimal design
8. **Visual Highlighting**: Enhanced chord visualization with consistent orange styling and improved contrast

### Known Working Features
- ✅ Audio recording (20-second WAV files)
- ✅ Pitch detection and analysis
- ✅ Key detection and chord suggestions
- ✅ Interactive piano keyboard with chord visualization
- ✅ Chord playback with realistic piano synthesis
- ✅ Visual feedback (bouncing note, progress bars, chord highlighting)
- ✅ Clean UI without debug elements

### Recent Bug Fixes
- **Note Parsing**: Fixed "Failed to parse note: F" - now correctly maps F→F4, A→A4, C→C4
- **Audio Playback**: Switched to just_audio with temp files instead of flutter_sound fromDataBuffer
- **Hot Reload**: Added proper ChordPlayer.dispose() to prevent static resource conflicts
- **Piano Integration**: Connected chord buttons to piano keyboard selection and audio
- **Visual Inconsistency**: Fixed incomplete orange highlighting - all chord notes now have consistent borders and indicator dots
- **UI Clutter**: Removed dropdown selector from piano widget for cleaner, more intuitive interface

## Common Commands

### Development
```bash
# Get dependencies
flutter pub get

# Run on Android (recommended)
flutter run

# Run on specific platform
flutter run -d windows
flutter run -d chrome

# Clean and rebuild (if hot reload issues)
flutter clean
flutter pub get
```

### Quality Assurance
```bash
# Analyze code for errors and warnings
flutter analyze

# Run tests
flutter test
```

## Project Architecture

This is a Flutter music analysis app that records audio, detects pitch/key, and suggests chord progressions with an interactive piano interface.

### Core Structure
- **lib/main.dart**: App entry point with MaterialApp setup
- **lib/src/recorder/**: Main UI (RecorderPage) - recording, playback, analysis, piano integration
- **lib/src/widgets/**: Interactive piano keyboard component
- **lib/src/audio/**: Low-level audio processing (WAV decoding, pitch detection, note conversion)
- **lib/src/analysis/**: Music theory logic (key detection, chord engine, progression suggestions)
- **lib/src/sound/**: Audio synthesis for chord playback (now using just_audio)
- **lib/src/theory/**: Music theory utilities

### Audio Processing Pipeline
1. **Recording**: Uses `record` package to capture 20-second WAV files
2. **Pitch Detection**: Autocorrelation algorithm analyzes audio samples
3. **Note Consolidation**: Converts pitch data to discrete musical notes
4. **Key Detection**: Uses Krumhansl-Schmuckler profiles for key identification
5. **Chord Suggestions**: Generates progressions based on detected melody and key
6. **Piano Visualization**: Shows chord notes on interactive piano keyboard
7. **Audio Playback**: Synthesizes and plays chord sounds via just_audio

### Key Dependencies
- `record`: Audio recording functionality
- `just_audio`: Audio playback (replaced flutter_sound for reliability)
- `permission_handler`: Microphone permissions
- `audio_session`: Cross-platform audio session management
- `path_provider`: Temporary file management for audio playback

### Audio Session Management
The app switches between recording and playback audio sessions to handle microphone access and speaker output properly across platforms.

### Platform Support
- Primary: Android (recommended)
- Secondary: Windows desktop, Web, iOS
- Audio recording requires microphone permissions on all platforms

## Component Details

### PianoKeyboard Widget
**Location**: `lib/src/widgets/piano_keyboard.dart`
**Features**:
- 2 octaves (C4-B5) with proper black key positioning
- Real piano layout with correct spacing
- **Enhanced visual chord highlighting**:
  - Consistent orange color (#FF9500) throughout
  - 3px orange borders for active chord notes
  - Orange indicator dots with white borders (8px white keys, 6px black keys)
  - Subtle box shadows for visual depth
  - Professional, polished appearance
- **Minimal interface**: No dropdown selector - chord selection handled by main UI buttons
- **Clear chord display**: Shows "Am: A, C, E" format above piano keys
- Integration with DetectedChord objects from analysis
- Unmistakable visual feedback for which keys belong to current chord

### ChordPlayer (Audio Engine)
**Location**: `lib/src/sound/chord_player.dart`
**Features**:
- Piano sound synthesis with harmonics and envelopes
- Note parsing: supports both "F4" and "F" formats (defaults to octave 4)
- Uses just_audio with temporary WAV files for reliable playback
- Comprehensive error handling and fallback test tones
- Proper resource cleanup for hot reload support

### RecorderPage (Main UI)
**Location**: `lib/src/recorder/recorder_page.dart`
**Features**:
- Recording interface with progress indicator and bouncing note animation
- Analysis workflow with loading overlay
- Chord progression display with clickable buttons
- Piano keyboard integration with state synchronization
- Clear results functionality

## Troubleshooting

### Hot Reload Issues
- Run `flutter clean && flutter pub get`
- Restart the app completely
- ChordPlayer.dispose() is properly integrated

### Audio Not Playing
- Check device volume and permissions
- Logs will show "ChordPlayer: Attempting to play chord with notes: [F4, A4, C4]"
- If notes show as [F, A, C], the _voiceChord mapping failed

### Note Parsing Errors
- Fixed: Parser now handles both "F4" and "F" formats
- Fallback to octave 4 for notes without octave specification
- Check logs for "Failed to parse note:" messages

### Piano Keyboard Issues
- **Visual Highlighting**: All chord notes should show consistent orange borders (3px) and indicator dots
- **Interface**: Piano widget no longer has dropdown - chord selection controlled by main UI buttons
- **State Updates**: Ensure chord buttons call setState() to update _selectedChord
- **Chord Display**: Should show format like "Am: A, C, E" above piano keys
- **Color Consistency**: All highlighting uses Color(0xFFFF9500) orange throughout

### Visual Highlighting Checklist
When chord "Am" is selected, verify:
- ✅ Keys A, C, E ALL have 3px orange borders
- ✅ Keys A, C, E ALL have orange indicator dots with white borders  
- ✅ Chord info displays as "Am: A, C, E" above piano
- ✅ No dropdown selector present (removed for minimal design)
- ✅ Consistent styling across white and black keys
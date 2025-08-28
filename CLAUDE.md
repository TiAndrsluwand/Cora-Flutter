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
9. **Metronome System**: Comprehensive metronome with count-in functionality for professional recording workflow
10. **Real-time Metronome Controls**: BPM and time signature adjustments during continuous playback
11. **Progressive Disclosure UI**: ExpansionTile-based interface with Card layout for optimal screen usage
12. **UI Cleanup**: Removed redundant "Ready to Record" card for streamlined, professional interface

### Known Working Features
- ✅ Audio recording (20-second WAV files)
- ✅ Pitch detection and analysis
- ✅ Key detection and chord suggestions
- ✅ Interactive piano keyboard with chord visualization
- ✅ Chord playback with realistic piano synthesis
- ✅ Visual feedback (bouncing note, progress bars, chord highlighting)
- ✅ Clean UI without debug elements
- ✅ **Professional metronome system with count-in functionality**
- ✅ **Real-time BPM and time signature adjustments during continuous playback**
- ✅ **Configurable BPM (60-200) and time signatures (4/4, 3/4, 2/4, 6/8, 2/2)**
- ✅ **Visual count-in indicators with beat tracking**
- ✅ **Strong/weak beat audio patterns (downbeat emphasis)**
- ✅ **Progressive disclosure UI with ExpansionTile metronome controls**
- ✅ **Clean, streamlined interface without redundant cards**

### Recent Bug Fixes
- **Note Parsing**: Fixed "Failed to parse note: F" - now correctly maps F→F4, A→A4, C→C4
- **Audio Playback**: Switched to just_audio with temp files instead of flutter_sound fromDataBuffer
- **Hot Reload**: Added proper ChordPlayer.dispose() to prevent static resource conflicts
- **Piano Integration**: Connected chord buttons to piano keyboard selection and audio
- **Visual Inconsistency**: Fixed incomplete orange highlighting - all chord notes now have consistent borders and indicator dots
- **UI Clutter**: Removed dropdown selector from piano widget for cleaner, more intuitive interface
- **BPM Real-time Updates**: Fixed BPM slider changes not affecting live metronome tempo during continuous playback
- **Redundant UI Elements**: Removed "Ready to Record" card that provided no additional value

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
- **lib/src/widgets/**: Interactive components (piano keyboard, metronome controls, count-in indicator)
- **lib/src/audio/**: Low-level audio processing (WAV decoding, pitch detection, note conversion)
- **lib/src/analysis/**: Music theory logic (key detection, chord engine, progression suggestions)
- **lib/src/sound/**: Audio synthesis (chord playback and metronome using just_audio)
- **lib/src/theory/**: Music theory utilities

### Audio Processing Pipeline
1. **Metronome Count-In** (optional): Plays count-in measure before recording starts
2. **Recording**: Uses `record` package to capture 20-second WAV files
3. **Pitch Detection**: Autocorrelation algorithm analyzes audio samples
4. **Note Consolidation**: Converts pitch data to discrete musical notes
5. **Key Detection**: Uses Krumhansl-Schmuckler profiles for key identification
6. **Chord Suggestions**: Generates progressions based on detected melody and key
7. **Piano Visualization**: Shows chord notes on interactive piano keyboard
8. **Audio Playback**: Synthesizes and plays chord sounds via just_audio

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

### MetronomePlayer (Timing Engine)
**Location**: `lib/src/sound/metronome_player.dart`
**Features**:
- Comprehensive metronome system with professional recording workflow
- Configurable BPM (60-200) and time signatures (4/4, 3/4, 2/4, 6/8, 2/2)
- Count-in functionality: plays one full measure before recording starts
- Strong beat (downbeat) vs weak beat audio differentiation (1200Hz vs 800Hz)
- Visual beat tracking with real-time callbacks
- Optional metronome continuation during recording
- Sharp click synthesis with exponential decay envelope
- Proper resource cleanup and hot reload support

### MetronomeControls Widget
**Location**: `lib/src/widgets/metronome_controls.dart`
**Features**:
- Professional metronome control interface
- BPM adjustment via slider, text input, and increment/decrement buttons
- Time signature dropdown with common patterns
- Advanced settings (volume control, continue during recording)
- Real-time settings synchronization with MetronomePlayer
- Informational tooltips and help text

### CountInIndicator Widget
**Location**: `lib/src/widgets/count_in_indicator.dart`
**Features**:
- Visual count-in display with animated beat indicators
- Phase-specific styling (amber for count-in, red for recording)
- Real-time beat tracking with pulse animations
- Downbeat emphasis (beat 1 has thicker border)
- Scale animation for smooth phase transitions
- Professional recording status display

### RecorderPage (Main UI)
**Location**: `lib/src/recorder/recorder_page.dart`
**Features**:
- Recording interface with progress indicator and bouncing note animation
- **Integrated metronome system with count-in workflow**
- Analysis workflow with loading overlay
- Chord progression display with clickable buttons
- Piano keyboard integration with state synchronization
- **Visual count-in indicators and beat tracking**
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

### Metronome System Issues
- **Count-In Not Working**: Ensure metronome is enabled in controls and BPM is set properly
- **Audio Not Playing**: Check volume settings and device audio permissions
- **Beat Timing**: Verify BPM calculations (60000ms / BPM = beat interval)
- **Phase Transitions**: Count-in should automatically transition to recording after full measure
- **Visual Indicators**: Beat circles should pulse and change color based on phase
- **Hot Reload**: MetronomePlayer.dispose() is properly integrated for cleanup

### Metronome Workflow Verification
When "Use Metronome" is enabled and user presses Record:
1. ✅ Shows "Get ready... Count-in starting!" message
2. ✅ CountInIndicator appears with amber styling
3. ✅ Plays count-in measure (e.g., 4 beats for 4/4 time)
4. ✅ Visual beat indicators pulse in sequence
5. ✅ After count-in completes, transitions to recording phase
6. ✅ Recording indicator turns red, actual audio recording begins
7. ✅ Optional: Metronome continues during recording if enabled

### Latest Improvements (December 2025)

#### Real-time Metronome Controls
- **BPM Slider Updates**: Live tempo changes during continuous metronome playback
- **Time Signature Changes**: Instant beat pattern updates without stopping playback
- **Auto-update Logic**: Enhanced setBpm() and setTimeSignature() methods with continuous mode detection
- **Timer Restart Mechanism**: Seamless tempo transitions without audio gaps

#### Progressive Disclosure UI Design
- **ExpansionTile Integration**: Collapsible metronome settings for better screen space utilization
- **Card-based Layout**: Professional visual hierarchy with Material Design principles
- **Animated Transitions**: Smooth expand/collapse animations for settings panels
- **Mobile-optimized**: Touch-friendly controls optimized for recording workflow

#### UI Cleanup and Streamlining
- **Removed Redundant Cards**: Eliminated "Ready to Record" card that provided no additional value
- **Cleaner Interface**: Streamlined layout focusing on essential recording controls
- **Reduced Visual Clutter**: Minimal design approach with progressive disclosure
- **Professional Appearance**: Clean, focused interface suitable for professional music recording

#### Technical Architecture Improvements  
- **Continuous Mode Detection**: Real-time parameter updates only when metronome is actively playing
- **State Management**: Proper handling of UI state updates during live parameter changes  
- **Performance Optimization**: Efficient timer restart mechanism for tempo changes
- **Error Handling**: Robust error handling for audio parameter updates
import 'package:flutter/material.dart';
import '../analysis/detected_chord.dart';

class PianoKeyboard extends StatefulWidget {
  final DetectedChord? selectedChord;
  final bool showChordNotes;

  const PianoKeyboard({
    super.key,
    this.selectedChord,
    this.showChordNotes = true,
  });

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  static const List<String> whiteKeys = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const List<String> blackKeys = ['C#', 'D#', '', 'F#', 'G#', 'A#', ''];

  // Consistent orange color for highlighting
  static const Color highlightOrange = Color(0xFFFF9500);

  bool _isKeyActive(String note) {
    if (widget.selectedChord == null) return false;
    // Remove octave numbers from notes for comparison
    final chordNotes = widget.selectedChord!.notes
        .map((n) => n.replaceAll(RegExp(r'\d+'), ''))
        .toList();
    return chordNotes.contains(note);
  }

  List<String> _getActiveNotes() {
    if (widget.selectedChord == null) return [];
    // Remove octave numbers from notes for display
    return widget.selectedChord!.notes
        .map((n) => n.replaceAll(RegExp(r'\d+'), ''))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.showChordNotes && widget.selectedChord != null) ...[
              Text(
                '${widget.selectedChord!.symbol}: ${_getActiveNotes().join(', ')}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: highlightOrange,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Piano keyboard - Responsive layout with LayoutBuilder
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate responsive key width based on available space
                const totalWhiteKeys = 14; // 2 octaves × 7 keys
                const keyMargin = 0.5;
                final availableWidth = constraints.maxWidth;
                final whiteKeyWidth = (availableWidth - (totalWhiteKeys * keyMargin)) / totalWhiteKeys;
                
                return SizedBox(
                  height: 80,
                  width: availableWidth,
                  child: Stack(
                    clipBehavior: Clip.hardEdge, // Prevent overflow
                    children: [
                      // White keys (2 octaves)
                      Row(
                        children: [
                          for (int octave = 0; octave < 2; octave++)
                            for (int i = 0; i < whiteKeys.length; i++)
                              _buildWhiteKey(
                                '${whiteKeys[i]}${octave + 4}', 
                                whiteKeys[i], 
                                whiteKeyWidth,
                              ),
                        ],
                      ),
                      // Black keys (2 octaves) - positioned responsively
                      for (int octave = 0; octave < 2; octave++)
                        for (int i = 0; i < blackKeys.length; i++)
                          if (blackKeys[i].isNotEmpty)
                            _buildBlackKey(
                              '${blackKeys[i]}${octave + 4}',
                              blackKeys[i], 
                              octave * 7 + i,
                              whiteKeyWidth,
                            ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteKey(String keyName, String note, double keyWidth) {
    final isActive = _isKeyActive(note);
    // Scale indicator dot and text size based on key width
    final dotSize = (keyWidth * 0.3).clamp(6.0, 10.0);
    final fontSize = (keyWidth * 0.3).clamp(6.0, 10.0);
    
    return Container(
      width: keyWidth,
      height: 80,
      margin: const EdgeInsets.only(right: 0.5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isActive ? highlightOrange : Colors.grey.shade300,
          width: isActive ? 3 : 1,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(3),
          bottomRight: Radius.circular(3),
        ),
        // Add subtle background tint for active keys
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: highlightOrange.withOpacity(0.1),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isActive)
            Container(
              width: dotSize,
              height: dotSize,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: highlightOrange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              note,
              style: TextStyle(
                fontSize: fontSize,
                color: isActive
                    ? highlightOrange.withOpacity(0.9)
                    : Colors.grey.shade600,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlackKey(String keyName, String note, int globalPosition, double whiteKeyWidth) {
    final isActive = _isKeyActive(note);

    // Calculate correct positioning based on responsive white key layout
    // In each octave: C# is between C-D, D# between D-E, F# between F-G, G# between G-A, A# between A-B
    final octave = globalPosition ~/ 7;
    final positionInOctave = globalPosition % 7;

    late double leftOffset;
    final whiteKeyWidthWithMargin = whiteKeyWidth + 0.5; // Include margin
    final octaveOffset = octave * 7 * whiteKeyWidthWithMargin;
    
    // Scale black key dimensions based on white key size
    final blackKeyWidth = (whiteKeyWidth * 0.65).clamp(10.0, 18.0);
    final blackKeyHeight = 50.0;
    final dotSize = (blackKeyWidth * 0.35).clamp(4.0, 8.0);
    final fontSize = (blackKeyWidth * 0.35).clamp(5.0, 8.0);

    switch (positionInOctave) {
      case 0: // C# - between C(0) and D(1)
        leftOffset = octaveOffset + (0.7 * whiteKeyWidthWithMargin);
        break;
      case 1: // D# - between D(1) and E(2)
        leftOffset = octaveOffset + (1.7 * whiteKeyWidthWithMargin);
        break;
      case 3: // F# - between F(3) and G(4)
        leftOffset = octaveOffset + (3.7 * whiteKeyWidthWithMargin);
        break;
      case 4: // G# - between G(4) and A(5)
        leftOffset = octaveOffset + (4.7 * whiteKeyWidthWithMargin);
        break;
      case 5: // A# - between A(5) and B(6)
        leftOffset = octaveOffset + (5.7 * whiteKeyWidthWithMargin);
        break;
      default:
        leftOffset = 0;
    }

    return Positioned(
      left: leftOffset,
      child: Container(
        width: blackKeyWidth,
        height: blackKeyHeight,
        decoration: BoxDecoration(
          color: isActive
              ? highlightOrange.withOpacity(0.8)
              : Colors.grey.shade800,
          border: Border.all(
            color: isActive ? highlightOrange : Colors.grey.shade700,
            width: isActive ? 3 : 1,
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(2),
            bottomRight: Radius.circular(2),
          ),
          // Add glow effect for active black keys
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: highlightOrange.withOpacity(0.3),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (isActive)
              Container(
                width: dotSize,
                height: dotSize,
                margin: const EdgeInsets.only(bottom: 3),
                decoration: BoxDecoration(
                  color: highlightOrange,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.8), width: 1),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                note.replaceAll('#', '♯'),
                style: TextStyle(
                  fontSize: fontSize,
                  color: isActive ? Colors.white : Colors.white70,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

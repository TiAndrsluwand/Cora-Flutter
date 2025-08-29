import 'package:flutter/material.dart';
import '../analysis/detected_chord.dart';
import '../theme/minimal_design_system.dart';

/// Minimal Piano Keyboard - Clean, functional, beautiful through restraint
/// 
/// Features:
/// - Pure white and black keys, no decoration
/// - Simple chord highlighting through outline
/// - Clean typography for chord display  
/// - No animations, effects, or visual clutter
/// - Horizontal scrolling for compact display
class MinimalPianoKeyboard extends StatefulWidget {
  final DetectedChord? selectedChord;
  final Function(String note)? onNotePressed;
  final int octaves;

  const MinimalPianoKeyboard({
    super.key,
    this.selectedChord,
    this.onNotePressed,
    this.octaves = 2,
  });

  @override
  State<MinimalPianoKeyboard> createState() => _MinimalPianoKeyboardState();
}

class _MinimalPianoKeyboardState extends State<MinimalPianoKeyboard> {
  static const List<String> whiteKeys = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  static const List<String> blackKeys = ['C#', 'D#', '', 'F#', 'G#', 'A#', ''];
  
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _isKeyActive(String note) {
    if (widget.selectedChord == null) return false;
    final chordNotes = widget.selectedChord!.notes
        .map((n) => n.replaceAll(RegExp(r'\d+'), ''))
        .toSet();
    return chordNotes.contains(note);
  }

  List<String> _getActiveNotes() {
    if (widget.selectedChord == null) return [];
    return widget.selectedChord!.notes
        .map((n) => n.replaceAll(RegExp(r'\d+'), ''))
        .toList();
  }

  void _handleKeyPress(String keyName) {
    widget.onNotePressed?.call(keyName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chord information - minimal typography
        if (widget.selectedChord != null) 
          _buildChordInfo(),
        
        MinimalDesign.verticalSpace(MinimalDesign.space3),
        
        // Piano keyboard
        SizedBox(
          height: 80,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: _buildKeyboard(),
          ),
        ),
      ],
    );
  }

  Widget _buildChordInfo() {
    final chord = widget.selectedChord!;
    final notes = _getActiveNotes();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          chord.symbol,
          style: MinimalDesign.heading,
        ),
        MinimalDesign.verticalSpace(MinimalDesign.space1),
        Text(
          notes.join('  '),
          style: MinimalDesign.caption,
        ),
      ],
    );
  }

  Widget _buildKeyboard() {
    return Stack(
      children: [
        // White keys
        Row(
          children: [
            for (int octave = 4; octave < 4 + widget.octaves; octave++)
              for (int i = 0; i < whiteKeys.length; i++)
                _buildWhiteKey('${whiteKeys[i]}$octave', whiteKeys[i]),
          ],
        ),
        
        // Black keys
        for (int octave = 4; octave < 4 + widget.octaves; octave++)
          for (int i = 0; i < blackKeys.length; i++)
            if (blackKeys[i].isNotEmpty)
              _buildBlackKey(
                '${blackKeys[i]}$octave',
                blackKeys[i],
                (octave - 4) * 7 + i,
              ),
      ],
    );
  }

  Widget _buildWhiteKey(String keyName, String note) {
    final isActive = _isKeyActive(note);
    
    return GestureDetector(
      onTap: () => _handleKeyPress(keyName),
      child: Container(
        width: 30,
        height: 80,
        decoration: BoxDecoration(
          color: MinimalDesign.white,
          border: Border.all(
            color: isActive ? MinimalDesign.black : MinimalDesign.lightGray,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              note,
              style: MinimalDesign.small.copyWith(
                color: isActive ? MinimalDesign.black : MinimalDesign.gray,
                fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBlackKey(String keyName, String note, int globalPosition) {
    final isActive = _isKeyActive(note);
    
    // Calculate position
    final octave = globalPosition ~/ 7;
    final positionInOctave = globalPosition % 7;
    
    late double leftOffset;
    const whiteKeyWidth = 30.0;
    const blackKeyWidth = 18.0;
    final octaveOffset = octave * 7 * whiteKeyWidth;
    
    switch (positionInOctave) {
      case 0: // C#
        leftOffset = octaveOffset + (whiteKeyWidth * 0.7);
        break;
      case 1: // D#
        leftOffset = octaveOffset + (whiteKeyWidth * 1.7);
        break;
      case 3: // F#
        leftOffset = octaveOffset + (whiteKeyWidth * 3.7);
        break;
      case 4: // G#
        leftOffset = octaveOffset + (whiteKeyWidth * 4.7);
        break;
      case 5: // A#
        leftOffset = octaveOffset + (whiteKeyWidth * 5.7);
        break;
      default:
        leftOffset = 0;
    }

    return Positioned(
      left: leftOffset,
      child: GestureDetector(
        onTap: () => _handleKeyPress(keyName),
        child: Container(
          width: blackKeyWidth,
          height: 50,
          decoration: BoxDecoration(
            color: isActive ? MinimalDesign.gray : MinimalDesign.black,
            border: isActive 
                ? Border.all(color: MinimalDesign.black, width: 2)
                : null,
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                note.replaceAll('#', '♯'),
                style: MinimalDesign.small.copyWith(
                  color: MinimalDesign.white,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../analysis/simple_sheet_music_service.dart';
import '../theme/minimal_design_system.dart';
import '../utils/debug_logger.dart';

class SimpleSheetMusicDisplay extends StatefulWidget {
  final SheetMusicData sheetMusicData;
  final VoidCallback? onClose;

  const SimpleSheetMusicDisplay({
    super.key,
    required this.sheetMusicData,
    this.onClose,
  });

  @override
  State<SimpleSheetMusicDisplay> createState() => _SimpleSheetMusicDisplayState();
}

class _SimpleSheetMusicDisplayState extends State<SimpleSheetMusicDisplay> {
  @override
  void initState() {
    super.initState();
    DebugLogger.debug('SimpleSheetMusicDisplay: Initialized with ${widget.sheetMusicData.notes.length} notes');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MinimalDesign.white,
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSheetMusicInfo(),
            Expanded(
              child: _buildSheetMusic(),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MinimalDesign.space3,
        vertical: MinimalDesign.space2,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: MinimalDesign.lightGray,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Sheet Music',
            style: MinimalDesign.title.copyWith(
              color: MinimalDesign.black,
            ),
          ),
          if (widget.onClose != null)
            GestureDetector(
              onTap: widget.onClose,
              child: Container(
                padding: const EdgeInsets.all(MinimalDesign.space1),
                child: Icon(
                  Icons.close,
                  color: MinimalDesign.black,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSheetMusicInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MinimalDesign.space3),
      decoration: BoxDecoration(
        color: MinimalDesign.isDarkMode 
            ? Color(0xFF2C2C2E)  // Dark mode: darker gray
            : Color(0xFFF8F8F8), // Light mode: light gray
        border: Border(
          bottom: BorderSide(
            color: MinimalDesign.lightGray,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key: ${widget.sheetMusicData.keySignature}',
                    style: MinimalDesign.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: MinimalDesign.black,
                    ),
                  ),
                  const SizedBox(height: MinimalDesign.space1),
                  Text(
                    'Time: ${widget.sheetMusicData.timeSignature}',
                    style: MinimalDesign.caption.copyWith(
                      color: MinimalDesign.primary,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${widget.sheetMusicData.bpm} BPM',
                    style: MinimalDesign.body.copyWith(
                      fontWeight: FontWeight.w500,
                      color: MinimalDesign.black,
                    ),
                  ),
                  const SizedBox(height: MinimalDesign.space1),
                  Text(
                    '${widget.sheetMusicData.notes.length} notes',
                    style: MinimalDesign.caption.copyWith(
                      color: MinimalDesign.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSheetMusic() {
    if (widget.sheetMusicData.notes.isEmpty) {
      return _buildEmptyState();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MinimalDesign.space3),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Melody:',
              style: MinimalDesign.heading.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: MinimalDesign.space3),
            
            // Musical notation display using text
            _buildTextNotation(),
            
            const SizedBox(height: MinimalDesign.space4),
            
            // Note sequence display
            _buildNoteSequence(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextNotation() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MinimalDesign.space3),
      decoration: BoxDecoration(
        color: MinimalDesign.secondary, // Adaptive background
        border: Border.all(
          color: MinimalDesign.lightGray,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Treble clef line
          Row(
            children: [
              Text(
                '𝄞', // Treble clef symbol
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w300,
                  color: MinimalDesign.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  height: 1,
                  color: MinimalDesign.primary,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: MinimalDesign.space3),
          
          // Notes display
          Wrap(
            spacing: 16.0,
            runSpacing: 8.0,
            children: widget.sheetMusicData.notes.map((note) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: MinimalDesign.isDarkMode
                      ? Color(0xFF3A3A3C)  // Dark mode: darker gray
                      : Color(0xFFF8F8F8), // Light mode: light gray
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: MinimalDesign.lightGray,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      note.duration.symbol,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: MinimalDesign.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      note.displayNote,
                      style: MinimalDesign.body.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSequence() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Note Sequence:',
          style: MinimalDesign.body.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: MinimalDesign.space2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(MinimalDesign.space3),
          decoration: BoxDecoration(
            color: MinimalDesign.isDarkMode
                ? Color(0xFF2C2C2E)  // Dark mode: darker gray
                : Color(0xFFF8F8F8), // Light mode: light gray
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: MinimalDesign.lightGray,
              width: 1,
            ),
          ),
          child: Text(
            widget.sheetMusicData.melodyText,
            style: TextStyle(
              fontSize: 16,
              fontFamily: 'monospace',
              height: 1.6,
              color: MinimalDesign.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MinimalDesign.space4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_note_outlined,
            size: 64,
            color: MinimalDesign.primary.withValues(alpha: 0.6),
          ),
          const SizedBox(height: MinimalDesign.space3),
          Text(
            'No melody detected',
            style: MinimalDesign.title.copyWith(
              color: MinimalDesign.primary,
            ),
          ),
          const SizedBox(height: MinimalDesign.space2),
          Text(
            'Record a melody to generate sheet music',
            style: MinimalDesign.body.copyWith(
              color: MinimalDesign.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(MinimalDesign.space3),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: MinimalDesign.lightGray,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: MinimalDesign.primary,
          ),
          const SizedBox(width: MinimalDesign.space1),
          Text(
            'Generated from recorded melody',
            style: MinimalDesign.caption.copyWith(
              color: MinimalDesign.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class SimpleSheetMusicModal extends StatelessWidget {
  final SheetMusicData sheetMusicData;

  const SimpleSheetMusicModal({
    super.key,
    required this.sheetMusicData,
  });

  static Future<void> show(BuildContext context, SheetMusicData sheetMusicData) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: MinimalDesign.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: SimpleSheetMusicDisplay(
            sheetMusicData: sheetMusicData,
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SimpleSheetMusicDisplay(
      sheetMusicData: sheetMusicData,
      onClose: () => Navigator.of(context).pop(),
    );
  }
}
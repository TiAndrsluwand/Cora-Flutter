class DetectedChord {
  final String symbol;
  final List<String> notes;

  DetectedChord({
    required this.symbol,
    required this.notes,
  });

  @override
  String toString() {
    return 'DetectedChord(symbol: $symbol, notes: $notes)';
  }
}

import 'dart:developer' as developer;

/// Production-safe debug logging utility
class DebugLogger {
  static const bool _kDebugMode = true; // Set to false for release builds
  
  /// Log debug information (only in debug mode)
  static void debug(String message, [String? name]) {
    if (_kDebugMode) {
      developer.log(message, name: name ?? 'Cora');
    }
  }
  
  /// Log info messages
  static void info(String message, [String? name]) {
    if (_kDebugMode) {
      developer.log('INFO: $message', name: name ?? 'Cora');
    }
  }
  
  /// Log warning messages
  static void warn(String message, [String? name]) {
    if (_kDebugMode) {
      developer.log('WARN: $message', name: name ?? 'Cora');
    }
  }
  
  /// Log error messages (always logged)
  static void error(String message, [String? name]) {
    developer.log('ERROR: $message', name: name ?? 'Cora');
  }
}
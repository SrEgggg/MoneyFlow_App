import 'dart:developer' as dev;

/// Simple application-wide logger for tracking system events,
/// repository operations, and unexpected errors.
class AppLogger {
  final String tag;

  AppLogger([this.tag = 'App']);

  void info(String message, {Object? error, StackTrace? stack}) {
    _log('INFO', message, error, stack);
  }

  void warn(String message, {Object? error, StackTrace? stack}) {
    _log('WARN', message, error, stack);
  }

  void error(String message, {Object? error, StackTrace? stack}) {
    _log('ERROR', message, error, stack);
  }

  void _log(String level, String message, Object? error, StackTrace? stack) {
    final timestamp = DateTime.now().toIso8601String();
    final logLine = '[$timestamp] [$tag] $level: $message';

    switch (level) {
      case 'INFO':
        dev.log(logLine, name: tag);
        break;
      case 'WARN':
        dev.log(logLine, name: tag, level: 900);
        break;
      case 'ERROR':
        dev.log(logLine, name: tag, level: 1000, error: error, stackTrace: stack);
        break;
    }
  }
}

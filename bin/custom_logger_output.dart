import 'dart:io';
import 'package:logger/logger.dart';

class FileOutput extends LogOutput {
  final File file;
  final bool printToConsole;

  FileOutput(this.file, {this.printToConsole = true}) {
    _initializeLogFile();
  }

  void _initializeLogFile() {
    try {
      print('Initializing log file: ${file.absolute.path}');
      final directory = Directory(file.parent.path);
      
      // Ensure directory exists with proper permissions
      if (!directory.existsSync()) {
        print('Creating logs directory: ${directory.absolute.path}');
        directory.createSync(recursive: true);
        Process.runSync('chmod', ['755', directory.path]);
        print('Logs directory created successfully with permissions set');
      }

      // Create or verify file with proper permissions
      if (!file.existsSync()) {
        print('Creating log file');
        file.createSync();
        Process.runSync('chmod', ['644', file.path]);
        print('Log file created successfully with permissions set');
      }

      // Write initial marker to verify file is writable
      final timestamp = DateTime.now().toIso8601String();
      file.writeAsStringSync('=== Log initialized at $timestamp ===\n', mode: FileMode.append);
      print('Successfully wrote initialization marker to log file');
      
    } catch (e, stackTrace) {
      print('Error initializing log file: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  void output(OutputEvent event) {
    try {
      // Ensure directory and file exist before writing
      if (!file.existsSync()) {
        print('Log file disappeared, recreating...');
        _initializeLogFile();
      }
      
      // Format timestamp and log level
      final timestamp = DateTime.now().toIso8601String();
      final level = event.level.toString().split('.').last.toUpperCase();
      
      // Format log entry with timestamp and level
      final logEntry = StringBuffer();
      logEntry.writeln('[$timestamp] [$level]');
      for (final line in event.lines) {
        logEntry.writeln('  $line');
      }
      logEntry.writeln('-' * 80); // Add separator for better readability
      
      // Write to file using RandomAccessFile for better control
      final raf = file.openSync(mode: FileMode.append);
      try {
        raf.writeStringSync(logEntry.toString());
        raf.flushSync();
      } finally {
        raf.closeSync();
      }
      
      // Also print to console if enabled
      if (printToConsole) {
        print(logEntry.toString());
      }
    } catch (e, stackTrace) {
      print('Error writing to log file: $e');
      print('Stack trace: $stackTrace');
      print('Attempted to log:');
      print(event.lines.join('\n'));
      
      // Try to recreate the file structure
      try {
        _initializeLogFile();
      } catch (e2) {
        print('Failed to recreate log file structure: $e2');
      }
    }
  }
}

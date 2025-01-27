// Import the dart:io library for file operations
import 'dart:io';
// Import the logger package
import 'package:logger/logger.dart';

// Define a class for file output
class FileOutput extends LogOutput {
  // Declare a final File object
  final File file;
  // Declare a final boolean to control console printing
  final bool printToConsole;

  // Constructor for FileOutput
  FileOutput(this.file, {this.printToConsole = true}) {
    // Initialize the log file
    _initializeLogFile();
  }

  // Method to initialize the log file
  void _initializeLogFile() {
    try {
      // Print the log file path
      print('Initializing log file: ${file.absolute.path}');
      // Get the directory of the log file
      final directory = Directory(file.parent.path);
      
      // Ensure directory exists with proper permissions
      if (!directory.existsSync()) {
        // Print that the directory is being created
        print('Creating logs directory: ${directory.absolute.path}');
        // Create the directory recursively
        directory.createSync(recursive: true);
        // Set directory permissions
        Process.runSync('chmod', ['755', directory.path]);
        // Print that the directory was created successfully
        print('Logs directory created successfully with permissions set');
      }

      // Create or verify file with proper permissions
      if (!file.existsSync()) {
        // Print that the log file is being created
        print('Creating log file');
        // Create the log file
        file.createSync();
        // Set file permissions
        Process.runSync('chmod', ['644', file.path]);
        // Print that the log file was created successfully
        print('Log file created successfully with permissions set');
      }

      // Write initial marker to verify file is writable
      final timestamp = DateTime.now().toIso8601String();
      // Write the initialization marker to the log file
      file.writeAsStringSync('=== Log initialized at $timestamp ===\n', mode: FileMode.append);
      // Print that the initialization marker was written successfully
      print('Successfully wrote initialization marker to log file');
      
    } catch (e, stackTrace) {
      // Print any errors that occur during initialization
      print('Error initializing log file: $e');
      // Print the stack trace
      print('Stack trace: $stackTrace');
      // Re-throw the exception
      rethrow;
    }
  }

  // Override the output method
  @override
  void output(OutputEvent event) {
    try {
      // Ensure directory and file exist before writing
      if (!file.existsSync()) {
        // Print that the log file disappeared and is being recreated
        print('Log file disappeared, recreating...');
        // Re-initialize the log file
        _initializeLogFile();
      }
      
      // Format timestamp and log level
      final timestamp = DateTime.now().toIso8601String();
      // Get the log level as a string
      final level = event.level.toString().split('.').last.toUpperCase();
      
      // Format log entry with timestamp and level
      final logEntry = StringBuffer();
      // Write the timestamp and level to the log entry
      logEntry.writeln('[$timestamp] [$level]');
      // Iterate through each line of the log event
      for (final line in event.lines) {
        // Write each line to the log entry
        logEntry.writeln('  $line');
      }
      // Add a separator for better readability
      logEntry.writeln('-' * 80);
      
      // Write to file using RandomAccessFile for better control
      final raf = file.openSync(mode: FileMode.append);
      try {
        // Write the log entry to the file
        raf.writeStringSync(logEntry.toString());
        // Flush the file
        raf.flushSync();
      } finally {
        // Close the file
        raf.closeSync();
      }
      
      // Also print to console if enabled
      if (printToConsole) {
        // Print the log entry to the console
        print(logEntry.toString());
      }
    } catch (e, stackTrace) {
      // Print any errors that occur during writing
      print('Error writing to log file: $e');
      // Print the stack trace
      print('Stack trace: $stackTrace');
      // Print the attempted log
      print('Attempted to log:');
      // Print the lines of the log event
      print(event.lines.join('\n'));
      
      // Try to recreate the file structure
      try {
        // Re-initialize the log file
        _initializeLogFile();
      } catch (e2) {
        // Print any errors that occur during recreation
        print('Failed to recreate log file structure: $e2');
      }
    }
  }
}

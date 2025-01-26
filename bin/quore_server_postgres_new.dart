import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:postgres/postgres.dart';
import 'package:qore_server_postgres/firebase_stuff.dart';
import 'package:qore_server_postgres/qore_server_postgres_funcs.dart';
import 'custom_logger_output.dart' as custom;

/*

  % psql postgres


  CREATE ROLE postgres WITH LOGIN PASSWORD 'root';
  ALTER ROLE postgres CREATEDB;

  postgres=# create database qore;
  CREATE DATABASE

  Antes de poder insertar los registros:

  % psql postgres

  postgres=# \c qore;    <- Me conecto a la BD (equivalente al use de MySQL)

  qore=# GRANT USAGE, SELECT ON SEQUENCE pacientes_id_seq TO postgres;
  GRANT

  Desde la línea de comando y conectado a qore (me conecto con \c qore)
  (https://en-wiki.ikoula.com/en/Adding_an_extension_in_PostgreSQL)
  CREATE EXTENSION IF NOT EXISTS "unaccent";
  qore=# CREATE INDEX idx_normalized_apellido ON pacientes (normalized_apellido);

*/

/// Represents the available commands that can be processed by the server
enum Command {
  addPatient,
  getPatientsByIdDoc,
  getPatientsByLastName,
  getPatientById,
  updatePatient,
  deletePatient,
  lockPatient,
  rollback,
  pong;

  /// Safely convert an integer to a Command
  static Command? fromIndex(int index) {
    if (index >= 0 && index < Command.values.length) {
      return Command.values[index];
    }
    return null;
  }
}

// https://stackoverflow.com/questions/66340807/flutter-how-to-show-log-output-in-console-and-automatically-store-it
final logFile = File('logs/server.log');
var logger = Logger(
  filter: ProductionFilter(),
  printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: false, // Disable colors for file output
      printEmojis: false,
      printTime: true),
  output: custom.FileOutput(logFile, printToConsole: true),
);

var loggerNoStack = Logger(
  filter: ProductionFilter(),
  printer: PrettyPrinter(
      methodCount: 0,
      colors: false, // Disable colors for file output
      printEmojis: false,
      printTime: true),
  output: custom.FileOutput(logFile, printToConsole: true),
);

void main() async {
  try {
    // Logging levels explained. The most common logging levels include
    // FATAL, ERROR, WARN, INFO, DEBUG, TRACE, ALL, and OFF.
    Logger.level = Level.all;

    logger.i("==========================================");
    logger.i("Starting server at ${DateTime.now()}");
    logger.i("Log level: ${Logger.level}");
    logger.i("Log file path: ${logFile.absolute.path}");
    logger.d("Debug logging is enabled");
    logger.w("Warning logging is enabled");
    logger.e("Error logging is enabled");
    logger.i("==========================================");

    WebSocketServer(logger: logger).start();
  } catch (e, stackTrace) {
    logger.e("Error starting server", error: e, stackTrace: stackTrace);
    rethrow;
  }
}

/// A WebSocket server that handles patient data operations
class WebSocketServer {
  static const int port = 8080;
  final List<WebSocket> _clients = [];
  final Logger _logger;

  WebSocketServer({required Logger logger}) : _logger = logger;

  /// Starts the WebSocket server
  Future<void> start() async {
    SecurityContext? context;
    try {
      context = await _initializeSecurityContext();
    } catch (e, stackTrace) {
      _logger.e("Failed to initialize security context", error: e, stackTrace: stackTrace);
      rethrow;
    }

    late final HttpServer server;
    try {
      _logger.i("Attempting to bind server to port $port");
      server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      // For secure connections:
      // server = await HttpServer.bindSecure(InternetAddress.anyIPv4, port, context);
      _logger.i('WebSocket server successfully started on port $port');
      _logger.i('Server address: ${server.address}');
    } catch (e, stackTrace) {
      _logger.e("Failed to start server", error: e, stackTrace: stackTrace);
      rethrow;
    }

    await _handleIncomingConnections(server);
  }

  /// Initializes the security context for HTTPS/WSS
  Future<SecurityContext> _initializeSecurityContext() async {
    final certificate = await File('vcsinc_certificate.pem').readAsBytes();
    final privateKey = await File('vcsinc_private_key.pem').readAsBytes();

    _logger.d("Initializing security context");
    final context = SecurityContext()
      ..useCertificateChainBytes(certificate)
      ..usePrivateKeyBytes(privateKey);
    _logger.i("Security context initialized successfully");
    
    return context;
  }

  /// Handles incoming HTTP connections and upgrades them to WebSocket if appropriate
  Future<void> _handleIncomingConnections(HttpServer server) async {
    await for (final request in server) {
      _logger.d("New connection request received");

      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        _logger.w("Received non-WebSocket request, closing connection");
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write('WebSocket connections only')
          ..close();
        continue;
      }

      try {
        final postgresConnection = await _createDatabaseConnection();
        await _handleWebSocketConnection(request, postgresConnection);
      } catch (e, stackTrace) {
        _logger.e("Failed to handle connection", error: e, stackTrace: stackTrace);
        request.response
          ..statusCode = HttpStatus.internalServerError
          ..write('Internal server error')
          ..close();
      }
    }
  }

  /// Creates a new database connection
  Future<PostgreSQLConnection> _createDatabaseConnection() async {
    final connection = PostgreSQLConnection(
      'localhost', 
      5432, 
      'qore',
      username: 'postgres', 
      password: 'root',
      timeoutInSeconds: 30,
      queryTimeoutInSeconds: 30,
    );
    
    try {
      await connection.open();
      _logger.d("Database connection established");
      return connection;
    } catch (e) {
      _logger.e("Failed to connect to database", error: e);
      rethrow;
    }
  }

  /// Handles a WebSocket connection
  Future<void> _handleWebSocketConnection(
    HttpRequest request, 
    PostgreSQLConnection postgresConnection
  ) async {
    late final WebSocket webSocket;
    try {
      webSocket = await WebSocketTransformer.upgrade(request);
    } catch (e) {
      _logger.e("Failed to upgrade connection to WebSocket", error: e);
      request.response.close();
      return;
    }

    _clients.add(webSocket);
    _logger.i('Client connected');

    webSocket.listen(
      (message) async {
        _logger.d('Received message: $message');
        await _handleMessage(message, webSocket, postgresConnection);
      },
      onDone: () => _handleDisconnection(webSocket, postgresConnection),
      onError: (error) {
        _logger.e("WebSocket error", error: error);
        _handleDisconnection(webSocket, postgresConnection);
      },
      cancelOnError: true,
    );
  }

  /// Handles client disconnection
  Future<void> _handleDisconnection(
    WebSocket webSocket, 
    PostgreSQLConnection postgresConnection
  ) async {
    try {
      await postgresConnection.execute("ROLLBACK");
      await postgresConnection.close();
    } catch (e) {
      _logger.d("Error during cleanup: ${e.toString()}");
    } finally {
      _clients.remove(webSocket);
      _logger.i('Client disconnected');
    }
  }

  /// Handles incoming WebSocket messages
  Future<void> _handleMessage(
    dynamic message, 
    WebSocket webSocket, 
    PostgreSQLConnection postgresConnection
  ) async {
    try {
      final List<int> intList = message.toString().split(',').map((str) => int.parse(str)).toList();
      
      if (intList.isEmpty) {
        _logger.w("Received empty message");
        return;
      }

      final command = Command.fromIndex(intList[0]);
      if (command == null) {
        _logger.w("Invalid command index: ${intList[0]}");
        return;
      }

      final messageLength = intList[1] * 255 + intList[2];
      if (intList.length < 3 || intList.sublist(3).length != messageLength) {
        _logger.w("Invalid message format");
        return;
      }

      final decodedMessage = utf8.decode(intList.sublist(3));
      final parts = decodedMessage.split("|");
      if (parts.length != 2) {
        _logger.w("Invalid message format: missing token or data");
        return;
      }

      final firebaseToken = parts[0];
      final data = parts[1];

      _logger.d("Processing command: $command with token: $firebaseToken");

      if (!await validateUserFirebaseToken(firebaseToken)) {
        await _sendResponse("Usuario no autorizado", webSocket);
        return;
      }

      final responseMessage = await _processCommand(command, data, postgresConnection);
      await _sendResponse(responseMessage, webSocket);
    } catch (e, stackTrace) {
      _logger.e("Error processing message", error: e, stackTrace: stackTrace);
      await _sendResponse('{"Result":"Failure","Message":"Error interno del servidor"}', webSocket);
    }
  }

  /// Processes a command and returns the response
  Future<String> _processCommand(
    Command command,
    String data,
    PostgreSQLConnection postgresConnection
  ) async {
    switch (command) {
      case Command.getPatientsByLastName:
        return await getPatientsByLastName(data, postgresConnection);
      case Command.getPatientsByIdDoc:
        return await getPatientsByIdDoc(data, postgresConnection);
      case Command.getPatientById:
        return await getPatientById(data, postgresConnection);
      case Command.addPatient:
        return await addPatient(data, postgresConnection);
      case Command.updatePatient:
        return await updatePatient(data, postgresConnection);
      case Command.rollback:
        try {
          await postgresConnection.execute("ROLLBACK");
          return '{"Result":"Success","Message":"Rollback executed"}';
        } catch (e) {
          _logger.d("No transaction in progress");
          return '{"Result":"Success","Message":"No transaction to rollback"}';
        }
      default:
        _logger.w("Unhandled command: $command");
        await postgresConnection.execute("ROLLBACK");
        return '{"Result":"Failure","Message":"Comando no soportado"}';
    }
  }

  /// Sends a response to the client
  Future<void> _sendResponse(String responseMessage, WebSocket webSocket) async {
    try {
      _logger.d("Sending response: $responseMessage");
      final encodedMessage = utf8.encode(responseMessage);
      final length = encodedMessage.length;
      final lengthL = length % 255;
      final lengthH = (length / 255).truncate();
      final header = [0x01, lengthH, lengthL];
      final answerFrame = [...header, ...encodedMessage];
      webSocket.add(answerFrame);
    } catch (e) {
      _logger.e("Error sending response", error: e);
    }
  }
}

// Import the dart:convert library for JSON encoding/decoding
import 'dart:convert';
// Import the dart:io library for input/output operations
import 'dart:io';
import 'package:args/args.dart';
// Import the logger package
import 'package:logger/logger.dart';
// Import the postgres package for PostgreSQL database interaction
import 'package:postgres/postgres.dart';
// Import the firebase_stuff file
import 'package:qore_server_postgres/firebase_stuff.dart';
// Import the qore_server_postgres_funcs file
import 'package:qore_server_postgres/qore_server_postgres_funcs.dart';
// Import the custom_logger_output file
import '../lib/custom_logger_output.dart' as custom;

// Constants for database connection
const int databasePort = 5432;
const String databaseHost = 'localhost';
const String databaseName = 'qore';
const String databaseUsername = 'postgres';
const String databasePassword = 'root';

// Constants for logging
const int loggerLineLength = 120;
const int loggerMethodCount = 2;
const int loggerErrorMethodCount = 8;
const int loggerNoStackMethodCount = 0;
const String logFilePath = 'logs/server.log';
const String logSeparator = "==========================================";

// Constants for WebSocket server
const int webSocketPort = 8080;
const int messageLengthMultiplier = 255;
const int headerByte = 0x01;
const String certificatePath = 'vcsinc_certificate.pem';
const String privateKeyPath = 'vcsinc_private_key.pem';

// Constants for log messages
const String clientConnectedLog = 'Client connected';
const String enteringInfiniteLoopLog =
    'Entering infinite loop to attend connection';
const String clientDisconnectedLog = 'Client disconnected';
const String clientDisconnectedErrorLog = 'Client disconnected due to error';
const String noTransactionLog = "No había transacción en curso";
const String unknownCommandLog = "Comando desconocido recibido";
const String unauthorizedUserLog = "Usuario no autorizado";
const String receivedMessageLog = 'Received message: ';
const String receivedActionLog = 'Received action: ';
const String accionRecibidaLog = 'Accion recibida: ';
const String receivedDataLog = 'Received data: ';
const String elTokenRecibidoLog = 'El token recibido es: ';
const String laDecodificacionLog =
    'La decodificación del mensaje recibido es: ';
const String responseMessageLog = "Response message to be enconded: ";
const String sendingResponseLog = "Sending response back to client";
const String postgresUpLog = 'PostgreSQL is up and running! Result: ';
const String postgresErrorLog = 'PostgreSQL error: ';
const String anErrorOccurredLog = 'An error occurred: ';
const String databaseDownLog = 'Database is down. \nExiting the program...';
const String startingServerLog = 'Starting server at ';
const String logLevelLog = 'Log level: ';
const String logFilePathLog = 'Log file path: ';
const String debugLoggingEnabledLog = 'Debug logging is enabled';
const String warningLoggingEnabledLog = 'Warning logging is enabled';
const String errorLoggingEnabledLog = 'Error logging is enabled';
const String initializingSecurityContextLog = 'Initializing security context';
const String securityContextInitializedLog =
    'Security context initialized successfully';
const String failedSecurityContextLog = 'Failed to initialize security context';
const String attemptingBindLog = 'Attempting to bind server to port ';
const String webSocketStartedLog =
    'WebSocket server successfully started on port ';
const String serverAddressLog = 'Server address: ';
const String newConnectionLog = "New connection with a client opened";

// Constants for SQL commands
const String rollbackCommand = "ROLLBACK";

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

bool debugMode = false;

// Define an enum for available commands
enum Commands {
  addPatient,
  getPatientsByIdDoc,
  getPatientsByLastName,
  getPatientById,
  updatePatient,
  deletePatient,
  lockPatient,
  rollback,
  pong,
}

// https://stackoverflow.com/questions/66340807/flutter-how-to-show-log-output-in-console-and-automatically-store-it
// Define the log file
final logFile = File(logFilePath);
// Initialize a logger instance
var logger = Logger(
  filter: ProductionFilter(),
  printer: PrettyPrinter(
    methodCount: loggerMethodCount,
    errorMethodCount: loggerErrorMethodCount,
    lineLength: loggerLineLength,
    colors: false, // Disable colors for file output
    printEmojis: false,
    // printTime: true
  ),
  output: custom.FileOutput(logFile, printToConsole: true),
);

// Initialize a logger instance without stack trace
var loggerNoStack = Logger(
  filter: ProductionFilter(),
  printer: PrettyPrinter(
    methodCount: loggerNoStackMethodCount,
    colors: false, // Disable colors for file output
    printEmojis: false,
    // printTime: true,
  ),
  output: custom.FileOutput(logFile, printToConsole: true),
);

// Main function
void main(List<String> arguments) async {
  try {
    // Parse command-line arguments
    final parser = ArgParser();
    parser.addFlag('debug',
        abbr: 'd', defaultsTo: false, help: 'Enable debug logging');
    final argResults = parser.parse(arguments);
    debugMode = argResults['debug'] as bool;

    // The most common logging levels include
    // FATAL, ERROR, WARN, INFO, DEBUG, TRACE, ALL, and OFF.
    // Set the logging level to all
    Logger.level = Level.all;

    // Log the start of the server
    logger.i("==========================================");
    logger.i("Starting server at ${DateTime.now()}");
    logger.i("Log level: ${Logger.level}");
    logger.i("Log file path: ${logFile.absolute.path}");
    logger.d("Debug logging is enabled");
    logger.w("Warning logging is enabled");
    logger.e("Error logging is enabled");
    logger.i("==========================================");

    // Log if debug mode is enabled
    logger.i(
        "Debug mode is ${debugMode ? 'enabled' : 'disabled'} via command line flag");

    // Check if the database is up and running.
    logger.d("Checking if the database is up and running...");

    await checkDatabaseIsUp();

    logger.i("PostgreSQL is up and running!");

    logger.d("Starting WebSocket server...");

    // Start the WebSocket server
    WebSocketServer().start();
  } catch (e, stackTrace) {
    // Log any errors that occur during server startup
    logger.e("Error starting server", error: e, stackTrace: stackTrace);
    // Re-throw the exception
    rethrow;
  }
}

// Function to check if the database is up and running
Future<void> checkDatabaseIsUp() async {
  // Database connection settings
  final connection = PostgreSQLConnection(
    databaseHost,
    databasePort,
    databaseName,
    username: databaseUsername,
    password: databasePassword,
  );

  try {
    // Attempt to open a connection to the database
    await connection.open();

    // Execute a simple query to check if the database is responsive
    final result = await connection.query('SELECT 1');
    print('PostgreSQL is up and running! Result: $result');
  } on PostgreSQLException catch (e) {
    // Handle PostgreSQL-specific exceptions
    print('PostgreSQL error: ${e.message}');
  } catch (e) {
    // Handle any other exceptions
    print('An error occurred: $e');
    // Exit the program
    print('Database is down. \nExiting the program...');
    exit(0); // Exit with code 0 (success)
  } finally {
    // Close the connection
    await connection.close();
  }
}

// Define a class for the WebSocket server
class WebSocketServer {
  // Define the port
  final int port = webSocketPort;
  // Define a list of clients
  List<WebSocket> clients = [];

  // Function to start the WebSocket server
  void start() async {
    // Read the certificate and private key files
    // final certificate = File(certificatePath).readAsBytesSync();
    // final privateKey = File(privateKeyPath).readAsBytesSync();

    final context = SecurityContext();

    // Declare a security context
    // late final SecurityContext context;

    // Clod: volver a probar con los vencidos y bajar el servidor.
/*
    Para ver si un certificado está vencido:
    D:\home\Gutierrez\Desarrollos\qore_server_postgres> openssl x509 -enddate -noout -in cauto_chain.pem
    notAfter=Sep 19 02:45:22 2023 GMT
*/

    // Log that the server is attempting to bind to the port
    logger.i("$attemptingBindLog$port");

    HttpServer server;

    // Bind the server to the specified address and port
    if (debugMode) {

      server = await HttpServer.bind(InternetAddress.anyIPv4, port);

    } else {

      // Not in debug mode (production) setup the security context

      try {
        // Log that the security context is being initialized
        logger.d(initializingSecurityContextLog);

        // Initialize the security context

        // context = SecurityContext()
        //   ..useCertificateChainBytes(certificate)
        //   ..usePrivateKeyBytes(privateKey);
        context.useCertificateChain(
            '/Users/claudiograsso/AndroidStudioProjects/qore_server_postgres/fullchain.pem');
        context.usePrivateKey(
            '/Users/claudiograsso/AndroidStudioProjects/qore_server_postgres/privkey.pem');

        // Log that the security context was initialized successfully
        logger.i(securityContextInitializedLog);

      } catch (e, stackTrace) {
        // Log any errors that occur during security context initialization
        logger.e(failedSecurityContextLog, error: e, stackTrace: stackTrace);
        // Re-throw the exception
        rethrow;
      }

      server =
          await HttpServer.bindSecure(InternetAddress.anyIPv4, 8080, context);
    }

    // Log that the server was started successfully
    logger.i('$webSocketStartedLog$port');
    // Log the server address
    logger.i('Server listening at: $serverAddressLog${server.address}');

    // The await for statement is used to iterate over a Stream and asynchronously handle each emitted event.
    // It is specifically used with Stream objects to listen to and process the events emitted by the stream
    // in a sequential and asynchronous manner.

    // Listen for incoming HTTP requests
    await for (var request in server) {
      // Log that a new connection with a client was opened
      logger.d("New connection with a client opened");

      // Open a connection to the DB per http connection (one connection per client)
      final postgresConnection = PostgreSQLConnection(
        databaseHost,
        databasePort,
        databaseName,
        username: databaseUsername,
        password: databasePassword,
      );
      // Open the database connection
      await postgresConnection.open();

      // Check if the request is a WebSocket upgrade request
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        // Handle the WebSocket connection
        handleWebSocket(request, postgresConnection);
      }
    }
  }

  // Function to handle a WebSocket connection
  void handleWebSocket(
    HttpRequest request,
    PostgreSQLConnection postgresConnection,
  ) async {
    // Upgrade the request to a WebSocket connection
    WebSocket webSocket = await WebSocketTransformer.upgrade(request);
    // Add the client to the list of clients
    clients.add(webSocket);
    // Log that a client connected
    logger.i(clientConnectedLog);

    // Log that the server is entering an infinite loop to attend the connection
    logger.i(enteringInfiniteLoopLog);
    // Listen for messages from the client
    webSocket.listen(
      (message) {
        // Log the received message
        logger.d('$receivedMessageLog$message');
        // Handle the message
        handleMessage(message, webSocket, postgresConnection);
      },
      onDone: () {
        // Rollback the transaction
        postgresConnection.execute(rollbackCommand);
        // Remove the client
        removeClient(webSocket);
        // Log that the client disconnected
        logger.i(clientDisconnectedLog);
      },
      onError: (error) {
        // Rollback the transaction
        postgresConnection.execute(rollbackCommand);
        // Remove the client
        removeClient(webSocket);
        // Log that the client disconnected due to an error
        logger.i(clientDisconnectedErrorLog);
      },
    );
  }

  // Function to remove a client
  void removeClient(WebSocket webSocket) {
    // Remove the client from the list of clients
    clients.remove(webSocket);
  }

  // Stop
  // Function to handle a message
  void handleMessage(
      message, webSocket, PostgreSQLConnection postgresConnection) async {
    // Convert the message to a list of int
    List<int> intList =
        message.toString().split(',').map((str) => int.parse(str)).toList();
    // Declare a firebase token
    String firebaseToken;

    // Initialize the response message
    String responseMessage = "";

    // Extract action
    int qoreAction = intList[0];
    // Log the received action
    logger.d("Received action: $qoreAction = ${Commands.values[qoreAction]}",
        time: DateTime.now());

    // Extract message length
    int messageLength = intList[1] * messageLengthMultiplier + intList[2];

    // Initialize the decoded message
    String decoded = '';

    // Extract action
    int action = intList[0];
    // Log the received action
    logger.d('$accionRecibidaLog$action = ${Commands.values[action]}');

    // Check if the message length matches the data length
    if (intList.sublist(3).length == messageLength) {
      // Decode from UTF8 list to String
      decoded = utf8.decode(intList.sublist(3));
      // Log the received data
      logger.d('$receivedDataLog$decoded', time: DateTime.now());
    }

    // Check if the message length matches the data length
    if (intList.sublist(3).length == messageLength) {
      // Process command
      var decodedMessage = utf8.decode(intList.sublist(3));
      // Split the decoded message
      var decoded = decodedMessage.split("|")[1];
      // Get the firebase token
      firebaseToken = decodedMessage.split("|")[0];
      // Log the received token
      logger.d('$elTokenRecibidoLog$firebaseToken');

      // Validate the firebase token
      bool validToken = await validateUserFirebaseToken(firebaseToken);

      // If the token is valid
      if (validToken) {
        // Log the decoded message
        logger.d('$laDecodificacionLog$decoded', time: DateTime.now());

        // Process the command
        if (action == Commands.getPatientsByLastName.index) {
          responseMessage =
              await getPatientsByLastName(decoded, postgresConnection);
        } else if (action == Commands.getPatientsByIdDoc.index) {
          responseMessage =
              await getPatientsByIdDoc(decoded, postgresConnection);
        } else if (action == Commands.getPatientById.index) {
          responseMessage = await getPatientById(decoded, postgresConnection);
        } else if (action == Commands.addPatient.index) {
          responseMessage = await addPatient(decoded, postgresConnection);
        } else if (action == Commands.updatePatient.index) {
          responseMessage = await updatePatient(decoded, postgresConnection);
        } else if (action == Commands.rollback.index) {
          try {
            // Rollback the transaction
            await postgresConnection.execute(rollbackCommand);
          } catch (e) {
            // Log that there was no transaction in course
            logger.d(noTransactionLog, time: DateTime.now());
          }
        } else {
          // Log that an unknown command was received
          logger.i(unknownCommandLog, time: DateTime.now());
          // Rollback the transaction
          await postgresConnection.execute(rollbackCommand);
        }
      } else {
        // Set the response message to unauthorized
        responseMessage = unauthorizedUserLog;
      }

      // Send answer to client
      sendResponse(responseMessage, webSocket);
    }
  }
}

// Function to send a response to the client
void sendResponse(String responseMessage, WebSocket webSocket) {
  // Log the response message
  logger.d("$responseMessageLog$responseMessage");
  // Encode the response message
  final encodedMessage = utf8.encode(responseMessage);
  // Get the length of the encoded message
  final length = encodedMessage.length;
  // Calculate the low byte of the length
  final lengthL = length % messageLengthMultiplier;
  // Calculate the high byte of the length
  final lengthH = (length / messageLengthMultiplier).truncate();
  // Create the header
  final header = [headerByte, lengthH, lengthL];
  // Create the answer frame
  final answerFrame = [...header, ...encodedMessage];
  // Log that the response is being sent
  logger.d(sendingResponseLog);
  // Add the answer frame to the WebSocket
  webSocket.add(answerFrame);
}

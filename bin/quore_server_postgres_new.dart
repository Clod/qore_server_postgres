import 'dart:convert';
import 'dart:io';
import 'package:logger/logger.dart';
import 'package:postgres/postgres.dart';
import 'package:qore_server_postgres/firebase_stuff.dart';
import 'package:qore_server_postgres/qore_server_postgres_funcs.dart';


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
var logger = Logger(
  printer: PrettyPrinter(
      methodCount: 2,
      // number of method calls to be displayed
      errorMethodCount: 8,
      // number of method calls if stacktrace is provided
      lineLength: 120,
      // width of the output
      colors: true,
      // Colorful log messages
      printEmojis: false,
      // Print an emoji for each log message
      printTime: true // Should each log print contain a timestamp
  ),
);

var loggerNoStack = Logger(
  printer: PrettyPrinter(methodCount: 0),
);

void main() {

  // Logging levels explained. The most common logging levels include FATAL, ERROR, WARN, INFO, DEBUG, TRACE, ALL, and OFF.
  Logger.level = Level.all;

  WebSocketServer().start();
}

class WebSocketServer {
  final int port = 8080;
  List<WebSocket> clients = [];

  void start() async {
    final certificate = File('vcsinc_certificate.pem').readAsBytesSync();
    final privateKey = File('vcsinc_private_key.pem').readAsBytesSync();

    late final SecurityContext context;

    // Clod: volver a probar con los vencidos y bajar el servidor.
    try {
      context = SecurityContext()
        ..useCertificateChainBytes(certificate)
        ..usePrivateKeyBytes(privateKey);
    } catch (e) {
      logger.i(e);
      exit(42);
    }

    final server = await HttpServer.bindSecure(InternetAddress.anyIPv4, 8080, context);
    logger.i('WebSocket server started on port $port');

    // The await for statement is used to iterate over a Stream and asynchronously handle each emitted event.
    // It is specifically used with Stream objects to listen to and process the events emitted by the stream
    // in a sequential and asynchronous manner.

    await for (var request in server) {
      logger.d("New connection with a client opened");

      // Open a connection to the DB per http connection (one connection per client)
      final postgresConnection = PostgreSQLConnection('localhost', 5432, 'qore', username: 'postgres', password: 'root');
      await postgresConnection.open();

      if (WebSocketTransformer.isUpgradeRequest(request)) {
        handleWebSocket(request, postgresConnection);
      }
    }
  }

  void handleWebSocket(HttpRequest request, PostgreSQLConnection postgresConnection) async {
    WebSocket webSocket = await WebSocketTransformer.upgrade(request);
    clients.add(webSocket);
    logger.i('Client connected');

    logger.i("Entering infinite loop to attend connection");
    webSocket.listen(
      (message) {
        logger.d('Received message: $message');
        handleMessage(message, webSocket, postgresConnection);
      },
      onDone: () {
        postgresConnection.execute("ROLLBACK");
        removeClient(webSocket);
        logger.i('Client disconnected');
      },
      onError: (error) {
        postgresConnection.execute("ROLLBACK");
        removeClient(webSocket);
        logger.i('Client disconnected due to error');
      },
    );
  }

  void removeClient(WebSocket webSocket) {
    clients.remove(webSocket);
  }

  // Stop
  void handleMessage(message, webSocket, PostgreSQLConnection postgresConnection) async {

    // Convert the message to a list of int
    List<int> intList = message.toString().split(',').map((str) => int.parse(str)).toList();
    String firebaseToken;

    String responseMessage = "";

    // Extract action
    int qoreAction = intList[0];
    logger.d("Received action: $qoreAction = ${Commands.values[qoreAction]}", time: DateTime.now());

    // Extract message length
    int messageLength = intList[1] * 255 + intList[2];

    String decoded = '';

    // Extract action
    int action = intList[0];
    logger.d("Accion recibida: $action = ${Commands.values[action]}");

    if (intList.sublist(3).length == messageLength) {
      // Decode from UTF8 list to String
      decoded = utf8.decode(intList.sublist(3));
      logger.d("Received data: $decoded", time: DateTime.now());
    }

    if (intList.sublist(3).length == messageLength) {
      // Process command
      var decodedMessage = utf8.decode(intList.sublist(3));
      var decoded = decodedMessage.split("|")[1];
      firebaseToken = decodedMessage.split("|")[0];
      logger.d("El token recibido es: $firebaseToken");

      bool validToken = await validateUserFirebaseToken(firebaseToken);

      if (validToken) {
        logger.t("La decodificación del mensaje recibido es: $decoded", time: DateTime.now());

        if (action == Commands.getPatientsByLastName.index) {
          responseMessage = await getPatientsByLastName(decoded, postgresConnection);
        } else if (action == Commands.getPatientsByIdDoc.index) {
          responseMessage = await getPatientsByIdDoc(decoded, postgresConnection);
        } else if (action == Commands.getPatientById.index) {
          responseMessage = await getPatientById(decoded, postgresConnection);
        } else if (action == Commands.addPatient.index) {
          responseMessage = await addPatient(decoded, postgresConnection);
        } else if (action == Commands.updatePatient.index) {
          responseMessage = await updatePatient(decoded, postgresConnection);
        } else if (action == Commands.rollback.index) {
          try {
            await postgresConnection.execute("ROLLBACK");
          } catch (e) {
            logger.d("No había transacción en curso", time: DateTime.now());
          }
        } else {
          logger.i("Comando desconocido recibido", time: DateTime.now());
          await postgresConnection.execute("ROLLBACK");
        }
      } else {
        responseMessage = "Usuario no autorizado";
      }

      // Send answer to client
      sendResponse(responseMessage, webSocket);
    }
  }
}

void sendResponse(String responseMessage, WebSocket webSocket) {
  logger.d("Response message to be enconded: $responseMessage");
  final encodedMessage = utf8.encode(responseMessage);
  final length = encodedMessage.length;
  final lengthL = length % 255;
  final lengthH = (length / 255).truncate();
  final header = [0x01, lengthH, lengthL];
  final answerFrame = [...header, ...encodedMessage];
  logger.d("Sending response back to client");
  webSocket.add(answerFrame);
}

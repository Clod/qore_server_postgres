import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:qore_server_postgres/firebase_stuff.dart';
import 'package:qore_server_postgres/qore_server_postgres_funcs.dart';

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

void main() async {
  Logger.level = Level.trace;

  final certificate = File('vcsinc_certificate.pem').readAsBytesSync();
  final privateKey = File('vcsinc_private_key.pem').readAsBytesSync();

  late final SecurityContext context;

  // Clod: volver a probar con los vencidos y bajar el servidor.
  try {
    context = SecurityContext()
      ..useCertificateChainBytes(certificate)
      ..usePrivateKeyBytes(privateKey);
  } catch (e) {
    print(e);
    exit(42);
  }

  final server = await HttpServer.bindSecure(InternetAddress.anyIPv4, 8080, context);
  logger.i('WebSocket server running on ${server.address}:${server.port}', time: DateTime.now());

  await for (HttpRequest request in server) {
    String firebaseToken;
    // Open a connection to the DB per http connection (one connection per client)
    final postgresConnection = PostgreSQLConnection('localhost', 5432, 'qore', username: 'postgres', password: 'root');
    await postgresConnection.open();

    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then((webSocket) async {
        logger.i('WebSocket connected', time: DateTime.now());

        handleTimeoutPing() async {
          try {
            logger.d("Enviando ping", time: DateTime.now());
            // responseMessage = 'ping';
            webSocket.add('ping');
          } catch (e) {
            logger.d("No pude enviar el ping", time: DateTime.now());
            print(e);
          }
        }

        handleTimeoutPong() {
          // No hubo respuesta al útlimo ping.
          logger.f("El cliente is dead", time: DateTime.now());
        }

        // Define a Maximum inactive timer for the client
        Duration pingInterval = Duration(seconds: 460);
        Duration maxInactivityInterval = Duration(seconds: 490);
        Timer pingTimer = Timer(pingInterval, handleTimeoutPing);
        Timer pongTimer = Timer(maxInactivityInterval, handleTimeoutPong);

        // Infinite loop waiting for messages
        await for (var message in webSocket) {
          // Message arrived,reset timers.
          pingTimer.cancel();
          pongTimer.cancel();
          pingTimer = Timer(pingInterval, handleTimeoutPing);

          // Convert the message to a list of int
          List<int> intList = message.toString().split(',').map((str) => int.parse(str)).toList();

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
            logger.t("El token recibido es: $firebaseToken");

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
              } else if (action == Commands.pong.index) {
                logger.d("Pong recibido", time: DateTime.now());
                // Envío otro ping y lanzo timer. Si recibo pong el cliente está
                // vivo y, si no, es que murió.
                responseMessage = "ping";
                pingTimer = Timer(maxInactivityInterval, handleTimeoutPong);
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
      });
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
  logger.i("Sending response back to client");
  webSocket.add(answerFrame);
}

/*
Future<void> createRecord(Map<String, dynamic> payload, PostgreSQLConnection connection) async {
  final name = payload['name'];
  final age = payload['age'];

  await connection.query('INSERT INTO users (name, age) VALUES (@name, @age)', substitutionValues: {'name': name, 'age': age});
}

Future<void> readRecord(Map<String, dynamic> payload, WebSocket webSocket, PostgreSQLConnection connection) async {
  final id = payload['id'];

  final result = await connection.query('SELECT name, age FROM users WHERE id = @id', substitutionValues: {'id': id});

  if (result.isNotEmpty) {
    final user = result[0];
    final name = user[0];
    final age = user[1];

    final response = {'name': name, 'age': age};
    webSocket.add(json.encode(response));
  }
}

Future<void> updateRecord(Map<String, dynamic> payload, PostgreSQLConnection connection) async {
  final id = payload['id'];
  final name = payload['name'];
  final age = payload['age'];

  await connection
      .query('UPDATE users SET name = @name, age = @age WHERE id = @id', substitutionValues: {'id': id, 'name': name, 'age': age});
}

Future<void> deleteRecord(Map<String, dynamic> payload, PostgreSQLConnection connection) async {
  final id = payload['id'];

  await connection.query('DELETE FROM users WHERE id = @id', substitutionValues: {'id': id});
}
*/

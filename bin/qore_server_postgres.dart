import 'package:logger/logger.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:postgres/postgres.dart';
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
}

var logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    lineLength: 132,
  ),
);

var loggerNoStack = Logger(
  printer: PrettyPrinter(methodCount: 0),
);

void main() async {
  Logger.level = Level.trace;

  final certificate = File('cauto_chain.pem').readAsBytesSync();
  final privateKey = File('cauto_key.pem').readAsBytesSync();

  late final SecurityContext context;

  try {
    context = SecurityContext()
      ..useCertificateChainBytes(certificate)
      ..usePrivateKeyBytes(privateKey);
  } catch (e) {
    print(e);
    exit(33);
  }

  final server = await HttpServer.bindSecure(InternetAddress.anyIPv4, 8080, context);
  logger.i('WebSocket server running on ${server.address}:${server.port}');

  final postgresConnection = PostgreSQLConnection('localhost', 5432, 'qore', username: 'postgres', password: 'root');
  await postgresConnection.open();

  bool blockingRegister = false;

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then((webSocket) async {
        logger.i('WebSocket connected');

        await for (var message in webSocket) {
          // Convert the message to a list of int
          List<int> intList = message.toString().split(',').map((str) => int.parse(str)).toList();

          String responseMessage = "";

          // Extract action
          int qoreAction = intList[0];
          logger.d("Received action: $qoreAction = ${Commands.values[qoreAction]}");

          // Extract message length
          int messageLength = intList[1] * 255 + intList[2];
          // print("Message Length: $messageLength");

          String decoded = '';

          // Extract action
          int action = intList[0];
          logger.d("Accion recibida: $action = ${Commands.values[action]}");

          if (intList.sublist(3).length == messageLength) {
            // Decode from UTF8 list to String
            decoded = utf8.decode(intList.sublist(3));
            logger.d("Received data: $decoded");
          }

          if (intList.sublist(3).length == messageLength) {
            // Process command
            var decoded = utf8.decode(intList.sublist(3));
            logger.t("La decodificación del mensaje recibido es: $decoded");

            //      if (connectedToDB == true) {
            if (action == Commands.getPatientsByLastName.index) {
              if (postgresConnection.isClosed) await postgresConnection.open();
              responseMessage = await getPatientsByLastName(decoded, postgresConnection);
              logger.d(responseMessage);
            } else if (action == Commands.getPatientsByIdDoc.index) {
              if (postgresConnection.isClosed) await postgresConnection.open();
              responseMessage = await getPatientsByIdDoc(decoded, postgresConnection);
              logger.d(responseMessage);
            } else if (action == Commands.addPatient.index) {
              if (postgresConnection.isClosed) await postgresConnection.open();
              String patient = utf8.decode(intList.sublist(3));
              responseMessage = await addPatient(patient, postgresConnection);
            } else if (action == Commands.updatePatient.index) {
              if (postgresConnection.isClosed) await postgresConnection.open();
              String patient = utf8.decode(intList.sublist(3));
              responseMessage = await updatePatient(patient, postgresConnection);
            } else if (action == Commands.lockPatient.index ||
                action == Commands.updatePatient.index ||
                action == Commands.rollback.index) {
              String patient = utf8.decode(intList.sublist(3));
              logger.d("Entramos por la triple.");
              // First time
              if (action == Commands.lockPatient.index) {
              } else if (action == Commands.updatePatient.index) {
                logger.i("Update received");
              } else {
                logger.i("Rollback received");
                logger.i("Rollback executed");
              }
            } else if (action == Commands.lockPatient.index) {
              String patient = utf8.decode(intList.sublist(3));
            } else {
              logger.i("Rollback received");
              await postgresConnection.execute("ROLLBACK");
            }

            // exit(0);
            // Prof JSON to Dart structure
            //final data = json.decode(decoded);

            final data = {"action": "pirulines", "payload": "chuenga"};
            //
            // final action = data['action'];
            // final payload = data['payload'];
            //

            logger.d("Response message to be enconded: $responseMessage");
            final encodedMessage = utf8.encode(responseMessage);
            final length = encodedMessage.length;
            final lengthL = length % 255;
            final lengthH = (length / 255).truncate();
            final header = [0x01, lengthH, lengthL];
            final answerFrame = [...header, ...encodedMessage];
            logger.i("Sending response back to client");
            webSocket.add(answerFrame);
            //webSocket.add("$request");
          }
        }
      });
    }
  }
}

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

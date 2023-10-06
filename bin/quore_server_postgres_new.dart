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

void main() {
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
      print(e);
      exit(42);
    }

    final server = await HttpServer.bindSecure(InternetAddress.anyIPv4, 8080, context);
    print('WebSocket server started on port $port');

    await for (var request in server) {
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
    print('Client connected');

    webSocket.listen(
      (message) {
        print('Received message: $message');
        handleMessage(message, webSocket, postgresConnection);
      },
      onDone: () {
        postgresConnection.execute("ROLLBACK");
        removeClient(webSocket);
        print('Client disconnected');
      },
      onError: (error) {
        postgresConnection.execute("ROLLBACK");
        removeClient(webSocket);
        print('Client disconnected due to error');
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
  logger.i("Sending response back to client");
  webSocket.add(answerFrame);
}

# **Qore Server PostgreSQL**

This is a Dart-based server application that uses PostgreSQL for data storage and WebSockets for communication. It provides an API for managing patient data, including adding, retrieving, updating, and deleting patient records. The server also uses Firebase for user authentication.

## **Features**

* **PostgreSQL Database:** Uses PostgreSQL for persistent data storage.  
* **WebSocket Communication:** Uses WebSockets for real-time communication with clients.  
* **Patient Management:** Provides API endpoints for managing patient data.  
* **Firebase Authentication:** Uses Firebase for user authentication.  
* **Custom Logging:** Uses a custom logger for detailed logging of server events.  
* **Secure Communication:** Uses certificates for secure WebSocket communication.

## **How it Works**

The server listens for incoming WebSocket connections on port 8080\. Upon receiving a connection, it establishes a database connection to PostgreSQL. The server then listens for messages from the client. Each message is expected to be a comma-separated list of integers. The first integer represents the action to be performed, the second and third integers represent the length of the message, and the remaining integers represent the message data.

The server supports the following actions:

* `addPatient`: Adds a new patient record to the database.  
* `getPatientsByIdDoc`: Retrieves patient records by ID document.  
* `getPatientsByLastName`: Retrieves patient records by last name.  
* `getPatientById`: Retrieves a patient record by ID.  
* `updatePatient`: Updates an existing patient record.  
* `deletePatient`: Deletes a patient record.  
* `lockPatient`: Locks a patient record.  
* `rollback`: Rolls back the current database transaction.  
* `pong`: A simple ping-pong command for testing the connection.

The server uses Firebase to validate user tokens. If the token is invalid, the server will return an unauthorized message.

## **How to Run**

1. **Install Dart:** Make sure you have Dart installed on your system. You can download it from [https://dart.dev/get-dart](https://dart.dev/get-dart).  
2. **Install PostgreSQL:** Make sure you have PostgreSQL installed and running. You can download it from [https://www.postgresql.org/download/](https://www.postgresql.org/download/).

3. **Create a PostgreSQL database:** Create a database named `qore` and a user named `postgres` with password `root`.  

```language
CREATE ROLE postgres WITH LOGIN PASSWORD 'root';  
ALTER ROLE postgres CREATEDB;  
create database qore;
```

4. **Grant permissions:** Grant the necessary permissions to the `postgres` user.  

```language
\\c qore;  
GRANT USAGE, SELECT ON SEQUENCE pacientes\_id\_seq TO postgres;  
CREATE EXTENSION IF NOT EXISTS "unaccent";  
CREATE INDEX idx\_normalized\_apellido ON pacientes (normalized\_apellido);
```
  
5. **Set up Firebase:** Set up a Firebase project and obtain the necessary credentials.  
6. **Configure certificates:** Place the `vcsinc_certificate.pem` and `vcsinc_private_key.pem` files in the root directory of the project.

7. **Run the server:** Navigate to the project directory in your terminal and run the following command:  

```language
dart bin/quore\_server\_postgres\_new.dart
```


  
8. **Connect with a client:** Use a WebSocket client to connect to the server at `ws://localhost:8080`.


## **Configuration**

The following constants can be configured in the `bin/quore_server_postgres_new.dart` file:

* **Database:**  
  * `databasePort`: The port number for the PostgreSQL database (default: 5432).  
  * `databaseHost`: The host address for the PostgreSQL database (default: 'localhost').  
  * `databaseName`: The name of the PostgreSQL database (default: 'qore').  
  * `databaseUsername`: The username for the PostgreSQL database (default: 'postgres').  
  * `databasePassword`: The password for the PostgreSQL database (default: 'root').  
* **Logging:**  
  * `loggerLineLength`: The maximum length of a log line (default: 120).  
  * `loggerMethodCount`: The number of methods to include in the log output (default: 2).  
  * `loggerErrorMethodCount`: The number of methods to include in the log output for errors (default: 8).  
  * `loggerNoStackMethodCount`: The number of methods to include in the log output without stack trace (default: 0).  
  * `logFilePath`: The path to the log file (default: 'logs/server.log').  
  * `logSeparator`: The separator used in the log output (default: "==========================================").  
* **WebSocket:**  
  * `webSocketPort`: The port number for the WebSocket server (default: 8080).  
  * `messageLengthMultiplier`: The multiplier for calculating the message length (default: 255).  
  * `headerByte`: The header byte for WebSocket messages (default: 0x01).  
  * `certificatePath`: The path to the certificate file (default: 'vcsinc\_certificate.pem').  
  * `privateKeyPath`: The path to the private key file (default: 'vcsinc\_private\_key.pem').

## **Dependencies**

The server uses the following Dart packages:

* `logger`: For logging.  
* `postgres`: For PostgreSQL database interaction.  
* `firebase_stuff`: For Firebase authentication.  
* `qore_server_postgres_funcs`: For server functions.

## **Notes**

* Make sure to configure the database connection settings and Firebase credentials before running the server.  
* The server uses a custom logger that outputs to both the console and a log file.  
* The server uses certificates for secure WebSocket communication.


// Import the dart:async library for asynchronous operations
import 'dart:async';
// Import the dart:convert library for JSON encoding/decoding
import 'dart:convert';
// Import the characters package for handling grapheme clusters
import 'package:characters/characters.dart';
// Import the postgres package for PostgreSQL database interaction
import 'package:postgres/postgres.dart';
// Import the logger package for logging
import 'package:logger/logger.dart';
// Import the paciente model
import 'model/paciente.dart';

// Initialize a logger instance
var logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    lineLength: 132,
  ),
);

/*
                  FUNCTION addPatient
                  
                  inputs:
                  String patientData            : JSON string with Patient data 
                  PostgreSQLConnection? conn    : connection with database
                  
                  returns:
                    Future<String> : 
                  
                      
*/

// Function to add a new patient to the database
Future<String> addPatient(
    String patientData, PostgreSQLConnection? conn) async {
  // Log the received creation request
  logger.i("Received Creation request for:  $patientData");
  // Initialize the result string
  String result = "";
  // Remove curly braces from the string
  String keyValueString = patientData.replaceAll('{', '').replaceAll('}', '');

// Split the string into an array of key-value pairs
  List<String> keyValuePairs = keyValueString.split(',');

// Create a new Map<String, dynamic> object
  Map<String, dynamic> resultMap = {};

// Populate the Map with key-value pairs
  for (String keyValue in keyValuePairs) {
    // Split each key-value pair by the colon
    List<String> pair = keyValue.split(':');

    // Trim whitespace from the key and value strings
    String key = pair[0].trim();
    String? value = (pair[1].trim() == 'null' ? null : pair[1].trim());

    // Add the key-value pair to the Map
    resultMap[key] = value;
  }

  // Create a Paciente object from the map
  Paciente patient = Paciente.fromJson(resultMap);
  try {
    // Check if a patient with the same document and country already exists
    var checkResult = await conn!.query(
        "SELECT * FROM pacientes WHERE documento = @documento AND pais = @pais",
        substitutionValues: {
          "documento": patient.documento,
          "pais": patient.pais
        });

    // If a patient with the same document and country already exists
    if (checkResult.isNotEmpty) {
      // Log that we are trying to create an already existent patient
      logger.i("Trying to create an already existent patient: $patient");
      // Set the result to a failure message
      result =
          '{"Result" : "Failure", "Message" : "Ya existe un paciente de ese país con el mismo nro. de documento" }';
    } else {
      // Initialize the creation result
      PostgreSQLResult? creationResult;

      // Normalize the last name
      String normalizedApellido =
          removeDiacritics(patient.apellido.toLowerCase());

      // Declare a new row variable
      late PostgreSQLResult newRow;

      // Execute the database transaction
      await conn.transaction((ctx) async {
        // Insert the new patient into the database
        creationResult = await ctx.query(
            "INSERT INTO pacientes (apellido, normalized_apellido, comentarios, historial, diag1, diag2, diag3, diag4,  sind_y_asoc_gen, diagnostico_prenatal,  documento,  fecha_creacion_ficha, fecha_nacimiento,   fecha_primer_diagnostico, nombre, nro_ficha_diag_prenatal, nro_hist_clinica_papel,  paciente_fallecido, pais,  semanas_gestacion, sexo ) VALUES (@apellido, @normalized_apellido, @comentarios, @historial, @diag1, @diag2, @diag3, @diag4, @sind_y_asoc_gen, @diagnostico_prenatal, @documento,  @fecha_creacion_ficha, @fecha_nacimiento,  @fecha_primer_diagnostico, @nombre,  @nro_ficha_diag_prenatal, @nro_hist_clinica_papel, @paciente_fallecido, @pais,  @semanas_gestacion, @sexo)",
            substitutionValues: {
              "nombre": patient.nombre,
              "apellido": patient.apellido,
              "normalized_apellido": normalizedApellido,
              "documento": patient.documento,
              "pais": patient.pais,
              "diag1": patient.diag1,
              "diag2": patient.diag2,
              "diag3": patient.diag3,
              "diag4": patient.diag4,
              "sind_y_asoc_gen": patient.sindAsocGen,
              "comentarios": patient.comentarios,
              "historial": patient.historial,
              "fecha_nacimiento": patient.fechaNacimiento != null
                  ? DateTime.parse(patient.fechaNacimiento!)
                  : null,
              "fecha_creacion_ficha":
                  DateTime.parse(patient.fechaCreacionFicha),
              "sexo": patient.sexo,
              "diagnostico_prenatal": patient.diagnosticoPrenatal,
              "paciente_fallecido": patient.pacienteFallecido,
              "semanas_gestacion": patient.semanasGestacion,
              "fecha_primer_diagnostico": patient.fechaPrimerDiagnostico != null
                  ? DateTime.parse(patient.fechaPrimerDiagnostico!)
                      .toString()
                      .split(' ')[0]
                  : null,
              "nro_hist_clinica_papel": patient.nroHistClinicaPapel,
              "nro_ficha_diag_prenatal": patient.nroFichaDiagPrenatal,
            });

        // Get the id of the newly created patient
        newRow = await ctx.query("SELECT id FROM pacientes");
      });
      //     await conn.execute("COMMIT");
      // Log the database response
      logger.i(
          "Respuesta al ALTA de la BD ${creationResult!.columnDescriptions.toString()}");

      // Get the id of the new patient
      String id = newRow.last[0].toString();

      // Log that the patient was created
      logger.i(
          "Se creó el paciente ${patient.nombre} ${patient.apellido} con íd = $id");

      // Set the result to a success message
      result =
          '{"Result" : "Success", "Message" : "Se creó el paciente ${patient.nombre} ${patient.apellido} con íd = $id"}';
    }
    // affectedRows is a BigInt but I seriously doubt the number of
    // patiens cas exceed 9223372036854775807
    // Return the result
    return result;
  } catch (e) {
    // Log any errors that occur during patient creation
    logger.e("Error al crear paciente: ${e.toString()}");
    // Print the error
    print(e);
    // Return a failure message
    return '{"Result" : "Failure", "Message" : "Error en la comunicación contra la BD" }';
  }
}

/*********************************************************************************************
                  FUNCTION updatePatient

                  inputs:
                  String patientData            : JSON string with Patient data
                  PostgreSQLConnection? conn    : connection with database

                  returns:
                    Future<String> :


**********************************************************************************************/ ///

// Function to update an existing patient in the database
Future<String> updatePatient(
    String patientData, PostgreSQLConnection? conn) async {
  // Log the received update request
  logger.d("Received update request for:  $patientData");
  // Initialize the result string
  String result = "";
  // Remove curly braces from the string
  String keyValueString = patientData.replaceAll('{', '').replaceAll('}', '');

// Split the string into an array of key-value pairs
  List<String> keyValuePairs = keyValueString.split(',');

// Create a new Map<String, dynamic> object
  Map<String, dynamic> resultMap = {};

// Populate the Map with key-value pairs
  for (String keyValue in keyValuePairs) {
    // Split each key-value pair by the colon
    List<String> pair = keyValue.split(':');

    // Trim whitespace from the key and value strings
    String key = pair[0].trim();
    String? value = (pair[1].trim() == 'null' ? null : pair[1].trim());

    // Add the key-value pair to the Map
    resultMap[key] = value;
  }

  // Create a Paciente object from the map
  Paciente patient = Paciente.fromJson(resultMap);
  try {
    // Initialize the update result
    PostgreSQLResult? updateResult;

    // Just in case last name is changed
    // String normalizedApellido = removeDiacritics(patient.apellido.toLowerCase());

    // Execute the database transaction
    await conn!.transaction((ctx) async {
      // Update the patient in the database
      updateResult = await ctx.query(
          "UPDATE pacientes SET apellido = @apellido, nombre = @nombre, diag1 = @diag1, diag2 = @diag2, diag3 = @diag3, diag4 = @diag4, sind_y_asoc_gen = @sind_y_asoc_gen, comentarios = @comentarios, historial = @historial, sexo = @sexo, diagnostico_prenatal = @diagnostico_prenatal, paciente_fallecido = @paciente_fallecido, semanas_gestacion = @semanas_gestacion, nro_hist_clinica_papel = @nro_hist_clinica_papel, nro_ficha_diag_prenatal = @nro_ficha_diag_prenatal, fecha_nacimiento = @fecha_nacimiento WHERE id = @id ",
          substitutionValues: {
            "id": patient.id,
            "nombre": patient.nombre,
            "apellido": patient.apellido,
            "diag1": patient.diag1,
            "diag2": patient.diag2,
            "diag3": patient.diag3,
            "diag4": patient.diag4,
            "sind_y_asoc_gen": patient.sindAsocGen,
            "comentarios": patient.comentarios,
            "historial": patient.historial,
            "fecha_nacimiento": patient.fechaNacimiento != null
                ? DateTime.parse(patient.fechaNacimiento!)
                : null,
            "sexo": patient.sexo,
            "diagnostico_prenatal": patient.diagnosticoPrenatal,
            "paciente_fallecido": patient.pacienteFallecido,
            "semanas_gestacion": patient.semanasGestacion,
            "fecha_primer_diagnostico": patient.fechaPrimerDiagnostico != null
                ? DateTime.parse(patient.fechaPrimerDiagnostico!)
                    .toString()
                    .split(' ')[0]
                : null,
            "nro_hist_clinica_papel": patient.nroHistClinicaPapel,
            "nro_ficha_diag_prenatal": patient.nroFichaDiagPrenatal,
          });
    });
    //     await conn.execute("COMMIT");
    // Log the database response
    logger.d(
        "Respuesta al UPDATE de la BD ${updateResult!.columnDescriptions.toString()}");
    // Set the result to a success message
    result =
        '{"Result" : "Success", "Message" : "Se actualizó al paciente ${patient.nombre} ${patient.apellido} con índice nro. a determinar"}';

    // affectedRows is a BigInt but I seriously doubt the number of
    // patiens cas exceed 9223372036854775807
    // Return the result
    return result;
  } catch (e) {
    // Log any errors that occur during patient update
    logger.e("Error al actualizar paciente: ${e.toString()}");
    // Print the error
    print(e);
    // Return a failure message
    return '{"Result" : "Failure", "Message" : "Error en la conunicación contra la BD" }';
  }
}

// Function to get patients by last name
Future<String> getPatientsByLastName(
    String s, PostgreSQLConnection? conn) async {
  // Log the request
  logger.d("Looking for patients by Last Name: $s");

  // Initialize the list of retrieved patients
  List<Map<String, dynamic>> retrievedPatients = [];

  // make query
  try {
    // Remove diacritics and convert to lowercase
    s = removeDiacritics(s.toLowerCase());

    // Query the database for patients with a matching last name
    var results = await conn!.query(
        "SELECT * FROM pacientes WHERE unaccent(normalized_apellido) ILIKE @ape  LIMIT 10",
        substitutionValues: {"ape": '%$s%'});

    // Log the results
    logger.d("Looking by Last Name Found: ${results.toString()}");
    // print query result
    // Iterate through the results
    for (final row in results) {
      // Log the row
      logger.d(row.toString());
      // Log the row type
      logger.d(row.runtimeType);
      // retrievedPatients.add(Paciente.fromJson(row.assoc()));
      // Add the row to the list of retrieved patients
      retrievedPatients.add(row.toColumnMap());
      // Convert all DateTime type to String with format yyyy-mm-dd
      var date =
          retrievedPatients[retrievedPatients.length - 1]["fecha_nacimiento"];
      retrievedPatients[retrievedPatients.length - 1]["fecha_nacimiento"] =
          date != null ? "${date.year}-${date.month}-${date.day}" : null;
      date = retrievedPatients[retrievedPatients.length - 1]
          ["fecha_creacion_ficha"];
      retrievedPatients[retrievedPatients.length - 1]["fecha_creacion_ficha"] =
          date != null ? "${date.year}-${date.month}-${date.day}" : null;
      date = retrievedPatients[retrievedPatients.length - 1]
          ["fecha_primer_diagnostico"];
      retrievedPatients[retrievedPatients.length - 1]
              ["fecha_primer_diagnostico"] =
          date != null ? "${date.year}-${date.month}-${date.day}" : null;
      //
      // logger.d("Number of rows retrieved: ${result.numOfRows}");
      // logger.d("Rows retrieved: $retrievedPatients");
      // Log the JSON encoded list of retrieved patients
      logger.d(jsonEncode(retrievedPatients));
    }
    // Return the JSON encoded list of retrieved patients
    return jsonEncode(retrievedPatients);
  } catch (e) {
    // Log any errors that occur during the query
    logger.e(e);
    // Return a failure message
    return '{"Result" : "Failure", "Message" : "Error en la comunicación contra la Base de datos" }';
  }
}

// Function to get patients by document id
Future<String> getPatientsByIdDoc(String s, PostgreSQLConnection? conn) async {
  // Log the request
  logger.d("Looking for patients by Last Name: $s");

  // Initialize the list of retrieved patients
  List<Map<String, dynamic>> retrievedPatients = [];

  // make query
  try {
    // Query the database for patients with a matching document id
    var results = await conn!.query(
        "SELECT * FROM pacientes WHERE documento LIKE @documento  LIMIT 10",
        substitutionValues: {"documento": '%$s%'});

    // print query result
    // Iterate through the results
    for (final row in results) {
      // Log the row
      logger.d(row.toString());
      // Log the row type
      logger.d(row.runtimeType);
      // retrievedPatients.add(Paciente.fromJson(row.assoc()));
      // Add the row to the list of retrieved patients
      retrievedPatients.add(row.toColumnMap());
      // Convert all DateTime type to String with format yyyy-mm-dd
      var date =
          retrievedPatients[retrievedPatients.length - 1]["fecha_nacimiento"];
      retrievedPatients[retrievedPatients.length - 1]["fecha_nacimiento"] =
          date != null ? "${date.year}-${date.month}-${date.day}" : null;
      date = retrievedPatients[retrievedPatients.length - 1]
          ["fecha_creacion_ficha"];
      retrievedPatients[retrievedPatients.length - 1]["fecha_creacion_ficha"] =
          date != null ? "${date.year}-${date.month}-${date.day}" : null;
      date = retrievedPatients[retrievedPatients.length - 1]
          ["fecha_primer_diagnostico"];
      retrievedPatients[retrievedPatients.length - 1]
              ["fecha_primer_diagnostico"] =
          date != null ? "${date.year}-${date.month}-${date.day}" : null;
      //
      // logger.d("Number of rows retrieved: ${result.numOfRows}");
      // logger.d("Rows retrieved: $retrievedPatients");
      // Log the JSON encoded list of retrieved patients
      logger.d(jsonEncode(retrievedPatients));
    }
    // Return the JSON encoded list of retrieved patients
    return jsonEncode(retrievedPatients);
  } catch (e) {
    // Log any errors that occur during the query
    logger.e(e);
    // Return a failure message
    return '{"Result" : "Failure", "Message" : "Error en la comunicación contra la Base de datos" }';
  }
}

/*
* Traigo el paciente y lo lockeo
*
* */
// Function to get a patient by id and lock it
Future<String> getPatientById(String id, PostgreSQLConnection? conn) async {
  // Log the request
  logger.d("Looking for patients by id: $id");
  // Log the database connection id
  logger.d("Using connectionwith DB: ${conn!.processID}");

  // Initialize the list of retrieved patients
  List<Map<String, dynamic>> retrievedPatients = [];

  try {
    // Start a database transaction
    await conn.query('BEGIN');

    // Select and lock the patient. If already locked by another, return immediately with error
    var results = await conn.query(
        "SELECT * FROM pacientes WHERE id = @id  LIMIT 10 FOR UPDATE NOWAIT",
        substitutionValues: {"id": id});

    // Get the first row
    var row = results[0];
    // Log the row
    logger.d(row.toString());
    // Log the row type
    logger.d(row.runtimeType);
    // retrievedPatients.add(Paciente.fromJson(row.assoc()));
    // Add the row to the list of retrieved patients
    retrievedPatients.add(row.toColumnMap());
    // Convert all DateTime type to String with format yyyy-mm-dd
    var date =
        retrievedPatients[retrievedPatients.length - 1]["fecha_nacimiento"];
    retrievedPatients[retrievedPatients.length - 1]["fecha_nacimiento"] =
        date != null ? "${date.year}-${date.month}-${date.day}" : null;
    date =
        retrievedPatients[retrievedPatients.length - 1]["fecha_creacion_ficha"];
    retrievedPatients[retrievedPatients.length - 1]["fecha_creacion_ficha"] =
        date != null ? "${date.year}-${date.month}-${date.day}" : null;
    date = retrievedPatients[retrievedPatients.length - 1]
        ["fecha_primer_diagnostico"];
    retrievedPatients[retrievedPatients.length - 1]
            ["fecha_primer_diagnostico"] =
        date != null ? "${date.year}-${date.month}-${date.day}" : null;
    //
    // logger.d("Number of rows retrieved: ${result.numOfRows}");
    // logger.d("Rows retrieved: $retrievedPatients");
    // Log the JSON encoded list of retrieved patients
    logger.d(jsonEncode(retrievedPatients));

    // Return the JSON encoded list of retrieved patients
    return jsonEncode(retrievedPatients);
  } catch (e) {
    // Log any errors that occur during the query
    logger.e(e.toString());
    // If the error is a lock error
    if (e.toString().contains(
        "PostgreSQLSeverity.error 55P03: no se pudo bloquear un candado en la fila")) {
      // Return a message indicating the record is locked
      return '{"Result" : "Failure", "Message" : "Registro lockeado" }';
    } else {
      // Return a failure message
      return '{"Result" : "Failure", "Message" : "Error en la comunicación contra la Base de datos" }';
    }
  }
}

// Function to remove diacritics from a string
String removeDiacritics(String input) {
  // Define a map of diacritic characters to their non-diacritic counterparts
  final diacriticMap = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    // Add more mappings as needed
  };

  // Map each character in the input string to its non-diacritic counterpart
  String result = input.characters.map((char) {
    final replacement = diacriticMap[char];
    return replacement ?? char;
  }).join('');

  // Return the result
  return result;
}

// Future<String> updatePatientL(String patientData, PostgreSQLConnection? conn) async {
//   logger.d("Received update request L for:  $patientData");
//   String result = "";
//   // Remove curly braces from the string
//   String keyValueString = patientData.replaceAll('{', '').replaceAll('}', '');
//
// // Split the string into an array of key-value pairs
//   List<String> keyValuePairs = keyValueString.split(',');
//
// // Create a new Map<String, dynamic> object
//   Map<String, dynamic> resultMap = {};
//
// // Populate the Map with key-value pairs
//   for (String keyValue in keyValuePairs) {
//     // Split each key-value pair by the colon
//     List<String> pair = keyValue.split(':');
//
//     // Trim whitespace from the key and value strings
//     String key = pair[0].trim();
//     String? value = (pair[1].trim() == 'null' ? null : pair[1].trim());
//
//     // Add the key-value pair to the Map
//     resultMap[key] = value;
//   }
//
//   Paciente patient = Paciente.fromJson(resultMap);
//
//   try {
//     PostgreSQLResult? updateResult;
//
//     // Just in case last name is changed
//     String normalizedApellido = removeDiacritics(patient.apellido.toLowerCase());
//
//     logger.d("Abriendo transacción para modificar paciente con id: ${patient.id}");
//
//     await conn!.transaction((ctx) async {
//       await ctx.query('SELECT * FROM pacientes WHERE id = @id for update', substitutionValues: {'id': patient.id});
//
//       updateResult = await ctx.query(
//           "UPDATE pacientes SET apellido = @apellido, nombre = @nombre, diag1 = @diag1, diag2 = @diag2, diag3 = @diag3, diag4 = @diag4, comentarios = @comentarios, sexo = @sexo, diagnostico_prenatal = @diagnostico_prenatal, paciente_fallecido = @paciente_fallecido, semanas_gestacion = @semanas_gestacion, nro_hist_clinica_papel = @nro_hist_clinica_papel, nro_ficha_diag_prenatal = @nro_ficha_diag_prenatal, fecha_nacimiento = @fecha_nacimiento WHERE id = @id ",
//           substitutionValues: {
//             "id": patient.id,
//             "nombre": patient.nombre,
//             "apellido": patient.apellido,
//             "diag1": patient.diag1,
//             "diag2": patient.diag2,
//             "diag3": patient.diag3,
//             "diag4": patient.diag4,
//             "comentarios": patient.comentarios,
//             "fecha_nacimiento": patient.fechaNacimiento != null ? DateTime.parse(patient.fechaNacimiento!) : null,
//             "sexo": patient.sexo,
//             "diagnostico_prenatal": patient.diagnosticoPrenatal,
//             "paciente_fallecido": patient.pacienteFallecido,
//             "semanas_gestacion": patient.semanasGestacion,
//             "fecha_primer_diagnostico": patient.fechaPrimerDiagnostico != null
//                 ? DateTime.parse(patient.fechaPrimerDiagnostico!).toString().split(' ')[0]
//                 : null,
//             "nro_hist_clinica_papel": patient.nroHistClinicaPapel,
//             "nro_ficha_diag_prenatal": patient.nroFichaDiagPrenatal,
//           });
//     });
//     //     await conn.execute("COMMIT");
//     logger.d("Respuesta al UPDATE de la BD ${updateResult!.columnDescriptions.toString()}");
//     result =
//         '{"Result" : "Success", "Message" : "Se actualizó al paciente ${patient.nombre} ${patient.apellido} con índice nro. a determinar"}';
//
//     // affectedRows is a BigInt but I seriously doubt the number of
//     // patiens cas exceed 9223372036854775807
//     return result;
//   } catch (e) {
//     logger.e("Error al actualizar paciente: ${e.toString()}");
//     print(e);
//     return '{"Result" : "Failure", "Message" : "Error en la conunicación contra la BD" }';
//   }
// }

// Function to update a patient with a lock
Future<String> updatePatientLOCK(
    String patientData, PostgreSQLConnection? conn) async {
  // Log the received update request
  logger.d("Received update request L for:  $patientData");
  // Initialize the result string
  String result = "";
  // Remove curly braces from the string
  String keyValueString = patientData.replaceAll('{', '').replaceAll('}', '');

// Split the string into an array of key-value pairs
  List<String> keyValuePairs = keyValueString.split(',');

// Create a new Map<String, dynamic> object
  Map<String, dynamic> resultMap = {};

// Populate the Map with key-value pairs
  for (String keyValue in keyValuePairs) {
    // Split each key-value pair by the colon
    List<String> pair = keyValue.split(':');

    // Trim whitespace from the key and value strings
    String key = pair[0].trim();
    String? value = (pair[1].trim() == 'null' ? null : pair[1].trim());

    // Add the key-value pair to the Map
    resultMap[key] = value;
  }

  // Create a Paciente object from the map
  Paciente patient = Paciente.fromJson(resultMap);

  try {
    // Initialize the update result
    PostgreSQLResult? updateResult;

    // Just in case last name is changed
    // String normalizedApellido = removeDiacritics(patient.apellido.toLowerCase());

    // Log that we are opening a transaction to modify the patient
    logger.d(
        "Abriendo transacción para modificar paciente con id: ${patient.id}");

    // Start a database transaction
    await conn?.query('BEGIN');

    // Select and lock the patient
    await conn?.query('SELECT * FROM pacientes WHERE id = @id FOR UPDATE',
        substitutionValues: {'id': patient.id});

    // Print a message before the delay
    print('Before delayed');
    // Delay for 60 seconds and then rollback the transaction
    Future.delayed(const Duration(seconds: 60), () {
      // Print a message after the delay
      print('After delay');
      // Rollback the transaction
      conn?.query('ROLLBAK');
    });

    // Update the patient in the database
    updateResult = await conn?.query(
        "UPDATE pacientes SET apellido = @apellido, nombre = @nombre, diag1 = @diag1, diag2 = @diag2, diag3 = @diag3, diag4 = @diag4, sind_y_asoc_gen = @sind_y_asoc_gen, comentarios = @comentarios, historial = @historial, sexo = @sexo, diagnostico_prenatal = @diagnostico_prenatal, paciente_fallecido = @paciente_fallecido, semanas_gestacion = @semanas_gestacion, nro_hist_clinica_papel = @nro_hist_clinica_papel, nro_ficha_diag_prenatal = @nro_ficha_diag_prenatal, fecha_nacimiento = @fecha_nacimiento WHERE id = @id ",
        substitutionValues: {
          "id": patient.id,
          "nombre": patient.nombre,
          "apellido": patient.apellido,
          "diag1": patient.diag1,
          "diag2": patient.diag2,
          "diag3": patient.diag3,
          "diag4": patient.diag4,
          "sind_y_asoc_gen": patient.sindAsocGen,
          "comentarios": patient.comentarios,
          "historial": patient.historial,
          "fecha_nacimiento": patient.fechaNacimiento != null
              ? DateTime.parse(patient.fechaNacimiento!)
              : null,
          "sexo": patient.sexo,
          "diagnostico_prenatal": patient.diagnosticoPrenatal,
          "paciente_fallecido": patient.pacienteFallecido,
          "semanas_gestacion": patient.semanasGestacion,
          "fecha_primer_diagnostico": patient.fechaPrimerDiagnostico != null
              ? DateTime.parse(patient.fechaPrimerDiagnostico!)
                  .toString()
                  .split(' ')[0]
              : null,
          "nro_hist_clinica_papel": patient.nroHistClinicaPapel,
          "nro_ficha_diag_prenatal": patient.nroFichaDiagPrenatal,
        });

    // Commit the transaction
    await conn?.query("COMMIT");

    // Log the database response
    logger.d(
        "Respuesta al UPDATE de la BD ${updateResult!.columnDescriptions.toString()}");
    // Set the result to a success message
    result =
        '{"Result" : "Success", "Message" : "Se actualizó al paciente ${patient.nombre} ${patient.apellido} con índice nro. a determinar"}';

    // affectedRows is a BigInt but I seriously doubt the number of
    // patiens can exceed 9223372036854775807
    // Return the result
    return result;
  } catch (e) {
    // Log any errors that occur during the update
    logger.e("Error al actualizar paciente: ${e.toString()}");
    // Print the error
    print(e);
    // Return a failure message
    return '{"Result" : "Failure", "Message" : "Error en la conunicación contra la BD" }';
  }
}

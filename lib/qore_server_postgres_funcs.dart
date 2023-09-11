import 'dart:async';
import 'dart:convert';
import 'package:characters/characters.dart';
import 'package:postgres/postgres.dart';
import 'package:logger/logger.dart';
import 'model/paciente.dart';

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

Future<String> updatePatientLocking(String patientData, PostgreSQLConnection? conn) async {
  logger.d("Received update request for:  $patientData");
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

  Paciente patient = Paciente.fromJson(resultMap);
  try {
    PostgreSQLResult? updateResult;

    // Just in case last name is changed
    String normalizedApellido = removeDiacritics(patient.apellido.toLowerCase());

    await conn!.transaction((ctx) async {
      var checkResult = await conn.query("SELECT * FROM pacientes WHERE documento = @documento AND pais = @pais FOR UPDATE",
          substitutionValues: {"documento": patient.documento, "pais": patient.pais});

      updateResult = await ctx.query(
          "UPDATE pacientes SET apellido = @apellido, normalized_apellido = @normalized_apellido, @nombre = @nombre, diag1 = @diag1, diag2 = @diag2, diag3 = @diag3, diag4 = @diag4, comentarios = @comentarios, fecha_nacimiento = @fecha_nacimiento, fecha_creacion_ficha = @fecha_creacion_ficha, sexo = @sexo, diagnostico_prenatal = @diagnostico_prenatal, paciente_fallecido = @paciente_fallecido, semanas_gestacion = @semanas_gestacion, nro_hist_clinica_papel = @nro_hist_clinica_papel, nro_ficha_diag_prenatal = @nro_ficha_diag_prenatal WHERE id = @id ",
          substitutionValues: {
            "id": patient.id,
            "nombre": patient.nombre,
            "apellido": patient.apellido,
            "normalized_apellido": normalizedApellido,
            "diag1": patient.diag1,
            "diag2": patient.diag2,
            "diag3": patient.diag3,
            "diag4": patient.diag4,
            "comentarios": patient.comentarios,
            "fecha_nacimiento": patient.fechaNacimiento != null ? DateTime.parse(patient.fechaNacimiento!) : null,
            "sexo": patient.sexo,
            "diagnostico_prenatal": patient.diagnosticoPrenatal,
            "paciente_fallecido": patient.pacienteFallecido,
            "semanas_gestacion": patient.semanasGestacion,
            "fecha_primer_diagnostico": patient.fechaPrimerDiagnostico != null
                ? DateTime.parse(patient.fechaPrimerDiagnostico!).toString().split(' ')[0]
                : null,
            "nro_hist_clinica_papel": patient.nroHistClinicaPapel,
            "nro_ficha_diag_prenatal": patient.nroFichaDiagPrenatal,
          });

      await ctx.query("COMMIT");
    });

    //     await conn.execute("COMMIT");
    logger.d("Respuesta al UPDATE de la BD ${updateResult!.columnDescriptions.toString()}");
    result =
        '{"Result" : "Success", "Message" : "Se actualizó al paciente ${patient.nombre} ${patient.apellido} con índice nro. a determinar"}';

    // affectedRows is a BigInt but I seriously doubt the number of
    // patiens cas exceed 9223372036854775807
    return result;
  } catch (e) {
    logger.e("Error al actualizar paciente: ${e.toString()}");
    print(e);
    return '{"Result" : "Failure", "Message" : "Error en la conunicación contra la BD" }';
  }
}

Future<String> addPatient(String patientData, PostgreSQLConnection? conn) async {
  logger.i("Received Creation request for:  $patientData");
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

  Paciente patient = Paciente.fromJson(resultMap);
  try {
    // Check if there is already a patient with the same id document from the same country
    // var checkResult = await conn!.execute("SELECT * FROM pacientes WHERE pais = :pais and documento = :doc ",
    //     {"pais": patient.pais, "doc": patient.documento});

    //final checkResult = await conn!.query("SELECT * FROM table WHERE id = @idParam:int4", substitutionValues: {"idParam" : 2});

    // final checkResult = await conn!.query("SELECT documento FROM pacientes WHERE documento = @documento", substitutionValues: {"documento": "14623438"});
    var checkResult = await conn!.query("SELECT * FROM pacientes WHERE documento = @documento AND pais = @pais",
        substitutionValues: {"documento": patient.documento, "pais": patient.pais});

    if (checkResult.isNotEmpty) {
      logger.i("Trying to create an already existent patient: $patient");
      result = '{"Result" : "Failure", "Message" : "Ya existe un paciente de ese país con el mismo nro. de documento" }';
    } else {
/*      await conn.transaction((ctx) async {
        var result = await ctx.query("SELECT * FROM pacientes");
        await ctx.query("INSERT INTO pacientes (nombre) VALUES (@a:varchar)", substitutionValues: {
          "a" : "Pirulo"
        });
      });*/

      // logger.e(patient.fechaNacimiento);
      // logger.e(patient.fechaNacimiento != null ? DateTime.parse(patient.fechaNacimiento!).toString().split(' ')[0] : null);
      PostgreSQLResult? creationResult;

      String normalizedApellido = removeDiacritics(patient.apellido.toLowerCase());

      await conn.transaction((ctx) async {
        creationResult = await ctx.query(
            "INSERT INTO pacientes (apellido, normalized_apellido, comentarios,  diag1,  diag2,  diag3,  diag4,  diagnostico_prenatal,  documento,  fecha_creacion_ficha, fecha_nacimiento,   fecha_primer_diagnostico, nombre, nro_ficha_diag_prenatal, nro_hist_clinica_papel,  paciente_fallecido, pais,  semanas_gestacion, sexo ) VALUES (@apellido, @normalized_apellido, @comentarios, @diag1, @diag2, @diag3, @diag4, @diagnostico_prenatal, @documento,  @fecha_creacion_ficha, @fecha_nacimiento,  @fecha_primer_diagnostico, @nombre,  @nro_ficha_diag_prenatal, @nro_hist_clinica_papel, @paciente_fallecido, @pais,  @semanas_gestacion, @sexo)",
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
              "comentarios": patient.comentarios,
              "fecha_nacimiento": patient.fechaNacimiento != null ? DateTime.parse(patient.fechaNacimiento!) : null,
              "fecha_creacion_ficha": DateTime.parse(patient.fechaCreacionFicha),
              "sexo": patient.sexo,
              "diagnostico_prenatal": patient.diagnosticoPrenatal,
              "paciente_fallecido": patient.pacienteFallecido,
              "semanas_gestacion": patient.semanasGestacion,
              "fecha_primer_diagnostico": patient.fechaPrimerDiagnostico != null
                  ? DateTime.parse(patient.fechaPrimerDiagnostico!).toString().split(' ')[0]
                  : null,
              "nro_hist_clinica_papel": patient.nroHistClinicaPapel,
              "nro_ficha_diag_prenatal": patient.nroFichaDiagPrenatal,
            });
      });
      //     await conn.execute("COMMIT");
      logger.i("Respuesta al ALTA de la BD ${creationResult!.columnDescriptions.toString()}");
      result =
          '{"Result" : "Success", "Message" : "Se creó el paciente ${patient.nombre} ${patient.apellido} con índice nro. a determinar"}';
    }
    // affectedRows is a BigInt but I seriously doubt the number of
    // patiens cas exceed 9223372036854775807
    return result;
  } catch (e) {
    logger.e("Error al crear paciente: ${e.toString()}");
    print(e);
    return '{"Result" : "Failure", "Message" : "Error en la comunicación contra la BD" }';
  }
}

/*
                  FUNCTION updatePatient

                  inputs:
                  String patientData            : JSON string with Patient data
                  PostgreSQLConnection? conn    : connection with database

                  returns:
                    Future<String> :


*/

Future<String> updatePatient(String patientData, PostgreSQLConnection? conn) async {
  logger.d("Received update request for:  $patientData");
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

  Paciente patient = Paciente.fromJson(resultMap);
  try {
    PostgreSQLResult? updateResult;

    await conn!.transaction((ctx) async {
      updateResult = await ctx.query(
          "UPDATE pacientes SET apellido = @apellido, nombre = @nombre, diag1 = @diag1, diag2 = @diag2, diag3 = @diag3, diag4 = @diag4, comentarios = @comentarios, sexo = @sexo, diagnostico_prenatal = @diagnostico_prenatal, paciente_fallecido = @paciente_fallecido, semanas_gestacion = @semanas_gestacion, nro_hist_clinica_papel = @nro_hist_clinica_papel, nro_ficha_diag_prenatal = @nro_ficha_diag_prenatal, fecha_nacimiento = @fecha_nacimiento WHERE id = @id ",
          substitutionValues: {
            "id": patient.id,
            "nombre": patient.nombre,
            "apellido": patient.apellido,
            "diag1": patient.diag1,
            "diag2": patient.diag2,
            "diag3": patient.diag3,
            "diag4": patient.diag4,
            "comentarios": patient.comentarios,
            "fecha_nacimiento": patient.fechaNacimiento != null ? DateTime.parse(patient.fechaNacimiento!) : null,
            "sexo": patient.sexo,
            "diagnostico_prenatal": patient.diagnosticoPrenatal,
            "paciente_fallecido": patient.pacienteFallecido,
            "semanas_gestacion": patient.semanasGestacion,
            "fecha_primer_diagnostico": patient.fechaPrimerDiagnostico != null
                ? DateTime.parse(patient.fechaPrimerDiagnostico!).toString().split(' ')[0]
                : null,
            "nro_hist_clinica_papel": patient.nroHistClinicaPapel,
            "nro_ficha_diag_prenatal": patient.nroFichaDiagPrenatal,
          });
    });
    //     await conn.execute("COMMIT");
    logger.d("Respuesta al UPDATE de la BD ${updateResult!.columnDescriptions.toString()}");
    result =
        '{"Result" : "Success", "Message" : "Se actualizó al paciente ${patient.nombre} ${patient.apellido} con índice nro. a determinar"}';

    // affectedRows is a BigInt but I seriously doubt the number of
    // patiens cas exceed 9223372036854775807
    return result;
  } catch (e) {
    logger.e("Error al actualizar paciente: ${e.toString()}");
    print(e);
    return '{"Result" : "Failure", "Message" : "Error en la conunicación contra la BD" }';
  }
}

Future<String> getPatientsByLastName(String s, PostgreSQLConnection? conn) async {
  logger.d("Looking for patients by Last Name: $s");

  List<Map<String, dynamic>> retrievedPatients = [];

  // make query
  try {
    s = removeDiacritics(s.toLowerCase());

    var results = await conn!.query("SELECT * FROM pacientes WHERE unaccent(normalized_apellido) ILIKE @ape  LIMIT 10",
        substitutionValues: {"ape": '%$s%'});

    logger.d("Looking by Last Name Found: ${results.toString()}");
    // print query result
    for (final row in results) {
      logger.d(row.toString());
      logger.d(row.runtimeType);
      // retrievedPatients.add(Paciente.fromJson(row.assoc()));
      retrievedPatients.add(row.toColumnMap());
      // Convert all DateTime type to String with format yyyy-mm-dd
      var date = retrievedPatients[retrievedPatients.length - 1]["fecha_nacimiento"];
      retrievedPatients[retrievedPatients.length - 1]["fecha_nacimiento"] =
          date != null ? "${date.year}-${date.month}-${date.day}" : null;
      date = retrievedPatients[retrievedPatients.length - 1]["fecha_creacion_ficha"];
      retrievedPatients[retrievedPatients.length - 1]["fecha_creacion_ficha"] =
          date != null ? "${date.year}-${date.month}-${date.day}" : null;
      date = retrievedPatients[retrievedPatients.length - 1]["fecha_primer_diagnostico"];
      retrievedPatients[retrievedPatients.length - 1]["fecha_primer_diagnostico"] =
          date != null ? "${date.year}-${date.month}-${date.day}" : null;
      //
      // logger.d("Number of rows retrieved: ${result.numOfRows}");
      // logger.d("Rows retrieved: $retrievedPatients");
      logger.d(jsonEncode(retrievedPatients));
    }
    return jsonEncode(retrievedPatients);
  } catch (e) {
    logger.e(e);
    return '{"Result" : "Failure", "Message" : "Error en la comunicación contra la Base de datos" }';
  }
}

Future<String> getPatientsByIdDoc(String s, PostgreSQLConnection? conn) async {
  logger.d("Looking for patients by Last Name: $s");

  List<Map<String, dynamic>> retrievedPatients = [];

  // make query
  try {
    var results = await conn!
        .query("SELECT * FROM pacientes WHERE documento LIKE @documento  LIMIT 10", substitutionValues: {"documento": '%$s%'});

    // print query result
    for (final row in results) {
      logger.d(row.toString());
      logger.d(row.runtimeType);
      // retrievedPatients.add(Paciente.fromJson(row.assoc()));
      retrievedPatients.add(row.toColumnMap());
      // Convert all DateTime type to String with format yyyy-mm-dd
      var date = retrievedPatients[retrievedPatients.length - 1]["fecha_de_nacimiento"];
      retrievedPatients[retrievedPatients.length - 1]["fecha_de_nacimiento"] =
          date != null ? "${date.year}-${date.month}-${date.day}" : null;
      date = retrievedPatients[retrievedPatients.length - 1]["fecha_creacion_ficha"];
      retrievedPatients[retrievedPatients.length - 1]["fecha_creacion_ficha"] =
          date != null ? "${date.year}-${date.month}-${date.day}" : null;
      date = retrievedPatients[retrievedPatients.length - 1]["fecha_primer_diagnostico"];
      retrievedPatients[retrievedPatients.length - 1]["fecha_primer_diagnostico"] =
          date != null ? "${date.year}-${date.month}-${date.day}" : null;
      //
      // logger.d("Number of rows retrieved: ${result.numOfRows}");
      // logger.d("Rows retrieved: $retrievedPatients");
      logger.d(jsonEncode(retrievedPatients));
    }
    return jsonEncode(retrievedPatients);
  } catch (e) {
    logger.e(e);
    return '{"Result" : "Failure", "Message" : "Error en la comunicación contra la Base de datos" }';
  }
}

String removeDiacritics(String input) {
  final diacriticMap = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    // Add more mappings as needed
  };

  String result = input.characters.map((char) {
    final replacement = diacriticMap[char];
    return replacement ?? char;
  }).join('');

  return result;
}

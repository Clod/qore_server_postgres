import 'dart:async';
import 'dart:convert';
import 'package:characters/characters.dart';
import 'package:postgres/postgres.dart';
import 'package:logger/logger.dart';
import 'model/paciente.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 1,
    lineLength: 132,
    colors: false,
    printEmojis: false,
    printTime: true,
  ),
);

/// Error messages
const errorMessages = {
  'dbConnection': '{"Result":"Failure","Message":"Error en la comunicación contra la Base de datos"}',
  'patientExists': '{"Result":"Failure","Message":"Ya existe un paciente de ese país con el mismo nro. de documento"}',
  'recordLocked': '{"Result":"Failure","Message":"Registro lockeado"}',
  'unauthorized': '{"Result":"Failure","Message":"Usuario no autorizado"}',
};

/// Formats a success response message
String formatSuccessResponse(String message) => 
  '{"Result":"Success","Message":"$message"}';

/// Formats a failure response message
String formatFailureResponse(String message) => 
  '{"Result":"Failure","Message":"$message"}';

/*
                  FUNCTION addPatient
                  
                  inputs:
                  String patientData            : JSON string with Patient data 
                  PostgreSQLConnection? conn    : connection with database
                  
                  returns:
                    Future<String> : 
                  
                      
*/

/// Parses a string representation of a patient data into a Map
Map<String, dynamic> parsePatientData(String patientData) {
  final keyValueString = patientData.replaceAll('{', '').replaceAll('}', '');
  final keyValuePairs = keyValueString.split(',');
  
  return Map.fromEntries(
    keyValuePairs.map((keyValue) {
      final pair = keyValue.split(':');
      final key = pair[0].trim();
      final value = pair[1].trim() == 'null' ? null : pair[1].trim();
      return MapEntry(key, value);
    }),
  );
}

/// Adds a new patient to the database
Future<String> addPatient(String patientData, PostgreSQLConnection? conn) async {
  if (conn == null) return errorMessages['dbConnection']!;
  
  logger.i("Received Creation request for: $patientData");
  
  try {
    final resultMap = parsePatientData(patientData);
    final patient = Paciente.fromJson(resultMap);

    // Check if patient already exists
    final checkResult = await conn.query(
      "SELECT * FROM pacientes WHERE documento = @documento AND pais = @pais",
      substitutionValues: {
        "documento": patient.documento,
        "pais": patient.pais
      }
    );

    if (checkResult.isNotEmpty) {
      logger.i("Trying to create an already existent patient: $patient");
      return errorMessages['patientExists']!;
    }

    final normalizedApellido = removeDiacritics(patient.apellido.toLowerCase());
    late final String id;

    await conn.transaction((ctx) async {
      await ctx.query(
        """
        INSERT INTO pacientes (
          apellido, normalized_apellido, comentarios, historial, 
          diag1, diag2, diag3, diag4, sind_y_asoc_gen, 
          diagnostico_prenatal, documento, fecha_creacion_ficha, 
          fecha_nacimiento, fecha_primer_diagnostico, nombre, 
          nro_ficha_diag_prenatal, nro_hist_clinica_papel, 
          paciente_fallecido, pais, semanas_gestacion, sexo
        ) VALUES (
          @apellido, @normalized_apellido, @comentarios, @historial,
          @diag1, @diag2, @diag3, @diag4, @sind_y_asoc_gen,
          @diagnostico_prenatal, @documento, @fecha_creacion_ficha,
          @fecha_nacimiento, @fecha_primer_diagnostico, @nombre,
          @nro_ficha_diag_prenatal, @nro_hist_clinica_papel,
          @paciente_fallecido, @pais, @semanas_gestacion, @sexo
        )
        """,
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
        }
      );

      final newRow = await ctx.query("SELECT lastval()");
      id = newRow[0][0].toString();
    });

    logger.i("Created patient ${patient.nombre} ${patient.apellido} with id = $id");
    return formatSuccessResponse(
      "Se creó el paciente ${patient.nombre} ${patient.apellido} con íd = $id"
    );
  } catch (e) {
    logger.e("Error creating patient", error: e);
    return errorMessages['dbConnection']!;
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

/// Updates an existing patient in the database
Future<String> updatePatient(String patientData, PostgreSQLConnection? conn) async {
  if (conn == null) return errorMessages['dbConnection']!;
  
  logger.d("Received update request for: $patientData");
  
  try {
    final resultMap = parsePatientData(patientData);
    final patient = Paciente.fromJson(resultMap);
    final normalizedApellido = removeDiacritics(patient.apellido.toLowerCase());

    await conn.transaction((ctx) async {
      final result = await ctx.query(
        """
        UPDATE pacientes SET 
          apellido = @apellido,
          normalized_apellido = @normalized_apellido,
          nombre = @nombre,
          diag1 = @diag1,
          diag2 = @diag2,
          diag3 = @diag3,
          diag4 = @diag4,
          sind_y_asoc_gen = @sind_y_asoc_gen,
          comentarios = @comentarios,
          historial = @historial,
          sexo = @sexo,
          diagnostico_prenatal = @diagnostico_prenatal,
          paciente_fallecido = @paciente_fallecido,
          semanas_gestacion = @semanas_gestacion,
          nro_hist_clinica_papel = @nro_hist_clinica_papel,
          nro_ficha_diag_prenatal = @nro_ficha_diag_prenatal,
          fecha_nacimiento = @fecha_nacimiento,
          fecha_primer_diagnostico = @fecha_primer_diagnostico
        WHERE id = @id
        """,
        substitutionValues: {
          "id": patient.id,
          "nombre": patient.nombre,
          "apellido": patient.apellido,
          "normalized_apellido": normalizedApellido,
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
              ? DateTime.parse(patient.fechaPrimerDiagnostico!).toString().split(' ')[0]
              : null,
          "nro_hist_clinica_papel": patient.nroHistClinicaPapel,
          "nro_ficha_diag_prenatal": patient.nroFichaDiagPrenatal,
        }
      );

      if (result.affectedRowCount == 0) {
        throw Exception('No patient found with id ${patient.id}');
      }
    });

    logger.i("Updated patient ${patient.nombre} ${patient.apellido}");
    return formatSuccessResponse(
      "Se actualizó al paciente ${patient.nombre} ${patient.apellido}"
    );
  } catch (e) {
    logger.e("Error updating patient", error: e);
    return errorMessages['dbConnection']!;
  }
}

/// Formats a date to string in yyyy-mm-dd format
String? _formatDate(DateTime? date) {
  if (date == null) return null;
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// Converts a PostgreSQL row to a map with properly formatted dates
Map<String, dynamic> _convertRowToMap(Map<String, dynamic> row) {
  final map = Map<String, dynamic>.from(row);
  
  // Format dates consistently
  map['fecha_nacimiento'] = _formatDate(map['fecha_nacimiento'] as DateTime?);
  map['fecha_creacion_ficha'] = _formatDate(map['fecha_creacion_ficha'] as DateTime?);
  map['fecha_primer_diagnostico'] = _formatDate(map['fecha_primer_diagnostico'] as DateTime?);
  
  return map;
}

/// Searches for patients by last name
Future<String> getPatientsByLastName(String lastName, PostgreSQLConnection? conn) async {
  if (conn == null) return errorMessages['dbConnection']!;
  
  logger.d("Looking for patients by last name: $lastName");
  
  try {
    final normalizedLastName = removeDiacritics(lastName.toLowerCase());
    
    final results = await conn.query(
      """
      SELECT * FROM pacientes 
      WHERE unaccent(normalized_apellido) ILIKE @ape 
      ORDER BY apellido, nombre
      LIMIT 10
      """,
      substitutionValues: {"ape": '%$normalizedLastName%'}
    );

    final patients = results.map((row) => _convertRowToMap(row.toColumnMap())).toList();
    logger.d("Found ${patients.length} patients");
    
    return jsonEncode(patients);
  } catch (e) {
    logger.e("Error searching patients by last name", error: e);
    return errorMessages['dbConnection']!;
  }
}

/// Searches for patients by document ID
Future<String> getPatientsByIdDoc(String documentId, PostgreSQLConnection? conn) async {
  if (conn == null) return errorMessages['dbConnection']!;
  
  logger.d("Looking for patients by document ID: $documentId");
  
  try {
    final results = await conn.query(
      """
      SELECT * FROM pacientes 
      WHERE documento LIKE @documento
      ORDER BY apellido, nombre
      LIMIT 10
      """,
      substitutionValues: {"documento": '%$documentId%'}
    );

    final patients = results.map((row) => _convertRowToMap(row.toColumnMap())).toList();
    logger.d("Found ${patients.length} patients");
    
    return jsonEncode(patients);
  } catch (e) {
    logger.e("Error searching patients by document ID", error: e);
    return errorMessages['dbConnection']!;
  }
}

/*
* Traigo el paciente y lo lockeo
*
* */
/// Gets a patient by ID and locks the record for update
Future<String> getPatientById(String id, PostgreSQLConnection? conn) async {
  if (conn == null) return errorMessages['dbConnection']!;
  
  logger.d("Looking for patient by ID: $id");
  logger.d("Using connection with DB: ${conn.processID}");
  
  try {
    await conn.query('BEGIN');

    final results = await conn.query(
      """
      SELECT * FROM pacientes 
      WHERE id = @id 
      FOR UPDATE NOWAIT
      """,
      substitutionValues: {"id": id}
    );

    if (results.isEmpty) {
      await conn.query('ROLLBACK');
      return formatFailureResponse("No se encontró el paciente");
    }

    final patient = _convertRowToMap(results[0].toColumnMap());
    logger.d("Found and locked patient record");
    
    return jsonEncode([patient]); // Keep array format for consistency
  } catch (e) {
    await conn.query('ROLLBACK');
    
    if (e.toString().contains("PostgreSQLSeverity.error 55P03")) {
      return errorMessages['recordLocked']!;
    }
    
    logger.e("Error getting patient by ID", error: e);
    return errorMessages['dbConnection']!;
  }
}

/// Updates a patient record with a lock for concurrent access control
Future<String> updatePatientLOCK(String patientData, PostgreSQLConnection? conn) async {
  if (conn == null) return errorMessages['dbConnection']!;
  
  logger.d("Received update request with lock for: $patientData");
  
  try {
    final resultMap = parsePatientData(patientData);
    final patient = Paciente.fromJson(resultMap);
    final normalizedApellido = removeDiacritics(patient.apellido.toLowerCase());

    await conn.query('BEGIN');

    try {
      // Lock the patient record
      final lockResult = await conn.query(
        'SELECT * FROM pacientes WHERE id = @id FOR UPDATE NOWAIT',
        substitutionValues: {'id': patient.id}
      );

      if (lockResult.isEmpty) {
        await conn.query('ROLLBACK');
        return formatFailureResponse("No se encontró el paciente");
      }

      final result = await conn.query(
        """
        UPDATE pacientes SET 
          apellido = @apellido,
          normalized_apellido = @normalized_apellido,
          nombre = @nombre,
          diag1 = @diag1,
          diag2 = @diag2,
          diag3 = @diag3,
          diag4 = @diag4,
          sind_y_asoc_gen = @sind_y_asoc_gen,
          comentarios = @comentarios,
          historial = @historial,
          sexo = @sexo,
          diagnostico_prenatal = @diagnostico_prenatal,
          paciente_fallecido = @paciente_fallecido,
          semanas_gestacion = @semanas_gestacion,
          nro_hist_clinica_papel = @nro_hist_clinica_papel,
          nro_ficha_diag_prenatal = @nro_ficha_diag_prenatal,
          fecha_nacimiento = @fecha_nacimiento,
          fecha_primer_diagnostico = @fecha_primer_diagnostico
        WHERE id = @id
        """,
        substitutionValues: {
          "id": patient.id,
          "nombre": patient.nombre,
          "apellido": patient.apellido,
          "normalized_apellido": normalizedApellido,
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
              ? DateTime.parse(patient.fechaPrimerDiagnostico!).toString().split(' ')[0]
              : null,
          "nro_hist_clinica_papel": patient.nroHistClinicaPapel,
          "nro_ficha_diag_prenatal": patient.nroFichaDiagPrenatal,
        }
      );

      if (result.affectedRowCount == 0) {
        throw Exception('Failed to update patient ${patient.id}');
      }

      await conn.query('COMMIT');
      logger.i("Updated patient ${patient.nombre} ${patient.apellido} with lock");
      
      return formatSuccessResponse(
        "Se actualizó al paciente ${patient.nombre} ${patient.apellido}"
      );
    } catch (e) {
      await conn.query('ROLLBACK');
      if (e.toString().contains("PostgreSQLSeverity.error 55P03")) {
        return errorMessages['recordLocked']!;
      }
      rethrow;
    }
  } catch (e) {
    logger.e("Error updating patient with lock", error: e);
    return errorMessages['dbConnection']!;
  }
}

/// Removes diacritics (accent marks) from a string
/// 
/// This function takes a string input and returns a new string with all diacritical
/// marks removed. For example, 'á' becomes 'a', 'é' becomes 'e', etc.
/// 
/// Example:
/// ```dart
/// final normalized = removeDiacritics('José'); // Returns 'Jose'
/// ```
String removeDiacritics(String input) {
  const diacriticMap = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'Á': 'A',
    'É': 'E',
    'Í': 'I',
    'Ó': 'O',
    'Ú': 'U',
    'Ü': 'U',
    'ñ': 'n',
    'Ñ': 'N',
  };

  return input.characters.map((char) => diacriticMap[char] ?? char).join('');
}

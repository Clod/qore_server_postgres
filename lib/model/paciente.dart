// Define a class for Paciente
class Paciente {
  // Constructor for Paciente
  Paciente({
    required this.id,
    required this.nombre,
    required this.apellido,
    this.fechaNacimiento,
    this.documento,
    this.pais,
    required this.fechaCreacionFicha,
    this.sexo,
    this.diagnosticoPrenatal,
    this.pacienteFallecido,
    this.semanasGestacion,
    this.diag1,
    this.diag2,
    this.diag3,
    this.diag4,
    this.sindAsocGen,
    this.fechaPrimerDiagnostico,
    this.nroHistClinicaPapel,
    this.nroFichaDiagPrenatal,
    this.comentarios,
    this.historial,
  });

  // Declare final int id
  final int id;
  // Declare String nombre
  String nombre;
  // Declare String apellido
  String apellido;
  // Declare String? documento
  String? documento;
  // Declare String? pais
  String? pais;
  // Declare String? fechaNacimiento
  String? fechaNacimiento;
  // Declare String fechaCreacionFicha
  String fechaCreacionFicha;
  // Declare String? sexo
  String? sexo;
  // Declare String? diagnosticoPrenatal
  String? diagnosticoPrenatal;
  // Declare String? pacienteFallecido
  String? pacienteFallecido;
  // Declare int? semanasGestacion
  int? semanasGestacion;
  // Declare String? diag1
  String? diag1;
  // Declare String? diag2
  String? diag2;
  // Declare String? diag3
  String? diag3;
  // Declare String? diag4
  String? diag4;
  // Declare String? sindAsocGen
  String? sindAsocGen;
  // Declare String? fechaPrimerDiagnostico
  String? fechaPrimerDiagnostico;
  // Declare String? nroHistClinicaPapel
  String? nroHistClinicaPapel;
  // Declare String? nroFichaDiagPrenatal
  String? nroFichaDiagPrenatal;
  // Declare String? comentarios
  String? comentarios;
  // Declare String? historial
  String? historial;

  // Factory method to create a Paciente object from JSON
  factory Paciente.fromJson(Map<String, dynamic> data) {
// note the explicit cast to String
// this is required if robust lint rules are enabled
    // Parse the id
    final id = int.parse(data['id']);
    // Get the name
    final nombre = data['nombre'] as String;
    // Get the last name
    final apellido = data['apellido'] as String;
    // Get the birth date
    final fechaNacimiento = data['fechaNacimiento'] != null
        ? data['semanasGestacion'] as String
        : null;
    // Get the document
    final documento = data['documento'] as String?;
    // Get the country
    final pais = data['pais'] as String?;
    // Get the creation date
    final fechaCreacionFicha = data['fechaCreacionFicha'] as String;
    // Get the sex
    final sexo = data['sexo'] as String?;
    // Get the prenatal diagnosis
    final diagnosticoPrenatal = data['diagnosticoPenatal'] != null
        ? data['diagnosticoPenatal'] as String?
        : null;
    // Get the deceased patient
    final pacienteFallecido = data['pacienteFallecido'] as String?;
    // Get the weeks of gestation
    final semanasGestacion = data['semanasGestacion'] != null
        ? int.parse(data['semanasGestacion'])
        : null;
    // Get the diagnosis 1
    final diag1 = data['diag1'] as String?;
    // Get the diagnosis 2
    final diag2 = data['diag2'] != null ? data['diag2'] as String? : null;
    // Get the diagnosis 3
    final diag3 = data['diag3'] != null ? data['diag3'] as String? : null;
    // Get the diagnosis 4
    final diag4 = data['diag4'] != null ? data['diag4'] as String? : null;
    // Get the genetic syndrome
    final sindAsocGen =
        data['sindAsocGen'] != null ? data['sindAsocGen'] as String? : null;
    // Get the first diagnosis date
    final fechaPrimerDiagnostico = data['fechaPrimerDiagnostico'] != null
        ? data['fechaPrimerDiagnostico'] as String?
        : null;
    // Get the paper clinical history number
    final nroHistClinicaPapel = data['nroHistClinicaPapel'] as String?;
    // Get the prenatal diagnosis number
    final nroFichaDiagPrenatal = data['nroFichaDiagPrenatal'] != null
        ? data['nroFichaDiagPrenatal'] as String?
        : null;
    // Get the comments
    final comentarios =
        data['comentarios'] != null ? data['comentarios'] as String? : null;
    // Get the history
    final historial =
        data['historial'] != null ? data['historial'] as String? : null;

    // Return a new Paciente object
    return Paciente(
      id: id,
      nombre: nombre,
      apellido: apellido,
      fechaNacimiento: fechaNacimiento,
      documento: documento,
      pais: pais,
      fechaCreacionFicha: fechaCreacionFicha,
      sexo: sexo,
      diagnosticoPrenatal: diagnosticoPrenatal,
      pacienteFallecido: pacienteFallecido,
      semanasGestacion: semanasGestacion,
      diag1: diag1,
      diag2: diag2,
      diag3: diag3,
      diag4: diag4,
      sindAsocGen: sindAsocGen,
      fechaPrimerDiagnostico: fechaPrimerDiagnostico,
      nroHistClinicaPapel: nroHistClinicaPapel,
      nroFichaDiagPrenatal: nroFichaDiagPrenatal,
      comentarios: comentarios,
      historial: historial,
    );
  }

  // Method to convert a Paciente object to JSON
  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'apellido': apellido,
        'fechaNacimiento': fechaNacimiento,
        'documento': documento,
        'pais': pais,
        'fechaCreacionFicha': fechaCreacionFicha,
        'sexo': sexo,
        'diagnosticoPrenatal': diagnosticoPrenatal,
        'pacienteFallecido': pacienteFallecido,
        'semanasGestacion': semanasGestacion,
        'diag1': diag1,
        'diag2': diag2,
        'diag3': diag3,
        'diag4': diag4,
        'sindAsocGen': sindAsocGen,
        'fechaPrimerDiagnostico': fechaPrimerDiagnostico,
        'nroHistClinicaPapel': nroHistClinicaPapel,
        'nroFichaDiagPrenatal': nroFichaDiagPrenatal,
        'comentarios': comentarios,
        'historial': historial,
      };

  // Override the toString method
  @override
  String toString() {
    // return (id.toString() + " " + nombre + " " + apellido);
    return toJson().toString();
  }
}

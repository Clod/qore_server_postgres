class Paciente {
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

  final int id;
  String nombre;
  String apellido;
  String? documento;
  String? pais;
  String? fechaNacimiento;
  String fechaCreacionFicha;
  String? sexo;
  String? diagnosticoPrenatal;
  String? pacienteFallecido;
  int? semanasGestacion;
  String? diag1;
  String? diag2;
  String? diag3;
  String? diag4;
  String? sindAsocGen;
  String? fechaPrimerDiagnostico;
  String? nroHistClinicaPapel;
  String? nroFichaDiagPrenatal;
  String? comentarios;
  String? historial;

  factory Paciente.fromJson(Map<String, dynamic> data) {
// note the explicit cast to String
// this is required if robust lint rules are enabled
    final id = int.parse(data['id']);
    final nombre = data['nombre'] as String;
    final apellido = data['apellido'] as String;
    final fechaNacimiento = data['fechaNacimiento'] != null
        ? data['semanasGestacion'] as String
        : null;
    final documento = data['documento'] as String?;
    final pais = data['pais'] as String?;
    final fechaCreacionFicha = data['fechaCreacionFicha'] as String;
    final sexo = data['sexo'] as String?;
    final diagnosticoPrenatal = data['diagnosticoPenatal'] != null
        ? data['diagnosticoPenatal'] as String?
        : null;
    final pacienteFallecido = data['pacienteFallecido'] as String?;
    final semanasGestacion = data['semanasGestacion'] != null
        ? int.parse(data['semanasGestacion'])
        : null;
    final diag1 = data['diag1'] as String?;
    final diag2 = data['diag2'] != null ? data['diag2'] as String? : null;
    final diag3 = data['diag3'] != null ? data['diag3'] as String? : null;
    final diag4 = data['diag4'] != null ? data['diag4'] as String? : null;
    final sindAsocGen =
        data['sindAsocGen'] != null ? data['sindAsocGen'] as String? : null;
    final fechaPrimerDiagnostico = data['fechaPrimerDiagnostico'] != null
        ? data['fechaPrimerDiagnostico'] as String?
        : null;
    final nroHistClinicaPapel = data['nroHistClinicaPapel'] as String?;
    final nroFichaDiagPrenatal = data['nroFichaDiagPrenatal'] != null
        ? data['nroFichaDiagPrenatal'] as String?
        : null;
    final comentarios =
        data['comentarios'] != null ? data['comentarios'] as String? : null;
    final historial =
        data['historial'] != null ? data['historial'] as String? : null;

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

  @override
  String toString() {
    // return (id.toString() + " " + nombre + " " + apellido);
    return toJson().toString();
  }
}

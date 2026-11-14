import 'course.dart';
import 'enrollment.dart';

/// Una escritura que hará el plan sobre `enrollments`.
class EnrollmentChange {
  const EnrollmentChange({
    required this.target,
    required this.isNew,
    required this.statusChanged,
  });

  /// Estado final de la matrícula.
  final Enrollment target;

  /// Documento nuevo (`create`) o existente (`update`).
  final bool isNew;

  /// Cambia el estado: el servicio pone `statusAt` = hora del servidor.
  final bool statusChanged;
}

/// Cambios sobre la lista de una asignatura, calculados antes de guardar
/// para mostrarlos en la vista previa. Es lógica pura y se prueba sola.
///
/// Reglas (docs/MODELO_DE_DATOS.md):
/// - **Importar reemplaza la lista oficial:** quien viene en el archivo queda
///   activo; quien vino de una importación anterior y ya no está, sale
///   (`removed`). Sus asistencias se conservan.
/// - La lista queda **igual al archivo**: también salen los agregados a mano
///   que no vienen en él.
/// - Quien canceló o rechazó y sigue en el archivo **no cambia** (se respeta
///   su decisión) y se avisa.
/// - Agregar a mano crea una invitación (o la renueva).
class RosterPlan {
  RosterPlan._(this.changes, this.counts, this.keptChoice, this.leaving);

  /// Plan para una lista importada ([imported]) sobre la lista actual.
  factory RosterPlan.forImport({
    required String courseId,
    required List<Enrollment> current,
    required List<RosterEntry> imported,
  }) {
    final byEmail = {for (final e in current) e.email: e};
    final inFile = <String>{};
    final changes = <EnrollmentChange>[];
    final counts = <RosterChangeKind, int>{};
    final keptChoice = <Enrollment>[];
    final leaving = <Enrollment>[];
    void count(RosterChangeKind k) => counts[k] = (counts[k] ?? 0) + 1;

    for (final r in imported) {
      final email = r.email.trim().toLowerCase();
      if (!inFile.add(email)) continue; // repetido (parseRoster ya lo avisa)
      final old = byEmail[email];
      if (old == null) {
        changes.add(
          EnrollmentChange(
            target: Enrollment(
              courseId: courseId,
              email: email,
              code: r.code,
              name: r.name,
              program: r.program,
              status: EnrollmentStatus.active,
              source: EnrollmentSource.import,
            ),
            isNew: true,
            statusChanged: true,
          ),
        );
        count(RosterChangeKind.added);
        continue;
      }
      final sameData =
          old.code == r.code && old.name == r.name && old.program == r.program;
      switch (old.status) {
        case EnrollmentStatus.withdrawn:
        case EnrollmentStatus.declined:
          keptChoice.add(old);
          count(RosterChangeKind.keptChoice);
        case EnrollmentStatus.invited:
        case EnrollmentStatus.removed:
          changes.add(
            EnrollmentChange(
              target: old.copyWith(
                code: r.code,
                name: r.name,
                program: r.program,
                status: EnrollmentStatus.active,
                source: EnrollmentSource.import,
              ),
              isNew: false,
              statusChanged: true,
            ),
          );
          count(RosterChangeKind.reactivated);
        case EnrollmentStatus.active:
          if (sameData && old.source == EnrollmentSource.import) {
            count(RosterChangeKind.unchanged);
          } else {
            changes.add(
              EnrollmentChange(
                target: old.copyWith(
                  code: r.code,
                  name: r.name,
                  program: r.program,
                  source: EnrollmentSource.import,
                ),
                isNew: false,
                statusChanged: false,
              ),
            );
            count(
              sameData ? RosterChangeKind.unchanged : RosterChangeKind.updated,
            );
          }
      }
    }

    for (final old in current) {
      // La lista queda igual al archivo: también salen los agregados a mano
      // (matriculados o con la invitación pendiente) que no vienen en él.
      if (inFile.contains(old.email) || !old.status.isCurrent) continue;
      leaving.add(old);
      changes.add(
        EnrollmentChange(
          target: old.copyWith(status: EnrollmentStatus.removed),
          isNew: false,
          statusChanged: true,
        ),
      );
      count(RosterChangeKind.removed);
    }
    return RosterPlan._(changes, counts, keptChoice, leaving);
  }

  /// Invitar a mano a un estudiante. Devuelve null y un motivo en [error]
  /// si ya está matriculado o invitado.
  static EnrollmentChange? invite({
    required String courseId,
    required List<Enrollment> current,
    required RosterEntry entry,
    void Function(String message)? error,
  }) {
    final email = entry.email.trim().toLowerCase();
    Enrollment? old;
    for (final e in current) {
      if (e.email == email) old = e;
    }
    if (old != null && old.status.isCurrent) {
      error?.call(
        old.isActive
            ? 'Ese estudiante ya está matriculado.'
            : 'Ese estudiante ya tiene una invitación pendiente.',
      );
      return null;
    }
    for (final e in current) {
      if (e.status.isCurrent && e.code == entry.code && e.email != email) {
        error?.call('Ese código ya está en la lista con otro correo.');
        return null;
      }
    }
    return EnrollmentChange(
      target:
          (old ??
                  Enrollment(
                    courseId: courseId,
                    email: email,
                    code: entry.code,
                    name: entry.name,
                    status: EnrollmentStatus.invited,
                  ))
              .copyWith(
                code: entry.code,
                name: entry.name,
                program: entry.program,
                status: EnrollmentStatus.invited,
                source: EnrollmentSource.manual,
              ),
      isNew: old == null,
      statusChanged: true,
    );
  }

  /// Quitar a mano de la lista (queda `removed`; su historial se conserva).
  static EnrollmentChange remove(Enrollment e) => EnrollmentChange(
    target: e.copyWith(status: EnrollmentStatus.removed),
    isNew: false,
    statusChanged: true,
  );

  /// Escrituras necesarias para pasar de [before] a [after] (ambas listas
  /// de la misma asignatura, por correo). Los nuevos que terminan fuera de
  /// la lista no se escriben.
  static List<EnrollmentChange> diff(
    List<Enrollment> before,
    List<Enrollment> after,
  ) {
    final old = {for (final e in before) e.email: e};
    final out = <EnrollmentChange>[];
    for (final e in after) {
      final o = old[e.email];
      if (o == null) {
        if (e.status.isCurrent) {
          out.add(
            EnrollmentChange(target: e, isNew: true, statusChanged: true),
          );
        }
        continue;
      }
      final changed =
          o.status != e.status ||
          o.code != e.code ||
          o.name != e.name ||
          o.program != e.program ||
          o.source != e.source;
      if (changed) {
        out.add(
          EnrollmentChange(
            target: e,
            isNew: false,
            statusChanged: o.status != e.status,
          ),
        );
      }
    }
    return out;
  }

  final List<EnrollmentChange> changes;
  final Map<RosterChangeKind, int> counts;

  /// Cancelaron o rechazaron y siguen en el archivo (no cambian).
  final List<Enrollment> keptChoice;

  /// Salen de la lista con esta importación.
  final List<Enrollment> leaving;

  int countOf(RosterChangeKind k) => counts[k] ?? 0;

  bool get hasChanges => changes.isNotEmpty;
}

enum RosterChangeKind {
  added,
  reactivated,
  updated,
  unchanged,
  removed,
  keptChoice,
}

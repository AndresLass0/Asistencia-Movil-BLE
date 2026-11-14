import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/date_format.dart';
import '../models/academic_snapshot.dart';
import '../models/attendance_record.dart';
import '../models/teacher_snapshot.dart';
import 'spreadsheet.dart';

/// Genera y comparte los reportes (PDF y Excel) del estudiante y del
/// docente, siempre a partir de los registros reales.
class ReportService {
  ReportService._();

  static const _green = PdfColor.fromInt(0xFF006B35);

  static const _disclaimer =
      'Documento generado por la app a partir de los registros de '
      'asistencia. No reemplaza las certificaciones oficiales de la '
      'universidad.';

  /// Documento con la fuente Roboto incrustada (soporte de tildes).
  static Future<pw.Document> _document(String title) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    return pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      title: '$title - BioAsistencia',
      author: 'BioAsistencia - Universidad de la Amazonia',
    );
  }

  static pw.Widget _title(String text) => pw.Text(
    text,
    style: pw.TextStyle(
      fontSize: 20,
      fontWeight: pw.FontWeight.bold,
      color: _green,
    ),
  );

  static pw.Widget _table(
    List<String> headers,
    List<List<String>> rows, {
    Set<int> centered = const {},
  }) => pw.TableHelper.fromTextArray(
    headers: headers,
    headerStyle: pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.white,
    ),
    headerDecoration: const pw.BoxDecoration(color: _green),
    cellAlignments: {for (final i in centered) i: pw.Alignment.center},
    data: rows,
  );

  static String _pct(int? p) => p == null ? '-' : '$p%';

  static String _stamp(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}'
      '${d.day.toString().padLeft(2, '0')}';

  static String _safe(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9áéíóúñ]+'), '_')
      .replaceAll(RegExp(r'_+'), '_');

  // ---------------------------------------------------------------------
  // Docente
  // ---------------------------------------------------------------------

  static String _status(AttendanceRow r) {
    if (r.present) {
      return r.record!.method == AttendanceMethod.manual
          ? 'Presente (manual)'
          : 'Presente';
    }
    final label = r.justification?.status.label ?? 'Ausente';
    return r.enrolled ? label : '$label (${r.student.status.label})';
  }

  /// Filas de la planilla de una sesión (para PDF y Excel).
  static List<List<String>> sessionRows(SessionReport report) => [
    for (final r in [...report.presentRows, ...report.absentRows])
      [
        r.student.code,
        r.student.name,
        _status(r),
        r.present ? time12h(r.record!.registeredAt) : '',
      ],
  ];

  static const _sessionHeaders = ['Código', 'Estudiante', 'Estado', 'Hora'];

  static Future<Uint8List> buildSessionPdf({
    required SessionReport report,
    required String teacherName,
    DateTime? generatedAt,
  }) async {
    final now = generatedAt ?? DateTime.now();
    final doc = await _document('Planilla de asistencia');
    final c = report.course;
    final s = report.session;
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          _title('Planilla de asistencia'),
          pw.SizedBox(height: 4),
          pw.Text('BioAsistencia - Universidad de la Amazonia (UDLA)'),
          pw.SizedBox(height: 10),
          pw.Text(
            '${c.name}${c.group.isEmpty ? '' : ' (Grupo ${c.group})'}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          if (c.period.isNotEmpty) pw.Text('Periodo: ${c.period}'),
          pw.Text('Docente: $teacherName'),
          pw.Text(
            'Sesión: ${shortDate(s.startsAt)}, ${time12h(s.startsAt)}'
            '${s.closedAt != null ? ' - ${time12h(s.closedAt!)}' : ''}',
          ),
          if (c.location.isNotEmpty) pw.Text('Lugar: ${c.location}'),
          pw.SizedBox(height: 8),
          pw.Text(
            'Presentes: ${report.present} de ${report.total} '
            '(${_pct(report.percent)}) · Ausentes: ${report.absent}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _table(_sessionHeaders, sessionRows(report), centered: {3}),
          pw.SizedBox(height: 16),
          pw.Text(
            'Generado: ${shortDate(now)} ${time12h(now)}. $_disclaimer',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static Uint8List buildSessionXlsx(SessionReport report) =>
      Spreadsheet.buildXlsx('Asistencia', [
        [report.course.name],
        [
          'Sesión',
          '${shortDate(report.session.startsAt)} '
              '${time12h(report.session.startsAt)}',
        ],
        ['Presentes', report.present, 'Total', report.total],
        [],
        _sessionHeaders,
        ...sessionRows(report),
      ]);

  static String sessionFileName(SessionReport report, String ext) =>
      'asistencia_${_safe(report.course.name)}_'
      '${_stamp(report.session.startsAt)}.$ext';

  /// Filas del consolidado por estudiante de un periodo.
  static List<List<Object>> consolidatedRows(
    TeacherSnapshot data,
    String? period,
  ) => [
    for (final c in data.coursesInPeriod(period))
      for (final st in data.reportForCourse(c).standings)
        [
          c.name,
          c.group,
          st.student.code,
          st.student.name,
          st.attended,
          st.absences,
          _pct(st.percent),
          st.remaining == null ? '' : '${st.remaining}',
        ],
  ];

  static const _consolidatedHeaders = [
    'Asignatura',
    'Grupo',
    'Código',
    'Estudiante',
    'Asistencias',
    'Faltas',
    '%',
    'Faltas restantes',
  ];

  static Uint8List buildConsolidatedXlsx(
    TeacherSnapshot data,
    String? period,
  ) => Spreadsheet.buildXlsx('Consolidado', [
    ['Consolidado de asistencia${period == null ? '' : ' $period'}'],
    [],
    _consolidatedHeaders,
    ...consolidatedRows(data, period),
  ]);

  static Future<Uint8List> buildTeacherPdf({
    required TeacherSnapshot data,
    required String? period,
    required String teacherName,
    DateTime? generatedAt,
  }) async {
    final now = generatedAt ?? DateTime.now();
    final doc = await _document('Reporte de asistencia');
    final sum = data.summary(period);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          _title('Reporte de asistencia${period == null ? '' : ' $period'}'),
          pw.SizedBox(height: 4),
          pw.Text('BioAsistencia - Universidad de la Amazonia (UDLA)'),
          pw.Text('Docente: $teacherName'),
          pw.Text('Generado: ${shortDate(now)} ${time12h(now)}'),
          pw.SizedBox(height: 10),
          pw.Text(
            'Asistencia promedio: ${_pct(sum.percent)} · '
            '${sum.heldSessions} sesiones · ${sum.students} estudiantes · '
            '${sum.atRisk} en riesgo',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          _table(
            ['Asignatura', 'Grupo', 'Inscritos', 'Sesiones', 'Asistencia'],
            [
              for (final c in data.coursesInPeriod(period))
                () {
                  final r = data.reportForCourse(c);
                  return [
                    c.name,
                    c.group,
                    '${data.enrolledCount(c.id)}',
                    '${r.heldSessions.length}',
                    _pct(r.percent),
                  ];
                }(),
            ],
            centered: {2, 3, 4},
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Detalle por estudiante',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14),
          ),
          pw.SizedBox(height: 6),
          _table(
            _consolidatedHeaders,
            [
              for (final row in consolidatedRows(data, period))
                [for (final v in row) '$v'],
            ],
            centered: {4, 5, 6, 7},
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            _disclaimer,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static String consolidatedFileName(
    String? period,
    DateTime now,
    String ext,
  ) => 'consolidado_asistencia_${period ?? 'todos'}_${_stamp(now)}.$ext';

  /// Abre el diálogo del sistema para compartir o guardar un PDF.
  static Future<void> sharePdf(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);

  /// Abre el diálogo del sistema para guardar un .xlsx. Devuelve false si
  /// el usuario lo canceló.
  static Future<bool> saveXlsx(Uint8List bytes, String fileName) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    return uri != null;
  }

  /// Construye el PDF con los datos reales del estudiante.
  static Future<Uint8List> buildHistoryPdf({
    required String studentName,
    required String email,
    required String code,
    required AcademicSnapshot data,
    DateTime? generatedAt,
  }) async {
    final now = generatedAt ?? DateTime.now();
    // Fuente con soporte Unicode (las fuentes estándar del PDF no tienen
    // todas las tildes ni símbolos).
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      title: 'Historial de asistencia - BioAsistencia',
      author: 'BioAsistencia - Universidad de la Amazonia',
    );
    final overall = data.overall;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text(
            'Historial de asistencia',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: _green,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text('BioAsistencia - Universidad de la Amazonia (UDLA)'),
          pw.SizedBox(height: 12),
          pw.Text('Estudiante: $studentName'),
          pw.Text('Correo: $email'),
          if (code.isNotEmpty) pw.Text('Código: $code'),
          pw.Text('Generado: ${shortDate(now)} ${time12h(now)}'),
          pw.SizedBox(height: 12),
          pw.Text(
            'Total: ${overall.held} clases · ${overall.attended} asistidas · '
            '${overall.absences} inasistencias'
            '${overall.percent == null ? '' : ' · ${overall.percent}%'}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          for (final period in data.periods) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Periodo $period',
              style: pw.TextStyle(
                fontSize: 15,
                fontWeight: pw.FontWeight.bold,
                color: _green,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['Asignatura', 'Docente', 'Asistidas', 'Faltas', '%'],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(color: _green),
              cellAlignments: {
                2: pw.Alignment.center,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
              },
              data: [
                for (final c in data.coursesInPeriod(period))
                  () {
                    final s = data.statsFor(c);
                    return [
                      c.name,
                      c.teacherName,
                      '${s.attended} / ${s.held}',
                      '${s.absences}',
                      s.percent == null ? '-' : '${s.percent}%',
                    ];
                  }(),
              ],
            ),
          ],
          if (data.periods.isEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text('No hay asignaturas registradas.'),
          ],
          pw.SizedBox(height: 20),
          pw.Text(
            'Documento generado por la app a partir de los registros de '
            'asistencia. No reemplaza las certificaciones oficiales de la '
            'universidad.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Abre el diálogo del sistema para guardar o compartir el PDF.
  static Future<void> share(Uint8List bytes, DateTime now) => Printing.sharePdf(
    bytes: bytes,
    filename:
        'historial_asistencia_${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}.pdf',
  );
}

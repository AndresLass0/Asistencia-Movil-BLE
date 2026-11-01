import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/date_format.dart';
import '../models/academic_snapshot.dart';

/// Genera y comparte el historial de asistencia en PDF.
class ReportService {
  ReportService._();

  static const _green = PdfColor.fromInt(0xFF006B35);

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

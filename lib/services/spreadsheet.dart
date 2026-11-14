import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../core/validators.dart';
import '../models/course.dart';

/// Lectura y escritura mínima de hojas de cálculo (.xlsx y .csv), sin
/// dependencias adicionales: un .xlsx es un ZIP con XML (`archive` y `xml`
/// ya los usa el paquete `pdf`).
class Spreadsheet {
  Spreadsheet._();

  /// Filas de la primera hoja de un .xlsx, o de un .csv (separado por
  /// comas o punto y coma). Lanza [FormatException] si no se puede leer.
  static List<List<String>> readRows(Uint8List bytes, String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.xlsx')) return _readXlsx(bytes);
    if (lower.endsWith('.csv') || lower.endsWith('.txt')) {
      return _readCsv(utf8.decode(bytes, allowMalformed: true));
    }
    throw const FormatException('Formato no admitido. Usa .xlsx o .csv.');
  }

  static List<List<String>> _readCsv(String text) {
    final lines = const LineSplitter()
        .convert(text.replaceFirst('﻿', ''))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return const [];
    final sep = lines.first.split(';').length > lines.first.split(',').length
        ? ';'
        : ',';
    return [for (final l in lines) _splitCsvLine(l, sep)];
  }

  static List<String> _splitCsvLine(String line, String sep) {
    final out = <String>[];
    final cell = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (ch == sep && !quoted) {
        out.add(cell.toString().trim());
        cell.clear();
      } else {
        cell.write(ch);
      }
    }
    out.add(cell.toString().trim());
    return out;
  }

  static List<List<String>> _readXlsx(Uint8List bytes) {
    final Archive zip;
    try {
      zip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('El archivo .xlsx está dañado.');
    }
    String? text(String name) {
      final f = zip.findFile(name);
      return f == null ? null : utf8.decode(f.content, allowMalformed: true);
    }

    final shared = <String>[];
    final sharedXml = text('xl/sharedStrings.xml');
    if (sharedXml != null) {
      for (final si in XmlDocument.parse(sharedXml).findAllElements('si')) {
        shared.add(si.findAllElements('t').map((t) => t.innerText).join());
      }
    }

    final sheets =
        zip.files
            .map((f) => f.name)
            .where((n) => RegExp(r'^xl/worksheets/sheet\d+\.xml$').hasMatch(n))
            .toList()
          ..sort((a, b) => _num(a).compareTo(_num(b)));
    if (sheets.isEmpty) {
      throw const FormatException('El archivo no tiene hojas.');
    }
    final sheet = XmlDocument.parse(text(sheets.first)!);
    final rows = <List<String>>[];
    for (final row in sheet.findAllElements('row')) {
      final cells = <int, String>{};
      var next = 0;
      for (final c in row.findElements('c')) {
        final ref = c.getAttribute('r');
        final col = ref == null ? next : _columnIndex(ref);
        next = col + 1;
        final type = c.getAttribute('t');
        final v = c.getElement('v')?.innerText ?? '';
        final value = switch (type) {
          's' =>
            (int.tryParse(v) ?? -1) < shared.length && v.isNotEmpty
                ? shared[int.parse(v)]
                : '',
          'inlineStr' => c.findAllElements('t').map((t) => t.innerText).join(),
          'n' || null => _number(v),
          _ => v,
        };
        cells[col] = value.trim();
      }
      if (cells.values.every((v) => v.isEmpty)) continue;
      final width = cells.keys.fold(0, (m, k) => k + 1 > m ? k + 1 : m);
      rows.add([for (var i = 0; i < width; i++) cells[i] ?? '']);
    }
    return rows;
  }

  static int _num(String name) =>
      int.tryParse(RegExp(r'(\d+)\.xml$').firstMatch(name)?.group(1) ?? '') ??
      0;

  /// "B12" -> 1.
  static int _columnIndex(String ref) {
    var n = 0;
    for (final ch in ref.toUpperCase().codeUnits) {
      if (ch < 65 || ch > 90) break;
      n = n * 26 + (ch - 64);
    }
    return n - 1;
  }

  /// Los códigos suelen guardarse como número: "1019283741" o "1.019283741E9".
  static String _number(String v) {
    final d = double.tryParse(v);
    if (d == null) return v;
    if (d == d.roundToDouble() && d.abs() < 1e15) return d.toInt().toString();
    return v;
  }

  /// Genera un .xlsx con una hoja (todas las celdas como texto o número).
  static Uint8List buildXlsx(String sheetName, List<List<Object?>> rows) {
    String esc(String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
    String col(int i) {
      var n = i + 1;
      var s = '';
      while (n > 0) {
        final r = (n - 1) % 26;
        s = String.fromCharCode(65 + r) + s;
        n = (n - 1) ~/ 26;
      }
      return s;
    }

    final sheet = StringBuffer(
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>',
    );
    for (var r = 0; r < rows.length; r++) {
      sheet.write('<row r="${r + 1}">');
      for (var c = 0; c < rows[r].length; c++) {
        final v = rows[r][c];
        if (v == null) continue;
        final ref = '${col(c)}${r + 1}';
        if (v is num) {
          sheet.write('<c r="$ref"><v>$v</v></c>');
        } else {
          sheet.write(
            '<c r="$ref" t="inlineStr"><is><t xml:space="preserve">'
            '${esc(v.toString())}</t></is></c>',
          );
        }
      }
      sheet.write('</row>');
    }
    sheet.write('</sheetData></worksheet>');

    final name = esc(sheetName.replaceAll(RegExp(r'[\\/?*\[\]:]'), ' ').trim());
    final safeName = name.isEmpty
        ? 'Hoja1'
        : name.substring(0, name.length > 31 ? 31 : name.length);
    final files = <String, String>{
      '[Content_Types].xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
          '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
          '</Types>',
      '_rels/.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
          '</Relationships>',
      'xl/workbook.xml':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
          '<sheets><sheet name="$safeName" sheetId="1" r:id="rId1"/></sheets></workbook>',
      'xl/_rels/workbook.xml.rels':
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
          '</Relationships>',
      'xl/worksheets/sheet1.xml': sheet.toString(),
    };
    final archive = Archive();
    files.forEach((path, content) {
      archive.addFile(ArchiveFile.bytes(path, utf8.encode(content)));
    });
    return ZipEncoder().encodeBytes(archive);
  }
}

/// Resultado de interpretar una lista de estudiantes.
class RosterImport {
  const RosterImport({required this.entries, required this.issues});

  final List<RosterEntry> entries;

  /// Filas descartadas, con el motivo (p. ej. "Fila 4: código inválido").
  final List<String> issues;
}

/// Convierte filas en estudiantes. Columnas: código, nombre y correo
/// (opcional). Si la primera fila tiene encabezados, se usan para ubicar
/// las columnas en cualquier orden.
RosterImport parseRoster(List<List<String>> rows) {
  if (rows.isEmpty) return const RosterImport(entries: [], issues: []);
  String norm(String s) => s
      .toLowerCase()
      .replaceAll('ó', 'o')
      .replaceAll('í', 'i')
      .replaceAll('é', 'e')
      .replaceAll('á', 'a')
      .trim();

  var codeCol = 0, nameCol = 1, emailCol = 2;
  var start = 0;
  final header = rows.first.map(norm).toList();
  final hc = header.indexWhere(
    (h) => h.startsWith('codigo') || h == 'cod' || h.startsWith('cod.'),
  );
  final hn = header.indexWhere((h) => h.startsWith('nombre'));
  if (hc >= 0 || hn >= 0) {
    start = 1;
    if (hc >= 0) codeCol = hc;
    if (hn >= 0) nameCol = hn;
    final he = header.indexWhere(
      (h) => h.startsWith('correo') || h.startsWith('email'),
    );
    emailCol = he;
  }

  String at(List<String> r, int i) => i >= 0 && i < r.length ? r[i].trim() : '';
  final entries = <RosterEntry>[];
  final issues = <String>[];
  final seen = <String>{};
  for (var i = start; i < rows.length; i++) {
    final row = rows[i];
    final code = at(row, codeCol).replaceAll(RegExp(r'\s'), '');
    final name = at(row, nameCol);
    final email = at(row, emailCol).toLowerCase();
    final n = i + 1;
    if (code.isEmpty && name.isEmpty) continue;
    if (!isValidCode(code)) {
      issues.add('Fila $n: código inválido ("$code")');
      continue;
    }
    if (name.isEmpty) {
      issues.add('Fila $n: falta el nombre');
      continue;
    }
    if (email.isNotEmpty && !isInstitutionalEmail(email)) {
      issues.add('Fila $n: el correo no es @$institutionalDomain');
      continue;
    }
    if (!seen.add(code)) {
      issues.add('Fila $n: código repetido ($code)');
      continue;
    }
    entries.add(RosterEntry(code: code, name: name, email: email));
  }
  return RosterImport(entries: entries, issues: issues);
}

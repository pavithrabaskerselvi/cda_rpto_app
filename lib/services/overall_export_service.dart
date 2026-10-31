import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../config/constants.dart';
import '../screens/aerial_fpv/aerial_fpv_student_list_screen.dart'
    show
    kAerialFpvCollection,
    aerialFpvCleanName,
    aerialFpvFmtDate,
    aerialFpvYearOf;

/// Column titles, exactly like the master spreadsheet.
const List<String> kOverallColumns = [
  'S NO',
  'NAME',
  'CONTACT NUMBER',
  'EMAIL ID',
  'ADDRESS',
  'COURSE ENROLLED',
  'ENROLLED DATE',
  'BATCH ALLOCATED',
  'BATCH COMPLETED',
  'CERTIFICATE',
  'REVIEWS',
];

enum OverallExportType { excel, pdf }

String overallDash(dynamic v) {
  final s = (v ?? '').toString().trim();
  return s.isEmpty ? '-' : s;
}

bool overallIsMedium(Map<String, dynamic> data) =>
    (data['batchSize'] ?? '').toString().toLowerCase().startsWith('medium');

bool overallIsRpc(Map<String, dynamic> data) =>
    normalizeBatchCategory(data['category'] as String?) == 'RPC';

/// 11 cells in [kOverallColumns] order (cell 0 = S NO, filled later).
List<String> overallAerialFpvCells(Map<String, dynamic> d) => [
  '',
  overallDash(aerialFpvCleanName((d['name'] ?? '').toString())),
  overallDash(d['phone']),
  overallDash(d['email']),
  overallDash(d['address']),
  overallDash(d['courseName'] ?? d['batch']),
  overallDash(aerialFpvFmtDate(d['enrolledDate'])),
  overallDash(d['batchAllocated']),
  overallDash(d['batchCompleted']),
  overallDash(d['certificate']),
  overallDash(d['reviews']),
];

List<String> overallBatchCells(
    Map<String, dynamic> s, Map<String, dynamic> batch) {
  final completed = (batch['status'] ?? '').toString() == 'Completed';
  return [
    '',
    overallDash(s['name']),
    overallDash(s['phone']),
    overallDash(s['email']),
    overallDash(s['address'] ?? s['place']),
    'RPC',
    overallDash(aerialFpvFmtDate(s['enrollmentDate'])),
    overallDash(s['batchName']),
    completed ? 'YES' : '-',
    overallDash(s['certificate']),
    overallDash(s['reviews']),
  ];
}

/// One sheet (Excel tab) / one titled section (PDF).
class OverallSection {
  final String name;
  final List<List<String>> rows; // 11 cells each, cell 0 ignored
  const OverallSection(this.name, this.rows);
}

class OverallExport {
  OverallExport._();

  // -------------------------------------------------------------------
  // Public entry points
  // -------------------------------------------------------------------

  /// Everything, like the sample workbook. Tabs:
  /// RPC SMALL | RPC MED | AERIAL | FPV
  /// [activeSheet] = the tab that is open when the file is opened.
  static Future<void> exportAll(BuildContext context, OverallExportType type,
      {String? activeSheet}) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
            'Preparing ${type == OverallExportType.excel ? 'Excel' : 'PDF'}...')));
    try {
      final sections = await loadSections();
      await _build(type, sections, 'Overall_List', activeSheet);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Export failed: $e')));
    }
  }

  // -------------------------------------------------------------------
  // Data
  // -------------------------------------------------------------------
  static Future<List<OverallSection>> loadSections() async {
    final fs = FirebaseFirestore.instance;
    final res = await Future.wait([
      fs.collection('batches').get(),
      fs.collection('students').get(),
      fs.collection(kAerialFpvCollection).get(),
    ]);
    final batchDocs = res[0].docs;
    final studentDocs = res[1].docs;
    final aerialDocs = res[2].docs;

    final batches = <String, Map<String, dynamic>>{
      for (final d in batchDocs)
        if (overallIsRpc(d.data())) d.id: d.data(),
    };

    // RPC students sorted by batch name, then student name
    final rpc = studentDocs
        .where((d) => batches.containsKey(d.data()['batchId']))
        .toList()
      ..sort((a, b) {
        final cmp = (a.data()['batchName'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b.data()['batchName'] ?? '').toString().toLowerCase());
        if (cmp != 0) return cmp;
        return (a.data()['name'] ?? '')
            .toString()
            .toLowerCase()
            .compareTo((b.data()['name'] ?? '').toString().toLowerCase());
      });

    final rpcSmall = <List<String>>[];
    final rpcMed = <List<String>>[];
    for (final d in rpc) {
      final s = d.data();
      final batch = batches[s['batchId']] ?? const <String, dynamic>{};
      final cells = overallBatchCells(s, batch);
      (overallIsMedium(batch) ? rpcMed : rpcSmall).add(cells);
    }

    // AERIAL and FPV: one tab each, oldest year first, then by created time
    int byYearThenCreated(QueryDocumentSnapshot<Map<String, dynamic>> a,
        QueryDocumentSnapshot<Map<String, dynamic>> b) {
      final ya = aerialFpvYearOf(a.data());
      final yb = aerialFpvYearOf(b.data());
      if (ya != yb) return ya.compareTo(yb);
      final ta = a.data()['createdAt'];
      final tb = b.data()['createdAt'];
      if (ta is Timestamp && tb is Timestamp) return ta.compareTo(tb);
      if (ta is Timestamp) return -1;
      if (tb is Timestamp) return 1;
      return (a.data()['name'] ?? '')
          .toString()
          .toLowerCase()
          .compareTo((b.data()['name'] ?? '').toString().toLowerCase());
    }

    List<List<String>> rowsFor(String cat) {
      final list = aerialDocs.where((d) => d.data()['category'] == cat).toList()
        ..sort(byYearThenCreated);
      return [for (final d in list) overallAerialFpvCells(d.data())];
    }

    return [
      OverallSection('RPC SMALL', rpcSmall),
      OverallSection('RPC MED', rpcMed),
      OverallSection('AERIAL', rowsFor('aerial')),
      OverallSection('FPV', rowsFor('fpv')),
    ];
  }

  // -------------------------------------------------------------------
  // Build + deliver
  // -------------------------------------------------------------------
  static Future<void> _build(OverallExportType type,
      List<OverallSection> sections, String baseName,
      [String? activeSheet]) async {
    final stamp = _today();
    final safe = baseName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), '_');
    if (type == OverallExportType.excel) {
      final bytes = buildExcel(sections, activeSheet: activeSheet);
      await _deliver(bytes, '${safe}_$stamp.xlsx',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    } else {
      final bytes = await buildPdf(sections);
      await _deliver(bytes, '${safe}_$stamp.pdf', 'application/pdf');
    }
  }

  static String _today() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)}';
  }

  static Future<void> _deliver(
      Uint8List bytes, String fileName, String mime) async {
    if (kIsWeb) {
      await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: mime, name: fileName)]);
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path, mimeType: mime)], text: fileName);
  }

  // -------------------------------------------------------------------
  // Excel: cyan header, thin borders on every cell, tabs like the sample
  // -------------------------------------------------------------------
  static const List<double> _excelWidths = [
    6, 26, 16, 32, 34, 34, 15, 22, 16, 14, 20,
  ];

  static String _sheetName(String n, Set<String> used) {
    var s = n.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
    if (s.isEmpty) s = 'Sheet';
    if (s.length > 31) s = s.substring(0, 31);
    var out = s;
    var i = 2;
    while (used.contains(out.toLowerCase())) {
      final suffix = ' $i';
      out = '${s.length + suffix.length > 31 ? s.substring(0, 31 - suffix.length) : s}$suffix';
      i++;
    }
    used.add(out.toLowerCase());
    return out;
  }

  static Uint8List buildExcel(List<OverallSection> sections,
      {String? activeSheet}) {
    final excel = xls.Excel.createExcel();
    final defaultName = excel.getDefaultSheet() ?? 'Sheet1';

    final black = xls.ExcelColor.fromHexString('#000000');
    xls.Border thin() =>
        xls.Border(borderStyle: xls.BorderStyle.Thin, borderColorHex: black);

    final headStyle = xls.CellStyle(
      bold: true,
      fontSize: 10,
      backgroundColorHex: xls.ExcelColor.fromHexString('#00FFFF'),
      horizontalAlign: xls.HorizontalAlign.Center,
      verticalAlign: xls.VerticalAlign.Center,
      textWrapping: xls.TextWrapping.WrapText,
      leftBorder: thin(),
      rightBorder: thin(),
      topBorder: thin(),
      bottomBorder: thin(),
    );
    xls.CellStyle bodyStyle(bool center, {bool bold = false}) => xls.CellStyle(
      bold: bold,
      fontSize: 10,
      horizontalAlign:
      center ? xls.HorizontalAlign.Center : xls.HorizontalAlign.Left,
      verticalAlign: xls.VerticalAlign.Center,
      leftBorder: thin(),
      rightBorder: thin(),
      topBorder: thin(),
      bottomBorder: thin(),
    );

    final used = <String>{};
    String? firstSheet;
    String? openSheet;
    for (final s in sections) {
      final name = _sheetName(s.name, used);
      if (firstSheet == null) {
        excel.rename(defaultName, name);
        firstSheet = name;
      }
      if (activeSheet != null && s.name == activeSheet) openSheet = name;
      final sheet = excel[name];

      for (var c = 0; c < kOverallColumns.length; c++) {
        sheet.updateCell(
          xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
          xls.TextCellValue(kOverallColumns[c]),
          cellStyle: headStyle,
        );
        sheet.setColumnWidth(c, _excelWidths[c]);
      }

      for (var r = 0; r < s.rows.length; r++) {
        final cells = s.rows[r];
        for (var c = 0; c < kOverallColumns.length; c++) {
          final xls.CellValue value = c == 0
              ? xls.IntCellValue(r + 1)
              : xls.TextCellValue(c < cells.length ? cells[c] : '-');
          sheet.updateCell(
            xls.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1),
            value,
            cellStyle: bodyStyle(c == 0, bold: false),
          );
        }
      }
    }

    final open = openSheet ?? firstSheet;
    if (open != null) excel.setDefaultSheet(open);
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Could not create the Excel file');
    return Uint8List.fromList(bytes);
  }

  // -------------------------------------------------------------------
  // PDF: landscape A4, section title (subtitle) on top, cyan header row
  // -------------------------------------------------------------------
  static Future<Uint8List> buildPdf(List<OverallSection> sections) async {
    final doc = pw.Document();
    final cyan = PdfColor.fromHex('#00FFFF');

    for (final s in sections) {
      final data = <List<String>>[
        for (var i = 0; i < s.rows.length; i++)
          ['${i + 1}', ...s.rows[i].sublist(1)],
      ];

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.fromLTRB(20, 20, 20, 24),
          maxPages: 2000,
          header: (ctx) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(s.name,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('${s.rows.length} students',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
          ),
          footer: (ctx) => pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style:
                const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          ),
          build: (ctx) => [
            pw.TableHelper.fromTextArray(
              headers: kOverallColumns,
              data: data,
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.black),
              headerDecoration: pw.BoxDecoration(color: cyan),
              headerStyle:
              pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 7),
              headerAlignment: pw.Alignment.center,
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {0: pw.Alignment.center},
              cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.55),
                1: const pw.FlexColumnWidth(1.7),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(2.1),
                4: const pw.FlexColumnWidth(2.1),
                5: const pw.FlexColumnWidth(2.0),
                6: const pw.FlexColumnWidth(1.1),
                7: const pw.FlexColumnWidth(1.4),
                8: const pw.FlexColumnWidth(1.0),
                9: const pw.FlexColumnWidth(1.0),
                10: const pw.FlexColumnWidth(1.3),
              },
            ),
          ],
        ),
      );
    }
    return doc.save();
  }
}
import 'dart:async';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xls;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme_colors.dart';

/// Plain, isolate-transferable representation of one parsed sheet.
/// We deliberately reduce everything to `String` here, inside the
/// decode step, instead of handing raw `xls.Data`/`CellValue` objects
/// back to the widget tree — those aren't guaranteed transferable
/// across `compute()`'s isolate boundary, and pre-formatting once here
/// is cheaper than re-formatting on every rebuild anyway.
class _ParsedSheet {
  final String name;
  final List<List<String>> rows;
  const _ParsedSheet(this.name, this.rows);
}

/// Runs on a background isolate via [compute] (real parallelism on
/// mobile/desktop; on Flutter Web `compute` simply runs this on the
/// next microtask on the same thread — there's no worker-isolate
/// support there, but at least it's no longer inline inside a
/// StatelessWidget.build(), so the frame with the loading spinner gets
/// a chance to actually paint before the parse starts).
///
/// Must be a top-level (or static) function — [compute] needs to be
/// able to send it to a fresh isolate.
List<_ParsedSheet> _decodeWorkbook(Uint8List bytes) {
  final workbook = xls.Excel.decodeBytes(bytes);

  final sheets = <_ParsedSheet>[];
  for (final name in workbook.tables.keys) {
    final sheet = workbook.tables[name];
    final rawRows = sheet?.rows ?? const [];
    if (rawRows.isEmpty) continue;

    var columnCount = 0;
    for (final row in rawRows) {
      if (row.length > columnCount) columnCount = row.length;
    }
    if (columnCount == 0) continue;

    final rows = <List<String>>[
      for (final row in rawRows)
        [
          for (var c = 0; c < columnCount; c++)
            c < row.length ? _cellText(row[c]) : '',
        ],
    ];
    sheets.add(_ParsedSheet(name, rows));
  }
  return sheets;
}

/// `excel` v4+ represents every cell value as a typed, sealed
/// `CellValue` (`TextCellValue`, `IntCellValue`, `DoubleCellValue`,
/// `BoolCellValue`, `DateCellValue`, `DateTimeCellValue`,
/// `TimeCellValue`, `FormulaCellValue`) instead of a raw `dynamic` —
/// calling plain `.toString()` on the wrapper (as the old version of
/// this file did) prints the wrapper's own debug representation, not
/// the clean cell text. This switches on the concrete subtype and
/// pulls out the actual displayable value from each.
String _cellText(xls.Data? cell) {
  final value = cell?.value;
  if (value == null) return '';

  if (value is xls.TextCellValue) return _plainText(value);
  if (value is xls.IntCellValue) return value.value.toString();
  if (value is xls.DoubleCellValue) {
    final d = value.value;
    return d == d.roundToDouble() ? d.toStringAsFixed(0) : d.toString();
  }
  if (value is xls.BoolCellValue) return value.value ? 'TRUE' : 'FALSE';
  if (value is xls.DateCellValue) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
  if (value is xls.DateTimeCellValue) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
  if (value is xls.TimeCellValue) {
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }
  if (value is xls.FormulaCellValue) return value.formula;

  return value.toString();
}

/// `TextCellValue` stores rich text internally (a `TextSpan`-like
/// object), not a bare `String`. There's no single documented "give
/// me the plain string" getter that's stable across versions, so this
/// tries the obvious `.text` accessor first and only falls back to
/// scraping `toString()` if that isn't there — never throws either way.
String _plainText(xls.TextCellValue value) {
  try {
    final dynamic v = value.value;
    final dynamic text = v.text;
    if (text is String) return text;
  } catch (_) {
    // fall through
  }
  final raw = value.value.toString();
  final match = RegExp(r'''text:\s*['"]?([^'",)]*)['"]?''').firstMatch(raw);
  return match?.group(1) ?? raw;
}

/// In-app viewer for .xlsx workbooks. Parses the file with the pure-Dart
/// `excel` package and renders each sheet as a scrollable, read-only
/// grid with one tab per sheet.
///
/// The parse itself is dispatched through [compute] and given a hard
/// timeout — `Excel.decodeBytes` runs fully synchronously with no
/// internal yield points, so calling it straight from `build()` (as
/// this file used to) can leave the tab looking completely frozen with
/// no error and nothing in the console if a particular file's parse
/// takes a while or the package trips over something unusual in it.
/// Routing it through [compute] at least gets it off the widget build
/// path, and the timeout guarantees the user always ends up with a
/// clear error + retry instead of a silent blank screen.
///
/// Note: only the modern .xlsx (OOXML) format is supported. Legacy
/// binary .xls files aren't parseable by this package and fall back to
/// the existing "Open in Browser" path in DocumentViewerScreen.
class ExcelViewerBody extends StatefulWidget {
  final Uint8List bytes;
  final CompanyColors colors;

  const ExcelViewerBody({super.key, required this.bytes, required this.colors});

  @override
  State<ExcelViewerBody> createState() => _ExcelViewerBodyState();
}

class _ExcelViewerBodyState extends State<ExcelViewerBody> {
  late Future<List<_ParsedSheet>> _sheetsFuture;

  @override
  void initState() {
    super.initState();
    _sheetsFuture = _parse();
  }

  Future<List<_ParsedSheet>> _parse() async {
    // Yield one real frame (macrotask, not just a microtask) before the
    // heavy synchronous parse starts, so the CircularProgressIndicator
    // actually gets painted first.
    await Future.delayed(const Duration(milliseconds: 50));

    // NOTE: deliberately NOT using compute() here. On Flutter Web, if the
    // callback passed to compute() throws, some SDK versions route that
    // exception to the zone error handler instead of completing the
    // returned Future with an error — so the Future just hangs forever,
    // the FutureBuilder never leaves "waiting", and the UI goes blank
    // with no error and no spinner update. Parsing directly with an
    // explicit try/catch guarantees a real Future completion either way.
    try {
      return _decodeWorkbook(widget.bytes);
    } catch (e) {
      debugPrint('Excel parse failed: $e');
      rethrow;
    }
  }

  void _retry() {
    setState(() => _sheetsFuture = _parse());
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context, widget.colors);
  }

  Widget _buildContent(BuildContext context, CompanyColors colors) {
    return FutureBuilder<List<_ParsedSheet>>(
      future: _sheetsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: colors.accent));
        }
        if (snapshot.hasError) {
          return _ExcelMessage(
            colors: colors,
            message: snapshot.error is TimeoutException
                ? (snapshot.error as TimeoutException).message ??
                'This workbook took too long to open.'
                : 'This file could not be read as an Excel workbook.',
            onRetry: _retry,
          );
        }
        final sheets = snapshot.data ?? const [];
        if (sheets.isEmpty) {
          return _ExcelMessage(
              colors: colors, message: 'This workbook has no readable sheets.');
        }
        return _buildSheets(sheets, colors);
      },
    );
  }

  Widget _buildSheets(List<_ParsedSheet> sheets, CompanyColors colors) {
    return DefaultTabController(
      length: sheets.length,
      child: Column(
        children: [
          if (sheets.length > 1)
            Material(
              color: colors.surface,
              child: TabBar(
                isScrollable: true,
                labelColor: colors.accent,
                unselectedLabelColor: colors.textSecondary,
                indicatorColor: colors.accent,
                labelStyle:
                GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: sheets.map((s) => Tab(text: s.name)).toList(),
              ),
            ),
          Expanded(
            child: TabBarView(
              children: sheets.map((s) => _SheetGrid(sheet: s, colors: colors)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetGrid extends StatelessWidget {
  final _ParsedSheet sheet;
  final CompanyColors colors;

  const _SheetGrid({required this.sheet, required this.colors});

  static const double _colWidth = 130;
  static const double _rowHeight = 38;

  @override
  Widget build(BuildContext context) {
    final rows = sheet.rows;
    if (rows.isEmpty) {
      return _ExcelMessage(colors: colors, message: 'This sheet is empty.');
    }

    final columnCount = rows.first.length;
    final totalWidth = columnCount * _colWidth;

    // Text styles built ONCE here, not per-cell — GoogleFonts.plusJakartaSans()
    // does real work (font lookup / TextStyle merge) on every call, and calling
    // it for every one of a few thousand cells was what froze the UI thread
    // long enough to look like a permanently blank screen.
    final headerStyle = GoogleFonts.plusJakartaSans(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: colors.textPrimary,
    );
    final cellStyle = GoogleFonts.plusJakartaSans(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: colors.textPrimary,
    );

    Widget buildRow(int r) {
      final row = rows[r];
      return Container(
        width: totalWidth,
        height: _rowHeight,
        decoration: BoxDecoration(
          color: r == 0
              ? colors.accent.withValues(alpha: 0.10)
              : (r.isOdd ? colors.background : colors.surface),
          border: Border(
            bottom: BorderSide(color: colors.borderSubtle.withValues(alpha: 0.15)),
          ),
        ),
        child: Row(
          children: [
            for (var c = 0; c < columnCount; c++)
              Container(
                width: _colWidth,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                        color: colors.borderSubtle.withValues(alpha: 0.15)),
                  ),
                ),
                child: Text(
                  c < row.length ? row[c] : '',
                  overflow: TextOverflow.ellipsis,
                  style: r == 0 ? headerStyle : cellStyle,
                ),
              ),
          ],
        ),
      );
    }

    // Horizontal scroll wraps a fixed-width inner area; ListView.builder
    // inside that only builds the rows actually on screen (virtualization),
    // instead of Table's old behaviour of building all 1003 rows up front.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalWidth,
        child: ListView.builder(
          itemCount: rows.length,
          itemExtent: _rowHeight,
          itemBuilder: (context, r) => buildRow(r),
        ),
      ),
    );
  }
}

class _ExcelMessage extends StatelessWidget {
  final CompanyColors colors;
  final String message;
  final VoidCallback? onRetry;

  const _ExcelMessage({required this.colors, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_off_outlined, color: colors.textSecondary, size: 38),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: colors.textSecondary, fontSize: 13),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textPrimary,
                  side: BorderSide(color: colors.borderSubtle.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('Retry', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:excel/excel.dart';
import '../database/pos_database.dart';

/// Result summary of database export to Excel
class ExcelExportResult {
  final File file;
  final Map<String, int> recordCounts;
  final int totalRecords;

  const ExcelExportResult({
    required this.file,
    required this.recordCounts,
    required this.totalRecords,
  });
}

class ExcelExportService {
  /// The exact 6 primary database tables requested
  static const List<String> primaryTables = [
    'restaurant_table',
    'customer_table',
    'category_table',
    'item_table',
    'order_table',
    'order_items_table',
  ];

  /// Generate a single Excel file with 6 tabs for all tables and records
  static Future<ExcelExportResult> generateDatabaseExcel() async {
    final db = await PosDatabase.instance.database;
    final excel = Excel.createExcel();

    final recordCounts = <String, int>{};
    int totalRecords = 0;

    for (int i = 0; i < primaryTables.length; i++) {
      final tableName = primaryTables[i];

      // If it's the very first table, rename the default 'Sheet1' to the table name
      if (i == 0 && excel.sheets.containsKey('Sheet1')) {
        excel.rename('Sheet1', tableName);
      }

      final sheet = excel[tableName];

      // 1. Fetch column names from schema
      final columnsInfo = await db.rawQuery('PRAGMA table_info($tableName);');
      final columnNames = columnsInfo.map((c) => c['name'] as String).toList();

      // 2. Append Header Row with column names
      sheet.appendRow(
        columnNames.map((name) => TextCellValue(name)).toList(),
      );

      // 3. Fetch all records from the table
      final rows = await db.query(tableName);
      recordCounts[tableName] = rows.length;
      totalRecords += rows.length;

      // 4. Append Data Rows
      for (final row in rows) {
        final rowValues = columnNames.map((col) {
          final val = row[col];
          return _toCellValue(val);
        }).toList();

        sheet.appendRow(rowValues);
      }
    }

    // Clean up any stray Sheet1 if still present
    if (excel.sheets.containsKey('Sheet1') && !primaryTables.contains('Sheet1')) {
      excel.delete('Sheet1');
    }

    // Determine save directory
    Directory? outputDir;
    if (!kIsWeb && Platform.isAndroid) {
      outputDir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      outputDir = await getApplicationDocumentsDirectory();
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = p.join(outputDir.path, 'pos_database_export_$timestamp.xlsx');

    final fileBytes = excel.save();
    if (fileBytes == null || fileBytes.isEmpty) {
      throw Exception('Failed to generate Excel file bytes');
    }

    final file = File(filePath);
    await file.writeAsBytes(fileBytes, flush: true);

    return ExcelExportResult(
      file: file,
      recordCounts: recordCounts,
      totalRecords: totalRecords,
    );
  }

  /// Generate Excel file and trigger native Share Sheet (for tablet / phone)
  static Future<ExcelExportResult?> exportAndShare(BuildContext context) async {
    try {
      // Show quick loading notification
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 14),
              Text('Generating Excel file with 6 tabs...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF0F172A),
        ),
      );

      final result = await generateDatabaseExcel();

      // Trigger native share dialog
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(result.file.path)],
          subject: 'POS Database Export (6 Tables)',
          text: 'POS Database export containing 6 tables and ${result.totalRecords} records.',
        ),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Excel generated: 6 tabs, ${result.totalRecords} records exported.\nSaved to: ${p.basename(result.file.path)}',
            ),
            backgroundColor: const Color(0xFF16A34A),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      return result;
    } catch (e) {
      debugPrint('Error generating or sharing Excel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export Excel: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return null;
    }
  }

  static CellValue _toCellValue(dynamic val) {
    if (val == null) {
      return TextCellValue('');
    }
    if (val is int) {
      return IntCellValue(val);
    }
    if (val is double) {
      return DoubleCellValue(val);
    }
    if (val is num) {
      return DoubleCellValue(val.toDouble());
    }
    if (val is bool) {
      return BoolCellValue(val);
    }
    return TextCellValue(val.toString());
  }
}

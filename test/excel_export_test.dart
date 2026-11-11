import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:pos/database/pos_database.dart';
import 'package:excel/excel.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = await getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dbPath, 'pos_offline.db'));
  });

  test('Excel generation: creates 1 file with 6 tabs for all tables and records', () async {
    final db = await PosDatabase.instance.database;

    final tableNames = [
      'restaurant_table',
      'customer_table',
      'category_table',
      'item_table',
      'order_table',
      'order_items_table',
    ];

    final excel = Excel.createExcel();

    for (final table in tableNames) {
      final sheet = excel[table];

      final columnsInfo = await db.rawQuery('PRAGMA table_info($table);');
      final columnNames = columnsInfo.map((c) => c['name'] as String).toList();

      // Header row
      sheet.appendRow(columnNames.map((c) => TextCellValue(c)).toList());

      // Data rows
      final rows = await db.query(table);
      for (final row in rows) {
        final rowValues = columnNames.map((col) {
          final val = row[col];
          if (val == null) return TextCellValue('');
          if (val is int) return IntCellValue(val);
          if (val is double) return DoubleCellValue(val);
          if (val is num) return DoubleCellValue(val.toDouble());
          if (val is bool) return BoolCellValue(val);
          return TextCellValue(val.toString());
        }).toList();

        sheet.appendRow(rowValues);
      }
    }

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    expect(excel.sheets.keys.length, equals(6));
    for (final table in tableNames) {
      expect(excel.sheets.containsKey(table), isTrue);
      final sheet = excel[table];
      expect(sheet.maxRows, greaterThan(0));
    }

    final bytes = excel.save();
    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(0));

    // Verify it can be decoded back
    final decoded = Excel.decodeBytes(bytes);
    expect(decoded.sheets.keys.length, equals(6));
    for (final table in tableNames) {
      expect(decoded.sheets.containsKey(table), isTrue);
    }
  });
}

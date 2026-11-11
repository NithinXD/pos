import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'package:pos/database/pos_database.dart';
import 'package:pos/services/excel_import_service.dart';
import 'package:excel/excel.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = await getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dbPath, 'pos_offline.db'));
  });

  test('Excel import: successfully imports categories and menu items from Excel bytes', () async {
    final excel = Excel.createExcel();
    final sheet = excel['Menu'];

    // Header row
    sheet.appendRow([
      TextCellValue('Category'),
      TextCellValue('Item Name'),
      TextCellValue('Sitdown Price'),
      TextCellValue('Takeaway Price'),
      TextCellValue('Type'),
      TextCellValue('Tax Rate'),
    ]);

    // Data rows
    sheet.appendRow([
      TextCellValue('Starters'),
      TextCellValue('Crispy Corn'),
      DoubleCellValue(180.0),
      DoubleCellValue(170.0),
      TextCellValue('veg'),
      DoubleCellValue(5.0),
    ]);
    sheet.appendRow([
      TextCellValue('Main Course'),
      TextCellValue('Mutton Rogan Josh'),
      DoubleCellValue(420.0),
      DoubleCellValue(400.0),
      TextCellValue('non_veg'),
      DoubleCellValue(5.0),
    ]);
    sheet.appendRow([
      TextCellValue('Beverages'),
      TextCellValue('Mango Lassi'),
      DoubleCellValue(90.0),
      DoubleCellValue(90.0),
      TextCellValue('beverage'),
      DoubleCellValue(5.0),
    ]);

    if (excel.sheets.containsKey('Sheet1')) {
      excel.delete('Sheet1');
    }

    final bytes = excel.save();
    expect(bytes, isNotNull);

    final summary = await ExcelImportService.importMenuFromBytes(Uint8List.fromList(bytes!));
    expect(summary.success, isTrue);
    expect(summary.itemsImported, equals(3));
    expect(summary.categoriesImported, greaterThanOrEqualTo(1));

    // Verify items in DB
    final allItems = await PosDatabase.instance.getAllMenuItems();
    expect(allItems.any((i) => i.name == 'Crispy Corn'), isTrue);
    expect(allItems.any((i) => i.name == 'Mutton Rogan Josh'), isTrue);
    expect(allItems.any((i) => i.name == 'Mango Lassi'), isTrue);
  });
}

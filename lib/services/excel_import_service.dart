import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import '../database/pos_database.dart';
import '../models/category_model.dart';
import '../models/menu_item_model.dart';

class ExcelImportSummary {
  final bool success;
  final int categoriesImported;
  final int itemsImported;
  final String message;

  const ExcelImportSummary({
    required this.success,
    required this.categoriesImported,
    required this.itemsImported,
    required this.message,
  });
}

class ExcelImportService {
  /// Open file picker, parse Excel workbook (.xlsx / .xls), and insert/update categories & menu items in SQLite
  static Future<ExcelImportSummary> pickAndImportMenu([BuildContext? context]) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (files.isEmpty) {
        return const ExcelImportSummary(
          success: false,
          categoriesImported: 0,
          itemsImported: 0,
          message: 'No file selected.',
        );
      }

      final file = files.first;
      final bytes = await file.xFile.readAsBytes();

      if (bytes.isEmpty) {
        return const ExcelImportSummary(
          success: false,
          categoriesImported: 0,
          itemsImported: 0,
          message: 'Could not read file data or file is empty.',
        );
      }

      return await importMenuFromBytes(bytes);
    } catch (e) {
      debugPrint('Error picking/importing Excel menu: $e');
      return ExcelImportSummary(
        success: false,
        categoriesImported: 0,
        itemsImported: 0,
        message: 'Import failed: $e',
      );
    }
  }

  /// Parse Excel bytes and persist categories and items to SQLite
  static Future<ExcelImportSummary> importMenuFromBytes(Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.sheets.isEmpty) {
      return const ExcelImportSummary(
        success: false,
        categoriesImported: 0,
        itemsImported: 0,
        message: 'Excel file has no sheets.',
      );
    }

    final db = PosDatabase.instance;
    final existingCategories = await db.getAllCategories();
    final categoryMap = <String, CategoryModel>{};
    for (final c in existingCategories) {
      categoryMap[c.name.trim().toLowerCase()] = c;
    }

    int categoriesImported = 0;
    int itemsImported = 0;

    // Helper to get or create category
    Future<CategoryModel> getOrCreateCategory(String catName, {String? colorHex}) async {
      final key = catName.trim().toLowerCase();
      if (categoryMap.containsKey(key)) {
        return categoryMap[key]!;
      }
      final newCat = CategoryModel(
        id: 0,
        name: catName.trim(),
        colorHex: colorHex ?? '#7C5DFA',
        status: 1,
      );
      final id = await db.addCategory(newCat);
      final created = CategoryModel(
        id: id,
        name: catName.trim(),
        colorHex: colorHex ?? '#7C5DFA',
        status: 1,
      );
      categoryMap[key] = created;
      categoriesImported++;
      return created;
    }

    // 1. Check if dedicated category tab exists (category_table or Categories)
    Sheet? categorySheet;
    for (final sheetName in excel.sheets.keys) {
      final lower = sheetName.toLowerCase().trim();
      if (lower == 'category_table' || lower == 'categories' || lower == 'category') {
        categorySheet = excel.sheets[sheetName];
        break;
      }
    }

    if (categorySheet != null && categorySheet.rows.length > 1) {
      final headerRow = categorySheet.rows.first;
      final headers = headerRow.map((c) => _extractCellString(c).toLowerCase().trim()).toList();
      final nameIdx = _findColumnIndex(headers, ['category_name', 'name', 'category', 'title']);
      final colorIdx = _findColumnIndex(headers, ['category_color', 'color', 'colorhex']);

      if (nameIdx != -1) {
        for (int r = 1; r < categorySheet.rows.length; r++) {
          final row = categorySheet.rows[r];
          if (row.isEmpty || nameIdx >= row.length) continue;
          final catName = _extractCellString(row[nameIdx]).trim();
          if (catName.isEmpty) continue;
          final color = (colorIdx != -1 && colorIdx < row.length)
              ? _extractCellString(row[colorIdx]).trim()
              : null;
          await getOrCreateCategory(catName, colorHex: color?.isNotEmpty == true ? color : null);
        }
      }
    }

    // 2. Process Menu Items: check for item_table, items, menu, or fallback to first sheet
    Sheet? itemSheet;
    for (final sheetName in excel.sheets.keys) {
      final lower = sheetName.toLowerCase().trim();
      if (lower == 'item_table' || lower == 'items' || lower == 'menu' || lower == 'menu_items') {
        itemSheet = excel.sheets[sheetName];
        break;
      }
    }
    itemSheet ??= excel.sheets.values.first;

    if (itemSheet.rows.length > 1) {
      final headerRow = itemSheet.rows.first;
      final headers = headerRow.map((c) => _extractCellString(c).toLowerCase().trim()).toList();

      final nameIdx = _findColumnIndex(headers, ['item_name', 'name', 'item', 'dish', 'dish_name', 'product']);
      final catIdx = _findColumnIndex(headers, ['category_name', 'category', 'cat', 'category_id', 'group']);
      final sitdownPriceIdx = _findColumnIndex(headers, ['item_sitdown_price', 'sitdown_price', 'sitdownprice', 'dine_in_price', 'price', 'dinein_price', 'rate']);
      final takeawayPriceIdx = _findColumnIndex(headers, ['item_takeaway_price', 'takeaway_price', 'takeawayprice', 'parcel_price']);
      final typeIdx = _findColumnIndex(headers, ['item_type', 'type', 'food_type', 'veg_nonveg']);
      final taxIdx = _findColumnIndex(headers, ['item_tax_rate', 'tax_rate', 'tax', 'tax_percentage', 'gst']);

      if (nameIdx != -1) {
        for (int r = 1; r < itemSheet.rows.length; r++) {
          final row = itemSheet.rows[r];
          if (row.isEmpty || nameIdx >= row.length) continue;
          final itemName = _extractCellString(row[nameIdx]).trim();
          if (itemName.isEmpty) continue;

          // Category
          String catName = 'General';
          if (catIdx != -1 && catIdx < row.length) {
            final parsedCat = _extractCellString(row[catIdx]).trim();
            if (parsedCat.isNotEmpty) {
              catName = parsedCat;
            }
          }
          final cat = await getOrCreateCategory(catName);

          // Sitdown price
          double sitdownPrice = 0.0;
          if (sitdownPriceIdx != -1 && sitdownPriceIdx < row.length) {
            sitdownPrice = _parseDouble(_extractCellString(row[sitdownPriceIdx]));
          }

          // Takeaway price
          double takeawayPrice = sitdownPrice;
          if (takeawayPriceIdx != -1 && takeawayPriceIdx < row.length) {
            final parsed = _parseDouble(_extractCellString(row[takeawayPriceIdx]));
            if (parsed > 0) takeawayPrice = parsed;
          }

          // Item type: veg, non-veg, vegan, beverage
          String itemType = 'veg';
          if (typeIdx != -1 && typeIdx < row.length) {
            final rawType = _extractCellString(row[typeIdx]).toLowerCase().trim();
            if (rawType.contains('non') || rawType == 'nv') {
              itemType = 'non-veg';
            } else if (rawType.contains('vegan')) {
              itemType = 'vegan';
            } else if (rawType.contains('drink') || rawType.contains('bev') || rawType.contains('shake') || rawType.contains('tea') || rawType.contains('coffee') || rawType.contains('liquor') || rawType.contains('bar') || rawType.contains('alcohol') || rawType.contains('beer')) {
              itemType = 'beverage';
            } else {
              itemType = 'veg';
            }
          }

          // Tax rate
          double taxRate = 5.0;
          if (taxIdx != -1 && taxIdx < row.length) {
            final parsedTax = _parseDouble(_extractCellString(row[taxIdx]));
            if (parsedTax >= 0) taxRate = parsedTax;
          }

          final menuItem = MenuItemModel(
            id: 0,
            categoryId: cat.id,
            categoryName: cat.name,
            name: itemName,
            sitdownPrice: sitdownPrice,
            takeawayPrice: takeawayPrice,
            deliveryPrice: takeawayPrice,
            itemType: itemType,
            kitchenType: itemType == 'beverage' ? 'bar' : 'hot_kitchen',
            taxRate: taxRate,
            status: 1,
          );

          await db.addMenuItem(menuItem);
          itemsImported++;
        }
      }
    }

    if (itemsImported == 0 && categoriesImported == 0) {
      return const ExcelImportSummary(
        success: false,
        categoriesImported: 0,
        itemsImported: 0,
        message: 'No valid categories or menu items found in the Excel file.',
      );
    }

    return ExcelImportSummary(
      success: true,
      categoriesImported: categoriesImported,
      itemsImported: itemsImported,
      message: 'Successfully imported $categoriesImported categories and $itemsImported menu items from Excel!',
    );
  }

  static int _findColumnIndex(List<String> headers, List<String> possibleNames) {
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].replaceAll('_', '').replaceAll(' ', '');
      for (final name in possibleNames) {
        final cleanName = name.replaceAll('_', '').replaceAll(' ', '');
        if (h == cleanName || h.contains(cleanName)) {
          return i;
        }
      }
    }
    return -1;
  }

  static String _extractCellString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final val = cell.value;
    return val.toString().trim();
  }

  static double _parseDouble(String str) {
    if (str.isEmpty) return 0.0;
    final cleaned = str.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }
}

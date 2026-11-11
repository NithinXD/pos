import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  print('Generating sample Excel files for menu upload...');

  // 1. Realistic Sample Menu (sample_menu_upload.xlsx)
  final excel1 = Excel.createExcel();
  final sheet1 = excel1['Menu'];

  // Headers
  sheet1.appendRow([
    TextCellValue('Category'),
    TextCellValue('Item Name'),
    TextCellValue('Sitdown Price'),
    TextCellValue('Takeaway Price'),
    TextCellValue('Type'),
    TextCellValue('Tax Rate'),
  ]);

  // Starters
  sheet1.appendRow([
    TextCellValue('Starters'),
    TextCellValue('Crispy Corn Salt & Pepper'),
    DoubleCellValue(180.0),
    DoubleCellValue(170.0),
    TextCellValue('veg'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Starters'),
    TextCellValue('Paneer Tikka Tandoori'),
    DoubleCellValue(250.0),
    DoubleCellValue(240.0),
    TextCellValue('veg'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Starters'),
    TextCellValue('Chicken Tikka Masaledar'),
    DoubleCellValue(320.0),
    DoubleCellValue(300.0),
    TextCellValue('non-veg'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Starters'),
    TextCellValue('Golden Fried Prawns'),
    DoubleCellValue(380.0),
    DoubleCellValue(360.0),
    TextCellValue('non-veg'),
    DoubleCellValue(5.0),
  ]);

  // Main Course
  sheet1.appendRow([
    TextCellValue('Main Course'),
    TextCellValue('Paneer Butter Masala'),
    DoubleCellValue(280.0),
    DoubleCellValue(260.0),
    TextCellValue('veg'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Main Course'),
    TextCellValue('Dal Makhani Slow Cooked'),
    DoubleCellValue(220.0),
    DoubleCellValue(200.0),
    TextCellValue('veg'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Main Course'),
    TextCellValue('Butter Chicken Special'),
    DoubleCellValue(360.0),
    DoubleCellValue(340.0),
    TextCellValue('non-veg'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Main Course'),
    TextCellValue('Mutton Rogan Josh'),
    DoubleCellValue(420.0),
    DoubleCellValue(400.0),
    TextCellValue('non-veg'),
    DoubleCellValue(5.0),
  ]);

  // Breads & Rice
  sheet1.appendRow([
    TextCellValue('Breads & Rice'),
    TextCellValue('Butter Naan'),
    DoubleCellValue(45.0),
    DoubleCellValue(45.0),
    TextCellValue('veg'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Breads & Rice'),
    TextCellValue('Garlic Roti'),
    DoubleCellValue(40.0),
    DoubleCellValue(40.0),
    TextCellValue('veg'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Breads & Rice'),
    TextCellValue('Chicken Dum Biryani'),
    DoubleCellValue(310.0),
    DoubleCellValue(290.0),
    TextCellValue('non-veg'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Breads & Rice'),
    TextCellValue('Jeera Ghee Rice'),
    DoubleCellValue(160.0),
    DoubleCellValue(150.0),
    TextCellValue('veg'),
    DoubleCellValue(5.0),
  ]);

  // Beverages
  sheet1.appendRow([
    TextCellValue('Beverages'),
    TextCellValue('Fresh Lime Soda'),
    DoubleCellValue(80.0),
    DoubleCellValue(80.0),
    TextCellValue('beverage'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Beverages'),
    TextCellValue('Mango Lassi Thick'),
    DoubleCellValue(110.0),
    DoubleCellValue(110.0),
    TextCellValue('beverage'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Beverages'),
    TextCellValue('Masala Chai Pot'),
    DoubleCellValue(40.0),
    DoubleCellValue(40.0),
    TextCellValue('beverage'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Beverages'),
    TextCellValue('Cold Coffee with Ice Cream'),
    DoubleCellValue(120.0),
    DoubleCellValue(120.0),
    TextCellValue('beverage'),
    DoubleCellValue(5.0),
  ]);

  // Desserts
  sheet1.appendRow([
    TextCellValue('Desserts'),
    TextCellValue('Warm Gulab Jamun (2 pcs)'),
    DoubleCellValue(90.0),
    DoubleCellValue(90.0),
    TextCellValue('veg'),
    DoubleCellValue(5.0),
  ]);
  sheet1.appendRow([
    TextCellValue('Desserts'),
    TextCellValue('Saffron Rasmalai (2 pcs)'),
    DoubleCellValue(130.0),
    DoubleCellValue(130.0),
    TextCellValue('veg'),
    DoubleCellValue(5.0),
  ]);

  if (excel1.sheets.containsKey('Sheet1')) {
    excel1.delete('Sheet1');
  }

  final bytes1 = excel1.save();
  if (bytes1 != null) {
    File('sample_menu_upload.xlsx').writeAsBytesSync(bytes1);
    print('Created sample_menu_upload.xlsx successfully (${bytes1.length} bytes)');
  }

  // 2. Multi-tab Schema Export Format (sample_database_export.xlsx)
  final excel2 = Excel.createExcel();
  final catSheet = excel2['category_table'];
  catSheet.appendRow([
    TextCellValue('category_id'),
    TextCellValue('category_name'),
    TextCellValue('category_color'),
  ]);
  catSheet.appendRow([IntCellValue(1), TextCellValue('Starters'), TextCellValue('#10B981')]);
  catSheet.appendRow([IntCellValue(2), TextCellValue('Main Course'), TextCellValue('#F59E0B')]);
  catSheet.appendRow([IntCellValue(3), TextCellValue('Breads & Rice'), TextCellValue('#8B5CF6')]);
  catSheet.appendRow([IntCellValue(4), TextCellValue('Beverages'), TextCellValue('#06B6D4')]);
  catSheet.appendRow([IntCellValue(5), TextCellValue('Desserts'), TextCellValue('#EC4899')]);

  final itemSheet = excel2['item_table'];
  itemSheet.appendRow([
    TextCellValue('category_name'),
    TextCellValue('item_name'),
    TextCellValue('item_sitdown_price'),
    TextCellValue('item_takeaway_price'),
    TextCellValue('item_type'),
    TextCellValue('item_tax_rate'),
  ]);
  itemSheet.appendRow([
    TextCellValue('Starters'),
    TextCellValue('Paneer Tikka'),
    DoubleCellValue(240.0),
    DoubleCellValue(230.0),
    TextCellValue('veg'),
    DoubleCellValue(5.0),
  ]);
  itemSheet.appendRow([
    TextCellValue('Main Course'),
    TextCellValue('Chicken Butter Masala'),
    DoubleCellValue(350.0),
    DoubleCellValue(330.0),
    TextCellValue('non-veg'),
    DoubleCellValue(5.0),
  ]);
  itemSheet.appendRow([
    TextCellValue('Beverages'),
    TextCellValue('Fresh Lime Soda'),
    DoubleCellValue(80.0),
    DoubleCellValue(80.0),
    TextCellValue('beverage'),
    DoubleCellValue(5.0),
  ]);

  if (excel2.sheets.containsKey('Sheet1')) {
    excel2.delete('Sheet1');
  }

  final bytes2 = excel2.save();
  if (bytes2 != null) {
    File('sample_database_export.xlsx').writeAsBytesSync(bytes2);
    print('Created sample_database_export.xlsx successfully (${bytes2.length} bytes)');
  }
}

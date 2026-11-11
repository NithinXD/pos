import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/database/pos_database.dart';
import 'package:pos/models/menu_item_model.dart';
import 'package:pos/models/report_model.dart';
import 'package:pos/models/table_model.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = await getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dbPath, 'pos_offline.db'));
  });

  group('Reopen Table Percent Discount Workflow Tests', () {
    test('Open table -> add items -> hold -> add percent discount -> reopen -> add new item -> hold: DISCOUNT UPDATED', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final paneerTikka = items.firstWhere((i) => i.id == 1); // sitdownPrice: 240, taxRate: 5%
      final biryani = items.firstWhere((i) => i.id == 12); // sitdownPrice: 310, taxRate: 5%

      // 1. Open new table (Table 8) -> add items -> hold and print
      final initialCart = [
        CartItemModel(
          item: paneerTikka,
          quantity: 2, // 2 x 240 = 480
          existingQuantity: 0,
        ),
      ];
      await PosDatabase.instance.holdSitDownOrder(
        8,
        initialCart,
        discountAmount: 0.0,
        isPercent: false,
        percentValue: 0.0,
      );

      var tables = await PosDatabase.instance.getSitDownTables();
      var table8 = tables.firstWhere((t) => t.tableNumber == 8);
      expect(table8.status, equals(TableOrderStatus.open));
      expect(table8.netTotal, equals(480.0));
      expect(table8.discountAmount, equals(0.0));
      expect(table8.discountPercent, equals(0.0));
      expect(table8.isDiscountPercent, isFalse);

      // 2. Click on table -> click add items -> add percent discount (10%) -> save discount
      // No new items added yet; existing quantity is 2
      final existingCart = table8.activeCart;
      expect(existingCart.fold(0, (sum, c) => sum + (c.isExisting ? c.newQuantity : c.quantity)), equals(0));

      // Save discount (via holdSitDownOrder or updateOrderDiscountAndMeta)
      await PosDatabase.instance.holdSitDownOrder(
        8,
        existingCart,
        discountAmount: 48.0, // 10% of 480
        isPercent: true,
        percentValue: 10.0,
      );

      tables = await PosDatabase.instance.getSitDownTables();
      table8 = tables.firstWhere((t) => t.tableNumber == 8);
      expect(table8.isDiscountPercent, isTrue);
      expect(table8.discountPercent, equals(10.0));
      expect(table8.discountAmount, equals(48.0));
      expect(table8.effectiveDiscount, equals(48.0));
      expect(table8.netTotal, equals(480.0));

      // Check SQLite table directly to verify mutual exclusivity and columns
      final db = await PosDatabase.instance.database;
      final orderRow = (await db.query(
        'order_table',
        where: 'order_id = ?',
        whereArgs: [table8.activeOrderId!],
      )).first;
      expect((orderRow['order_discount_percent'] as num).toDouble(), equals(10.0));
      expect((orderRow['order_discount_amount'] as num).toDouble(), equals(0.0));
      expect((orderRow['order_discount'] as num).toDouble(), equals(48.0));

      // 3. Now reopen table -> add another item (1x Biryani @ 310) -> hold and print
      // Total net should become 480 + 310 = 790
      // 10% discount should recalculate to 79.0!
      final newItem = CartItemModel(
        item: biryani,
        quantity: 1,
        existingQuantity: 0,
      );

      final orderId = table8.activeOrderId ?? (orderRow['order_id'] as int);
      await PosDatabase.instance.addNewItemsToSitDownOrder(
        orderId: orderId,
        tableNumber: 8,
        newItems: [newItem],
        discountAmount: 79.0, // Calculated dynamically by MenuOrderingScreen: 790 * 0.10
        isPercent: true,
        percentValue: 10.0,
      );

      // Verify that discount is UPDATED in SQLite and TableModel
      tables = await PosDatabase.instance.getSitDownTables();
      table8 = tables.firstWhere((t) => t.tableNumber == 8);
      expect(table8.netTotal, equals(790.0));
      expect(table8.isDiscountPercent, isTrue);
      expect(table8.discountPercent, equals(10.0));
      expect(table8.discountAmount, equals(79.0), reason: 'Discount should be updated to 10% of new net total 790 = 79');
      expect(table8.effectiveDiscount, equals(79.0));

      final updatedOrderRow = (await db.query(
        'order_table',
        where: 'order_id = ?',
        whereArgs: [orderId],
      )).first;
      expect((updatedOrderRow['order_discount'] as num).toDouble(), equals(79.0));
      expect((updatedOrderRow['order_discount_percent'] as num).toDouble(), equals(10.0));
      expect((updatedOrderRow['order_discount_amount'] as num).toDouble(), equals(0.0));

      // 4. Settle the order and verify completed sales record
      await PosDatabase.instance.settleAndReleaseTable(
        8,
        paymentMethod: 'Cash',
        discountAmount: 79.0,
        isPercent: true,
        percentValue: 10.0,
      );

      final settledOrders = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );
      final orderOn8 = settledOrders.completedOrders.firstWhere((o) => o.tableNumber == 8);
      expect(orderOn8.discountAmount, equals(79.0));

      final settledDbRow = (await db.query(
        'order_table',
        where: 'order_id = ?',
        whereArgs: [orderId],
      )).first;
      expect((settledDbRow['order_discount_percent'] as num).toDouble(), equals(10.0));
      expect((settledDbRow['order_discount'] as num).toDouble(), equals(79.0));
      expect((settledDbRow['order_discount_amount'] as num).toDouble(), equals(0.0));
    });

    test('addNewItemsToSitDownOrder preserves and recalculates percent discount even when called with default params', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final paneerTikka = items.firstWhere((i) => i.id == 1); // 240
      final biryani = items.firstWhere((i) => i.id == 12); // 310

      // Table 9: initial order 1x Paneer Tikka (240)
      await PosDatabase.instance.holdSitDownOrder(
        9,
        [CartItemModel(item: paneerTikka, quantity: 1, existingQuantity: 0)],
        discountAmount: 48.0, // 20% of 240
        isPercent: true,
        percentValue: 20.0,
      );

      var tables = await PosDatabase.instance.getSitDownTables();
      var table9 = tables.firstWhere((t) => t.tableNumber == 9);
      final orderId = table9.activeOrderId!;

      // Add 1x Biryani (310) without explicitly passing isPercent/percentValue (simulating fallback)
      await PosDatabase.instance.addNewItemsToSitDownOrder(
        orderId: orderId,
        tableNumber: 9,
        newItems: [CartItemModel(item: biryani, quantity: 1, existingQuantity: 0)],
        discountAmount: 0.0,
        // isPercent / percentValue omitted -> database detects existing 20% and updates discount to 20% of 550 = 110
      );

      tables = await PosDatabase.instance.getSitDownTables();
      table9 = tables.firstWhere((t) => t.tableNumber == 9);
      expect(table9.netTotal, equals(550.0));
      expect(table9.discountPercent, equals(20.0));
      expect(table9.discountAmount, equals(110.0), reason: '20% of 550 is 110');
      expect(table9.isDiscountPercent, isTrue);
    });
  });
}

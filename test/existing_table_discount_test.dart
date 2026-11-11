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

  group('Existing Table & Parcel Discount Workflow Tests', () {
    test('Open existing table, add no new items, apply discount, and save to SQLite', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final paneerTikka = items.firstWhere((i) => i.id == 1); // sitdownPrice: 240, taxRate: 5%

      // 1. Initial Order: Table 6 with 2x Paneer Tikka, 0 initial discount
      final initialCart = [
        CartItemModel(
          item: paneerTikka,
          quantity: 2,
          existingQuantity: 0,
        ),
      ];
      await PosDatabase.instance.holdSitDownOrder(6, initialCart, discountAmount: 0.0);

      // Verify Table 6 is open with 0 discount
      var tables = await PosDatabase.instance.getSitDownTables();
      var table6 = tables.firstWhere((t) => t.tableNumber == 6);
      expect(table6.status, equals(TableOrderStatus.open));
      expect(table6.discountAmount, equals(0.0));
      expect(table6.activeCart.length, equals(1));
      expect(table6.activeCart.first.existingQuantity, equals(2));

      // 2. Re-open Table 6: Staff adds NO new food items, only applies ₹50 discount
      // Both existingQuantity and quantity are 2, so newQuantity == 0 (no new items added)
      final existingCart = table6.activeCart;
      expect(existingCart.fold(0, (sum, c) => sum + (c.isExisting ? c.newQuantity : c.quantity)), equals(0));

      // Save discount without new food items
      await PosDatabase.instance.holdSitDownOrder(6, existingCart, discountAmount: 50.0);

      // Verify discount is updated and saved in SQLite
      tables = await PosDatabase.instance.getSitDownTables();
      table6 = tables.firstWhere((t) => t.tableNumber == 6);
      expect(table6.discountAmount, equals(50.0));
      expect(table6.effectiveDiscount, equals(50.0));
      expect(table6.netTotal, equals(480.0));
      // Total with tax = (480 - 50) + 24 = 454
      expect(table6.totalWithTax, equals(454.0));

      // 3. Close the table with the discount
      await PosDatabase.instance.settleAndReleaseTable(6, paymentMethod: 'Card', discountAmount: 50.0);

      // Verify table is closed (Green / Free)
      tables = await PosDatabase.instance.getSitDownTables();
      table6 = tables.firstWhere((t) => t.tableNumber == 6);
      expect(table6.status, equals(TableOrderStatus.closed));
      expect(table6.activeCart, isEmpty);

      // Verify the settled order in database has the discount recorded
      final settledOrders = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );
      final orderOn6 = settledOrders.completedOrders.firstWhere((o) => o.tableNumber == 6);
      expect(orderOn6.discountAmount, equals(50.0));
      expect(orderOn6.totalAmount, equals(454.0));
      expect(orderOn6.paymentDisplay, equals('Card'));
    });

    test('Open existing parcel, add no new items, apply discount, and close parcel', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final biryani = items.firstWhere((i) => i.id == 12); // sitdownPrice: 310, takeawayPrice: 300

      // 1. Create Parcel Order: 2x Biryani, 0 initial discount
      final initialCart = [
        CartItemModel(
          item: biryani,
          quantity: 2,
          existingQuantity: 0,
          isTakeaway: true,
        ),
      ];
      final orderId = await PosDatabase.instance.createParcelOrder(
        customerName: 'Sam Guest',
        customerPhone: '9876543210',
        cartItems: initialCart,
        discountAmount: 0.0,
      );

      var parcels = await PosDatabase.instance.getOpenParcelOrders();
      var parcel = parcels.firstWhere((p) => p.id == orderId);
      expect(parcel.discountAmount, equals(0.0));

      // 2. Staff updates discount on existing parcel with 0 new food items
      await PosDatabase.instance.updateParcelOrder(
        orderId,
        parcel.activeCart,
        discountAmount: 60.0, // ₹60 discount
      );

      parcels = await PosDatabase.instance.getOpenParcelOrders();
      parcel = parcels.firstWhere((p) => p.id == orderId);
      expect(parcel.discountAmount, equals(60.0));
      expect(parcel.effectiveDiscount, equals(60.0));

      // 3. Close parcel order upon pickup & payment
      await PosDatabase.instance.closeParcelOrder(orderId, paymentMethod: 'UPI QR', discountAmount: 60.0);

      // Verify parcel is removed from open parcels
      parcels = await PosDatabase.instance.getOpenParcelOrders();
      expect(parcels.any((p) => p.id == orderId), isFalse);

      // Verify recorded in sales report
      final report = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );
      final settledParcel = report.completedOrders.firstWhere((o) => o.orderId == orderId);
      expect(settledParcel.discountAmount, equals(60.0));
      expect(settledParcel.paymentDisplay, equals('UPI QR'));
    });
  });
}

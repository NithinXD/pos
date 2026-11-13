import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/database/pos_database.dart';
import 'package:pos/models/menu_item_model.dart';
import 'package:pos/models/report_model.dart';
import 'package:pos/services/printer_service.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = await getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dbPath, 'pos_offline.db'));
  });

  group('Closed Orders Reprint Receipt Tests', () {
    test('Reprinting closed parcel order includes delivery charge and discount', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final paneerTikka = items.firstWhere((i) => i.id == 1); // sitdownPrice: 240, taxRate: 5%

      // 1. Create a parcel order: 2x Paneer Tikka (480 net), discount 40, delivery charge 35
      final cart = [
        CartItemModel(
          item: paneerTikka,
          quantity: 2,
          existingQuantity: 0,
          isTakeaway: true,
        ),
      ];

      final orderId = await PosDatabase.instance.createParcelOrder(
        customerName: 'Sam VIP',
        customerPhone: '9988776655',
        cartItems: cart,
        discountAmount: 40.0,
        deliveryCharge: 35.0,
        isPercent: false,
        percentValue: 0.0,
      );

      // 2. Close parcel order
      await PosDatabase.instance.closeParcelOrder(
        orderId,
        paymentMethod: 'UPI QR',
        discountAmount: 40.0,
        deliveryCharge: 35.0,
      );

      // 3. Load closed order from database via getSalesReport (same as OrdersScreen)
      final report = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );

      final closedOrder = report.completedOrders.firstWhere((o) => o.orderId == orderId);
      expect(closedOrder.deliveryCharge, equals(35.0));
      expect(closedOrder.discountAmount, equals(40.0));
      expect(closedOrder.totalAmount, equals(478.0)); // 2x takeawayPrice (230) = 460. (460 - 40) + 23 + 35 = 478

      // 4. Verify the reprinted receipt text includes both delivery charge and discount
      final rest = await PosDatabase.instance.getRestaurantDetails();
      final orderItems = await PosDatabase.instance.getOrderItems(closedOrder.orderId);

      final receiptText = PrinterService.instance.formatBillReceipt(
        restaurant: rest,
        destinationName: 'PARCEL: ${closedOrder.customerName}',
        items: orderItems,
        total: closedOrder.totalAmount,
        paymentMethod: closedOrder.paymentDisplay,
        orderId: closedOrder.orderId,
        netTotal: closedOrder.netAmount,
        taxTotal: closedOrder.taxAmount,
        discountAmount: closedOrder.discountAmount,
        deliveryCharge: closedOrder.deliveryCharge,
      );

      expect(receiptText.contains('Delivery Charge:'), isTrue, reason: 'Reprinted receipt must show Delivery Charge');
      expect(receiptText.contains('35.00'), isTrue);
      expect(receiptText.contains('Discount:'), isTrue, reason: 'Reprinted receipt must show Discount');
      expect(receiptText.contains('-Rs.40.00') || receiptText.contains('40.00'), isTrue);
      expect(receiptText.contains('TOTAL PAYABLE:'), isTrue);
      expect(receiptText.contains('478.00'), isTrue);
    });

    test('Reprinting closed table order with percent discount shows accurate discount amount on receipt', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final paneerTikka = items.firstWhere((i) => i.id == 1); // 240

      // 1. Hold table order: 2x Paneer Tikka = 480
      await PosDatabase.instance.holdSitDownOrder(
        11,
        [CartItemModel(item: paneerTikka, quantity: 2, existingQuantity: 0)],
        discountAmount: 48.0,
        isPercent: true,
        percentValue: 10.0,
      );

      // 2. Settle table 11 with 10% discount (48.0)
      await PosDatabase.instance.settleAndReleaseTable(
        11,
        paymentMethod: 'Cash',
        discountAmount: 48.0,
        isPercent: true,
        percentValue: 10.0,
      );

      // 3. Load closed orders
      final report = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );

      final closedOrder = report.completedOrders.firstWhere((o) => o.tableNumber == 11);
      expect(closedOrder.discountAmount, equals(48.0));

      final rest = await PosDatabase.instance.getRestaurantDetails();
      final orderItems = await PosDatabase.instance.getOrderItems(closedOrder.orderId);

      final receiptText = PrinterService.instance.formatBillReceipt(
        restaurant: rest,
        destinationName: 'Table ${closedOrder.tableNumber}',
        items: orderItems,
        total: closedOrder.totalAmount,
        paymentMethod: closedOrder.paymentDisplay,
        orderId: closedOrder.orderId,
        netTotal: closedOrder.netAmount,
        taxTotal: closedOrder.taxAmount,
        discountAmount: closedOrder.discountAmount,
        deliveryCharge: closedOrder.deliveryCharge,
      );

      expect(receiptText.contains('Discount:'), isTrue);
      expect(receiptText.contains('-Rs.48.00') || receiptText.contains('48.00'), isTrue);
    });

    test('KOT formatted ticket has prominent double-size font formatting for chefs', () {
      final item = const MenuItemModel(
        id: 5,
        categoryId: 1,
        categoryName: 'Starters',
        name: 'Kadai Paneer',
        sitdownPrice: 280,
      );

      final kot = PrinterService.instance.formatKotTicket(
        restaurantName: 'Test Bistro',
        tableName: 'Table 7',
        items: [CartItemModel(item: item, quantity: 3, notes: 'Less oil')],
        isRunningKot: false,
        orderId: 701,
      );

      // Verify double size ESC/POS command is used for Table Name and Food Items
      const escDoubleSize = '\x1D\x21\x11';
      expect(kot.contains(escDoubleSize), isTrue);
      expect(kot.contains('3 x Kadai Paneer'), isTrue);
      expect(kot.contains('TABLE 7'), isTrue);
      expect(kot.contains('Note: Less oil'), isTrue);
    });
  });
}

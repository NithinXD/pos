import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/database/pos_database.dart';
import 'package:pos/models/delivery_zone_model.dart';
import 'package:pos/models/menu_item_model.dart';
import 'package:pos/models/report_model.dart';
import 'package:pos/models/table_model.dart';
import 'package:pos/services/printer_service.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = await getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dbPath, 'pos_offline.db'));
  });

  group('Phase 2 Delivery Charge, Order Comments, GSTN & Reports Tests', () {
    test('1. Delivery zones table seed and CRUD operations', () async {
      final zones = await PosDatabase.instance.getDeliveryZones();
      expect(zones.length, greaterThanOrEqualTo(5));
      expect(zones.first.deliveryArea, equals('Area 1'));
      expect(zones.first.deliveryCharge, equals(20.0));

      // Add new zone
      final newZoneId = await PosDatabase.instance.addDeliveryZone(
        const DeliveryZoneModel(id: 0, deliveryArea: 'Area 6 Express', deliveryCharge: 65.0),
      );
      expect(newZoneId, greaterThan(0));

      var updatedZones = await PosDatabase.instance.getDeliveryZones();
      expect(updatedZones.any((z) => z.id == newZoneId && z.deliveryCharge == 65.0), isTrue);

      // Update zone
      await PosDatabase.instance.updateDeliveryZone(
        DeliveryZoneModel(id: newZoneId, deliveryArea: 'Area 6 Express', deliveryCharge: 70.0),
      );
      updatedZones = await PosDatabase.instance.getDeliveryZones();
      expect(updatedZones.firstWhere((z) => z.id == newZoneId).deliveryCharge, equals(70.0));

      // Delete zone
      await PosDatabase.instance.deleteDeliveryZone(newZoneId);
      updatedZones = await PosDatabase.instance.getDeliveryZones();
      expect(updatedZones.any((z) => z.id == newZoneId), isFalse);
    });

    test('2. Order comments and delivery charge on Dine-In table holding and settling', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final paneerTikka = items.firstWhere((i) => i.id == 1); // sitdownPrice: 240, taxRate: 5%

      final cart = [
        CartItemModel(
          item: paneerTikka,
          quantity: 2, // 480.0
          existingQuantity: 0,
        ),
      ];

      // Hold Table 7 with delivery charge and order comments
      await PosDatabase.instance.holdSitDownOrder(
        7,
        cart,
        discountAmount: 30.0,
        deliveryCharge: 25.0,
        orderComments: 'Extra spicy, less oil',
      );

      // Verify table state in SQLite
      final tables = await PosDatabase.instance.getSitDownTables();
      final table7 = tables.firstWhere((t) => t.tableNumber == 7);
      expect(table7.status, equals(TableOrderStatus.open));
      expect(table7.discountAmount, equals(30.0));
      expect(table7.deliveryCharge, equals(25.0));
      expect(table7.orderComments, equals('Extra spicy, less oil'));
      expect(table7.netTotal, equals(480.0));
      // Net: 480, Discount: 30, Tax: 24 (5% of 480), Delivery: 25
      // Total Payable = (480 - 30) + 24 + 25 = 499.0
      expect(table7.totalWithTax, equals(499.0));

      // Settle Table 7
      await PosDatabase.instance.settleAndReleaseTable(
        7,
        paymentMethod: 'Cash',
        discountAmount: 30.0,
        deliveryCharge: 25.0,
        orderComments: 'Extra spicy, less oil',
      );

      // Verify table is released
      final tablesAfter = await PosDatabase.instance.getSitDownTables();
      expect(tablesAfter.firstWhere((t) => t.tableNumber == 7).status, equals(TableOrderStatus.closed));
    });

    test('3. Order comments and delivery charge on Parcel orders', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final biryani = items.firstWhere((i) => i.id == 12); // takeawayPrice: 300, taxRate: 5%

      final cart = [
        CartItemModel(
          item: biryani,
          quantity: 2, // 600.0
          existingQuantity: 0,
          isTakeaway: true,
        ),
      ];

      final parcelId = await PosDatabase.instance.createParcelOrder(
        customerName: 'Customer X',
        customerPhone: '9988112233',
        cartItems: cart,
        discountAmount: 50.0,
        deliveryCharge: 35.0,
        orderComments: 'Deliver to 2nd Floor Apt 4B',
      );

      final openParcels = await PosDatabase.instance.getOpenParcelOrders();
      final parcel = openParcels.firstWhere((p) => p.id == parcelId);
      expect(parcel.deliveryCharge, equals(35.0));
      expect(parcel.orderComments, equals('Deliver to 2nd Floor Apt 4B'));
      expect(parcel.discountAmount, equals(50.0));

      // Net: 600, Tax: 30 (5% of 600), Discount: 50, Delivery: 35
      // Total = (600 - 50) + 30 + 35 = 615.0
      expect(parcel.totalWithTax, equals(615.0));

      // Close parcel
      await PosDatabase.instance.closeParcelOrder(
        parcelId,
        paymentMethod: 'UPI QR',
        deliveryCharge: 35.0,
        orderComments: 'Deliver to 2nd Floor Apt 4B',
      );

      final parcelsAfter = await PosDatabase.instance.getOpenParcelOrders();
      expect(parcelsAfter.any((p) => p.id == parcelId), isFalse);
    });

    test('4. GSTN Number in restaurant model, database and printed receipt bottom', () async {
      final initial = await PosDatabase.instance.getRestaurantDetails();
      final updated = initial.copyWith(
        gstnNumber: '19ABCDE1234F1Z5',
      );
      await PosDatabase.instance.updateRestaurantDetails(updated);

      final reloaded = await PosDatabase.instance.getRestaurantDetails();
      expect(reloaded.gstnNumber, equals('19ABCDE1234F1Z5'));

      // Format customer receipt
      final receiptText = PrinterService.instance.formatBillReceipt(
        restaurant: reloaded,
        destinationName: 'Table 3',
        orderId: 777,
        items: [
          CartItemModel(
            item: MenuItemModel(
              id: 1,
              categoryId: 1,
              categoryName: 'Starters',
              name: 'Paneer Tikka',
              sitdownPrice: 240.0,
              takeawayPrice: 230.0,
              quantity: 10,
              status: 1,
            ),
            quantity: 1,
          ),
        ],
        total: 257.0,
        paymentMethod: 'Cash',
        discountAmount: 20.0,
        deliveryCharge: 25.0,
      );

      // Verify delivery charge row appears
      expect(receiptText.contains('Delivery Charge:'), isTrue);
      expect(receiptText.contains('25.00'), isTrue);
      // Verify GSTIN is at bottom of receipt
      expect(receiptText.contains('GSTIN: 19ABCDE1234F1Z5'), isTrue);
    });

    test('5. Item-wise sales report & formatted print sales report ticket', () async {
      final report = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );

      // Item-wise sales
      expect(report.itemSales, isNotEmpty);
      expect(report.itemSales.first.quantitySold, greaterThan(0));
      expect(report.itemSales.first.totalRevenue, greaterThan(0));

      // Delivery charges aggregated
      expect(report.totalDeliveryCharge, greaterThan(0));

      // Verify formula: Total Business = Net Sales + Tax + Delivery Charge - Discount
      final computedBusiness = (report.totalNetSales + report.totalTax + report.totalDeliveryCharge - report.totalDiscount);
      expect(report.totalRevenue, closeTo(computedBusiness, 0.05));

      // Verify payment split adds up to total business
      expect(
        (report.totalCashBusiness + report.totalCardBusiness + report.totalUpiBusiness),
        closeTo(report.totalRevenue, 0.05),
      );

      // Format print sales report ticket
      final restaurant = await PosDatabase.instance.getRestaurantDetails();
      final ticketText = PrinterService.instance.formatSalesReportTicket(
        restaurant: restaurant,
        report: report,
      );

      // Check required print ticket metrics:
      // Net Sales, Net Tax, Net Discount, Net Delivery Charge, Total Business, Net Cash, Net Card, Net UPI, Total Business, Date
      expect(ticketText.contains('Net Sales:'), isTrue);
      expect(ticketText.contains('Net Tax:'), isTrue);
      expect(ticketText.contains('Net Discount:'), isTrue);
      expect(ticketText.contains('Net Delivery Charge:'), isTrue);
      expect(ticketText.contains('Total Business:'), isTrue);
      expect(ticketText.contains('Net Cash:'), isTrue);
      expect(ticketText.contains('Net Card:'), isTrue);
      expect(ticketText.contains('Net UPI:'), isTrue);
      expect(ticketText.contains('Date:'), isTrue);
    });

    test('6. Change Payment on closed order updates order_payment_type in SQLite', () async {
      final report = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );
      final firstOrder = report.completedOrders.first;
      final targetOrderId = firstOrder.orderId;

      // Update payment to UPI
      await PosDatabase.instance.updateOrderPaymentMethod(targetOrderId, 'UPI QR');
      var updatedReport = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );
      var updatedOrder = updatedReport.completedOrders.firstWhere((o) => o.orderId == targetOrderId);
      expect(updatedOrder.paymentDisplay, equals('UPI QR'));

      // Update payment to Card
      await PosDatabase.instance.updateOrderPaymentMethod(targetOrderId, 'Card');
      updatedReport = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );
      updatedOrder = updatedReport.completedOrders.firstWhere((o) => o.orderId == targetOrderId);
      expect(updatedOrder.paymentDisplay, equals('Card'));

      // Update payment to Cash
      await PosDatabase.instance.updateOrderPaymentMethod(targetOrderId, 'Cash');
      updatedReport = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );
      updatedOrder = updatedReport.completedOrders.firstWhere((o) => o.orderId == targetOrderId);
      expect(updatedOrder.paymentDisplay, equals('Cash'));
    });
  });
}

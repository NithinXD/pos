import 'package:flutter_test/flutter_test.dart';
import 'package:pos/models/menu_item_model.dart';
import 'package:pos/models/restaurant_model.dart';
import 'package:pos/services/printer_service.dart';

void main() {
  group('PrinterService Formatting Tests', () {
    final sampleRestaurant = RestaurantModel(
      id: 1,
      name: 'Spice Garden',
      phone: '9876543210',
      address: '123 Food Street, Downtown',
      currency: '₹',
      numberOfTables: 12,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    final item1 = const MenuItemModel(
      id: 1,
      categoryId: 1,
      categoryName: 'Main Course',
      name: 'Chicken Biryani',
      sitdownPrice: 250,
      takeawayPrice: 250,
      deliveryPrice: 270,
    );

    final item2 = const MenuItemModel(
      id: 2,
      categoryId: 2,
      categoryName: 'Breads & Rice',
      name: 'Butter Naan',
      sitdownPrice: 40,
      takeawayPrice: 40,
      deliveryPrice: 45,
    );

    test('formatKotTicket: generates clean new KOT ticket', () {
      final cart = [
        CartItemModel(item: item1, quantity: 2, notes: 'Spicy'),
        CartItemModel(item: item2, quantity: 4),
      ];

      final ticket = PrinterService.instance.formatKotTicket(
        restaurantName: sampleRestaurant.name,
        tableName: 'Table 4',
        items: cart,
        isRunningKot: false,
        orderId: 101,
        timestamp: DateTime(2026, 10, 31, 14, 30),
        orderTypeLabel: 'DINE-IN',
      );

      expect(ticket.contains('KITCHEN ORDER TICKET'), isTrue);
      expect(ticket.contains('(NEW KOT)'), isTrue);
      expect(ticket.contains('SITDOWN ORDER'), isTrue);
      expect(ticket.contains('Table 4'), isTrue);
      expect(ticket.contains('#101'), isTrue);
      expect(ticket.contains('Chicken Biryani'), isTrue);
      expect(ticket.contains('Butter Naan'), isTrue);
      expect(ticket.contains('Note: Spicy'), isTrue);
      expect(ticket.contains('ITEMS TO COOK:'), isTrue);
      expect(ticket.contains('6'), isTrue); // 2 + 4
      expect(ticket.contains('*** CHEF COPY ***'), isTrue);
    });

    test('formatKotTicket: generates parcel KOT with PARCEL ORDER prominently', () {
      final cart = [
        CartItemModel(item: item1, quantity: 1),
      ];

      final ticket = PrinterService.instance.formatKotTicket(
        restaurantName: sampleRestaurant.name,
        tableName: 'Parcel #1',
        items: cart,
        isRunningKot: false,
        orderId: 105,
        orderTypeLabel: 'PARCEL ORDER',
      );

      expect(ticket.contains('PARCEL ORDER'), isTrue);
    });

    test('formatKotTicket: generates running KOT ticket with only newly added items and excludes held items', () {
      final cart = [
        // Previously held item (no new qty)
        CartItemModel(item: item1, quantity: 2, existingQuantity: 2),
        // Item with additional quantity ordered
        CartItemModel(item: item2, quantity: 5, existingQuantity: 2), // 3 new
      ];

      final ticket = PrinterService.instance.formatKotTicket(
        restaurantName: sampleRestaurant.name,
        tableName: 'Table 2',
        items: cart,
        isRunningKot: true,
        orderId: 102,
        orderTypeLabel: 'DINE-IN',
      );

      expect(ticket.contains('(RUNNING KOT)'), isTrue);
      expect(ticket.contains('>> NEW ITEMS TO PREPARE <<'), isTrue);
      expect(ticket.contains('Butter Naan'), isTrue);
      expect(ticket.contains('3 [NEW]'), isTrue);
      // Previously held items must NOT be printed
      expect(ticket.contains('-- Previously Held --'), isFalse);
      expect(ticket.contains('Chicken Biryani'), isFalse);
      expect(ticket.contains('(Sent)'), isFalse);
      expect(ticket.contains('ITEMS TO COOK:'), isTrue);
      expect(ticket.contains('3'), isTrue);
    });

    test('formatBillReceipt: generates retail invoice with totals and payment mode', () {
      final cart = [
        CartItemModel(item: item1, quantity: 2),
        CartItemModel(item: item2, quantity: 3),
      ];
      final total = 2 * 250.0 + 3 * 40.0; // 500 + 120 = 620

      final bill = PrinterService.instance.formatBillReceipt(
        restaurant: sampleRestaurant,
        destinationName: 'Table 8',
        items: cart,
        total: total,
        paymentMethod: 'UPI QR',
        orderId: 205,
      );

      expect(bill.contains('SPICE GARDEN'), isTrue);
      expect(bill.contains('RETAIL INVOICE'), isTrue);
      expect(bill.contains('Table 8'), isTrue);
      expect(bill.contains('UPI QR'), isTrue);
      expect(bill.contains('Rs.620.00') || bill.contains('620.00'), isTrue);
      expect(bill.contains('TOTAL PAYABLE:'), isTrue);
      expect(bill.contains('Thank you for dining with us!'), isTrue);
    });

    test('formatBillReceipt: includes discount and calculates total payable accurately', () {
      final cart = [
        CartItemModel(item: item1, quantity: 2), // 500
      ];
      final bill = PrinterService.instance.formatBillReceipt(
        restaurant: sampleRestaurant,
        destinationName: 'Table 3',
        items: cart,
        total: 500.0,
        paymentMethod: 'Cash',
        netTotal: 500.0,
        discountAmount: 75.0,
        taxTotal: 25.0,
      );

      expect(bill.contains('Net Total:'), isTrue);
      expect(bill.contains('Rs.500.00') || bill.contains('500.00'), isTrue);
      expect(bill.contains('Discount:'), isTrue);
      expect(bill.contains('-Rs.75.00') || bill.contains('75.00'), isTrue);
      expect(bill.contains('Total Tax:'), isTrue);
      expect(bill.contains('Rs.25.00') || bill.contains('25.00'), isTrue);
      expect(bill.contains('TOTAL PAYABLE:'), isTrue);
      expect(bill.contains('Rs.450.00') || bill.contains('450.00'), isTrue); // (500 - 75) + 25 = 450
    });

    test('formatTestTicket: generates proper printer test pattern', () {
      final testTicket = PrinterService.instance.formatTestTicket(restaurant: sampleRestaurant);
      expect(testTicket.contains('THERMAL PRINTER TEST'), isTrue);
      expect(testTicket.contains('Spice Garden'), isTrue);
      expect(testTicket.contains('Direct Thermal POS Driver') || testTicket.contains('RawBT Print Service'), isTrue);
      expect(testTicket.contains('PRINTER TEST SUCCESSFUL'), isTrue);
    });
  });
}

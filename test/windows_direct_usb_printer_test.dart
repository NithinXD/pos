import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/services/windows_spooler_service.dart';
import 'package:pos/services/printer_service.dart';
import 'package:pos/models/restaurant_model.dart';
import 'package:pos/models/menu_item_model.dart';

void main() {
  group('Windows Direct USB Thermal Printing Tests', () {
    test('WindowsDirectSpooler: lists installed Windows printers', () {
      if (Platform.isWindows) {
        final printers = WindowsDirectSpooler.getInstalledPrinters();
        expect(printers, isA<List<String>>());
        expect(printers.isNotEmpty, isTrue);
      }
    });

    test('WindowsDirectSpooler: gets default printer name on Windows', () {
      if (Platform.isWindows) {
        final defaultPrinter = WindowsDirectSpooler.getDefaultPrinter();
        expect(defaultPrinter, isA<String?>());
      }
    });

    test('PrinterService.getWindowsPrinters: returns Windows printer list', () {
      if (Platform.isWindows) {
        final printers = PrinterService.getWindowsPrinters();
        expect(printers, isA<List<String>>());
        expect(printers.isNotEmpty, isTrue);
      }
    });

    test('PrinterService: formats receipt and generates ESC/POS bytes for Windows Direct USB', () async {
      final restaurant = RestaurantModel(
        id: 1,
        name: 'Windows Test Bistro',
        address: '123 PC Road',
        phone: '9876543210',
        currency: '₹',
        numberOfTables: 10,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

      final items = [
        CartItemModel(
          item: const MenuItemModel(
            id: 1,
            name: 'Chicken Burger',
            sitdownPrice: 199.0,
            takeawayPrice: 199.0,
            deliveryPrice: 219.0,
            categoryId: 1,
            categoryName: 'Food',
          ),
          quantity: 2,
        ),
      ];

      // Format bill
      final ticket = PrinterService.instance.formatBillReceipt(
        restaurant: restaurant,
        destinationName: 'Table 1',
        items: items,
        total: 398.0,
        netTotal: 398.0,
        taxTotal: 0.0,
        paymentMethod: 'CASH',
        orderId: 101,
      );

      expect(ticket.contains('WINDOWS TEST BISTRO'), isTrue);
      expect(ticket.contains('Chicken Burger'), isTrue);
      expect(ticket.contains('398.00'), isTrue);

      // Verify encodeTicketBytes generates valid ESC/POS byte sequence
      final bytes = PrinterService.encodeTicketBytes(ticket);
      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      // ESC @ (0x1B 0x40)
      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x40));
      // FS . (0x1C 0x2E - cancel double-byte mode)
      expect(bytes[2], equals(0x1C));
      expect(bytes[3], equals(0x2E));
    });
  });
}

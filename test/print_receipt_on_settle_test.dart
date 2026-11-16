import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/database/pos_database.dart';
import 'package:pos/models/restaurant_model.dart';
import 'package:pos/models/table_model.dart';
import 'package:pos/models/menu_item_model.dart';
import 'package:pos/widgets/table_active_order_sheet.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Print Receipt On Settle Bill Feature Tests (Per Sam Biswas)', () {
    test('1. RestaurantModel default, serialization and deserialization', () {
      const defaultRest = RestaurantModel(
        id: 1,
        name: 'Test Restaurant',
        phone: '1234567890',
        address: 'Test Address',
        createdAt: '',
        updatedAt: '',
      );

      // Default value is 1 (true)
      expect(defaultRest.printReceiptOnSettle, isTrue);

      final map = defaultRest.toMap();
      expect(map['print_receipt_on_settle'], equals(1));

      // Parsing 0 from map
      final restWithZero = RestaurantModel.fromMap({
        ...map,
        'print_receipt_on_settle': 0,
      });
      expect(restWithZero.printReceiptOnSettle, isFalse);

      // Parsing 1 from map
      final restWithOne = RestaurantModel.fromMap({
        ...map,
        'print_receipt_on_settle': 1,
      });
      expect(restWithOne.printReceiptOnSettle, isTrue);

      // copyWith toggle
      final toggled = defaultRest.copyWith(printReceiptOnSettle: false);
      expect(toggled.printReceiptOnSettle, isFalse);
    });

    test('2. SQLite Database: Toggle print_receipt_on_settle between 1 and 0', () async {
      final db = PosDatabase.instance;
      await db.database; // Ensure initialized

      // Initially enabled (1)
      final initialVal = await db.getPrintReceiptOnSettle();
      expect(initialVal, isTrue);

      // Toggle to disabled (0)
      await db.setPrintReceiptOnSettle(false);
      final disabledVal = await db.getPrintReceiptOnSettle();
      expect(disabledVal, isFalse);

      final rest = await db.getRestaurantDetails();
      expect(rest.printReceiptOnSettle, isFalse);

      // Toggle back to enabled (1)
      await db.setPrintReceiptOnSettle(true);
      final reEnabledVal = await db.getPrintReceiptOnSettle();
      expect(reEnabledVal, isTrue);
    });

    testWidgets('3. TableActiveOrderSheet: button text dynamically reflects printReceiptOnSettle mode', (tester) async {
      const testFood = MenuItemModel(
        id: 1,
        categoryId: 1,
        categoryName: 'Pizza',
        name: 'Pizza Margherita',
        sitdownPrice: 250.0,
        takeawayPrice: 250.0,
        kitchenType: 'kitchen',
        taxRate: 5.0,
      );

      final table = TableModel(
        id: 1,
        name: 'Table 1',
        tableNumber: 1,
        status: TableOrderStatus.open,
        activeCart: [CartItemModel(item: testFood, quantity: 1)],
        currentTotal: 250.0,
      );

      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Mode 1: printReceiptOnSettle = true -> "Print and Settle"
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableActiveOrderSheet(
              table: table,
              currency: 'Rs.',
              printReceiptOnSettle: true,
              onAddMoreItems: () {},
              onSettleAndReleaseTable: (method, [disc, del, comm]) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Print and Settle'), findsOneWidget);
      expect(find.text('Print Receipt'), findsOneWidget);

      // Mode 0: printReceiptOnSettle = false -> "Settle Table"
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableActiveOrderSheet(
              table: table,
              currency: 'Rs.',
              printReceiptOnSettle: false,
              onAddMoreItems: () {},
              onSettleAndReleaseTable: (method, [disc, del, comm]) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Settle Table'), findsOneWidget);
      // Independent "Print Receipt" manual button is still available
      expect(find.text('Print Receipt'), findsOneWidget);
    });
  });
}

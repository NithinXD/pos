import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/models/table_model.dart';
import 'package:pos/models/menu_item_model.dart';
import 'package:pos/screens/menu_ordering_screen.dart';
import 'package:pos/widgets/table_active_order_sheet.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = await getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dbPath, 'pos_offline.db'));
  });

  group('Sit Down Table Delivery Charge Disabled Tests', () {
    testWidgets('1. MenuOrderingScreen: Del Chg button is DISABLED for Sit-Down tables', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const sitDownTable = TableModel(
        id: 1,
        name: 'Table 1',
        tableNumber: 1,
        status: TableOrderStatus.closed,
        orderType: OrderType.sitDown,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MenuOrderingScreen(
            table: sitDownTable,
            onOrderHeld: (cart, [discount = 0.0, delivery = 0.0, comments = '', isPercent = false, percentValue = 0.0]) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Del Chg button
      final delChgButtonFinder = find.widgetWithText(OutlinedButton, 'Del Chg');
      expect(delChgButtonFinder, findsOneWidget);

      final OutlinedButton button = tester.widget(delChgButtonFinder);
      // Button must be disabled (onPressed is null)
      expect(button.onPressed, isNull);
    });

    testWidgets('2. MenuOrderingScreen: Del Chg button is ENABLED for Parcel orders', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const parcelTable = TableModel(
        id: 101,
        name: 'Takeaway #1',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'Rahul',
        customerPhone: '9876543210',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MenuOrderingScreen(
            table: parcelTable,
            onOrderHeld: (cart, [discount = 0.0, delivery = 0.0, comments = '', isPercent = false, percentValue = 0.0]) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Del Chg button
      final delChgButtonFinder = find.widgetWithText(OutlinedButton, 'Del Chg');
      expect(delChgButtonFinder, findsOneWidget);

      final OutlinedButton button = tester.widget(delChgButtonFinder);
      // Button must be ENABLED for parcel orders
      expect(button.onPressed, isNotNull);
    });

    testWidgets('3. TableActiveOrderSheet: Delivery Charge is disabled for sit down active table sheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const paneerTikka = MenuItemModel(
        id: 1,
        name: 'Paneer Tikka',
        categoryId: 1,
        categoryName: 'Starters',
        sitdownPrice: 240.0,
        taxRate: 5.0,
      );

      final sitDownTable = TableModel(
        id: 2,
        name: 'Table 2',
        tableNumber: 2,
        status: TableOrderStatus.open,
        orderType: OrderType.sitDown,
        activeCart: [
          CartItemModel(
            item: paneerTikka,
            quantity: 2,
            existingQuantity: 2,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TableActiveOrderSheet(
              table: sitDownTable,
              onAddMoreItems: () {},
              onSettleAndReleaseTable: (method, [discount, delivery, comments]) {
                // Must pass 0.0 for delivery charge
                expect(delivery, equals(0.0));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display "Disabled" badge for Delivery Charge
      expect(find.text('Disabled'), findsOneWidget);

      // Settle button should not include delivery charge
      expect(find.textContaining('Print and Settle'), findsOneWidget);
      expect(find.textContaining('₹504'), findsWidgets);
    });
  });
}

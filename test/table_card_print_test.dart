import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos/models/menu_item_model.dart';
import 'package:pos/models/table_model.dart';
import 'package:pos/widgets/table_card.dart';
import 'package:pos/widgets/parcel_settlement_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TableCard Print Button & Parcel Receipt Tests', () {
    testWidgets('TableCard: shows blue Bill button when open, invokes onPrint when tapped', (tester) async {
      bool printTapped = false;
      bool cardTapped = false;

      final openTable = TableModel(
        id: 3,
        name: 'Table 3',
        tableNumber: 3,
        status: TableOrderStatus.open,
        currentTotal: 450.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 150,
              child: TableCard(
                table: openTable,
                onTap: () => cardTapped = true,
                onPrint: () => printTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bill'), findsOneWidget);
      expect(find.byIcon(Icons.print_rounded), findsOneWidget);

      // Tap the Bill button
      await tester.tap(find.text('Bill'));
      await tester.pump();

      expect(printTapped, isTrue);
      expect(cardTapped, isFalse);
    });

    testWidgets('TableCard: hides Bill button when table is closed / free', (tester) async {
      final closedTable = TableModel(
        id: 5,
        name: 'Table 5',
        tableNumber: 5,
        status: TableOrderStatus.closed,
        currentTotal: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 150,
              child: TableCard(
                table: closedTable,
                onTap: () {},
                onPrint: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Bill'), findsNothing);
      expect(find.byIcon(Icons.print_rounded), findsNothing);
    });

    testWidgets('ParcelSettlementSheet: contains Print Receipt button', (tester) async {
      const foodItem = MenuItemModel(
        id: 1,
        categoryId: 1,
        categoryName: 'Main',
        name: 'Burger',
        sitdownPrice: 150,
        takeawayPrice: 150,
      );

      final parcel = TableModel(
        id: 1,
        name: 'Takeaway John',
        customerName: 'John',
        customerPhone: '9876543210',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        activeCart: [CartItemModel(item: foodItem, quantity: 2)],
        currentTotal: 300.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ParcelSettlementSheet(
              parcel: parcel,
              onCollectAndClose: (method, [disc, del, comm]) {},
            ),
          ),
        ),
      );

      expect(find.text('Print Receipt'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_rounded), findsOneWidget);
      expect(find.text('Reprint KOT'), findsOneWidget);
    });
  });
}


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/database/pos_database.dart';
import 'package:pos/models/delivery_zone_model.dart';
import 'package:pos/screens/delivery_zones_screen.dart';
import 'package:pos/widgets/delivery_charge_dialog.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = await getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dbPath, 'pos_offline.db'));
  });

  group('Delivery Zones Management Tests', () {
    test('Database CRUD: add, edit name, change price, and delete delivery zones', () async {
      // 1. Initial seeded zones
      final initialZones = await PosDatabase.instance.getDeliveryZones();
      expect(initialZones.isNotEmpty, isTrue);
      final initialCount = initialZones.length;

      // 2. Add new delivery zone
      final newZone = const DeliveryZoneModel(
        id: 0,
        deliveryArea: 'North Extension (3-5km)',
        deliveryCharge: 45.0,
      );
      final insertedId = await PosDatabase.instance.addDeliveryZone(newZone);
      expect(insertedId, isPositive);

      var updatedZones = await PosDatabase.instance.getDeliveryZones();
      expect(updatedZones.length, equals(initialCount + 1));
      var addedZone = updatedZones.firstWhere((z) => z.id == insertedId);
      expect(addedZone.deliveryArea, equals('North Extension (3-5km)'));
      expect(addedZone.deliveryCharge, equals(45.0));

      // 3. Edit zone name and price
      final editedZone = addedZone.copyWith(
        deliveryArea: 'North Sector A (0-4km)',
        deliveryCharge: 60.0,
      );
      await PosDatabase.instance.updateDeliveryZone(editedZone);

      updatedZones = await PosDatabase.instance.getDeliveryZones();
      var fetchedEdited = updatedZones.firstWhere((z) => z.id == insertedId);
      expect(fetchedEdited.deliveryArea, equals('North Sector A (0-4km)'));
      expect(fetchedEdited.deliveryCharge, equals(60.0));

      // 4. Delete delivery zone
      await PosDatabase.instance.deleteDeliveryZone(insertedId);
      updatedZones = await PosDatabase.instance.getDeliveryZones();
      expect(updatedZones.length, equals(initialCount));
      expect(updatedZones.any((z) => z.id == insertedId), isFalse);
    });

    testWidgets('DeliveryZonesScreen: renders zones list and displays edit action', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: DeliveryZonesScreen(),
        ),
      );
      await tester.runAsync(() async {
        for (int i = 0; i < 20; i++) {
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
          await Future.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pump();

      // Verify Screen title
      expect(find.text('Delivery Zones'), findsOneWidget);
      expect(find.text('Add Zone'), findsOneWidget);

      // Verify seeded zones exist in list
      expect(find.text('Area 1'), findsOneWidget);
      expect(find.text('Area 2'), findsOneWidget);

      // Verify Edit icon buttons exist
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });

    testWidgets('DeliveryChargeDialog: includes Manage Zones button and loads zones', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => DeliveryChargeDialog(
                      initialCharge: 0.0,
                      onApply: (_) {},
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Tap button to open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.runAsync(() async {
        for (int i = 0; i < 20; i++) {
          if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
          await Future.delayed(const Duration(milliseconds: 50));
          await tester.pump();
        }
      });
      await tester.pump();

      // Verify Dialog header
      expect(find.text('Delivery Charge'), findsOneWidget);
      expect(find.text('DELIVERY ZONES'), findsOneWidget);

      // Verify "Manage Zones" button is present
      expect(find.text('Manage Zones'), findsOneWidget);

      // Verify choice chips exist for zones
      expect(find.byType(ChoiceChip), findsWidgets);
    });
  });
}


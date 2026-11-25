import 'package:flutter_test/flutter_test.dart';
import 'package:pos/database/pos_database.dart';
import 'package:pos/models/employee_model.dart';
import 'package:pos/models/menu_item_model.dart';
import 'package:pos/services/printer_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Order Notes Table Tests', () {
    test('Can retrieve default order notes and perform CRUD', () async {
      final db = PosDatabase.instance;
      final initialNotes = await db.getOrderNotes();
      expect(initialNotes, isNotEmpty);
      expect(initialNotes.any((n) => n.note == 'Extra Spicy'), isTrue);

      // Insert new note
      final newId = await db.insertOrderNote('Extra Gravy');
      expect(newId, isPositive);

      final updatedNotes = await db.getOrderNotes();
      expect(updatedNotes.any((n) => n.note == 'Extra Gravy'), isTrue);

      // Update note
      await db.updateOrderNote(newId, 'Extra Thick Gravy');
      final notesAfterUpdate = await db.getOrderNotes();
      expect(notesAfterUpdate.any((n) => n.note == 'Extra Thick Gravy'), isTrue);

      // Delete note
      final deletedCount = await db.deleteOrderNote(newId);
      expect(deletedCount, 1);
      final notesAfterDelete = await db.getOrderNotes();
      expect(notesAfterDelete.any((n) => n.note == 'Extra Thick Gravy'), isFalse);
    });
  });

  group('Employee Table Tests', () {
    test('Can retrieve employees and perform CRUD by employee_type', () async {
      final db = PosDatabase.instance;
      final employees = await db.getEmployees();
      expect(employees, isNotEmpty);

      // Types: 0 kitchen, 1 service, 3 driver, 4 manager
      final kitchenStaff = await db.getEmployeesByType(0);
      expect(kitchenStaff.any((e) => e.employeeType == 0), isTrue);

      // Insert a new driver
      const newDriver = EmployeeModel(
        id: 0,
        employeeName: 'Ramesh Fast',
        employeePhone: '9988776655',
        employeeType: 3,
      );
      final driverId = await db.insertEmployee(newDriver);
      expect(driverId, isPositive);

      final drivers = await db.getEmployeesByType(3);
      expect(drivers.any((d) => d.employeeName == 'Ramesh Fast' && d.employeeType == 3), isTrue);

      // Update employee
      final updatedDriver = EmployeeModel(
        id: driverId,
        employeeName: 'Ramesh Express',
        employeePhone: '9988776655',
        employeeType: 3,
      );
      await db.updateEmployee(updatedDriver);
      final driversAfterUpdate = await db.getEmployeesByType(3);
      expect(driversAfterUpdate.any((d) => d.employeeName == 'Ramesh Express'), isTrue);

      // Delete employee
      final deleted = await db.deleteEmployee(driverId);
      expect(deleted, 1);
      final driversAfterDelete = await db.getEmployeesByType(3);
      expect(driversAfterDelete.any((d) => d.id == driverId), isFalse);
    });
  });

  group('KOT Printing Note Placement Tests', () {
    test('Order note is formatted and printed above ITEMS TO COOK count', () {
      final dummyItem = MenuItemModel(
        id: 1,
        categoryId: 1,
        categoryName: 'Main Course',
        name: 'Paneer Butter Masala',
        sitdownPrice: 280,
        takeawayPrice: 270,
        deliveryPrice: 270,
        kitchenType: 'hot_kitchen',
        itemType: 'veg',
      );
      final cartItem = CartItemModel(
        item: dummyItem,
        quantity: 2,
      );

      final kotOutput = PrinterService.instance.formatKotTicket(
        restaurantName: 'The Royal Bistro',
        tableName: 'Table 2',
        items: [cartItem],
        isRunningKot: false,
        orderNotes: 'Extra Spicy, Less Salt',
      );

      expect(kotOutput.contains('*** ORDER NOTE / INSTRUCTIONS ***'), isTrue);
      expect(kotOutput.contains('Extra Spicy, Less Salt'), isTrue);
      expect(kotOutput.contains('ITEMS TO COOK:'), isTrue);

      // Verify note appears BEFORE 'ITEMS TO COOK:'
      final noteIndex = kotOutput.indexOf('*** ORDER NOTE / INSTRUCTIONS ***');
      final itemsToCookIndex = kotOutput.indexOf('ITEMS TO COOK:');
      expect(noteIndex, isNonNegative);
      expect(itemsToCookIndex, isNonNegative);
      expect(noteIndex < itemsToCookIndex, isTrue, reason: 'Order note must be printed above ITEMS TO COOK');
    });
  });
}

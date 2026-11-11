import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/database/pos_database.dart';
import 'package:pos/models/category_model.dart';
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

  group('POS Management Features & Policy Tests', () {
    test('1. Restaurant Details: Update only, verifies dynamic table count', () async {
      final initial = await PosDatabase.instance.getRestaurantDetails();
      expect(initial.id, equals(1));
      expect(initial.name, isNotEmpty);

      // Update restaurant details
      final updated = initial.copyWith(
        name: 'Sam Deluxe Diner',
        phone: '9988776655',
        address: '42 Central Boulevard, Sector 5',
        status: 'open',
        currency: '₹',
        numberOfTables: 12, // Increased from 10 to 12
      );

      await PosDatabase.instance.updateRestaurantDetails(updated);

      final reloaded = await PosDatabase.instance.getRestaurantDetails();
      expect(reloaded.name, equals('Sam Deluxe Diner'));
      expect(reloaded.phone, equals('9988776655'));
      expect(reloaded.status, equals('open'));
      expect(reloaded.numberOfTables, equals(12));

      // Verify getSitDownTables() dynamically reflects 12 tables
      final sitDownTables = await PosDatabase.instance.getSitDownTables();
      expect(sitDownTables.length, equals(12));
      expect(sitDownTables.any((t) => t.tableNumber == 11), isTrue);
      expect(sitDownTables.any((t) => t.tableNumber == 12), isTrue);
    });

    test('2. Category Management: Add, edit, and enable/disable toggle', () async {
      // Add a new category (default status = 1)
      final newCat = CategoryModel(
        id: 0,
        name: 'Mocktails & Shakes',
        position: 99,
        colorHex: '#42A5F5',
        type: 'drinks',
        status: 1,
      );

      final catId = await PosDatabase.instance.addCategory(newCat);
      expect(catId, greaterThan(0));

      // Verify category appears in all categories and enabled categories
      final allCats = await PosDatabase.instance.getAllCategories();
      final added = allCats.firstWhere((c) => c.id == catId);
      expect(added.name, equals('Mocktails & Shakes'));
      expect(added.status, equals(1));
      expect(added.isEnabled, isTrue);

      final activeNames = await PosDatabase.instance.getCategories();
      expect(activeNames.contains('Mocktails & Shakes'), isTrue);

      // Edit category details
      final edited = added.copyWith(
        name: 'Signature Mocktails & Shakes',
        position: 50,
      );
      await PosDatabase.instance.updateCategory(edited);

      final afterEdit = (await PosDatabase.instance.getAllCategories()).firstWhere((c) => c.id == catId);
      expect(afterEdit.name, equals('Signature Mocktails & Shakes'));
      expect(afterEdit.position, equals(50));

      // Disable category (status = 0)
      await PosDatabase.instance.toggleCategoryStatus(catId, 0);

      final afterDisable = (await PosDatabase.instance.getAllCategories()).firstWhere((c) => c.id == catId);
      expect(afterDisable.status, equals(0));
      expect(afterDisable.isEnabled, isFalse);

      // Verify disabled category is excluded from cart/ordering category list
      final activeAfterDisable = await PosDatabase.instance.getCategories();
      expect(activeAfterDisable.contains('Signature Mocktails & Shakes'), isFalse);

      // Re-enable category (status = 1)
      await PosDatabase.instance.toggleCategoryStatus(catId, 1);
      final activeAfterReEnable = await PosDatabase.instance.getCategories();
      expect(activeAfterReEnable.contains('Signature Mocktails & Shakes'), isTrue);
    });

    test('3. Menu Item Management: Add, edit, and enable/disable toggle', () async {
      // Find an enabled category ID
      final allCats = await PosDatabase.instance.getAllCategories();
      final targetCat = allCats.firstWhere((c) => c.status == 1);

      // Add a new menu item
      final newItem = MenuItemModel(
        id: 0,
        categoryId: targetCat.id,
        categoryName: targetCat.name,
        name: 'Blueberry Mojito Cooler',
        sitdownPrice: 160.0,
        takeawayPrice: 150.0,
        deliveryPrice: 170.0,
        quantity: 50,
        itemType: 'beverage',
        kitchenType: 'bar',
        taxRate: 5.0,
        status: 1,
      );

      final itemId = await PosDatabase.instance.addMenuItem(newItem);
      expect(itemId, greaterThan(0));

      // Verify item appears in all menu items and active menu items for cart
      final allItems = await PosDatabase.instance.getAllMenuItems();
      final addedItem = allItems.firstWhere((i) => i.id == itemId);
      expect(addedItem.name, equals('Blueberry Mojito Cooler'));
      expect(addedItem.status, equals(1));

      final activeMenuItems = await PosDatabase.instance.getMenuItems();
      expect(activeMenuItems.any((i) => i.id == itemId), isTrue);

      // Edit item details
      final editedItem = addedItem.copyWith(
        name: 'Blueberry Mint Mojito Deluxe',
        sitdownPrice: 175.0,
        takeawayPrice: 165.0,
      );
      await PosDatabase.instance.updateMenuItem(editedItem);

      final afterEdit = (await PosDatabase.instance.getAllMenuItems()).firstWhere((i) => i.id == itemId);
      expect(afterEdit.name, equals('Blueberry Mint Mojito Deluxe'));
      expect(afterEdit.sitdownPrice, equals(175.0));

      // Disable item (status = 0)
      await PosDatabase.instance.toggleMenuItemStatus(itemId, 0);

      // Verify item is excluded from cart/ordering menu
      final activeAfterItemDisable = await PosDatabase.instance.getMenuItems();
      expect(activeAfterItemDisable.any((i) => i.id == itemId), isFalse);

      // But item remains in all items management list
      final allAfterItemDisable = await PosDatabase.instance.getAllMenuItems();
      expect(allAfterItemDisable.any((i) => i.id == itemId && i.status == 0), isTrue);

      // Re-enable item
      await PosDatabase.instance.toggleMenuItemStatus(itemId, 1);
      final activeAfterItemReEnable = await PosDatabase.instance.getMenuItems();
      expect(activeAfterItemReEnable.any((i) => i.id == itemId), isTrue);

      // Test category disabling cascading to items:
      // If the parent category is disabled, its items MUST be hidden from getMenuItems()
      await PosDatabase.instance.toggleCategoryStatus(targetCat.id, 0);
      final itemsAfterCatDisabled = await PosDatabase.instance.getMenuItems();
      expect(itemsAfterCatDisabled.any((i) => i.id == itemId), isFalse);

      // Restore category status
      await PosDatabase.instance.toggleCategoryStatus(targetCat.id, 1);
      final itemsAfterCatRestored = await PosDatabase.instance.getMenuItems();
      expect(itemsAfterCatRestored.any((i) => i.id == itemId), isTrue);
    });

    test('4. First-time Startup: asks restaurant name and tables, provisions layout & marks completed', () async {
      // Reset setup flag to simulate clean first-time install
      await PosDatabase.instance.resetFirstTimeSetup();

      // Check that setup is required
      final neededInitially = await PosDatabase.instance.isFirstTimeSetupNeeded();
      expect(neededInitially, isTrue);

      // Complete setup with restaurant name and table count
      await PosDatabase.instance.completeFirstTimeSetup(
        restaurantName: 'Bella Bistro Offline',
        numberOfTables: 16,
        phone: '9876543210',
        currency: '₹',
      );

      // Verify setup is no longer required on subsequent startups
      final neededAfter = await PosDatabase.instance.isFirstTimeSetupNeeded();
      expect(neededAfter, isFalse);

      // Verify restaurant table was updated
      final restaurant = await PosDatabase.instance.getRestaurantDetails();
      expect(restaurant.name, equals('Bella Bistro Offline'));
      expect(restaurant.numberOfTables, equals(16));
      expect(restaurant.phone, equals('9876543210'));

      // Verify Dine-In tables floor layout dynamically reflects 16 tables
      final tables = await PosDatabase.instance.getSitDownTables();
      expect(tables.length, equals(16));
      expect(tables.last.tableNumber, equals(16));
    });

    test('5. Business Reports: Calculates total cash, card, upi, food, drinks business and total orders accurately', () async {
      // 1. Fetch Daily Report for today
      final dailyReport = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );

      // Verify non-empty report
      expect(dailyReport.period, equals(ReportPeriod.daily));
      expect(dailyReport.totalOrders, greaterThanOrEqualTo(3));
      expect(dailyReport.totalRevenue, greaterThan(0));

      // Verify payment split
      expect(dailyReport.totalCashBusiness, greaterThan(0));
      expect(dailyReport.totalCardBusiness, greaterThan(0));
      expect(dailyReport.totalUpiBusiness, greaterThan(0));
      expect(
        (dailyReport.totalCashBusiness + dailyReport.totalCardBusiness + dailyReport.totalUpiBusiness),
        closeTo(dailyReport.totalRevenue, 0.01),
      );

      // Verify category breakdown (Food vs Drinks)
      expect(dailyReport.totalFoodBusiness, greaterThan(0));
      expect(dailyReport.totalDrinksBusiness, greaterThan(0));
      expect(
        (dailyReport.totalFoodBusiness + dailyReport.totalDrinksBusiness),
        closeTo(dailyReport.totalNetSales, 0.01),
      );
      expect(
        (dailyReport.totalNetSales + dailyReport.totalTax),
        closeTo(dailyReport.totalRevenue, 0.01),
      );

      // 2. Fetch Weekly Report for this week
      final weeklyReport = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.weekly,
        targetDate: DateTime.now(),
      );

      expect(weeklyReport.period, equals(ReportPeriod.weekly));
      expect(weeklyReport.totalOrders, greaterThanOrEqualTo(dailyReport.totalOrders));
      expect(weeklyReport.totalRevenue, greaterThanOrEqualTo(dailyReport.totalRevenue));

      // 3. Settle Table 2 via UPI QR and verify instant report increment
      final initialOrders = dailyReport.totalOrders;
      final initialUpi = dailyReport.totalUpiBusiness;

      // Table 2 was active in seeded DB
      await PosDatabase.instance.settleAndReleaseTable(2, paymentMethod: 'UPI QR');

      final updatedDailyReport = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );

      expect(updatedDailyReport.totalOrders, equals(initialOrders + 1));
      expect(updatedDailyReport.totalUpiBusiness, greaterThan(initialUpi));
      expect(
        (updatedDailyReport.totalCashBusiness + updatedDailyReport.totalCardBusiness + updatedDailyReport.totalUpiBusiness),
        closeTo(updatedDailyReport.totalRevenue, 0.01),
      );
    });

    test('6. Parcel & Takeaway Pricing: Uses takeawayPrice instead of sitdownPrice for parcels in Cart and SQLite', () async {
      final sampleItem = const MenuItemModel(
        id: 1,
        categoryId: 1,
        categoryName: 'Appetizers',
        name: 'Paneer Tikka',
        sitdownPrice: 240.0,
        takeawayPrice: 230.0,
      );

      // Verify MenuItemModel priceFor helper
      expect(sampleItem.priceFor(isTakeaway: false), equals(240.0));
      expect(sampleItem.priceFor(isTakeaway: true), equals(230.0));

      // Verify CartItemModel defaults to sitdown price when isTakeaway = false
      final dineInCart = CartItemModel(
        item: sampleItem,
        quantity: 2,
        isTakeaway: false,
      );
      expect(dineInCart.unitPrice, equals(240.0));
      expect(dineInCart.totalPrice, equals(480.0));

      // Verify CartItemModel uses takeaway price when isTakeaway = true
      final parcelCart = CartItemModel(
        item: sampleItem,
        quantity: 2,
        isTakeaway: true,
      );
      expect(parcelCart.unitPrice, equals(230.0));
      expect(parcelCart.totalPrice, equals(460.0));

      // Fallback verification: item with takeawayPrice = 0 should fall back to sitdownPrice
      final fallbackItem = const MenuItemModel(
        id: 99,
        categoryId: 1,
        categoryName: 'Appetizers',
        name: 'Special Item',
        sitdownPrice: 150.0,
        takeawayPrice: 0.0,
      );
      final fallbackCart = CartItemModel(
        item: fallbackItem,
        quantity: 1,
        isTakeaway: true,
      );
      expect(fallbackItem.priceFor(isTakeaway: true), equals(150.0));
      expect(fallbackCart.unitPrice, equals(150.0));
      expect(fallbackCart.totalPrice, equals(150.0));

      // Test SQLite createParcelOrder stores takeaway price into order_items_table
      final orderId = await PosDatabase.instance.createParcelOrder(
        customerName: 'Priya Sharma',
        customerPhone: '9845012345',
        cartItems: [parcelCart],
      );
      expect(orderId, greaterThan(0));

      // Verify stored order items
      final orderItems = await PosDatabase.instance.getOrderItems(orderId);
      expect(orderItems.length, equals(1));
      expect(orderItems.first.unitPrice, equals(230.0));
      expect(orderItems.first.totalPrice, equals(460.0));

      // Verify getOpenParcelOrders correctly loads takeaway price and total
      final openParcels = await PosDatabase.instance.getOpenParcelOrders();
      final createdParcel = openParcels.firstWhere((p) => p.customerName == 'Priya Sharma');
      expect(createdParcel.currentTotal, equals(460.0));
      expect(createdParcel.activeCart.first.unitPrice, equals(230.0));
      expect(createdParcel.activeCart.first.totalPrice, equals(460.0));
    });

    test('8. Order Discounts: Amount & percent discount calculation, formula and reports', () async {
      // 1. Test TableModel discount logic
      final sampleItem = const MenuItemModel(
        id: 1,
        categoryId: 1,
        categoryName: 'Appetizers',
        name: 'Paneer Tikka',
        sitdownPrice: 200.0,
        taxRate: 5.0, // 5% tax
      );
      final cart = [
        CartItemModel(item: sampleItem, quantity: 2), // Net = 400.0, Tax = 20.0
      ];

      final table = TableModel(
        id: 5,
        name: 'Table 5',
        tableNumber: 5,
        status: TableOrderStatus.open,
        activeCart: cart,
        currentTotal: 400.0,
        discountAmount: 50.0, // Amount discount = 50.0
      );

      expect(table.netTotal, equals(400.0));
      expect(table.taxTotal, equals(20.0));
      expect(table.effectiveDiscount, equals(50.0));
      // Formula: (Net - Discount) + Tax = (400 - 50) + 20 = 370.0
      expect(table.totalWithTax, equals(370.0));

      // Test discount clamping if discount exceeds net total
      final overDiscountTable = table.copyWith(discountAmount: 500.0);
      expect(overDiscountTable.effectiveDiscount, equals(400.0)); // clamped to 400
      expect(overDiscountTable.totalWithTax, equals(20.0)); // (400 - 400) + 20 = 20

      // 2. Persist order with discount into SQLite
      await PosDatabase.instance.holdSitDownOrder(
        5,
        cart,
        discountAmount: 50.0,
      );

      // Verify getSitDownTables reloads discountAmount
      final tables = await PosDatabase.instance.getSitDownTables();
      final heldTable = tables.firstWhere((t) => t.tableNumber == 5);
      expect(heldTable.discountAmount, equals(50.0));
      expect(heldTable.effectiveDiscount, equals(50.0));
      expect(heldTable.totalWithTax, equals(370.0));

      // 3. Settle table and verify sales report
      await PosDatabase.instance.settleAndReleaseTable(
        5,
        paymentMethod: 'Cash',
        discountAmount: 50.0,
      );

      final report = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: DateTime.now(),
      );

      expect(report.totalDiscount, greaterThanOrEqualTo(50.0));
      final completed = report.completedOrders.firstWhere((o) => o.tableNumber == 5);
      expect(completed.discountAmount, equals(50.0));
      // Formula: net (400) + tax (20) - discount (50) = 370
      expect(completed.totalAmount, equals(370.0));
    });
  });
}

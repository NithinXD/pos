import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pos/database/pos_database.dart';
import 'package:pos/models/menu_item_model.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final dbPath = await getDatabasesPath();
    await databaseFactory.deleteDatabase(p.join(dbPath, 'pos_offline.db'));
  });

  group('Duplicate Orders and Items Prevention Tests', () {
    test('Open existing table, add discount, save discount - table has NO duplicate items', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final item1 = items.firstWhere((i) => i.id == 1); // Paneer Tikka
      final item2 = items.firstWhere((i) => i.id == 2); // Crispy Corn
      final item3 = items.firstWhere((i) => i.id == 3); // Veg Spring Rolls

      // Step 1: Place initial order on Table 7 with 3 items (1 each)
      final initialCart = [
        CartItemModel(item: item1, quantity: 1, existingQuantity: 0),
        CartItemModel(item: item2, quantity: 1, existingQuantity: 0),
        CartItemModel(item: item3, quantity: 1, existingQuantity: 0),
      ];
      await PosDatabase.instance.holdSitDownOrder(7, initialCart);

      var tables = await PosDatabase.instance.getSitDownTables();
      var table7 = tables.firstWhere((t) => t.tableNumber == 7);
      expect(table7.activeCart.length, equals(3));
      expect(table7.itemCount, equals(3));

      // Step 2: Simulate adding discount and saving (even if called concurrently or re-held)
      final cartToSave = table7.activeCart;
      await Future.wait([
        PosDatabase.instance.holdSitDownOrder(7, cartToSave, discountAmount: 50.0),
        PosDatabase.instance.holdSitDownOrder(7, cartToSave, discountAmount: 50.0),
      ]);

      // Step 3: Re-fetch Table 7
      tables = await PosDatabase.instance.getSitDownTables();
      table7 = tables.firstWhere((t) => t.tableNumber == 7);

      // Verify: Table MUST have exactly 3 items, NOT 6 items!
      expect(table7.activeCart.length, equals(3), reason: 'Items must not be duplicated on table');
      expect(table7.itemCount, equals(3));
      expect(table7.discountAmount, equals(50.0));
      expect(table7.activeCart.map((c) => c.item.id).toSet().length, equals(3));
    });

    test('Open existing parcel, add discount, save discount - parcel has NO duplicate items', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final item1 = items.firstWhere((i) => i.id == 7);  // Butter Chicken Masala
      final item2 = items.firstWhere((i) => i.id == 12); // Chicken Dum Biryani
      final item3 = items.firstWhere((i) => i.id == 9);  // Butter Naan

      // Step 1: Create takeaway parcel for 'aaaa' with 3 distinct items
      final initialCart = [
        CartItemModel(item: item1, quantity: 1, isTakeaway: true),
        CartItemModel(item: item2, quantity: 1, isTakeaway: true),
        CartItemModel(item: item3, quantity: 4, isTakeaway: true),
      ];
      final orderId = await PosDatabase.instance.createParcelOrder(
        customerName: 'aaaa',
        customerPhone: '12345678',
        cartItems: initialCart,
      );

      var parcels = await PosDatabase.instance.getOpenParcelOrders();
      var parcel = parcels.firstWhere((p) => p.id == orderId);
      expect(parcel.activeCart.length, equals(3));
      expect(parcel.itemCount, equals(6)); // 1 + 1 + 4 = 6

      // Step 2: Add discount ₹72 and update parcel order concurrently
      final cartToSave = parcel.activeCart;
      await Future.wait([
        PosDatabase.instance.updateParcelOrder(orderId, cartToSave, discountAmount: 72.0),
        PosDatabase.instance.updateParcelOrder(orderId, cartToSave, discountAmount: 72.0),
      ]);

      // Step 3: Re-fetch parcel orders
      parcels = await PosDatabase.instance.getOpenParcelOrders();
      parcel = parcels.firstWhere((p) => p.id == orderId);

      // Verify: Parcel MUST have exactly 3 items and 6 total quantity, NOT 12!
      expect(parcel.activeCart.length, equals(3), reason: 'Items must not be duplicated on parcel');
      expect(parcel.itemCount, equals(6), reason: 'Total food item quantity must remain 6');
      expect(parcel.discountAmount, equals(72.0));
    });

    test('Self-healing: Consolidates duplicate rows if database already contains duplicate lines', () async {
      final db = await PosDatabase.instance.database;
      final now = DateTime.now().toIso8601String();

      // Create an order directly
      final orderId = await db.insert('order_table', {
        'customer_id': 1,
        'customer_phone': '9999999999',
        'table_number': 0,
        'order_type': 'takeaway',
        'order_payment_type': 'cash',
        'order_payment_status': 'unpaid',
        'order_status': 'active',
        'order_discount_amount': 0.0,
        'order_tax': 10.0,
        'order_deliver_status': 'na',
        'order_date': now,
        'order_delivery_charge': 0.0,
        'order_comments': '',
        'order_cash_amount': 0.0,
        'order_card_amount': 0.0,
        'order_print_status': 'printed',
      });

      // Insert duplicate rows for item_id 1 (e.g. 1x and 1x)
      await db.insert('order_items_table', {
        'order_id': orderId,
        'item_id': 1,
        'item_name': 'Paneer Tikka',
        'item_price': 240.0,
        'item_quantity': 1,
        'item_tax_rate': 5.0,
        'item_type': 'veg',
        'item_kitchen_type': 'hot_kitchen',
        'item_printer_id': 'printer_main',
        'item_status': 'ordered',
        'added_at': now,
      });
      await db.insert('order_items_table', {
        'order_id': orderId,
        'item_id': 1,
        'item_name': 'Paneer Tikka',
        'item_price': 240.0,
        'item_quantity': 1,
        'item_tax_rate': 5.0,
        'item_type': 'veg',
        'item_kitchen_type': 'hot_kitchen',
        'item_printer_id': 'printer_main',
        'item_status': 'ordered',
        'added_at': now,
      });

      // Fetch via getOpenParcelOrders
      final parcels = await PosDatabase.instance.getOpenParcelOrders();
      final parcel = parcels.firstWhere((p) => p.id == orderId);

      // Verify: Consolidated into 1 item with quantity 2
      expect(parcel.activeCart.length, equals(1));
      expect(parcel.activeCart.first.quantity, equals(2));
      expect(parcel.activeCart.first.item.id, equals(1));

      // Fetch via getOrderItems
      final items = await PosDatabase.instance.getOrderItems(orderId);
      expect(items.length, equals(1));
      expect(items.first.quantity, equals(2));
    });

    test('Creating a parcel with discount creates exactly ONE parcel', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final biryani = items.firstWhere((i) => i.id == 12);

      final initialCart = [
        CartItemModel(item: biryani, quantity: 2, isTakeaway: true),
      ];

      final orderId = await PosDatabase.instance.createParcelOrder(
        customerName: 'Single Parcel Test',
        customerPhone: '5555555555',
        cartItems: initialCart,
        discountAmount: 25.0,
      );

      final parcels = await PosDatabase.instance.getOpenParcelOrders();
      final matching = parcels.where((p) => p.customerName == 'Single Parcel Test').toList();

      expect(matching.length, equals(1), reason: 'Must create exactly one parcel');
      expect(matching.first.id, equals(orderId));
      expect(matching.first.discountAmount, equals(25.0));
    });

    test('Table discount update and remove workflow per Sam Biswas', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final item1 = items.firstWhere((i) => i.id == 1);

      // Step 1: Open table 9, add items, hold order
      final initialCart = [
        CartItemModel(item: item1, quantity: 2, existingQuantity: 0),
      ];
      final orderId = await PosDatabase.instance.holdSitDownOrder(9, initialCart);

      var tables = await PosDatabase.instance.getSitDownTables();
      var table9 = tables.firstWhere((t) => t.tableNumber == 9);
      expect(table9.discountAmount, equals(0.0));
      expect(table9.activeOrderId, equals(orderId));

      // Step 2: Add discount ₹50 and save discount
      await PosDatabase.instance.holdSitDownOrder(
        9,
        table9.activeCart,
        discountAmount: 50.0,
        activeOrderId: table9.activeOrderId,
      );

      tables = await PosDatabase.instance.getSitDownTables();
      table9 = tables.firstWhere((t) => t.tableNumber == 9);
      expect(table9.discountAmount, equals(50.0), reason: 'Discount must be updated to 50.0');

      // Step 3: Change discount amount to ₹30 and save discount
      await PosDatabase.instance.holdSitDownOrder(
        9,
        table9.activeCart,
        discountAmount: 30.0,
        activeOrderId: table9.activeOrderId,
      );

      tables = await PosDatabase.instance.getSitDownTables();
      table9 = tables.firstWhere((t) => t.tableNumber == 9);
      expect(table9.discountAmount, equals(30.0), reason: 'Discount must be updated to 30.0');

      // Step 4: Remove discount (discountAmount = 0.0)
      await PosDatabase.instance.holdSitDownOrder(
        9,
        table9.activeCart,
        discountAmount: 0.0,
        activeOrderId: table9.activeOrderId,
      );

      tables = await PosDatabase.instance.getSitDownTables();
      table9 = tables.firstWhere((t) => t.tableNumber == 9);
      expect(table9.discountAmount, equals(0.0), reason: 'Discount must be removed back to 0.0');
    });

    test('Parcel discount update and remove workflow', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final item1 = items.firstWhere((i) => i.id == 2);

      // Step 1: Create parcel
      final cart = [CartItemModel(item: item1, quantity: 1, isTakeaway: true)];
      final parcelId = await PosDatabase.instance.createParcelOrder(
        customerName: 'Discount Parcel Test',
        customerPhone: '1111111111',
        cartItems: cart,
        discountAmount: 40.0,
      );

      var parcels = await PosDatabase.instance.getOpenParcelOrders();
      var parcel = parcels.firstWhere((p) => p.id == parcelId);
      expect(parcel.discountAmount, equals(40.0));

      // Step 2: Change discount to ₹15
      await PosDatabase.instance.updateParcelOrder(
        parcelId,
        parcel.activeCart,
        discountAmount: 15.0,
      );

      parcels = await PosDatabase.instance.getOpenParcelOrders();
      parcel = parcels.firstWhere((p) => p.id == parcelId);
      expect(parcel.discountAmount, equals(15.0));

      // Step 3: Remove discount
      await PosDatabase.instance.updateParcelOrder(
        parcelId,
        parcel.activeCart,
        discountAmount: 0.0,
      );

      parcels = await PosDatabase.instance.getOpenParcelOrders();
      parcel = parcels.firstWhere((p) => p.id == parcelId);
      expect(parcel.discountAmount, equals(0.0), reason: 'Parcel discount must be removed back to 0.0');
    });

    test('Sam Biswas bug test: Re-open table, apply discount (0 new items) -> no duplicates, then add new items -> items added properly', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final item1 = items.firstWhere((i) => i.id == 1); // Paneer Tikka
      final item2 = items.firstWhere((i) => i.id == 2); // Crispy Corn
      final item3 = items.firstWhere((i) => i.id == 3); // Veg Spring Rolls

      // Step 1: Open new table (Table 4), add items, hold and print KOT
      final initialCart = [
        CartItemModel(item: item1, quantity: 1, existingQuantity: 0),
        CartItemModel(item: item2, quantity: 2, existingQuantity: 0),
      ];
      final orderId = await PosDatabase.instance.holdSitDownOrder(4, initialCart);

      var tables = await PosDatabase.instance.getSitDownTables();
      var table4 = tables.firstWhere((t) => t.tableNumber == 4);
      expect(table4.activeCart.length, equals(2));
      expect(table4.itemCount, equals(3)); // 1 + 2 = 3
      expect(table4.discountAmount, equals(0.0));

      // Step 2: Re-open table, apply discount and save table (newItemsCount == 0)
      // Per Sam Biswas: if(number of new items == 0) { calculateDiscount; updateDiscount() }
      await PosDatabase.instance.updateOrderDiscountAndMeta(
        orderId: orderId,
        discountAmount: 60.0,
      );

      tables = await PosDatabase.instance.getSitDownTables();
      table4 = tables.firstWhere((t) => t.tableNumber == 4);

      // Verify: Problem 1 resolved - NO DUPLICATE ITEMS
      expect(table4.activeCart.length, equals(2), reason: 'Table must NOT duplicate items on discount save');
      expect(table4.itemCount, equals(3), reason: 'Item count must remain 3');
      expect(table4.discountAmount, equals(60.0), reason: 'Discount must be updated to 60.0');

      // Step 3: Re-open table, ADD NEW ITEMS to that table which has discount
      // Per Sam Biswas: if(number of new items > 0) { add new items to order item table; calculateDiscount(); updateDiscount(); PrintNewItems() }
      final newItemsToAdd = [
        CartItemModel(item: item1, quantity: 2, existingQuantity: 1), // 1 more Paneer Tikka (newQuantity = 1)
        CartItemModel(item: item3, quantity: 1, existingQuantity: 0), // 1 new Spring Roll (newQuantity = 1)
      ];

      await PosDatabase.instance.addNewItemsToSitDownOrder(
        orderId: orderId,
        tableNumber: 4,
        newItems: newItemsToAdd,
        discountAmount: table4.discountAmount,
      );

      tables = await PosDatabase.instance.getSitDownTables();
      table4 = tables.firstWhere((t) => t.tableNumber == 4);

      // Verify: Problem 2 resolved - Can add new items to table with discount
      expect(table4.activeCart.length, equals(3), reason: 'Table now has 3 distinct dishes');
      final paneerTikka = table4.activeCart.firstWhere((c) => c.item.id == item1.id);
      final crispyCorn = table4.activeCart.firstWhere((c) => c.item.id == item2.id);
      final springRoll = table4.activeCart.firstWhere((c) => c.item.id == item3.id);

      expect(paneerTikka.quantity, equals(2), reason: 'Paneer Tikka updated from 1 to 2');
      expect(crispyCorn.quantity, equals(2), reason: 'Crispy Corn remained 2');
      expect(springRoll.quantity, equals(1), reason: 'Veg Spring Roll added with quantity 1');
      expect(table4.itemCount, equals(5), reason: 'Total item count must be 5 (2 + 2 + 1)');
      expect(table4.discountAmount, equals(60.0), reason: 'Discount remains 60.0');
    });

    test('Open table popup, edit discount and save updates order_discount field in SQLite order_table', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final item1 = items.firstWhere((i) => i.id == 1); // Paneer Tikka
      final item2 = items.firstWhere((i) => i.id == 2); // Crispy Corn

      // Step 1: Open Table 5 with items
      final cart = [
        CartItemModel(item: item1, quantity: 2, existingQuantity: 0),
        CartItemModel(item: item2, quantity: 1, existingQuantity: 0),
      ];
      final orderId = await PosDatabase.instance.holdSitDownOrder(5, cart);

      // Verify initial discount is 0 in order_table
      final db = await PosDatabase.instance.database;
      var rows = await db.query('order_table', where: 'order_id = ?', whereArgs: [orderId]);
      expect(rows.first['order_discount'], equals(0.0));
      expect(rows.first['order_discount_amount'], equals(0.0));

      // Step 2: User clicks edit discount in open table popup and saves ₹85.0 discount
      await PosDatabase.instance.updateSitDownTableDiscount(
        tableNumber: 5,
        discountAmount: 85.0,
      );

      // Verify order_discount field is updated in SQLite order_table!
      rows = await db.query('order_table', where: 'order_id = ?', whereArgs: [orderId]);
      expect(rows.first['order_discount'], equals(85.0), reason: 'order_discount column in SQLite must be 85.0');
      expect(rows.first['order_discount_amount'], equals(85.0), reason: 'order_discount_amount in SQLite must be 85.0');

      // Re-fetch tables to confirm TableModel reflects the updated discount
      var tables = await PosDatabase.instance.getSitDownTables();
      var table5 = tables.firstWhere((t) => t.tableNumber == 5);
      expect(table5.discountAmount, equals(85.0));
      expect(table5.activeCart.length, equals(2), reason: 'Items must not be duplicated');

      // Step 3: Change discount to ₹30.0 and save
      await PosDatabase.instance.updateOrderDiscountAndMeta(
        orderId: orderId,
        discountAmount: 30.0,
      );
      rows = await db.query('order_table', where: 'order_id = ?', whereArgs: [orderId]);
      expect(rows.first['order_discount'], equals(30.0), reason: 'order_discount must update to 30.0');

      // Step 4: Remove/clear discount (0.0) and save
      await PosDatabase.instance.updateOrderDiscountAndMeta(
        orderId: orderId,
        discountAmount: 0.0,
      );
      rows = await db.query('order_table', where: 'order_id = ?', whereArgs: [orderId]);
      expect(rows.first['order_discount'], equals(0.0), reason: 'order_discount must update to 0.0');
    });

    test('Sam Biswas: 3 discount fields (order_discount, order_discount_amount, order_discount_percent) and mutual exclusivity', () async {
      final items = await PosDatabase.instance.getMenuItems();
      final item1 = items.firstWhere((i) => i.id == 1); // Paneer Tikka (220)
      final item2 = items.firstWhere((i) => i.id == 2); // Crispy Corn (180)

      // Step 1: Open Table 8 with items (Total = 220 + 180 = 400)
      final cart = [
        CartItemModel(item: item1, quantity: 1, existingQuantity: 0),
        CartItemModel(item: item2, quantity: 1, existingQuantity: 0),
      ];
      final orderId = await PosDatabase.instance.holdSitDownOrder(8, cart);

      final db = await PosDatabase.instance.database;

      // Test calculateDiscount function directly
      final calcAmt = PosDatabase.instance.calculateDiscount(
        netTotal: 400.0,
        isPercent: false,
        discountAmount: 50.0,
      );
      expect(calcAmt, equals(50.0));

      final calcPct = PosDatabase.instance.calculateDiscount(
        netTotal: 400.0,
        isPercent: true,
        percentValue: 10.0,
      );
      expect(calcPct, equals(40.0)); // 10% of 400 = 40

      // Case A: User clicks Discount Amount (₹50)
      // "so when the user click Discount Amount, it updates two fields order_discount and order_discount_amount"
      await PosDatabase.instance.updateDiscount(
        orderId: orderId,
        isPercent: false,
        discountAmount: 50.0,
      );

      var rows = await db.query('order_table', where: 'order_id = ?', whereArgs: [orderId]);
      expect(rows.first['order_discount'], equals(50.0));
      expect(rows.first['order_discount_amount'], equals(50.0));
      expect(rows.first['order_discount_percent'], equals(0.0));
      // Rule: "for all orders both order_discount_amount and order_discount_percent cannot be non zero."
      expect(
        rows.first['order_discount_amount'] == 0.0 || rows.first['order_discount_percent'] == 0.0,
        isTrue,
        reason: 'Both order_discount_amount and order_discount_percent cannot be non-zero simultaneously',
      );

      // Verify reopening table shows order_discount
      var tables = await PosDatabase.instance.getSitDownTables();
      var table8 = tables.firstWhere((t) => t.tableNumber == 8);
      expect(table8.discountAmount, equals(50.0));
      expect(table8.isDiscountPercent, isFalse);

      // Case B: User clicks Discount Percent (15%)
      // "when user clicks Discount Percent, it calculates total discount from order items and update order_discount_percent and and order_discount."
      await PosDatabase.instance.updateDiscount(
        orderId: orderId,
        isPercent: true,
        percentValue: 15.0,
      );

      rows = await db.query('order_table', where: 'order_id = ?', whereArgs: [orderId]);
      final expected15Pct = (item1.sitdownPrice + item2.sitdownPrice) * 0.15;
      expect(rows.first['order_discount'], equals(expected15Pct), reason: 'order_discount must be 15% of order items');
      expect(rows.first['order_discount_amount'], equals(0.0), reason: 'order_discount_amount must be 0.0 for percent discount');
      expect(rows.first['order_discount_percent'], equals(15.0), reason: 'order_discount_percent must be 15.0');
      // Rule: "for all orders both order_discount_amount and order_discount_percent cannot be non zero."
      expect(
        rows.first['order_discount_amount'] == 0.0 || rows.first['order_discount_percent'] == 0.0,
        isTrue,
        reason: 'Both order_discount_amount and order_discount_percent cannot be non-zero simultaneously',
      );

      // Verify reopening table: shows order_discount and discountPercent
      tables = await PosDatabase.instance.getSitDownTables();
      table8 = tables.firstWhere((t) => t.tableNumber == 8);
      expect(table8.discountAmount, equals(expected15Pct), reason: 'Now when we reopen the table, it shows order_discount');
      expect(table8.discountPercent, equals(15.0));
      expect(table8.isDiscountPercent, isTrue);

      // Case C: Add new items to table with 15% discount
      final newItemsToAdd = [
        CartItemModel(item: item1, quantity: 2, existingQuantity: 1),
      ];
      await PosDatabase.instance.addNewItemsToSitDownOrder(
        orderId: orderId,
        tableNumber: 8,
        newItems: newItemsToAdd,
        discountAmount: table8.discountAmount,
      );

      final newExpected15Pct = ((item1.sitdownPrice * 2) + item2.sitdownPrice) * 0.15;
      rows = await db.query('order_table', where: 'order_id = ?', whereArgs: [orderId]);
      expect(rows.first['order_discount'], equals(newExpected15Pct), reason: 'Discount recalculated to 15% of new total');
      expect(rows.first['order_discount_amount'], equals(0.0));
      expect(rows.first['order_discount_percent'], equals(15.0));
    });
  });
}

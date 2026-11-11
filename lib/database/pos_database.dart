import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import '../models/table_model.dart';
import '../models/menu_item_model.dart';
import '../models/restaurant_model.dart';
import '../models/category_model.dart';
import '../models/report_model.dart';
import '../models/delivery_zone_model.dart';

class PosDatabase {
  static final PosDatabase instance = PosDatabase._init();
  static Database? _database;

  PosDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onOpen: (db) async {
        // Enforce SQLite WAL mode and foreign keys per architecture plan
        // PRAGMA journal_mode returns a result row, so Android sqflite requires rawQuery
        await db.rawQuery('PRAGMA journal_mode = WAL;');
        await db.execute('PRAGMA synchronous = NORMAL;');
        await db.execute('PRAGMA foreign_keys = ON;');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          );
        ''');

        // Check if restaurant_gstn and print_kot columns exist in restaurant_table
        final restTableInfo = await db.rawQuery("PRAGMA table_info(restaurant_table);");
        final hasGstn = restTableInfo.any((col) => col['name'] == 'restaurant_gstn');
        if (!hasGstn && restTableInfo.isNotEmpty) {
          await db.execute("ALTER TABLE restaurant_table ADD COLUMN restaurant_gstn TEXT NOT NULL DEFAULT '';");
        }
        final hasPrintKot = restTableInfo.any((col) => col['name'] == 'print_kot' || col['name'] == 'print_KOT');
        if (!hasPrintKot && restTableInfo.isNotEmpty) {
          await db.execute("ALTER TABLE restaurant_table ADD COLUMN print_kot INTEGER NOT NULL DEFAULT 0;");
        }

        // Check if order columns exist in order_table, if not, add them
        final orderTableInfo = await db.rawQuery("PRAGMA table_info(order_table);");
        final hasOrderTax = orderTableInfo.any((col) => col['name'] == 'order_tax');
        if (!hasOrderTax && orderTableInfo.isNotEmpty) {
          await db.execute('ALTER TABLE order_table ADD COLUMN order_tax REAL NOT NULL DEFAULT 0.0;');
        }
        final hasOrderDiscount = orderTableInfo.any((col) => col['name'] == 'order_discount');
        if (!hasOrderDiscount && orderTableInfo.isNotEmpty) {
          await db.execute('ALTER TABLE order_table ADD COLUMN order_discount REAL NOT NULL DEFAULT 0.0;');
        }
        final hasOrderDiscountPercent = orderTableInfo.any((col) => col['name'] == 'order_discount_percent');
        if (!hasOrderDiscountPercent && orderTableInfo.isNotEmpty) {
          await db.execute('ALTER TABLE order_table ADD COLUMN order_discount_percent REAL NOT NULL DEFAULT 0.0;');
        }
        final hasOrderDscountPercent = orderTableInfo.any((col) => col['name'] == 'order_dscount_percent');
        if (!hasOrderDscountPercent && orderTableInfo.isNotEmpty) {
          await db.execute('ALTER TABLE order_table ADD COLUMN order_dscount_percent REAL NOT NULL DEFAULT 0.0;');
        }
        final hasOrderDriverId = orderTableInfo.any((col) => col['name'] == 'order_driver_id');
        if (!hasOrderDriverId && orderTableInfo.isNotEmpty) {
          await db.execute('ALTER TABLE order_table ADD COLUMN order_driver_id TEXT;');
        }
        final hasOrderDelChg = orderTableInfo.any((col) => col['name'] == 'order_delivery_charge');
        if (!hasOrderDelChg && orderTableInfo.isNotEmpty) {
          await db.execute('ALTER TABLE order_table ADD COLUMN order_delivery_charge REAL NOT NULL DEFAULT 0.0;');
        }
        final hasOrderComments = orderTableInfo.any((col) => col['name'] == 'order_comments');
        if (!hasOrderComments && orderTableInfo.isNotEmpty) {
          await db.execute('ALTER TABLE order_table ADD COLUMN order_comments TEXT;');
        }

        // Delivery zones table migration & seeding
        await db.execute('''
          CREATE TABLE IF NOT EXISTS delivery_zones (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            delivery_area TEXT NOT NULL,
            delivery_charge REAL NOT NULL DEFAULT 0.0 CHECK (delivery_charge >= 0.0)
          );
        ''');
        final zoneCountRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM delivery_zones;');
        final zoneCount = (zoneCountRes.isNotEmpty ? zoneCountRes.first['cnt'] as int? : 0) ?? 0;
        if (zoneCount == 0) {
          await db.insert('delivery_zones', {'delivery_area': 'Area 1', 'delivery_charge': 20.0});
          await db.insert('delivery_zones', {'delivery_area': 'Area 2', 'delivery_charge': 25.0});
          await db.insert('delivery_zones', {'delivery_area': 'Area 3', 'delivery_charge': 30.0});
          await db.insert('delivery_zones', {'delivery_area': 'Area 4', 'delivery_charge': 40.0});
          await db.insert('delivery_zones', {'delivery_area': 'Area 5', 'delivery_charge': 50.0});
        }

        // Backfill order_tax for any completed orders with order_tax = 0.0
        try {
          await db.execute('''
            UPDATE order_table
            SET order_tax = (
              SELECT COALESCE(SUM(oi.item_price * oi.item_quantity * (oi.item_tax_rate / 100.0)), 0.0)
              FROM order_items_table oi
              WHERE oi.order_id = order_table.order_id
            )
            WHERE order_tax = 0.0;
          ''');
        } catch (_) {}
      },
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. RESTAURANT TABLE
    await db.execute('''
      CREATE TABLE restaurant_table (
        restaurant_id INTEGER PRIMARY KEY CHECK (restaurant_id = 1),
        restaurant_name TEXT NOT NULL,
        restaurant_phone TEXT NOT NULL,
        restaurant_address TEXT NOT NULL,
        restaurant_status TEXT NOT NULL DEFAULT 'active' CHECK (restaurant_status IN ('active', 'open', 'closed')),
        restaurant_currency TEXT NOT NULL DEFAULT '₹',
        number_of_tables INTEGER NOT NULL DEFAULT 10 CHECK (number_of_tables > 0),
        restaurant_gstn TEXT NOT NULL DEFAULT '',
        print_kot INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    // 2. CUSTOMER TABLE
    await db.execute('''
      CREATE TABLE customer_table (
        customer_id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_name TEXT NOT NULL,
        customer_phone_number TEXT NOT NULL,
        customer_address TEXT NOT NULL,
        customer_area TEXT NOT NULL,
        is_table_record INTEGER NOT NULL DEFAULT 0 CHECK (is_table_record IN (0, 1)),
        created_at TEXT NOT NULL
      );
    ''');

    // 3. CATEGORY TABLE
    await db.execute('''
      CREATE TABLE category_table (
        category_id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_name TEXT NOT NULL UNIQUE,
        category_position INTEGER NOT NULL DEFAULT 0,
        category_colour TEXT NOT NULL DEFAULT '#4CAF50',
        category_type TEXT NOT NULL DEFAULT 'food' CHECK (category_type IN ('food', 'drinks', 'desserts', 'retail')),
        category_status INTEGER NOT NULL DEFAULT 1 CHECK (category_status IN (0, 1))
      );
    ''');

    // 4. ITEM TABLE
    await db.execute('''
      CREATE TABLE item_table (
        item_id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        item_sitdown_price REAL NOT NULL DEFAULT 0.0 CHECK (item_sitdown_price >= 0.0),
        item_takeaway_price REAL NOT NULL DEFAULT 0.0 CHECK (item_takeaway_price >= 0.0),
        item_delivery_price REAL NOT NULL DEFAULT 0.0 CHECK (item_delivery_price >= 0.0),
        item_quantity INTEGER NOT NULL DEFAULT 100 CHECK (item_quantity >= 0),
        item_type TEXT NOT NULL DEFAULT 'veg' CHECK (item_type IN ('veg', 'non-veg', 'vegan', 'beverage')),
        item_kitchen_type TEXT NOT NULL DEFAULT 'hot_kitchen' CHECK (item_kitchen_type IN ('hot_kitchen', 'bar', 'cold_kitchen', 'bakery')),
        item_tax_rate REAL NOT NULL DEFAULT 5.0 CHECK (item_tax_rate >= 0.0),
        item_status INTEGER NOT NULL DEFAULT 1 CHECK (item_status IN (0, 1)),
        FOREIGN KEY (category_id) REFERENCES category_table (category_id) ON DELETE RESTRICT
      );
    ''');

    // 5. ORDER TABLE
    await db.execute('''
      CREATE TABLE order_table (
        order_id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        customer_phone TEXT NOT NULL,
        table_number INTEGER NOT NULL DEFAULT 0,
        order_type TEXT NOT NULL DEFAULT 'sitdown' CHECK (order_type IN ('sitdown', 'takeaway', 'delivery')),
        order_payment_type TEXT NOT NULL DEFAULT 'cash' CHECK (order_payment_type IN ('cash', 'card', 'split', 'upi_qr', 'unpaid')),
        order_payment_status TEXT NOT NULL DEFAULT 'unpaid' CHECK (order_payment_status IN ('unpaid', 'paid', 'partially_paid', 'refunded')),
        order_status TEXT NOT NULL DEFAULT 'active' CHECK (order_status IN ('active', 'preparing', 'completed', 'cancelled')),
        order_discount_amount REAL NOT NULL DEFAULT 0.0 CHECK (order_discount_amount >= 0.0),
        order_discount REAL NOT NULL DEFAULT 0.0 CHECK (order_discount >= 0.0),
        order_discount_percent REAL NOT NULL DEFAULT 0.0 CHECK (order_discount_percent >= 0.0),
        order_dscount_percent REAL NOT NULL DEFAULT 0.0 CHECK (order_dscount_percent >= 0.0),
        order_tax REAL NOT NULL DEFAULT 0.0 CHECK (order_tax >= 0.0),
        order_deliver_status TEXT NOT NULL DEFAULT 'na' CHECK (order_deliver_status IN ('na', 'pending', 'out_for_delivery', 'delivered')),
        order_date TEXT NOT NULL,
        order_driver_id TEXT,
        order_delivery_charge REAL NOT NULL DEFAULT 0.0 CHECK (order_delivery_charge >= 0.0),
        order_comments TEXT,
        order_cash_amount REAL NOT NULL DEFAULT 0.0 CHECK (order_cash_amount >= 0.0),
        order_card_amount REAL NOT NULL DEFAULT 0.0 CHECK (order_card_amount >= 0.0),
        order_print_status TEXT NOT NULL DEFAULT 'not_printed' CHECK (order_print_status IN ('not_printed', 'printed', 'reprinted')),
        settled_at TEXT,
        FOREIGN KEY (customer_id) REFERENCES customer_table (customer_id) ON DELETE RESTRICT
      );
    ''');

    // 6. DELIVERY ZONES TABLE
    await db.execute('''
      CREATE TABLE delivery_zones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        delivery_area TEXT NOT NULL,
        delivery_charge REAL NOT NULL DEFAULT 0.0 CHECK (delivery_charge >= 0.0)
      );
    ''');

    // 6. ORDER ITEMS TABLE
    await db.execute('''
      CREATE TABLE order_items_table (
        order_item_id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        item_price REAL NOT NULL CHECK (item_price >= 0.0),
        item_quantity INTEGER NOT NULL DEFAULT 1 CHECK (item_quantity > 0),
        item_discount_amount REAL NOT NULL DEFAULT 0.0 CHECK (item_discount_amount >= 0.0),
        item_tax_rate REAL NOT NULL DEFAULT 5.0 CHECK (item_tax_rate >= 0.0),
        item_type TEXT NOT NULL DEFAULT 'veg' CHECK (item_type IN ('veg', 'non-veg', 'vegan', 'beverage')),
        item_kitchen_type TEXT NOT NULL DEFAULT 'hot_kitchen' CHECK (item_kitchen_type IN ('hot_kitchen', 'bar', 'cold_kitchen', 'bakery')),
        item_printer_id TEXT DEFAULT 'printer_main',
        item_status TEXT NOT NULL DEFAULT 'ordered' CHECK (item_status IN ('ordered', 'preparing', 'served')),
        added_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES order_table (order_id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES item_table (item_id) ON DELETE RESTRICT
      );
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_orders_table_active ON order_table (table_number, order_status);');
    await db.execute('CREATE INDEX idx_order_items_order_id ON order_items_table (order_id);');
    await db.execute('CREATE INDEX idx_item_category_pos ON item_table (category_id, item_status);');
    await db.execute('CREATE INDEX idx_customer_phone ON customer_table (customer_phone_number);');
    await db.execute('CREATE INDEX idx_order_date ON order_table (order_date DESC);');

    // Seed Initial Restaurant, Customers, Menu & Sample Orders
    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();

    // 1. Restaurant
    await db.insert('restaurant_table', {
      'restaurant_id': 1,
      'restaurant_name': 'Sam POS Restaurant',
      'restaurant_phone': '9845012345',
      'restaurant_address': 'Main High Street, Food Court',
      'restaurant_status': 'active',
      'restaurant_currency': '₹',
      'number_of_tables': 10,
      'created_at': now,
      'updated_at': now,
    });

    // 2. Pre-seeded Virtual Customers for 10 Tables
    for (int i = 1; i <= 10; i++) {
      await db.insert('customer_table', {
        'customer_name': 'Table $i',
        'customer_phone_number': '100000000$i',
        'customer_address': 'Dine-In Area',
        'customer_area': 'Main Dining Hall',
        'is_table_record': 1,
        'created_at': now,
      });
    }

    // 3. Categories
    final categories = [
      {'name': 'Appetizers', 'pos': 1, 'color': '#FF7043', 'type': 'food'},
      {'name': 'Main Course', 'pos': 2, 'color': '#26A69A', 'type': 'food'},
      {'name': 'Breads & Rice', 'pos': 3, 'color': '#AB47BC', 'type': 'food'},
      {'name': 'Beverages', 'pos': 4, 'color': '#42A5F5', 'type': 'drinks'},
      {'name': 'Desserts', 'pos': 5, 'color': '#EC407A', 'type': 'desserts'},
    ];

    final catIdMap = <String, int>{};
    for (var c in categories) {
      final id = await db.insert('category_table', {
        'category_name': c['name'],
        'category_position': c['pos'],
        'category_colour': c['color'],
        'category_type': c['type'],
        'category_status': 1,
      });
      catIdMap[c['name'] as String] = id;
    }

    // 4. Menu Items
    final items = [
      // Appetizers
      {'cat': 'Appetizers', 'name': 'Paneer Tikka', 'sd': 240.0, 'ta': 230.0, 'type': 'veg', 'kt': 'hot_kitchen'},
      {'cat': 'Appetizers', 'name': 'Crispy Corn Salt & Pepper', 'sd': 180.0, 'ta': 170.0, 'type': 'veg', 'kt': 'hot_kitchen'},
      {'cat': 'Appetizers', 'name': 'Chicken Malai Tikka', 'sd': 320.0, 'ta': 300.0, 'type': 'non-veg', 'kt': 'hot_kitchen'},
      {'cat': 'Appetizers', 'name': 'Veg Spring Rolls (6 pcs)', 'sd': 190.0, 'ta': 180.0, 'type': 'veg', 'kt': 'hot_kitchen'},
      // Main Course
      {'cat': 'Main Course', 'name': 'Paneer Butter Masala', 'sd': 280.0, 'ta': 270.0, 'type': 'veg', 'kt': 'hot_kitchen'},
      {'cat': 'Main Course', 'name': 'Dal Makhani Slow-Cooked', 'sd': 220.0, 'ta': 210.0, 'type': 'veg', 'kt': 'hot_kitchen'},
      {'cat': 'Main Course', 'name': 'Butter Chicken Masala', 'sd': 360.0, 'ta': 350.0, 'type': 'non-veg', 'kt': 'hot_kitchen'},
      {'cat': 'Main Course', 'name': 'Kadhai Paneer Special', 'sd': 270.0, 'ta': 260.0, 'type': 'veg', 'kt': 'hot_kitchen'},
      // Breads & Rice
      {'cat': 'Breads & Rice', 'name': 'Butter Naan', 'sd': 45.0, 'ta': 45.0, 'type': 'veg', 'kt': 'hot_kitchen'},
      {'cat': 'Breads & Rice', 'name': 'Garlic Roti', 'sd': 40.0, 'ta': 40.0, 'type': 'veg', 'kt': 'hot_kitchen'},
      {'cat': 'Breads & Rice', 'name': 'Jeera Rice with Ghee', 'sd': 150.0, 'ta': 140.0, 'type': 'veg', 'kt': 'hot_kitchen'},
      {'cat': 'Breads & Rice', 'name': 'Chicken Dum Biryani', 'sd': 310.0, 'ta': 300.0, 'type': 'non-veg', 'kt': 'hot_kitchen'},
      // Beverages
      {'cat': 'Beverages', 'name': 'Fresh Lime Soda (Sweet/Salt)', 'sd': 80.0, 'ta': 80.0, 'type': 'beverage', 'kt': 'bar'},
      {'cat': 'Beverages', 'name': 'Mango Lassi Thick', 'sd': 110.0, 'ta': 110.0, 'type': 'beverage', 'kt': 'bar'},
      {'cat': 'Beverages', 'name': 'Masala Chai Pot', 'sd': 40.0, 'ta': 40.0, 'type': 'beverage', 'kt': 'bar'},
      // Desserts
      {'cat': 'Desserts', 'name': 'Warm Gulab Jamun (2 pcs)', 'sd': 90.0, 'ta': 90.0, 'type': 'veg', 'kt': 'cold_kitchen'},
      {'cat': 'Desserts', 'name': 'Saffron Rasmalai (2 pcs)', 'sd': 130.0, 'ta': 130.0, 'type': 'veg', 'kt': 'cold_kitchen'},
    ];

    final itemIdMap = <String, int>{};
    for (var it in items) {
      final id = await db.insert('item_table', {
        'category_id': catIdMap[it['cat']] ?? 1,
        'item_name': it['name'],
        'item_sitdown_price': it['sd'],
        'item_takeaway_price': it['ta'],
        'item_delivery_price': (it['sd'] as double) + 20.0,
        'item_quantity': 100,
        'item_type': it['type'],
        'item_kitchen_type': it['kt'],
        'item_tax_rate': 5.0,
        'item_status': 1,
      });
      itemIdMap[it['name'] as String] = id;
    }

    // 5. Seed Open Dine-In Orders for Table 2, Table 5, Table 8
    // Table 2
    await _seedDineInOrder(db, tableNumber: 2, customerPhone: '1000000002', lines: [
      {'item_id': itemIdMap['Paneer Tikka']!, 'name': 'Paneer Tikka', 'price': 240.0, 'qty': 2, 'type': 'veg'},
      {'item_id': itemIdMap['Paneer Butter Masala']!, 'name': 'Paneer Butter Masala', 'price': 280.0, 'qty': 3, 'type': 'veg'},
      {'item_id': itemIdMap['Butter Naan']!, 'name': 'Butter Naan', 'price': 45.0, 'qty': 6, 'type': 'veg'},
    ]);

    // Table 5
    await _seedDineInOrder(db, tableNumber: 5, customerPhone: '1000000005', lines: [
      {'item_id': itemIdMap['Butter Chicken Masala']!, 'name': 'Butter Chicken Masala', 'price': 360.0, 'qty': 2, 'type': 'non-veg'},
      {'item_id': itemIdMap['Chicken Dum Biryani']!, 'name': 'Chicken Dum Biryani', 'price': 310.0, 'qty': 4, 'type': 'non-veg'},
    ]);

    // Table 8
    await _seedDineInOrder(db, tableNumber: 8, customerPhone: '1000000008', lines: [
      {'item_id': itemIdMap['Chicken Malai Tikka']!, 'name': 'Chicken Malai Tikka', 'price': 320.0, 'qty': 3, 'type': 'non-veg'},
      {'item_id': itemIdMap['Butter Chicken Masala']!, 'name': 'Butter Chicken Masala', 'price': 360.0, 'qty': 4, 'type': 'non-veg'},
      {'item_id': itemIdMap['Butter Naan']!, 'name': 'Butter Naan', 'price': 45.0, 'qty': 10, 'type': 'veg'},
    ]);

    // 6. Seed Open Parcels for Takeaway Guests
    await _seedTakeawayOrder(db, customerName: 'wasd', customerPhone: '1234567890', lines: [
      {'item_id': itemIdMap['Paneer Tikka']!, 'name': 'Paneer Tikka', 'price': 230.0, 'qty': 1, 'type': 'veg'},
      {'item_id': itemIdMap['Dal Makhani Slow-Cooked']!, 'name': 'Dal Makhani Slow-Cooked', 'price': 210.0, 'qty': 1, 'type': 'veg'},
    ]);

    await _seedTakeawayOrder(db, customerName: 'was', customerPhone: '9876543210', lines: [
      {'item_id': itemIdMap['Crispy Corn Salt & Pepper']!, 'name': 'Crispy Corn Salt & Pepper', 'price': 170.0, 'qty': 1, 'type': 'veg'},
      {'item_id': itemIdMap['Kadhai Paneer Special']!, 'name': 'Kadhai Paneer Special', 'price': 260.0, 'qty': 1, 'type': 'veg'},
    ]);

    await _seedTakeawayOrder(db, customerName: 'aaaa', customerPhone: '12345678', lines: [
      {'item_id': itemIdMap['Butter Chicken Masala']!, 'name': 'Butter Chicken Masala', 'price': 350.0, 'qty': 1, 'type': 'non-veg'},
      {'item_id': itemIdMap['Chicken Dum Biryani']!, 'name': 'Chicken Dum Biryani', 'price': 300.0, 'qty': 1, 'type': 'non-veg'},
      {'item_id': itemIdMap['Butter Naan']!, 'name': 'Butter Naan', 'price': 45.0, 'qty': 4, 'type': 'veg'},
    ]);

    // 7. Seed Sample Completed Orders for Today and This Week Reports
    final nowTime = DateTime.now();
    // Anchor seed orders within today's date range (e.g. today's lunch hours or recent minutes)
    final todayAnchor = DateTime(nowTime.year, nowTime.month, nowTime.day, 12, 0, 0);
    final order1Time = todayAnchor.subtract(const Duration(minutes: 50));
    final order2Time = todayAnchor.subtract(const Duration(minutes: 30));
    final order3Time = todayAnchor.subtract(const Duration(minutes: 10));

    await _seedCompletedOrder(
      db,
      orderType: 'sitdown',
      tableNumber: 1,
      customerName: 'Table 1',
      customerPhone: '1000000001',
      paymentType: 'cash',
      settledTime: order1Time,
      lines: [
        {'item_id': itemIdMap['Paneer Tikka']!, 'name': 'Paneer Tikka', 'price': 240.0, 'qty': 2, 'type': 'veg', 'kt': 'hot_kitchen'},
        {'item_id': itemIdMap['Butter Naan']!, 'name': 'Butter Naan', 'price': 45.0, 'qty': 4, 'type': 'veg', 'kt': 'hot_kitchen'},
        {'item_id': itemIdMap['Fresh Lime Soda (Sweet/Salt)']!, 'name': 'Fresh Lime Soda (Sweet/Salt)', 'price': 80.0, 'qty': 2, 'type': 'beverage', 'kt': 'bar'},
      ],
    );

    await _seedCompletedOrder(
      db,
      orderType: 'takeaway',
      tableNumber: 0,
      customerName: 'Rohan Verma',
      customerPhone: '9811223344',
      paymentType: 'card',
      settledTime: order2Time,
      lines: [
        {'item_id': itemIdMap['Butter Chicken Masala']!, 'name': 'Butter Chicken Masala', 'price': 360.0, 'qty': 1, 'type': 'non-veg', 'kt': 'hot_kitchen'},
        {'item_id': itemIdMap['Chicken Dum Biryani']!, 'name': 'Chicken Dum Biryani', 'price': 310.0, 'qty': 1, 'type': 'non-veg', 'kt': 'hot_kitchen'},
        {'item_id': itemIdMap['Mango Lassi Thick']!, 'name': 'Mango Lassi Thick', 'price': 110.0, 'qty': 2, 'type': 'beverage', 'kt': 'bar'},
      ],
    );

    await _seedCompletedOrder(
      db,
      orderType: 'takeaway',
      tableNumber: 0,
      customerName: 'Sneha Roy',
      customerPhone: '9922334455',
      paymentType: 'upi_qr',
      settledTime: order3Time,
      lines: [
        {'item_id': itemIdMap['Paneer Butter Masala']!, 'name': 'Paneer Butter Masala', 'price': 280.0, 'qty': 1, 'type': 'veg', 'kt': 'hot_kitchen'},
        {'item_id': itemIdMap['Butter Naan']!, 'name': 'Butter Naan', 'price': 45.0, 'qty': 3, 'type': 'veg', 'kt': 'hot_kitchen'},
        {'item_id': itemIdMap['Masala Chai Pot']!, 'name': 'Masala Chai Pot', 'price': 40.0, 'qty': 1, 'type': 'beverage', 'kt': 'bar'},
        {'item_id': itemIdMap['Warm Gulab Jamun (2 pcs)']!, 'name': 'Warm Gulab Jamun (2 pcs)', 'price': 90.0, 'qty': 1, 'type': 'veg', 'kt': 'cold_kitchen'},
      ],
    );

    if (nowTime.weekday > 1) {
      await _seedCompletedOrder(
        db,
        orderType: 'sitdown',
        tableNumber: 4,
        customerName: 'Table 4',
        customerPhone: '1000000004',
        paymentType: 'upi_qr',
        settledTime: todayAnchor.subtract(const Duration(days: 1)),
        lines: [
          {'item_id': itemIdMap['Chicken Malai Tikka']!, 'name': 'Chicken Malai Tikka', 'price': 320.0, 'qty': 1, 'type': 'non-veg', 'kt': 'hot_kitchen'},
          {'item_id': itemIdMap['Jeera Rice with Ghee']!, 'name': 'Jeera Rice with Ghee', 'price': 150.0, 'qty': 1, 'type': 'veg', 'kt': 'hot_kitchen'},
          {'item_id': itemIdMap['Fresh Lime Soda (Sweet/Salt)']!, 'name': 'Fresh Lime Soda (Sweet/Salt)', 'price': 80.0, 'qty': 1, 'type': 'beverage', 'kt': 'bar'},
        ],
      );
    }
  }

  Future<void> _seedDineInOrder(
    Database db, {
    required int tableNumber,
    required String customerPhone,
    required List<Map<String, dynamic>> lines,
  }) async {
    final now = DateTime.now().subtract(const Duration(minutes: 25)).toIso8601String();
    
    // Virtual customer ID
    final custRes = await db.query(
      'customer_table',
      where: 'customer_phone_number = ?',
      whereArgs: [customerPhone],
      limit: 1,
    );
    final customerId = custRes.isNotEmpty ? custRes.first['customer_id'] as int : 1;

    final orderTax = lines.fold(0.0, (sum, l) => sum + ((l['price'] as num) * (l['qty'] as num) * (((l['tax_rate'] ?? 5.0) as num).toDouble() / 100.0)));

    final orderId = await db.insert('order_table', {
      'customer_id': customerId,
      'customer_phone': customerPhone,
      'table_number': tableNumber,
      'order_type': 'sitdown',
      'order_payment_type': 'cash',
      'order_payment_status': 'unpaid',
      'order_status': 'active',
      'order_discount_amount': 0.0,
      'order_discount': 0.0,
      'order_discount_percent': 0.0,
      'order_dscount_percent': 0.0,
      'order_tax': orderTax,
      'order_deliver_status': 'na',
      'order_date': now,
      'order_delivery_charge': 0.0,
      'order_cash_amount': 0.0,
      'order_card_amount': 0.0,
      'order_print_status': 'printed',
    });

    for (var l in lines) {
      await db.insert('order_items_table', {
        'order_id': orderId,
        'item_id': l['item_id'],
        'item_name': l['name'],
        'item_price': l['price'],
        'item_quantity': l['qty'],
        'item_discount_amount': 0.0,
        'item_tax_rate': 5.0,
        'item_type': l['type'],
        'item_kitchen_type': 'hot_kitchen',
        'item_printer_id': 'printer_main',
        'item_status': 'ordered',
        'added_at': now,
      });
    }
  }

  Future<void> _seedTakeawayOrder(
    Database db, {
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> lines,
  }) async {
    final now = DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String();

    final customerId = await db.insert('customer_table', {
      'customer_name': customerName,
      'customer_phone_number': customerPhone,
      'customer_address': 'Counter Takeaway',
      'customer_area': 'Parcel Area',
      'is_table_record': 0,
      'created_at': now,
    });

    final orderTax = lines.fold(0.0, (sum, l) => sum + ((l['price'] as num) * (l['qty'] as num) * (((l['tax_rate'] ?? 5.0) as num).toDouble() / 100.0)));

    final orderId = await db.insert('order_table', {
      'customer_id': customerId,
      'customer_phone': customerPhone,
      'table_number': 0,
      'order_type': 'takeaway',
      'order_payment_type': 'cash',
      'order_payment_status': 'unpaid',
      'order_status': 'active',
      'order_discount_amount': 0.0,
      'order_discount': 0.0,
      'order_discount_percent': 0.0,
      'order_dscount_percent': 0.0,
      'order_tax': orderTax,
      'order_deliver_status': 'na',
      'order_date': now,
      'order_delivery_charge': 0.0,
      'order_cash_amount': 0.0,
      'order_card_amount': 0.0,
      'order_print_status': 'printed',
    });

    for (var l in lines) {
      await db.insert('order_items_table', {
        'order_id': orderId,
        'item_id': l['item_id'],
        'item_name': l['name'],
        'item_price': l['price'],
        'item_quantity': l['qty'],
        'item_discount_amount': 0.0,
        'item_tax_rate': 5.0,
        'item_type': l['type'],
        'item_kitchen_type': 'hot_kitchen',
        'item_printer_id': 'printer_main',
        'item_status': 'ordered',
        'added_at': now,
      });
    }
  }

  Future<void> _seedCompletedOrder(
    Database db, {
    required String orderType,
    int tableNumber = 0,
    required String customerName,
    required String customerPhone,
    required String paymentType,
    required DateTime settledTime,
    required List<Map<String, dynamic>> lines,
  }) async {
    final settledIso = settledTime.toIso8601String();
    final orderedIso = settledTime.subtract(const Duration(minutes: 35)).toIso8601String();

    int customerId = 1;
    if (orderType == 'sitdown') {
      final custRes = await db.query(
        'customer_table',
        where: 'customer_phone_number = ?',
        whereArgs: [customerPhone],
        limit: 1,
      );
      customerId = custRes.isNotEmpty ? custRes.first['customer_id'] as int : 1;
    } else {
      customerId = await db.insert('customer_table', {
        'customer_name': customerName,
        'customer_phone_number': customerPhone,
        'customer_address': 'Counter Takeaway',
        'customer_area': 'Parcel Area',
        'is_table_record': 0,
        'created_at': orderedIso,
      });
    }

    final orderTax = lines.fold(0.0, (sum, l) => sum + ((l['price'] as num) * (l['qty'] as num) * (((l['tax_rate'] ?? 5.0) as num).toDouble() / 100.0)));

    final orderId = await db.insert('order_table', {
      'customer_id': customerId,
      'customer_phone': customerPhone,
      'table_number': tableNumber,
      'order_type': orderType,
      'order_payment_type': normalizePaymentType(paymentType),
      'order_payment_status': 'paid',
      'order_status': 'completed',
      'order_discount_amount': 0.0,
      'order_discount': 0.0,
      'order_discount_percent': 0.0,
      'order_dscount_percent': 0.0,
      'order_tax': orderTax,
      'order_deliver_status': 'na',
      'order_date': orderedIso,
      'order_delivery_charge': 0.0,
      'order_cash_amount': 0.0,
      'order_card_amount': 0.0,
      'order_print_status': 'printed',
      'settled_at': settledIso,
    });

    for (var l in lines) {
      await db.insert('order_items_table', {
        'order_id': orderId,
        'item_id': l['item_id'],
        'item_name': l['name'],
        'item_price': l['price'],
        'item_quantity': l['qty'],
        'item_discount_amount': 0.0,
        'item_tax_rate': 5.0,
        'item_type': l['type'],
        'item_kitchen_type': l['kt'] ?? 'hot_kitchen',
        'item_printer_id': 'printer_main',
        'item_status': 'served',
        'added_at': orderedIso,
      });
    }
  }

  // ==========================================
  // APP SETUP / FIRST TIME STARTUP APIS
  // ==========================================

  /// Check whether initial setup wizard is required on app startup
  Future<bool> isFirstTimeSetupNeeded() async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');

    final res = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['is_setup_completed'],
      limit: 1,
    );

    if (res.isEmpty) {
      return true;
    }

    return res.first['value'] != '1';
  }

  /// Complete first-time startup: save restaurant name and table count, and mark setup completed
  Future<void> completeFirstTimeSetup({
    required String restaurantName,
    required int numberOfTables,
    String? phone,
    String? address,
    String? currency,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Check if restaurant record exists
    final res = await db.query(
      'restaurant_table',
      where: 'restaurant_id = 1',
      limit: 1,
    );

    if (res.isNotEmpty) {
      await db.update(
        'restaurant_table',
        {
          'restaurant_name': restaurantName,
          'number_of_tables': numberOfTables,
          if (phone != null && phone.isNotEmpty) 'restaurant_phone': phone,
          if (address != null && address.isNotEmpty) 'restaurant_address': address,
          if (currency != null && currency.isNotEmpty) 'restaurant_currency': currency,
          'updated_at': now,
        },
        where: 'restaurant_id = 1',
      );
    } else {
      await db.insert('restaurant_table', {
        'restaurant_id': 1,
        'restaurant_name': restaurantName,
        'restaurant_phone': phone ?? '9845012345',
        'restaurant_address': address ?? 'Main Dine-In Area',
        'restaurant_status': 'active',
        'restaurant_currency': currency ?? '₹',
        'number_of_tables': numberOfTables,
        'print_kot': 0,
        'created_at': now,
        'updated_at': now,
      });
    }

    // Provision virtual customer records for all tables
    for (int i = 1; i <= numberOfTables; i++) {
      final tPhone = '100000000$i';
      final exists = await db.query(
        'customer_table',
        where: 'customer_phone_number = ?',
        whereArgs: [tPhone],
        limit: 1,
      );
      if (exists.isEmpty) {
        await db.insert('customer_table', {
          'customer_name': 'Table $i',
          'customer_phone_number': tPhone,
          'customer_address': 'Dine-In Area',
          'customer_area': 'Main Dining Hall',
          'is_table_record': 1,
          'created_at': now,
        });
      }
    }

    // Mark setup as completed in app_settings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    await db.insert(
      'app_settings',
      {'key': 'is_setup_completed', 'value': '1'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get arbitrary setting from app_settings
  Future<String?> getSetting(String key) async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    final res = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first['value'] as String?;
    }
    return null;
  }

  /// Save arbitrary setting in app_settings
  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
    ''');
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Helper to reset setup flag (useful for testing or switching restaurant)
  Future<void> resetFirstTimeSetup() async {
    final db = await database;
    await db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: ['is_setup_completed'],
    );
  }

  // ==========================================
  // RESTAURANT APIS (Update only, No delete allowed)
  // ==========================================

  /// Fetch single restaurant details (ID = 1)
  Future<RestaurantModel> getRestaurantDetails() async {
    final db = await database;
    final results = await db.query(
      'restaurant_table',
      where: 'restaurant_id = 1',
      limit: 1,
    );

    if (results.isNotEmpty) {
      return RestaurantModel.fromMap(results.first);
    }

    final now = DateTime.now().toIso8601String();
    final defaultRestaurant = RestaurantModel(
      id: 1,
      name: 'Sam POS Restaurant',
      phone: '9845012345',
      address: 'Main High Street, Food Court',
      status: 'active',
      currency: '₹',
      numberOfTables: 10,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('restaurant_table', defaultRestaurant.toMap());
    return defaultRestaurant;
  }

  /// Update restaurant details. Deletion is NOT allowed per requirements.
  Future<void> updateRestaurantDetails(RestaurantModel restaurant) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'restaurant_table',
      {
        'restaurant_name': restaurant.name,
        'restaurant_phone': restaurant.phone,
        'restaurant_address': restaurant.address,
        'restaurant_status': restaurant.status,
        'restaurant_currency': restaurant.currency,
        'number_of_tables': restaurant.numberOfTables,
        'restaurant_gstn': restaurant.gstnNumber,
        'print_kot': restaurant.printKotSeparate ? 1 : 0,
        'updated_at': now,
      },
      where: 'restaurant_id = 1',
    );

    // Ensure virtual customer records exist for all tables up to numberOfTables
    for (int i = 1; i <= restaurant.numberOfTables; i++) {
      final phone = '100000000$i';
      final exists = await db.query(
        'customer_table',
        where: 'customer_phone_number = ?',
        whereArgs: [phone],
        limit: 1,
      );
      if (exists.isEmpty) {
        await db.insert('customer_table', {
          'customer_name': 'Table $i',
          'customer_phone_number': phone,
          'customer_address': 'Dine-In Area',
          'customer_area': 'Main Dining Hall',
          'is_table_record': 1,
          'created_at': now,
        });
      }
    }
  }

  // ==========================================
  // DELIVERY ZONES APIS
  // ==========================================

  /// Fetch all delivery zones for delivery charge selection
  Future<List<DeliveryZoneModel>> getDeliveryZones() async {
    final db = await database;
    final results = await db.query(
      'delivery_zones',
      orderBy: 'id ASC',
    );
    return results.map((r) => DeliveryZoneModel.fromMap(r)).toList();
  }

  /// Add a delivery zone
  Future<int> addDeliveryZone(DeliveryZoneModel zone) async {
    final db = await database;
    return await db.insert('delivery_zones', zone.toMap());
  }

  /// Update an existing delivery zone
  Future<void> updateDeliveryZone(DeliveryZoneModel zone) async {
    final db = await database;
    await db.update(
      'delivery_zones',
      zone.toMap(),
      where: 'id = ?',
      whereArgs: [zone.id],
    );
  }

  /// Delete a delivery zone
  Future<void> deleteDeliveryZone(int id) async {
    final db = await database;
    await db.delete(
      'delivery_zones',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // CATEGORY APIS (Add & Edit only, No delete allowed)
  // ==========================================

  /// Fetch all categories (both enabled and disabled) for category management
  Future<List<CategoryModel>> getAllCategories() async {
    final db = await database;
    final results = await db.query(
      'category_table',
      orderBy: 'category_position ASC, category_name ASC',
    );
    return results.map((r) => CategoryModel.fromMap(r)).toList();
  }

  /// Fetch only enabled categories for ordering/cart
  Future<List<CategoryModel>> getActiveCategories() async {
    final db = await database;
    final results = await db.query(
      'category_table',
      where: 'category_status = 1',
      orderBy: 'category_position ASC, category_name ASC',
    );
    return results.map((r) => CategoryModel.fromMap(r)).toList();
  }

  /// Add a new category. Deletion is NOT allowed per requirements.
  Future<int> addCategory(CategoryModel category) async {
    final db = await database;
    return await db.insert('category_table', {
      'category_name': category.name,
      'category_position': category.position,
      'category_colour': category.colorHex,
      'category_type': category.type,
      'category_status': category.status,
    });
  }

  /// Update an existing category. Deletion is NOT allowed per requirements.
  Future<void> updateCategory(CategoryModel category) async {
    final db = await database;
    await db.update(
      'category_table',
      {
        'category_name': category.name,
        'category_position': category.position,
        'category_colour': category.colorHex,
        'category_type': category.type,
        'category_status': category.status,
      },
      where: 'category_id = ?',
      whereArgs: [category.id],
    );
  }

  /// Enable or disable a category (1 = enabled, 0 = disabled)
  Future<void> toggleCategoryStatus(int categoryId, int newStatus) async {
    final db = await database;
    await db.update(
      'category_table',
      {'category_status': newStatus},
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
  }

  // ==========================================
  // MENU ITEM APIS (Add & Edit only, No delete allowed)
  // ==========================================

  /// Fetch all menu items (both enabled and disabled) for item management
  Future<List<MenuItemModel>> getAllMenuItems() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT i.*, c.category_name 
      FROM item_table i
      JOIN category_table c ON i.category_id = c.category_id
      ORDER BY c.category_position ASC, i.item_name ASC
    ''');
    return results.map((r) => MenuItemModel.fromMap(r)).toList();
  }

  /// Fetch active menu items: only enabled items whose category is also enabled
  Future<List<MenuItemModel>> getMenuItems() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT i.*, c.category_name 
      FROM item_table i
      JOIN category_table c ON i.category_id = c.category_id
      WHERE i.item_status = 1 AND c.category_status = 1
      ORDER BY c.category_position ASC, i.item_name ASC
    ''');

    return results.map((r) => MenuItemModel.fromMap(r)).toList();
  }

  /// Add a new menu item. Deletion is NOT allowed per requirements.
  Future<int> addMenuItem(MenuItemModel item) async {
    final db = await database;
    return await db.insert('item_table', {
      'category_id': item.categoryId,
      'item_name': item.name,
      'item_sitdown_price': item.sitdownPrice,
      'item_takeaway_price': item.takeawayPrice,
      'item_delivery_price': item.deliveryPrice,
      'item_quantity': item.quantity,
      'item_type': item.itemType,
      'item_kitchen_type': item.kitchenType,
      'item_tax_rate': item.taxRate,
      'item_status': item.status,
    });
  }

  /// Update an existing menu item. Deletion is NOT allowed per requirements.
  Future<void> updateMenuItem(MenuItemModel item) async {
    final db = await database;
    await db.update(
      'item_table',
      {
        'category_id': item.categoryId,
        'item_name': item.name,
        'item_sitdown_price': item.sitdownPrice,
        'item_takeaway_price': item.takeawayPrice,
        'item_delivery_price': item.deliveryPrice,
        'item_quantity': item.quantity,
        'item_type': item.itemType,
        'item_kitchen_type': item.kitchenType,
        'item_tax_rate': item.taxRate,
        'item_status': item.status,
      },
      where: 'item_id = ?',
      whereArgs: [item.id],
    );
  }

  /// Enable or disable a menu item (1 = enabled, 0 = disabled)
  Future<void> toggleMenuItemStatus(int itemId, int newStatus) async {
    final db = await database;
    await db.update(
      'item_table',
      {'item_status': newStatus},
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  /// Fetch all category names that are currently enabled
  Future<List<String>> getCategories() async {
    final db = await database;
    final results = await db.query(
      'category_table',
      columns: ['category_name'],
      where: 'category_status = 1',
      orderBy: 'category_position ASC',
    );
    final cats = results.map((r) => r['category_name'] as String).toList();
    if (!cats.contains('All')) {
      cats.insert(0, 'All');
    }
    return cats;
  }

  /// Fetch Dine-In Tables with their live SQLite status & activeCart
  Future<List<TableModel>> getSitDownTables() async {
    final db = await database;
    final restaurant = await getRestaurantDetails();
    final tableCount = restaurant.numberOfTables;
    final tables = <TableModel>[];

    for (int t = 1; t <= tableCount; t++) {
      // Find active order for this table
      final orderRes = await db.rawQuery('''
        SELECT o.*, c.customer_name, c.customer_phone_number
        FROM order_table o
        JOIN customer_table c ON o.customer_id = c.customer_id
        WHERE o.table_number = ? AND o.order_type = 'sitdown' AND o.order_status = 'active'
        ORDER BY o.order_id DESC
        LIMIT 1
      ''', [t]);

      if (orderRes.isNotEmpty) {
        final o = orderRes.first;
        final orderId = o['order_id'] as int;

        // Load items from order_items_table
        final itemsRes = await db.rawQuery('''
          SELECT oi.*, i.item_sitdown_price, i.category_id, i.item_takeaway_price, i.item_delivery_price, c.category_name
          FROM order_items_table oi
          LEFT JOIN item_table i ON oi.item_id = i.item_id
          LEFT JOIN category_table c ON i.category_id = c.category_id
          WHERE oi.order_id = ?
        ''', [orderId]);

        final consolidatedItems = <int, CartItemModel>{};
        for (var r in itemsRes) {
          final itemId = r['item_id'] as int;
          final savedPrice = (r['item_price'] as num).toDouble();
          final qty = r['item_quantity'] as int;
          if (consolidatedItems.containsKey(itemId)) {
            final prev = consolidatedItems[itemId]!;
            consolidatedItems[itemId] = prev.copyWith(
              quantity: prev.quantity + qty,
              existingQuantity: prev.existingQuantity + qty,
            );
          } else {
            final menuItem = MenuItemModel(
              id: itemId,
              categoryId: (r['category_id'] as num?)?.toInt() ?? 1,
              categoryName: (r['category_name'] as String?) ?? 'General',
              name: r['item_name'] as String,
              sitdownPrice: (r['item_sitdown_price'] as num?)?.toDouble() ?? savedPrice,
              takeawayPrice: (r['item_takeaway_price'] as num?)?.toDouble() ?? 0.0,
              deliveryPrice: (r['item_delivery_price'] as num?)?.toDouble() ?? 0.0,
              itemType: r['item_type'] as String,
              kitchenType: r['item_kitchen_type'] as String,
              taxRate: (r['item_tax_rate'] as num).toDouble(),
            );
            consolidatedItems[itemId] = CartItemModel(
              item: menuItem,
              quantity: qty,
              status: r['item_status'] as String,
              existingQuantity: qty, // Locked against deletion because held in kitchen
              isTakeaway: false,
              customUnitPrice: savedPrice,
            );
          }
        }
        final cartItems = consolidatedItems.values.toList();

        final total = cartItems.fold(0.0, (sum, i) => sum + i.totalPrice);
        final count = cartItems.fold(0, (sum, i) => sum + i.quantity);
        final seatedAt = DateTime.tryParse(o['order_date'] as String);
        final orderDiscount = (o['order_discount'] as num?)?.toDouble() ?? (o['order_discount_amount'] as num?)?.toDouble() ?? 0.0;
        final orderDiscountPercent = (o['order_discount_percent'] as num?)?.toDouble() ?? (o['order_dscount_percent'] as num?)?.toDouble() ?? 0.0;
        final orderDeliveryCharge = (o['order_delivery_charge'] as num?)?.toDouble() ?? 0.0;
        final orderComments = o['order_comments'] as String? ?? '';

        tables.add(TableModel(
          id: t,
          name: 'Table $t',
          tableNumber: t,
          status: TableOrderStatus.open,
          orderType: OrderType.sitDown,
          customerPhone: o['customer_phone_number'] as String?,
          currentTotal: total,
          discountAmount: orderDiscount,
          discountPercent: orderDiscountPercent,
          deliveryCharge: orderDeliveryCharge,
          orderComments: orderComments,
          itemCount: count,
          seatedAt: seatedAt,
          activeCart: cartItems,
          activeOrderId: orderId,
        ));
      } else {
        // Table is Closed / Free (Green)
        tables.add(TableModel(
          id: t,
          name: 'Table $t',
          tableNumber: t,
          status: TableOrderStatus.closed,
          orderType: OrderType.sitDown,
          customerPhone: '100000000$t',
          currentTotal: 0.0,
          itemCount: 0,
          activeCart: const [],
          activeOrderId: null,
        ));
      }
    }

    return tables;
  }

  /// Fetch all active takeaway/parcel orders from SQLite
  Future<List<TableModel>> getOpenParcelOrders() async {
    final db = await database;
    final orderRes = await db.rawQuery('''
      SELECT o.*, c.customer_name, c.customer_phone_number
      FROM order_table o
      JOIN customer_table c ON o.customer_id = c.customer_id
      WHERE o.order_type = 'takeaway' AND o.order_status = 'active'
      ORDER BY o.order_id DESC
    ''');

    final parcels = <TableModel>[];

    for (var o in orderRes) {
      final orderId = o['order_id'] as int;
      final custName = o['customer_name'] as String? ?? 'Takeaway Guest';
      final custPhone = o['customer_phone_number'] as String? ?? '';

      final itemsRes = await db.rawQuery('''
        SELECT oi.*, i.item_sitdown_price, i.category_id, i.item_takeaway_price, i.item_delivery_price, c.category_name
        FROM order_items_table oi
        LEFT JOIN item_table i ON oi.item_id = i.item_id
        LEFT JOIN category_table c ON i.category_id = c.category_id
        WHERE oi.order_id = ?
      ''', [orderId]);

      final consolidatedItems = <int, CartItemModel>{};
      for (var r in itemsRes) {
        final itemId = r['item_id'] as int;
        final savedPrice = (r['item_price'] as num).toDouble();
        final qty = r['item_quantity'] as int;
        if (consolidatedItems.containsKey(itemId)) {
          final prev = consolidatedItems[itemId]!;
          consolidatedItems[itemId] = prev.copyWith(
            quantity: prev.quantity + qty,
            existingQuantity: prev.existingQuantity + qty,
          );
        } else {
          final menuItem = MenuItemModel(
            id: itemId,
            categoryId: (r['category_id'] as num?)?.toInt() ?? 1,
            categoryName: (r['category_name'] as String?) ?? 'General',
            name: r['item_name'] as String,
            sitdownPrice: (r['item_sitdown_price'] as num?)?.toDouble() ?? savedPrice,
            takeawayPrice: (r['item_takeaway_price'] as num?)?.toDouble() ?? 0.0,
            deliveryPrice: (r['item_delivery_price'] as num?)?.toDouble() ?? 0.0,
            itemType: r['item_type'] as String,
            kitchenType: r['item_kitchen_type'] as String,
            taxRate: (r['item_tax_rate'] as num).toDouble(),
          );
          consolidatedItems[itemId] = CartItemModel(
            item: menuItem,
            quantity: qty,
            status: r['item_status'] as String,
            existingQuantity: qty,
            isTakeaway: true,
            customUnitPrice: savedPrice,
          );
        }
      }
      final cartItems = consolidatedItems.values.toList();

      final total = cartItems.fold(0.0, (sum, i) => sum + i.totalPrice);
      final count = cartItems.fold(0, (sum, i) => sum + i.quantity);
      final orderDiscount = (o['order_discount'] as num?)?.toDouble() ?? (o['order_discount_amount'] as num?)?.toDouble() ?? 0.0;
      final orderDiscountPercent = (o['order_discount_percent'] as num?)?.toDouble() ?? (o['order_dscount_percent'] as num?)?.toDouble() ?? 0.0;
      final orderDeliveryCharge = (o['order_delivery_charge'] as num?)?.toDouble() ?? 0.0;
      final orderComments = o['order_comments'] as String? ?? '';

      parcels.add(TableModel(
        id: orderId,
        name: custName,
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: custName,
        customerPhone: custPhone,
        currentTotal: total,
        discountAmount: orderDiscount,
        discountPercent: orderDiscountPercent,
        deliveryCharge: orderDeliveryCharge,
        orderComments: orderComments,
        itemCount: count,
        seatedAt: DateTime.tryParse(o['order_date'] as String),
        activeCart: cartItems,
        activeOrderId: orderId,
      ));
    }

    return parcels;
  }

  /// Retrieve line items for any order by orderId (used for reprinting bills & receipts)
  Future<List<CartItemModel>> getOrderItems(int orderId) async {
    final db = await database;
    final itemsRes = await db.rawQuery('''
      SELECT oi.*, i.item_sitdown_price, i.category_id, i.item_takeaway_price, i.item_delivery_price, c.category_name
      FROM order_items_table oi
      LEFT JOIN item_table i ON oi.item_id = i.item_id
      LEFT JOIN category_table c ON i.category_id = c.category_id
      WHERE oi.order_id = ?
    ''', [orderId]);

    final consolidatedItems = <int, CartItemModel>{};
    for (var r in itemsRes) {
      final savedPrice = (r['item_price'] as num?)?.toDouble() ?? 0.0;
      final itemId = (r['item_id'] as num?)?.toInt() ?? 0;
      final qty = (r['item_quantity'] as num?)?.toInt() ?? 1;
      if (consolidatedItems.containsKey(itemId)) {
        final prev = consolidatedItems[itemId]!;
        consolidatedItems[itemId] = prev.copyWith(
          quantity: prev.quantity + qty,
          existingQuantity: prev.existingQuantity + qty,
        );
      } else {
        final menuItem = MenuItemModel(
          id: itemId,
          categoryId: (r['category_id'] as num?)?.toInt() ?? 1,
          categoryName: (r['category_name'] as String?) ?? 'General',
          name: (r['item_name'] as String?) ?? 'Item',
          sitdownPrice: (r['item_sitdown_price'] as num?)?.toDouble() ?? savedPrice,
          takeawayPrice: (r['item_takeaway_price'] as num?)?.toDouble() ?? 0.0,
          deliveryPrice: (r['item_delivery_price'] as num?)?.toDouble() ?? 0.0,
          itemType: (r['item_type'] as String?) ?? 'veg',
          kitchenType: (r['item_kitchen_type'] as String?) ?? 'hot_kitchen',
          taxRate: (r['item_tax_rate'] as num?)?.toDouble() ?? 5.0,
        );
        consolidatedItems[itemId] = CartItemModel(
          item: menuItem,
          quantity: qty,
          status: (r['item_status'] as String?) ?? 'ordered',
          existingQuantity: qty,
          customUnitPrice: savedPrice,
        );
      }
    }
    return consolidatedItems.values.toList();
  }

  /// Hold a Dine-In table order: creates or updates order in SQLite and transitions table to Red
  Future<int> holdSitDownOrder(
    int tableNumber,
    List<CartItemModel> cartItems, {
    int? activeOrderId,
    double discountAmount = 0.0,
    bool isPercent = false,
    double percentValue = 0.0,
    double deliveryCharge = 0.0,
    String? orderComments,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Deduplicate / consolidate cart items by item.id so duplicate lines never occur
    final consolidated = <int, CartItemModel>{};
    for (var c in cartItems) {
      if (consolidated.containsKey(c.item.id)) {
        final existing = consolidated[c.item.id]!;
        consolidated[c.item.id] = existing.copyWith(
          quantity: existing.quantity + c.quantity,
          existingQuantity: existing.existingQuantity + c.existingQuantity,
        );
      } else {
        consolidated[c.item.id] = c;
      }
    }
    final cleanCartItems = consolidated.values.toList();
    final orderTax = cleanCartItems.fold(0.0, (sum, c) => sum + (c.totalPrice * (c.item.taxRate / 100.0)));
    final orderNetTotal = cleanCartItems.fold(0.0, (sum, c) => sum + c.totalPrice);
    final effectiveDiscount = calculateDiscount(
      netTotal: orderNetTotal,
      isPercent: isPercent,
      discountAmount: discountAmount,
      percentValue: percentValue,
    );
    final double storedAmount = (!isPercent && effectiveDiscount > 0) ? effectiveDiscount : 0.0;
    final double storedPercent = (isPercent && percentValue > 0) ? percentValue : 0.0;

    return await db.transaction<int>((txn) async {
      // Check if active order already exists (prioritizing activeOrderId if specified)
      List<Map<String, dynamic>> existingOrders;
      if (activeOrderId != null && activeOrderId > 0) {
        existingOrders = await txn.query(
          'order_table',
          where: 'order_id = ? AND order_status = ?',
          whereArgs: [activeOrderId, 'active'],
          limit: 1,
        );
      } else {
        existingOrders = await txn.query(
          'order_table',
          where: 'table_number = ? AND order_type = ? AND order_status = ?',
          whereArgs: [tableNumber, 'sitdown', 'active'],
          orderBy: 'order_id DESC',
        );
      }

      int orderId;
      if (existingOrders.isNotEmpty) {
        orderId = existingOrders.first['order_id'] as int;

        // Cancel any older stray duplicate active orders for this table to prevent orphaned rows
        await txn.update(
          'order_table',
          {'order_status': 'cancelled'},
          where: 'table_number = ? AND order_type = ? AND order_status = ? AND order_id != ?',
          whereArgs: [tableNumber, 'sitdown', 'active', orderId],
        );

        // Update print status, tax, discount, delivery charge, and order comments
        final updateData = <String, dynamic>{
          'order_print_status': 'printed',
          'order_tax': orderTax,
          'order_discount_amount': storedAmount,
          'order_discount_percent': storedPercent,
          'order_discount': effectiveDiscount,
          'order_delivery_charge': deliveryCharge,
        };
        final orderTableInfo = await txn.rawQuery("PRAGMA table_info(order_table);");
        if (orderTableInfo.any((col) => col['name'] == 'order_dscount_percent')) {
          updateData['order_dscount_percent'] = storedPercent;
        }
        if (orderComments != null) {
          updateData['order_comments'] = orderComments;
        }
        await txn.update(
          'order_table',
          updateData,
          where: 'order_id = ?',
          whereArgs: [orderId],
        );

        // Atomically delete existing lines and re-insert new consolidated list
        await txn.delete('order_items_table', where: 'order_id = ?', whereArgs: [orderId]);
      } else {
        // Find virtual customer ID for table
        final custPhone = '100000000$tableNumber';
        final custRes = await txn.query(
          'customer_table',
          where: 'customer_phone_number = ?',
          whereArgs: [custPhone],
          limit: 1,
        );
        final customerId = custRes.isNotEmpty ? custRes.first['customer_id'] as int : 1;

        final newOrderMap = <String, dynamic>{
          'customer_id': customerId,
          'customer_phone': custPhone,
          'table_number': tableNumber,
          'order_type': 'sitdown',
          'order_payment_type': 'cash',
          'order_payment_status': 'unpaid',
          'order_status': 'active',
          'order_discount_amount': storedAmount,
          'order_discount_percent': storedPercent,
          'order_discount': effectiveDiscount,
          'order_tax': orderTax,
          'order_deliver_status': 'na',
          'order_date': now,
          'order_delivery_charge': deliveryCharge,
          'order_comments': orderComments ?? '',
          'order_cash_amount': 0.0,
          'order_card_amount': 0.0,
          'order_print_status': 'printed',
        };
        final orderTableInfo = await txn.rawQuery("PRAGMA table_info(order_table);");
        if (orderTableInfo.any((col) => col['name'] == 'order_dscount_percent')) {
          newOrderMap['order_dscount_percent'] = storedPercent;
        }
        orderId = await txn.insert('order_table', newOrderMap);
      }

      // Insert clean consolidated cart items
      for (var c in cleanCartItems) {
        await txn.insert('order_items_table', {
          'order_id': orderId,
          'item_id': c.item.id,
          'item_name': c.item.name,
          'item_price': c.unitPrice,
          'item_quantity': c.quantity,
          'item_discount_amount': 0.0,
          'item_tax_rate': c.item.taxRate,
          'item_type': c.item.itemType,
          'item_kitchen_type': c.item.kitchenType,
          'item_printer_id': 'printer_main',
          'item_status': 'ordered',
          'added_at': now,
        });
      }

      return orderId;
    });
  }

  /// Calculates total discount in currency from net total (or order items) per Sam Biswas:
  /// - When user clicks Discount Amount: discount = discountAmount.clamp(0.0, netTotal).
  /// - When user clicks Discount Percent: calculates total discount from order items: netTotal * (percentValue / 100.0).
  double calculateDiscount({
    required double netTotal,
    required bool isPercent,
    double discountAmount = 0.0,
    double percentValue = 0.0,
  }) {
    if (isPercent) {
      final pct = percentValue.clamp(0.0, 100.0);
      return (netTotal * (pct / 100.0)).clamp(0.0, netTotal);
    } else {
      return discountAmount.clamp(0.0, netTotal > 0 ? netTotal : double.infinity);
    }
  }

  /// Updates discount fields in order_table per Sam Biswas:
  /// - When user clicks Discount Amount, it updates two fields: order_discount and order_discount_amount.
  /// - When user clicks Discount Percent, it calculates total discount from order items and updates order_discount_percent and order_discount.
  /// - Now when we reopen the table, it shows order_discount.
  /// - For all orders both order_discount_amount and order_discount_percent cannot be non-zero.
  Future<void> updateDiscount({
    required int orderId,
    required bool isPercent,
    double discountAmount = 0.0,
    double percentValue = 0.0,
    double deliveryCharge = 0.0,
    String? orderComments,
  }) async {
    final db = await database;

    final itemsRes = await db.query(
      'order_items_table',
      columns: ['item_price', 'item_quantity', 'item_tax_rate'],
      where: 'order_id = ?',
      whereArgs: [orderId],
    );

    double netTotal = 0.0;
    double taxTotal = 0.0;
    for (var r in itemsRes) {
      final price = (r['item_price'] as num).toDouble();
      final qty = (r['item_quantity'] as num).toInt();
      final taxRate = (r['item_tax_rate'] as num).toDouble();
      final linePrice = price * qty;
      netTotal += linePrice;
      taxTotal += linePrice * (taxRate / 100.0);
    }

    final effectiveDiscount = calculateDiscount(
      netTotal: netTotal,
      isPercent: isPercent,
      discountAmount: discountAmount,
      percentValue: percentValue,
    );

    // Mutual exclusivity: for all orders both order_discount_amount and order_discount_percent cannot be non-zero
    final double storedAmount = (!isPercent && effectiveDiscount > 0) ? effectiveDiscount : 0.0;
    final double storedPercent = (isPercent && percentValue > 0) ? percentValue : 0.0;

    final updateData = <String, dynamic>{
      'order_discount': effectiveDiscount,
      'order_discount_amount': storedAmount,
      'order_discount_percent': storedPercent,
      'order_tax': taxTotal,
      'order_delivery_charge': deliveryCharge,
    };

    final orderTableInfo = await db.rawQuery("PRAGMA table_info(order_table);");
    if (orderTableInfo.any((col) => col['name'] == 'order_dscount_percent')) {
      updateData['order_dscount_percent'] = storedPercent;
    }
    if (orderComments != null) {
      updateData['order_comments'] = orderComments;
    }

    await db.update(
      'order_table',
      updateData,
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  /// Update discount and metadata for an existing order without touching order_items_table.
  /// Used when: number of new items == 0 (calculateDiscount; updateDiscount())
  Future<void> updateOrderDiscountAndMeta({
    required int orderId,
    required double discountAmount,
    bool? isPercent,
    double? percentValue,
    double deliveryCharge = 0.0,
    String? orderComments,
  }) async {
    final db = await database;
    final orderRow = await db.query('order_table', where: 'order_id = ?', whereArgs: [orderId], limit: 1);
    final double existingPercent = orderRow.isNotEmpty
        ? ((orderRow.first['order_discount_percent'] as num?)?.toDouble() ??
           (orderRow.first['order_dscount_percent'] as num?)?.toDouble() ?? 0.0)
        : 0.0;
    final bool effectiveIsPercent = isPercent ?? (existingPercent > 0.0 && discountAmount == 0.0);
    final double effectivePercent = effectiveIsPercent
        ? (percentValue != null && percentValue > 0.0 ? percentValue : existingPercent)
        : 0.0;

    await updateDiscount(
      orderId: orderId,
      isPercent: effectiveIsPercent,
      discountAmount: discountAmount,
      percentValue: effectivePercent,
      deliveryCharge: deliveryCharge,
      orderComments: orderComments,
    );
  }

  /// Get active order_id for a sitdown table number
  Future<int?> getActiveSitDownOrderId(int tableNumber) async {
    final db = await database;
    final res = await db.query(
      'order_table',
      columns: ['order_id'],
      where: 'table_number = ? AND order_type = ? AND order_status = ?',
      whereArgs: [tableNumber, 'sitdown', 'active'],
      orderBy: 'order_id DESC',
      limit: 1,
    );
    if (res.isNotEmpty) {
      return res.first['order_id'] as int?;
    }
    return null;
  }

  /// Update discount for active sitdown table order directly by table number
  Future<void> updateSitDownTableDiscount({
    required int tableNumber,
    required double discountAmount,
    bool isPercent = false,
    double percentValue = 0.0,
    double? deliveryCharge,
    String? orderComments,
  }) async {
    final orderId = await getActiveSitDownOrderId(tableNumber);
    if (orderId != null && orderId > 0) {
      await updateDiscount(
        orderId: orderId,
        isPercent: isPercent,
        discountAmount: discountAmount,
        percentValue: percentValue,
        deliveryCharge: deliveryCharge ?? 0.0,
        orderComments: orderComments,
      );
    } else {
      final db = await database;
      final double storedAmount = (!isPercent && discountAmount > 0) ? discountAmount : 0.0;
      final double storedPercent = (isPercent && percentValue > 0) ? percentValue : 0.0;

      final updateMap = <String, dynamic>{
        'order_discount': discountAmount,
        'order_discount_amount': storedAmount,
        'order_discount_percent': storedPercent,
        'order_delivery_charge': ?deliveryCharge,
        'order_comments': ?orderComments,
      };
      final orderTableInfo = await db.rawQuery("PRAGMA table_info(order_table);");
      if (orderTableInfo.any((col) => col['name'] == 'order_dscount_percent')) {
        updateMap['order_dscount_percent'] = storedPercent;
      }
      await db.update(
        'order_table',
        updateMap,
        where: 'table_number = ? AND order_type = ? AND order_status = ?',
        whereArgs: [tableNumber, 'sitdown', 'active'],
      );
    }
  }

  /// Add new items to an existing Dine-In order, recompute tax and discount, and update order_table.
  /// Used when: number of new items > 0 (add new items to order item table; calculateDiscount(); updateDiscount(); PrintNewItems())
  Future<void> addNewItemsToSitDownOrder({
    required int orderId,
    required int tableNumber,
    required List<CartItemModel> newItems,
    required double discountAmount,
    bool? isPercent,
    double? percentValue,
    double deliveryCharge = 0.0,
    String? orderComments,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // 1. Insert ONLY the newly added items into order_items_table
      for (var c in newItems) {
        final qtyToAdd = c.isExisting ? c.newQuantity : c.quantity;
        if (qtyToAdd <= 0) continue;

        await txn.insert('order_items_table', {
          'order_id': orderId,
          'item_id': c.item.id,
          'item_name': c.item.name,
          'item_price': c.unitPrice,
          'item_quantity': qtyToAdd,
          'item_discount_amount': 0.0,
          'item_tax_rate': c.item.taxRate,
          'item_type': c.item.itemType,
          'item_kitchen_type': c.item.kitchenType,
          'item_printer_id': 'printer_main',
          'item_status': 'ordered',
          'added_at': now,
        });
      }

      // 2. Recompute net total and tax across all items (existing + new) in order_items_table
      final itemsRes = await txn.query(
        'order_items_table',
        columns: ['item_price', 'item_quantity', 'item_tax_rate'],
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      double netTotal = 0.0;
      double taxTotal = 0.0;
      for (var r in itemsRes) {
        final price = (r['item_price'] as num).toDouble();
        final qty = (r['item_quantity'] as num).toInt();
        final taxRate = (r['item_tax_rate'] as num).toDouble();
        final linePrice = price * qty;
        netTotal += linePrice;
        taxTotal += linePrice * (taxRate / 100.0);
      }

      // Fetch order's existing discount percent to know if discount was % or flat amount
      final orderRow = await txn.query('order_table', where: 'order_id = ?', whereArgs: [orderId], limit: 1);
      final double existingPercent = orderRow.isNotEmpty
          ? ((orderRow.first['order_discount_percent'] as num?)?.toDouble() ??
             (orderRow.first['order_dscount_percent'] as num?)?.toDouble() ?? 0.0)
          : 0.0;
      final bool effectiveIsPercent = isPercent ?? (existingPercent > 0.0);
      final double effectivePercentValue = effectiveIsPercent
          ? (percentValue != null && percentValue > 0.0 ? percentValue : existingPercent)
          : 0.0;
      final effectiveDiscount = calculateDiscount(
        netTotal: netTotal,
        isPercent: effectiveIsPercent,
        discountAmount: discountAmount,
        percentValue: effectivePercentValue,
      );
      final double storedAmount = (!effectiveIsPercent && effectiveDiscount > 0) ? effectiveDiscount : 0.0;
      final double storedPercent = (effectiveIsPercent && effectivePercentValue > 0) ? effectivePercentValue : 0.0;

      final updateData = <String, dynamic>{
        'order_print_status': 'printed',
        'order_tax': taxTotal,
        'order_discount': effectiveDiscount,
        'order_discount_amount': storedAmount,
        'order_discount_percent': storedPercent,
        'order_delivery_charge': deliveryCharge,
      };
      final orderTableInfo = await txn.rawQuery("PRAGMA table_info(order_table);");
      if (orderTableInfo.any((col) => col['name'] == 'order_dscount_percent')) {
        updateData['order_dscount_percent'] = storedPercent;
      }
      if (orderComments != null) {
        updateData['order_comments'] = orderComments;
      }

      await txn.update(
        'order_table',
        updateData,
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
    });
  }

  /// Add new items to an existing parcel/takeaway order, recompute tax and discount, and update order_table.
  Future<void> addNewItemsToParcelOrder({
    required int orderId,
    required List<CartItemModel> newItems,
    required double discountAmount,
    bool? isPercent,
    double? percentValue,
    double deliveryCharge = 0.0,
    String? orderComments,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (var c in newItems) {
        final qtyToAdd = c.isExisting ? c.newQuantity : c.quantity;
        if (qtyToAdd <= 0) continue;

        await txn.insert('order_items_table', {
          'order_id': orderId,
          'item_id': c.item.id,
          'item_name': c.item.name,
          'item_price': c.unitPrice,
          'item_quantity': qtyToAdd,
          'item_discount_amount': 0.0,
          'item_tax_rate': c.item.taxRate,
          'item_type': c.item.itemType,
          'item_kitchen_type': c.item.kitchenType,
          'item_printer_id': 'printer_main',
          'item_status': 'ordered',
          'added_at': now,
        });
      }

      final itemsRes = await txn.query(
        'order_items_table',
        columns: ['item_price', 'item_quantity', 'item_tax_rate'],
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      double netTotal = 0.0;
      double taxTotal = 0.0;
      for (var r in itemsRes) {
        final price = (r['item_price'] as num).toDouble();
        final qty = (r['item_quantity'] as num).toInt();
        final taxRate = (r['item_tax_rate'] as num).toDouble();
        final linePrice = price * qty;
        netTotal += linePrice;
        taxTotal += linePrice * (taxRate / 100.0);
      }

      final orderRow = await txn.query('order_table', where: 'order_id = ?', whereArgs: [orderId], limit: 1);
      final double existingPercent = orderRow.isNotEmpty
          ? ((orderRow.first['order_discount_percent'] as num?)?.toDouble() ??
             (orderRow.first['order_dscount_percent'] as num?)?.toDouble() ?? 0.0)
          : 0.0;
      final bool effectiveIsPercent = isPercent ?? (existingPercent > 0.0);
      final double effectivePercentValue = effectiveIsPercent
          ? (percentValue != null && percentValue > 0.0 ? percentValue : existingPercent)
          : 0.0;
      final effectiveDiscount = calculateDiscount(
        netTotal: netTotal,
        isPercent: effectiveIsPercent,
        discountAmount: discountAmount,
        percentValue: effectivePercentValue,
      );
      final double storedAmount = (!effectiveIsPercent && effectiveDiscount > 0) ? effectiveDiscount : 0.0;
      final double storedPercent = (effectiveIsPercent && effectivePercentValue > 0) ? effectivePercentValue : 0.0;

      final updateData = <String, dynamic>{
        'order_print_status': 'printed',
        'order_tax': taxTotal,
        'order_discount': effectiveDiscount,
        'order_discount_amount': storedAmount,
        'order_discount_percent': storedPercent,
        'order_delivery_charge': deliveryCharge,
      };
      final orderTableInfo = await txn.rawQuery("PRAGMA table_info(order_table);");
      if (orderTableInfo.any((col) => col['name'] == 'order_dscount_percent')) {
        updateData['order_dscount_percent'] = storedPercent;
      }
      if (orderComments != null) {
        updateData['order_comments'] = orderComments;
      }

      await txn.update(
        'order_table',
        updateData,
        where: 'order_id = ?',
        whereArgs: [orderId],
      );
    });
  }

  /// Settle & Release table: marks order as completed, freeing table back to Green
  Future<void> settleAndReleaseTable(
    int tableNumber, {
    String paymentMethod = 'Cash',
    double? discountAmount,
    double? deliveryCharge,
    String? orderComments,
    bool? isPercent,
    double? percentValue,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final existingOrders = await db.query(
      'order_table',
      where: 'table_number = ? AND order_type = ? AND order_status = ?',
      whereArgs: [tableNumber, 'sitdown', 'active'],
      orderBy: 'order_id DESC',
    );

    double orderTax = 0.0;
    if (existingOrders.isNotEmpty) {
      final orderId = existingOrders.first['order_id'] as int;
      final items = await db.rawQuery(
        'SELECT item_price, item_quantity, item_tax_rate FROM order_items_table WHERE order_id = ?',
        [orderId],
      );
      orderTax = items.fold(0.0, (sum, i) => sum + ((i['item_price'] as num) * (i['item_quantity'] as num) * (((i['item_tax_rate'] ?? 5.0) as num).toDouble() / 100.0)));
    }

    final updateMap = <String, dynamic>{
      'order_status': 'completed',
      'order_payment_status': 'paid',
      'order_payment_type': normalizePaymentType(paymentMethod),
      'order_tax': orderTax,
      'settled_at': now,
    };
    if (discountAmount != null) {
      final double existingPercent = (percentValue != null && percentValue > 0)
          ? percentValue
          : (existingOrders.isNotEmpty
              ? ((existingOrders.first['order_discount_percent'] as num?)?.toDouble() ??
                 (existingOrders.first['order_dscount_percent'] as num?)?.toDouble() ?? 0.0)
              : 0.0);
      final bool effectiveIsPercent = isPercent ?? (existingPercent > 0.0);
      final double storedAmount = (!effectiveIsPercent && discountAmount > 0) ? discountAmount : 0.0;
      final double storedPercent = (effectiveIsPercent && existingPercent > 0) ? existingPercent : 0.0;
      updateMap['order_discount'] = discountAmount;
      updateMap['order_discount_amount'] = storedAmount;
      updateMap['order_discount_percent'] = storedPercent;
      final orderTableInfo = await db.rawQuery("PRAGMA table_info(order_table);");
      if (orderTableInfo.any((col) => col['name'] == 'order_dscount_percent')) {
        updateMap['order_dscount_percent'] = storedPercent;
      }
    }
    if (deliveryCharge != null) {
      updateMap['order_delivery_charge'] = deliveryCharge;
    }
    if (orderComments != null) {
      updateMap['order_comments'] = orderComments;
    }

    // Mark all active orders for this table as completed to leave zero orphaned rows
    await db.update(
      'order_table',
      updateMap,
      where: 'table_number = ? AND order_type = ? AND order_status = ?',
      whereArgs: [tableNumber, 'sitdown', 'active'],
    );
  }

  /// Create a new takeaway parcel order with real customer details
  Future<int> createParcelOrder({
    required String customerName,
    required String customerPhone,
    required List<CartItemModel> cartItems,
    double discountAmount = 0.0,
    bool isPercent = false,
    double percentValue = 0.0,
    double deliveryCharge = 0.0,
    String? orderComments,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Deduplicate / consolidate cart items by item.id so duplicate lines never occur
    final consolidated = <int, CartItemModel>{};
    for (var c in cartItems) {
      if (consolidated.containsKey(c.item.id)) {
        final existing = consolidated[c.item.id]!;
        consolidated[c.item.id] = existing.copyWith(
          quantity: existing.quantity + c.quantity,
          existingQuantity: existing.existingQuantity + c.existingQuantity,
        );
      } else {
        consolidated[c.item.id] = c;
      }
    }
    final cleanCartItems = consolidated.values.toList();
    final orderTax = cleanCartItems.fold(0.0, (sum, c) => sum + (c.totalPrice * (c.item.taxRate / 100.0)));
    final orderNetTotal = cleanCartItems.fold(0.0, (sum, c) => sum + c.totalPrice);
    final effectiveDiscount = calculateDiscount(
      netTotal: orderNetTotal,
      isPercent: isPercent,
      discountAmount: discountAmount,
      percentValue: percentValue,
    );
    final double storedAmount = (!isPercent && effectiveDiscount > 0) ? effectiveDiscount : 0.0;
    final double storedPercent = (isPercent && percentValue > 0) ? percentValue : 0.0;

    return await db.transaction<int>((txn) async {
      // 1. Insert real customer
      final customerId = await txn.insert('customer_table', {
        'customer_name': customerName,
        'customer_phone_number': customerPhone.isNotEmpty ? customerPhone : 'No Phone',
        'customer_address': 'Counter Takeaway',
        'customer_area': 'Parcel Station',
        'is_table_record': 0,
        'created_at': now,
      });

      // 2. Insert order
      final newOrderMap = <String, dynamic>{
        'customer_id': customerId,
        'customer_phone': customerPhone.isNotEmpty ? customerPhone : 'No Phone',
        'table_number': 0,
        'order_type': 'takeaway',
        'order_payment_type': 'cash',
        'order_payment_status': 'unpaid',
        'order_status': 'active',
        'order_discount_amount': storedAmount,
        'order_discount_percent': storedPercent,
        'order_discount': effectiveDiscount,
        'order_tax': orderTax,
        'order_deliver_status': 'na',
        'order_date': now,
        'order_delivery_charge': deliveryCharge,
        'order_comments': orderComments ?? '',
        'order_cash_amount': 0.0,
        'order_card_amount': 0.0,
        'order_print_status': 'printed',
      };
      final orderTableInfo = await txn.rawQuery("PRAGMA table_info(order_table);");
      if (orderTableInfo.any((col) => col['name'] == 'order_dscount_percent')) {
        newOrderMap['order_dscount_percent'] = storedPercent;
      }
      final orderId = await txn.insert('order_table', newOrderMap);

      // 3. Insert clean line items
      for (var c in cleanCartItems) {
        await txn.insert('order_items_table', {
          'order_id': orderId,
          'item_id': c.item.id,
          'item_name': c.item.name,
          'item_price': c.unitPrice,
          'item_quantity': c.quantity,
          'item_discount_amount': 0.0,
          'item_tax_rate': c.item.taxRate,
          'item_type': c.item.itemType,
          'item_kitchen_type': c.item.kitchenType,
          'item_printer_id': 'printer_main',
          'item_status': 'ordered',
          'added_at': now,
        });
      }

      return orderId;
    });
  }

  /// Update existing parcel order items
  Future<void> updateParcelOrder(
    int orderId,
    List<CartItemModel> cartItems, {
    double discountAmount = 0.0,
    bool isPercent = false,
    double percentValue = 0.0,
    double deliveryCharge = 0.0,
    String? orderComments,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Deduplicate / consolidate cart items by item.id so duplicate lines never occur
    final consolidated = <int, CartItemModel>{};
    for (var c in cartItems) {
      if (consolidated.containsKey(c.item.id)) {
        final existing = consolidated[c.item.id]!;
        consolidated[c.item.id] = existing.copyWith(
          quantity: existing.quantity + c.quantity,
          existingQuantity: existing.existingQuantity + c.existingQuantity,
        );
      } else {
        consolidated[c.item.id] = c;
      }
    }
    final cleanCartItems = consolidated.values.toList();
    final orderTax = cleanCartItems.fold(0.0, (sum, c) => sum + (c.totalPrice * (c.item.taxRate / 100.0)));
    final orderNetTotal = cleanCartItems.fold(0.0, (sum, c) => sum + c.totalPrice);
    final effectiveDiscount = calculateDiscount(
      netTotal: orderNetTotal,
      isPercent: isPercent,
      discountAmount: discountAmount,
      percentValue: percentValue,
    );
    final double storedAmount = (!isPercent && effectiveDiscount > 0) ? effectiveDiscount : 0.0;
    final double storedPercent = (isPercent && percentValue > 0) ? percentValue : 0.0;

    final updateData = <String, dynamic>{
      'order_tax': orderTax,
      'order_discount_amount': storedAmount,
      'order_discount_percent': storedPercent,
      'order_discount': effectiveDiscount,
      'order_delivery_charge': deliveryCharge,
    };
    final orderTableInfo = await db.rawQuery("PRAGMA table_info(order_table);");
    if (orderTableInfo.any((col) => col['name'] == 'order_dscount_percent')) {
      updateData['order_dscount_percent'] = storedPercent;
    }
    if (orderComments != null) {
      updateData['order_comments'] = orderComments;
    }

    await db.transaction((txn) async {
      await txn.update(
        'order_table',
        updateData,
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      await txn.delete('order_items_table', where: 'order_id = ?', whereArgs: [orderId]);
      for (var c in cleanCartItems) {
        await txn.insert('order_items_table', {
          'order_id': orderId,
          'item_id': c.item.id,
          'item_name': c.item.name,
          'item_price': c.unitPrice,
          'item_quantity': c.quantity,
          'item_discount_amount': 0.0,
          'item_tax_rate': c.item.taxRate,
          'item_type': c.item.itemType,
          'item_kitchen_type': c.item.kitchenType,
          'item_printer_id': 'printer_main',
          'item_status': 'ordered',
          'added_at': now,
        });
      }
    });
  }

  /// Close parcel order upon customer handover & payment
  Future<void> closeParcelOrder(
    int orderId, {
    String paymentMethod = 'Cash',
    double? discountAmount,
    double? deliveryCharge,
    String? orderComments,
    bool? isPercent,
    double? percentValue,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final items = await db.rawQuery(
      'SELECT item_price, item_quantity, item_tax_rate FROM order_items_table WHERE order_id = ?',
      [orderId],
    );
    final orderTax = items.fold(0.0, (sum, i) => sum + ((i['item_price'] as num) * (i['item_quantity'] as num) * (((i['item_tax_rate'] ?? 5.0) as num).toDouble() / 100.0)));

    final updateMap = <String, dynamic>{
      'order_status': 'completed',
      'order_payment_status': 'paid',
      'order_payment_type': normalizePaymentType(paymentMethod),
      'order_tax': orderTax,
      'settled_at': now,
    };
    if (discountAmount != null) {
      final existingRow = await db.query('order_table', where: 'order_id = ?', whereArgs: [orderId], limit: 1);
      final double existingPercent = existingRow.isNotEmpty
          ? ((existingRow.first['order_discount_percent'] as num?)?.toDouble() ??
             (existingRow.first['order_dscount_percent'] as num?)?.toDouble() ?? 0.0)
          : 0.0;
      final bool effectiveIsPercent = isPercent ?? (existingPercent > 0.0);
      final double effectivePercentValue = percentValue ?? (effectiveIsPercent ? existingPercent : 0.0);
      final double storedAmount = (!effectiveIsPercent && discountAmount > 0) ? discountAmount : 0.0;
      final double storedPercent = (effectiveIsPercent && effectivePercentValue > 0) ? effectivePercentValue : 0.0;
      updateMap['order_discount'] = discountAmount;
      updateMap['order_discount_amount'] = storedAmount;
      updateMap['order_discount_percent'] = storedPercent;
      final orderTableInfo = await db.rawQuery("PRAGMA table_info(order_table);");
      if (orderTableInfo.any((col) => col['name'] == 'order_dscount_percent')) {
        updateMap['order_dscount_percent'] = storedPercent;
      }
    }
    if (deliveryCharge != null) {
      updateMap['order_delivery_charge'] = deliveryCharge;
    }
    if (orderComments != null) {
      updateMap['order_comments'] = orderComments;
    }

    await db.update(
      'order_table',
      updateMap,
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  /// Normalize payment method name to match SQLite CHECK constraint
  static String normalizePaymentType(String paymentMethod) {
    final clean = paymentMethod.trim().toLowerCase();
    if (clean.contains('card')) return 'card';
    if (clean.contains('upi')) return 'upi_qr';
    if (clean.contains('split')) return 'split';
    return 'cash';
  }

  /// Update the payment method for an existing/closed order (Cash, Card, UPI)
  Future<void> updateOrderPaymentMethod(int orderId, String newPaymentMethod) async {
    final db = await database;
    final normalized = normalizePaymentType(newPaymentMethod);
    await db.update(
      'order_table',
      {
        'order_payment_type': normalized,
      },
      where: 'order_id = ?',
      whereArgs: [orderId],
    );
  }

  /// Generate Sales Report (Daily or Weekly) with:
  /// - Total Orders
  /// - Total Revenue
  /// - Total Cash Business
  /// - Total Card Business
  /// - Total UPI Business
  /// - Total Food Business
  /// - Total Drinks Business
  Future<PosReportModel> getSalesReport({
    required ReportPeriod period,
    required DateTime targetDate,
  }) async {
    final db = await database;

    final DateTime startDate;
    final DateTime endDate;
    final DateTime nextPeriodStart;

    if (period == ReportPeriod.daily) {
      startDate = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
      endDate = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);
      nextPeriodStart = startDate.add(const Duration(days: 1));
    } else {
      // Weekly: Monday 00:00:00 to Sunday 23:59:59
      final weekday = targetDate.weekday; // 1 = Monday, 7 = Sunday
      final monday = targetDate.subtract(Duration(days: weekday - 1));
      startDate = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
      final sunday = startDate.add(const Duration(days: 6));
      endDate = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
      nextPeriodStart = startDate.add(const Duration(days: 7));
    }

    final startIso = startDate.toIso8601String();
    final endExclusiveIso = nextPeriodStart.toIso8601String();

    // 1. Fetch completed orders in date range
    final orderRows = await db.rawQuery('''
      SELECT 
        o.order_id,
        o.table_number,
        o.order_type,
        o.order_payment_type,
        COALESCE(NULLIF(o.order_discount, 0.0), o.order_discount_amount, 0.0) AS order_discount,
        o.order_discount_amount,
        o.order_discount_percent,
        COALESCE(o.order_tax, 0.0) AS order_tax,
        COALESCE(o.order_delivery_charge, 0.0) AS order_delivery_charge,
        COALESCE(o.order_comments, '') AS order_comments,
        o.order_date,
        o.settled_at,
        o.customer_phone,
        c.customer_name
      FROM order_table o
      JOIN customer_table c ON o.customer_id = c.customer_id
      WHERE o.order_status = 'completed'
        AND COALESCE(o.settled_at, o.order_date) >= ?
        AND COALESCE(o.settled_at, o.order_date) < ?
      ORDER BY COALESCE(o.settled_at, o.order_date) DESC
    ''', [startIso, endExclusiveIso]);

    if (orderRows.isEmpty) {
      return PosReportModel(
        period: period,
        startDate: startDate,
        endDate: endDate,
        totalOrders: 0,
        totalRevenue: 0.0,
        totalNetSales: 0.0,
        totalTax: 0.0,
        totalDiscount: 0.0,
        totalDeliveryCharge: 0.0,
        totalCashBusiness: 0.0,
        totalCardBusiness: 0.0,
        totalUpiBusiness: 0.0,
        totalFoodBusiness: 0.0,
        totalDrinksBusiness: 0.0,
        completedOrders: const [],
        itemSales: const [],
      );
    }

    // 2. Fetch order items for completed orders in range
    final itemRows = await db.rawQuery('''
      SELECT 
        oi.order_id,
        oi.item_name,
        oi.item_price,
        oi.item_quantity,
        oi.item_type,
        oi.item_discount_amount,
        oi.item_tax_rate,
        c.category_name,
        c.category_type
      FROM order_items_table oi
      JOIN order_table o ON oi.order_id = o.order_id
      LEFT JOIN item_table i ON oi.item_id = i.item_id
      LEFT JOIN category_table c ON i.category_id = c.category_id
      WHERE o.order_status = 'completed'
        AND COALESCE(o.settled_at, o.order_date) >= ?
        AND COALESCE(o.settled_at, o.order_date) < ?
    ''', [startIso, endExclusiveIso]);

    final Map<int, double> orderFoodMap = {};
    final Map<int, double> orderDrinksMap = {};
    final Map<int, double> orderTaxMap = {};
    final Map<int, int> orderItemCountMap = {};

    double totalFoodBusiness = 0.0;
    double totalDrinksBusiness = 0.0;

    // Item-wise sales aggregation
    final Map<String, ItemSalesSummary> itemSalesMap = {};

    for (final row in itemRows) {
      final orderId = row['order_id'] as int;
      final name = row['item_name'] as String;
      final catName = (row['category_name'] as String?) ?? 'General';
      final price = (row['item_price'] as num).toDouble();
      final qty = (row['item_quantity'] as num).toInt();
      final discount = (row['item_discount_amount'] as num?)?.toDouble() ?? 0.0;
      final taxRate = (row['item_tax_rate'] as num?)?.toDouble() ?? 5.0;
      final lineTotal = math.max(0.0, (price * qty) - discount);
      final lineTax = lineTotal * (taxRate / 100.0);

      final catType = (row['category_type'] as String? ?? '').toLowerCase();
      final itemType = (row['item_type'] as String? ?? '').toLowerCase();

      final isDrink = catType == 'drinks' || itemType == 'beverage';

      if (isDrink) {
        totalDrinksBusiness += lineTotal;
        orderDrinksMap[orderId] = (orderDrinksMap[orderId] ?? 0.0) + lineTotal;
      } else {
        totalFoodBusiness += lineTotal;
        orderFoodMap[orderId] = (orderFoodMap[orderId] ?? 0.0) + lineTotal;
      }

      orderTaxMap[orderId] = (orderTaxMap[orderId] ?? 0.0) + lineTax;
      orderItemCountMap[orderId] = (orderItemCountMap[orderId] ?? 0) + qty;

      if (itemSalesMap.containsKey(name)) {
        final existing = itemSalesMap[name]!;
        itemSalesMap[name] = ItemSalesSummary(
          itemName: name,
          categoryName: existing.categoryName.isNotEmpty ? existing.categoryName : catName,
          quantitySold: existing.quantitySold + qty,
          totalRevenue: existing.totalRevenue + lineTotal,
        );
      } else {
        itemSalesMap[name] = ItemSalesSummary(
          itemName: name,
          categoryName: catName,
          quantitySold: qty,
          totalRevenue: lineTotal,
        );
      }
    }

    final itemSalesList = itemSalesMap.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

    double totalCashBusiness = 0.0;
    double totalCardBusiness = 0.0;
    double totalUpiBusiness = 0.0;
    double totalRevenue = 0.0;
    double totalNetSales = 0.0;
    double totalDiscount = 0.0;
    double totalTax = 0.0;
    double totalDeliveryCharge = 0.0;

    final List<CompletedOrderSummary> summaries = [];

    for (final o in orderRows) {
      final orderId = o['order_id'] as int;
      final paymentType = normalizePaymentType(o['order_payment_type'] as String? ?? 'cash');
      final foodAmt = orderFoodMap[orderId] ?? 0.0;
      final drinksAmt = orderDrinksMap[orderId] ?? 0.0;
      final orderDiscount = (o['order_discount'] as num?)?.toDouble() ?? (o['order_discount_amount'] as num?)?.toDouble() ?? 0.0;
      final delCharge = (o['order_delivery_charge'] as num?)?.toDouble() ?? 0.0;
      final comments = (o['order_comments'] as String?) ?? '';
      final netAmt = foodAmt + drinksAmt;

      final dbTax = (o['order_tax'] as num?)?.toDouble() ?? 0.0;
      final computedTax = orderTaxMap[orderId] ?? 0.0;
      final taxAmt = dbTax > 0 ? dbTax : computedTax;

      // Formula from Sam Biswas: Order Total / Total Business = Net Total + Tax + Delivery Charge - Discount
      final orderTotal = math.max(0.0, (netAmt + taxAmt + delCharge) - orderDiscount);

      totalRevenue += orderTotal; // Net + Tax + Del Charge - Discount is the total business
      totalNetSales += netAmt;
      totalDiscount += orderDiscount;
      totalTax += taxAmt;
      totalDeliveryCharge += delCharge;

      if (paymentType == 'card') {
        totalCardBusiness += orderTotal;
      } else if (paymentType == 'upi_qr') {
        totalUpiBusiness += orderTotal;
      } else {
        totalCashBusiness += orderTotal;
      }

      final dateStr = (o['settled_at'] as String?) ?? (o['order_date'] as String);
      final settledDate = DateTime.tryParse(dateStr) ?? DateTime.now();
      final orderDate = DateTime.tryParse(o['order_date'] as String) ?? settledDate;

      summaries.add(CompletedOrderSummary(
        orderId: orderId,
        orderType: o['order_type'] as String? ?? 'sitdown',
        tableNumber: (o['table_number'] as num?)?.toInt() ?? 0,
        customerName: o['customer_name'] as String? ?? 'Guest',
        customerPhone: o['customer_phone'] as String? ?? '',
        paymentType: paymentType,
        totalAmount: orderTotal,
        netAmount: netAmt,
        discountAmount: orderDiscount,
        deliveryCharge: delCharge,
        taxAmount: taxAmt,
        orderComments: comments,
        foodAmount: foodAmt,
        drinksAmount: drinksAmt,
        orderDate: orderDate,
        settledAt: settledDate,
        itemCount: orderItemCountMap[orderId] ?? 0,
      ));
    }

    return PosReportModel(
      period: period,
      startDate: startDate,
      endDate: endDate,
      totalOrders: orderRows.length,
      totalRevenue: totalRevenue,
      totalNetSales: totalNetSales,
      totalDiscount: totalDiscount,
      totalTax: totalTax,
      totalDeliveryCharge: totalDeliveryCharge,
      totalCashBusiness: totalCashBusiness,
      totalCardBusiness: totalCardBusiness,
      totalUpiBusiness: totalUpiBusiness,
      totalFoodBusiness: totalFoodBusiness,
      totalDrinksBusiness: totalDrinksBusiness,
      completedOrders: summaries,
      itemSales: itemSalesList,
    );
  }
}

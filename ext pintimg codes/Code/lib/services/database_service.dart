import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  static bool _initialized = false;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  void _log(String operation, String message) {
    print('Database Operation - $operation: $message');
  }

  void _logError(String operation, dynamic error) {
    print('Database Error in $operation:');
    print('Error details: $error');
    print('Stack trace: ${StackTrace.current}');
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    
    try {
      _log('init', 'Initializing database');
      _database = await _initDatabase();
      _initialized = true;
      _log('init', 'Database initialized successfully');
      return _database!;
    } catch (e) {
      _logError('init', e);
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, 'shop_database.db');

      _log('init', 'Database path: $path');

      // Ensure the directory exists
      if (!await Directory(dirname(path)).exists()) {
        await Directory(dirname(path)).create(recursive: true);
        _log('init', 'Created database directory');
      }

      return await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onOpen: (db) async {
          _log('init', 'Database opened');
          // Verify the table exists
          var tables = await db.query('sqlite_master', 
              where: 'type = ? AND name = ?',
              whereArgs: ['table', 'shop']);
          if (tables.isEmpty) {
            _log('init', 'Shop table not found, creating it');
            await _onCreate(db, 1);
          } else {
            _log('init', 'Shop table exists');
          }
        },
      );
    } catch (e) {
      _logError('_initDatabase', e);
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      _log('onCreate', 'Creating shop table');
      await db.execute('''
        CREATE TABLE shop (
          id TEXT PRIMARY KEY,
          employeePhone TEXT,
          employeePin TEXT
        )
      ''');
      
      // Insert default values if table is empty
      var count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM shop'));
      if (count == 0) {
        _log('onCreate', 'Inserting default values');
        await db.insert('shop', {
          'id': '',
          'employeePhone': '',
          'employeePin': ''
        });
      }
      _log('onCreate', 'Table created successfully');
    } catch (e) {
      _logError('_onCreate', e);
      rethrow;
    }
  }

  Future<void> saveShopId(String shopId) async {
    try {
      _log('saveShopId', 'Saving App ID: $shopId');
      final db = await database;
      await db.transaction((txn) async {
        // Get existing values
        final List<Map<String, dynamic>> maps = await txn.query('shop');
        final String employeePhone = maps.isNotEmpty ? maps.first['employeePhone'] ?? '' : '';
        final String employeePin = maps.isNotEmpty ? maps.first['employeePin'] ?? '' : '';
        
        // Update with new shopId while preserving other fields
        await txn.delete('shop');
        await txn.insert('shop', {
          'id': shopId,
          'employeePhone': employeePhone,
          'employeePin': employeePin
        });
      });
      _log('saveShopId', 'App ID saved successfully');
    } catch (e) {
      _logError('saveShopId', e);
      rethrow;
    }
  }

  Future<String?> getShopId() async {
    try {
      _log('getShopId', 'Retrieving App ID');
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('shop');
      if (maps.isNotEmpty) {
        final id = maps.first['id'] as String?;
        _log('getShopId', 'Retrieved App ID: $id');
        return id;
      }
      _log('getShopId', 'No App ID found');
      return null;
    } catch (e) {
      _logError('getShopId', e);
      rethrow;
    }
  }

  Future<void> saveEmployeePhone(String phone) async {
    try {
      _log('saveEmployeePhone', 'Saving Phone Number: $phone');
      final db = await database;
      await db.transaction((txn) async {
        await txn.update('shop', {'employeePhone': phone});
      });
      _log('saveEmployeePhone', 'Phone Number saved successfully');
    } catch (e) {
      _logError('saveEmployeePhone', e);
      rethrow;
    }
  }

  Future<String?> getEmployeePhone() async {
    try {
      _log('getEmployeePhone', 'Retrieving Phone Number');
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('shop');
      if (maps.isNotEmpty) {
        final phone = maps.first['employeePhone'] as String?;
        _log('getEmployeePhone', 'Retrieved Phone Number: $phone');
        return phone;
      }
      _log('getEmployeePhone', 'No Phone Number found');
      return null;
    } catch (e) {
      _logError('getEmployeePhone', e);
      rethrow;
    }
  }

  Future<void> saveEmployeePin(String username) async {
    try {
      _log('saveEmployeePin', 'Saving Username: $username');
      final db = await database;
      await db.transaction((txn) async {
        await txn.update('shop', {'employeePin': username});
      });
      _log('saveEmployeePin', 'Username saved successfully');
    } catch (e) {
      _logError('saveEmployeePin', e);
      rethrow;
    }
  }

  Future<String?> getEmployeePin() async {
    try {
      _log('getEmployeePin', 'Retrieving Username');
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('shop');
      if (maps.isNotEmpty) {
        final username = maps.first['employeePin'] as String?;
        _log('getEmployeePin', 'Retrieved Username: $username');
        return username;
      }
      _log('getEmployeePin', 'No Username found');
      return null;
    } catch (e) {
      _logError('getEmployeePin', e);
      rethrow;
    }
  }

  Future<void> resetDatabase() async {
    try {
      _log('resetDatabase', 'Resetting database');
      if (_database != null) {
        await _database!.close();
        _database = null;
      }
      _initialized = false;
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, 'shop_database.db');
      await deleteDatabase(path);
      _log('resetDatabase', 'Database reset successfully');
    } catch (e) {
      _logError('resetDatabase', e);
      rethrow;
    }
  }
}
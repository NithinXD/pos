import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../database/pos_database.dart';
import '../models/menu_item_model.dart';
import '../models/restaurant_model.dart';
import '../models/report_model.dart';

enum PrinterConnectionMode {
  rawbt,
  bluetoothDirect,
  usbDirect,
  wifiDirect,
}

class PrinterResult {
  final bool success;
  final String message;
  final bool isRawBtMissing;
  final String formattedText;

  const PrinterResult({
    required this.success,
    required this.message,
    this.isRawBtMissing = false,
    required this.formattedText,
  });
}

class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  static const MethodChannel _rawbtChannel = MethodChannel('rawbt.intent.channel');
  static const MethodChannel _directChannel = MethodChannel('direct.printer.channel');

  /// Global selectable printer connection mode (defaults to rawbt, switchable at runtime)
  static PrinterConnectionMode activeMode = PrinterConnectionMode.rawbt;

  /// Selected Bluetooth device address & name
  static String? selectedBluetoothAddress;
  static String? selectedBluetoothName;

  /// Selected USB device id & name
  static int? selectedUsbDeviceId;
  static String? selectedUsbDeviceName;

  /// WiFi / Network printer IP and Port
  static String wifiPrinterIp = '192.168.1.100';
  static int wifiPrinterPort = 9100;

  static bool _hasLoadedPersistedSettings = false;

  /// Initialize and load saved printer configuration once from SQLite
  static Future<void> loadPersistedSettings() async {
    if (_hasLoadedPersistedSettings) return;
    try {
      final savedMode = await PosDatabase.instance.getSetting('printer_active_mode');
      if (savedMode != null) {
        activeMode = PrinterConnectionMode.values.firstWhere(
          (m) => m.name == savedMode,
          orElse: () => PrinterConnectionMode.rawbt,
        );
      }
      final savedBtAddr = await PosDatabase.instance.getSetting('printer_bt_address');
      if (savedBtAddr != null && savedBtAddr.isNotEmpty) {
        selectedBluetoothAddress = savedBtAddr;
      }
      final savedBtName = await PosDatabase.instance.getSetting('printer_bt_name');
      if (savedBtName != null && savedBtName.isNotEmpty) {
        selectedBluetoothName = savedBtName;
      }
      _hasLoadedPersistedSettings = true;
    } catch (e) {
      debugPrint('Error loading persisted printer settings: $e');
    }
  }

  /// Save current printer settings to SQLite so user never has to re-select
  static Future<void> persistSettings({
    PrinterConnectionMode? mode,
    String? btAddress,
    String? btName,
  }) async {
    try {
      if (mode != null) {
        activeMode = mode;
        await PosDatabase.instance.saveSetting('printer_active_mode', mode.name);
      }
      if (btAddress != null) {
        selectedBluetoothAddress = btAddress;
        await PosDatabase.instance.saveSetting('printer_bt_address', btAddress);
      }
      if (btName != null) {
        selectedBluetoothName = btName;
        await PosDatabase.instance.saveSetting('printer_bt_name', btName);
      }
    } catch (e) {
      debugPrint('Error persisting printer settings: $e');
    }
  }

  /// Retrieve list of paired Bluetooth thermal printers
  static Future<List<Map<String, String>>> getPairedBluetoothPrinters() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final List<dynamic>? list =
            await _directChannel.invokeMethod<List<dynamic>>('getBluetoothDevices');
        if (list != null) {
          return list.map((e) => Map<String, String>.from(e as Map)).toList();
        }
      } catch (e) {
        debugPrint('Error retrieving Bluetooth printers: $e');
      }
    }
    return [];
  }

  /// Retrieve list of attached USB thermal printers
  static Future<List<Map<String, dynamic>>> getAttachedUsbPrinters() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final List<dynamic>? list =
            await _directChannel.invokeMethod<List<dynamic>>('getUsbPrinters');
        if (list != null) {
          return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (e) {
        debugPrint('Error retrieving USB printers: $e');
      }
    }
    return [];
  }

  /// 32 characters for 58mm (2 inch) thermal printers, 42/48 for 80mm (3 inch)
  static const int defaultWidth = 32;

  /// ESC/POS Paper Cut command (GS V 1 - partial cut)
  static const String escCut = '\x1D\x56\x01';

  // -------------------------------------------------------------
  // String Formatting Helpers for Monospace Thermal Printers
  // -------------------------------------------------------------

  static String center(String text, [int width = defaultWidth]) {
    if (text.length >= width) return text;
    final leftPad = (width - text.length) ~/ 2;
    return ' ' * leftPad + text;
  }

  static String divider([String char = '-', int width = defaultWidth]) {
    return char * width;
  }

  static String row(String left, String right, [int width = defaultWidth]) {
    if (left.length + right.length >= width) {
      final maxLeft = width - right.length - 1;
      if (maxLeft > 0) {
        left = '${left.substring(0, maxLeft)} ';
      } else {
        left = '${left.substring(0, 3)} ';
      }
    }
    final spaces = width - left.length - right.length;
    return left + (' ' * (spaces > 0 ? spaces : 1)) + right;
  }

  // -------------------------------------------------------------
  // KOT (Kitchen Order Ticket) Builder
  // -------------------------------------------------------------

  String formatKotTicket({
    required String restaurantName,
    required String tableName,
    required List<CartItemModel> items,
    required bool isRunningKot,
    int? orderId,
    DateTime? timestamp,
    String? customerName,
    String? customerPhone,
    String? orderTypeLabel,
    String? kotSection,
    int width = defaultWidth,
  }) {
    final now = timestamp ?? DateTime.now();
    final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(now);
    final buffer = StringBuffer();

    final cleanLabel = (orderTypeLabel ?? '').toLowerCase();
    final isParcel = cleanLabel.contains('parcel') ||
        cleanLabel.contains('takeaway') ||
        tableName.toLowerCase().contains('parcel');
    final normalizedType = isParcel ? 'PARCEL ORDER' : 'SITDOWN ORDER';

    // ESC/POS command for double width + double height font (GS ! 0x11)
    const escDoubleSize = '\x1D\x21\x11';
    const escNormalSize = '\x1D\x21\x00';
    const escBoldOn = '\x1B\x45\x01';
    const escBoldOff = '\x1B\x45\x00';

    final sectionTitle = kotSection != null
        ? 'KITCHEN ORDER TICKET ($kotSection)'
        : 'KITCHEN ORDER TICKET';

    buffer.writeln(divider('=', width));
    buffer.writeln(center(sectionTitle, width));
    buffer.writeln(center(isRunningKot ? '(RUNNING KOT)' : '(NEW KOT)', width));
    buffer.writeln(divider('=', width));

    // Prominent Large-font Order Type Banner
    buffer.writeln('$escDoubleSize${center(normalizedType, (width / 2).floor())}$escNormalSize');
    buffer.writeln(center('*** $normalizedType ***', width));
    buffer.writeln(divider('=', width));

    if (restaurantName.isNotEmpty) {
      buffer.writeln(row('Restaurant:', restaurantName, width));
    }
    if (orderId != null && orderId > 0) {
      buffer.writeln(row('Order / KOT #:', '#$orderId', width));
    }
    buffer.writeln(row('Time:', timeStr, width));
    buffer.writeln(row('Destination:', tableName, width));
    buffer.writeln(row('Order Type:', normalizedType, width));

    // Prominent Large-font Destination Banner (e.g., Table 4 or Parcel) for Kitchen Staff
    buffer.writeln(divider('-', width));
    buffer.writeln('$escDoubleSize${center(tableName.toUpperCase(), (width / 2).floor())}$escNormalSize');

    if (customerName != null && customerName.isNotEmpty) {
      buffer.writeln(row('Customer:', customerName, width));
    }
    if (customerPhone != null &&
        customerPhone.isNotEmpty &&
        !customerPhone.startsWith('100000000')) {
      buffer.writeln(row('Phone:', customerPhone, width));
    }

    buffer.writeln(divider('-', width));
    buffer.writeln(row('ITEM', 'QTY', width));
    buffer.writeln(divider('-', width));

    final newItems = items
        .where((c) => !c.isExisting || (c.isExisting && c.newQuantity > 0))
        .toList();

    int totalPreparingCount = 0;

    if (isRunningKot && newItems.isNotEmpty) {
      buffer.writeln('$escBoldOn>> NEW ITEMS TO PREPARE <<$escBoldOff');
      for (final c in newItems) {
        final qty = c.isExisting ? c.newQuantity : c.quantity;
        totalPreparingCount += qty;
        buffer.writeln('$escDoubleSize$qty x ${c.item.name}$escNormalSize');
        buffer.writeln(row('   ↳ Status:', '$qty [NEW]', width));
        if (c.notes != null && c.notes!.trim().isNotEmpty) {
          buffer.writeln('$escBoldOn   Note: ${c.notes!.trim()}$escBoldOff');
        }
        buffer.writeln(divider('-', width));
      }
    } else {
      for (final c in items) {
        totalPreparingCount += c.quantity;
        buffer.writeln('$escDoubleSize${c.quantity} x ${c.item.name}$escNormalSize');
        if (c.notes != null && c.notes!.trim().isNotEmpty) {
          buffer.writeln('$escBoldOn   Note: ${c.notes!.trim()}$escBoldOff');
        }
        buffer.writeln(divider('-', width));
      }
    }

    buffer.writeln(divider('-', width));
    buffer.writeln(row('ITEMS TO COOK:', '$totalPreparingCount', width));
    buffer.writeln(divider('=', width));
    final footerText = kotSection == 'DRINKS'
        ? '*** BAR COPY (DRINKS) ***'
        : (kotSection == 'FOOD' ? '*** CHEF COPY (FOOD) ***' : '*** CHEF COPY ***');
    buffer.writeln(center(footerText, width));
    buffer.writeln('\n\n\n\n$escCut'); // Line feeds for paper tear-off + auto cut

    return buffer.toString();
  }

  // -------------------------------------------------------------
  // Customer Bill / Receipt Builder
  // -------------------------------------------------------------

  String formatBillReceipt({
    required RestaurantModel restaurant,
    required String destinationName,
    required List<CartItemModel> items,
    required double total,
    required String paymentMethod,
    int? orderId,
    DateTime? timestamp,
    String? customerName,
    String? customerPhone,
    double? foodTotal,
    double? drinksTotal,
    double? taxTotal,
    double? netTotal,
    double? discountAmount,
    double? deliveryCharge,
    int width = defaultWidth,
  }) {
    final now = timestamp ?? DateTime.now();
    final timeStr = DateFormat('dd/MM/yyyy HH:mm').format(now);
    final buffer = StringBuffer();
    final currency = restaurant.currency;

    buffer.writeln(divider('=', width));
    buffer.writeln(center(restaurant.name.toUpperCase(), width));
    if (restaurant.address.isNotEmpty) {
      buffer.writeln(center(restaurant.address, width));
    }
    if (restaurant.phone.isNotEmpty) {
      buffer.writeln(center('Phone: ${restaurant.phone}', width));
    }
    buffer.writeln(divider('=', width));
    buffer.writeln(center('RETAIL INVOICE', width));
    buffer.writeln(divider('-', width));

    if (orderId != null && orderId > 0) {
      buffer.writeln(row('Invoice #:', '#$orderId', width));
    }
    buffer.writeln(row('Date & Time:', timeStr, width));
    buffer.writeln(row('Table / Mode:', destinationName, width));
    if (customerName != null && customerName.isNotEmpty) {
      buffer.writeln(row('Customer:', customerName, width));
    }
    if (customerPhone != null &&
        customerPhone.isNotEmpty &&
        !customerPhone.startsWith('100000000')) {
      buffer.writeln(row('Phone:', customerPhone, width));
    }

    buffer.writeln(divider('-', width));
    buffer.writeln(row('ITEM x QTY', 'AMOUNT', width));
    buffer.writeln(divider('-', width));

    int totalQty = 0;
    double computedFood = 0.0;
    double computedDrinks = 0.0;
    double computedTax = 0.0;

    for (final c in items) {
      totalQty += c.quantity;
      final lineLeft = '${c.item.name} x${c.quantity}';
      final lineRight = '$currency${c.totalPrice.toStringAsFixed(2)}';
      buffer.writeln(row(lineLeft, lineRight, width));

      final isDrink = c.item.isBeverage ||
          c.item.kitchenType == 'bar' ||
          c.item.categoryName.toLowerCase().contains('drink') ||
          c.item.categoryName.toLowerCase().contains('beverage');
      if (isDrink) {
        computedDrinks += c.totalPrice;
      } else {
        computedFood += c.totalPrice;
      }
      computedTax += (c.totalPrice * (c.item.taxRate / 100.0));
    }

    final finalFood = foodTotal ?? computedFood;
    final finalDrinks = drinksTotal ?? computedDrinks;
    final finalTax = taxTotal ?? computedTax;
    final finalDiscount = discountAmount ?? 0.0;
    final finalDelivery = deliveryCharge ?? 0.0;
    final finalNet = netTotal ?? (total > finalTax ? total - finalTax : total);
    final finalBillAmount = ((finalNet - finalDiscount) + finalTax + finalDelivery).clamp(0.0, double.infinity);

    buffer.writeln(divider('-', width));
    buffer.writeln(row('Total Items:', '$totalQty', width));
    buffer.writeln(row('Payment Method:', paymentMethod.toUpperCase(), width));
    buffer.writeln(divider('-', width));
    if (finalFood > 0) {
      buffer.writeln(row('Food Total:', '$currency${finalFood.toStringAsFixed(2)}', width));
    }
    if (finalDrinks > 0) {
      buffer.writeln(row('Drinks Total:', '$currency${finalDrinks.toStringAsFixed(2)}', width));
    }
    buffer.writeln(row('Net Total:', '$currency${finalNet.toStringAsFixed(2)}', width));
    if (finalDiscount > 0) {
      buffer.writeln(row('Discount:', '-$currency${finalDiscount.toStringAsFixed(2)}', width));
    }
    if (finalDelivery > 0) {
      buffer.writeln(row('Delivery Charge:', '$currency${finalDelivery.toStringAsFixed(2)}', width));
    }
    buffer.writeln(row('Total Tax:', '$currency${finalTax.toStringAsFixed(2)}', width));
    buffer.writeln(divider('-', width));
    buffer.writeln(row('TOTAL PAYABLE:', '$currency${finalBillAmount.toStringAsFixed(2)}', width));
    buffer.writeln(divider('=', width));
    buffer.writeln(center('Thank you for dining with us!', width));
    buffer.writeln(center('Please Visit Again', width));
    if (restaurant.gstnNumber.trim().isNotEmpty) {
      buffer.writeln(divider('-', width));
      buffer.writeln(center('GSTIN: ${restaurant.gstnNumber.trim()}', width));
    }
    buffer.writeln('\n\n\n\n$escCut'); // Line feeds + ESC/POS Paper Cut

    return buffer.toString();
  }

  // -------------------------------------------------------------
  // Test Ticket Builder
  // -------------------------------------------------------------

  String formatTestTicket({
    RestaurantModel? restaurant,
    int width = defaultWidth,
  }) {
    final buffer = StringBuffer();
    final name = restaurant?.name.isNotEmpty == true ? restaurant!.name : 'POS System';
    final timeStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

    buffer.writeln(divider('=', width));
    buffer.writeln(center('THERMAL PRINTER TEST', width));
    buffer.writeln(divider('=', width));
    buffer.writeln(center(name, width));
    buffer.writeln(row('Status:', 'ONLINE / READY', width));
    buffer.writeln(row('Interface:', 'RawBT Print Service', width));
    buffer.writeln(row('Date/Time:', timeStr, width));
    buffer.writeln(divider('-', width));
    buffer.writeln(center('12345678901234567890123456789012', width));
    buffer.writeln(center('Bluetooth / USB / WiFi ESC/POS', width));
    buffer.writeln(divider('=', width));
    buffer.writeln(center('PRINTER TEST SUCCESSFUL', width));
    buffer.writeln('\n\n\n\n$escCut'); // Line feeds + ESC/POS Paper Cut

    return buffer.toString();
  }

  // -------------------------------------------------------------
  // Print Execution via RawBT MethodChannel
  // -------------------------------------------------------------

  /// Universal printRawText supporting toggle between RawBT, Bluetooth Direct, USB Direct, and WiFi Socket
  Future<PrinterResult> printRawText(String text, {String docTitle = 'Receipt'}) async {
    await loadPersistedSettings();
    if (!kIsWeb && Platform.isAndroid) {
      switch (activeMode) {
        // Mode 1: Legacy RawBT app intent dispatch
        case PrinterConnectionMode.rawbt:
          try {
            final result = await _rawbtChannel.invokeMethod<String>('sendToRawBT', {
              'text': text,
              'type': 'text/plain',
            });
            debugPrint('RawBT print dispatch result: $result');
            return PrinterResult(
              success: true,
              message: 'Printed successfully via RawBT',
              formattedText: text,
            );
          } on PlatformException catch (e) {
            final isMissing = e.code == 'UNAVAILABLE' ||
                (e.message != null && e.message!.toLowerCase().contains('not found'));
            return PrinterResult(
              success: false,
              message: isMissing
                  ? 'RawBT printer app is not installed on this Android device.'
                  : 'RawBT error: ${e.message}',
              isRawBtMissing: isMissing,
              formattedText: text,
            );
          } catch (e) {
            return PrinterResult(
              success: false,
              message: 'RawBT dispatch error: $e',
              formattedText: text,
            );
          }

        // Mode 2: Direct Bluetooth SPP (Zero RawBT)
        case PrinterConnectionMode.bluetoothDirect:
          try {
            var address = selectedBluetoothAddress;
            if (address == null || address.isEmpty) {
              final paired = await getPairedBluetoothPrinters();
              if (paired.isNotEmpty) {
                address = paired.first['address'];
                selectedBluetoothAddress = address;
                selectedBluetoothName = paired.first['name'];
                persistSettings(btAddress: address, btName: selectedBluetoothName);
              }
            }

            if (address == null || address.isEmpty) {
              return PrinterResult(
                success: false,
                message: 'No paired Bluetooth printer selected. Pair printer in Android Bluetooth Settings first.',
                formattedText: text,
              );
            }

            final List<int> bytes = [];
            bytes.addAll([0x1B, 0x40]);
            bytes.addAll(text.codeUnits);
            bytes.addAll([0x0A, 0x0A, 0x0A, 0x1D, 0x56, 0x01]);

            final result = await _directChannel.invokeMethod<String>('printBluetoothDirect', {
              'address': address,
              'bytes': Uint8List.fromList(bytes),
            });

            return PrinterResult(
              success: true,
              message: result ?? 'Printed directly via Bluetooth (${selectedBluetoothName ?? address})',
              formattedText: text,
            );
          } catch (e) {
            return PrinterResult(
              success: false,
              message: 'Direct Bluetooth print error: $e',
              formattedText: text,
            );
          }

        // Mode 3: Direct USB Host OTG (Zero RawBT)
        case PrinterConnectionMode.usbDirect:
          try {
            var deviceId = selectedUsbDeviceId;
            if (deviceId == null) {
              final printers = await getAttachedUsbPrinters();
              if (printers.isNotEmpty) {
                deviceId = printers.first['deviceId'] as int?;
                selectedUsbDeviceId = deviceId;
                selectedUsbDeviceName = printers.first['name'] as String?;
              }
            }

            if (deviceId == null) {
              return PrinterResult(
                success: false,
                message: 'No USB thermal printer detected. Connect via USB OTG cable.',
                formattedText: text,
              );
            }

            final List<int> bytes = [];
            bytes.addAll([0x1B, 0x40]);
            bytes.addAll(text.codeUnits);
            bytes.addAll([0x0A, 0x0A, 0x0A, 0x1D, 0x56, 0x01]);

            final result = await _directChannel.invokeMethod<String>('printUsbDirect', {
              'deviceId': deviceId,
              'bytes': Uint8List.fromList(bytes),
            });

            return PrinterResult(
              success: true,
              message: result ?? 'Printed directly via USB (${selectedUsbDeviceName ?? "Device #$deviceId"})',
              formattedText: text,
            );
          } catch (e) {
            return PrinterResult(
              success: false,
              message: 'Direct USB print error: $e',
              formattedText: text,
            );
          }

        // Mode 4: Direct WiFi / Network TCP Socket (Port 9100)
        case PrinterConnectionMode.wifiDirect:
          try {
            final socket = await Socket.connect(wifiPrinterIp, wifiPrinterPort,
                timeout: const Duration(seconds: 4));
            final List<int> bytes = [];
            bytes.addAll([0x1B, 0x40]);
            bytes.addAll(text.codeUnits);
            bytes.addAll([0x0A, 0x0A, 0x0A, 0x1D, 0x56, 0x01]);
            socket.add(bytes);
            await socket.flush();
            await socket.close();
            return PrinterResult(
              success: true,
              message: 'Printed directly via WiFi socket to $wifiPrinterIp:$wifiPrinterPort',
              formattedText: text,
            );
          } catch (e) {
            return PrinterResult(
              success: false,
              message: 'WiFi printer connection failed to $wifiPrinterIp:$wifiPrinterPort ($e)',
              formattedText: text,
            );
          }
      }
    } else {
      // Non-Android platforms (e.g. Windows desktop during development/testing)
      debugPrint('================= UNIVERSAL PRINTER OUTPUT ($activeMode - ${Platform.operatingSystem}) =================');
      debugPrint(text);
      debugPrint('========================================================================================================');
      return PrinterResult(
        success: true,
        message: 'Simulated print [$activeMode] on ${Platform.operatingSystem}',
        formattedText: text,
      );
    }
  }

  /// Helper to classify if a cart item is a Beverage / Drink / Bar item
  static bool isDrinkItem(CartItemModel c) {
    final cat = c.item.categoryName.toLowerCase();
    final kt = c.item.kitchenType.toLowerCase();
    return c.item.isBeverage ||
        kt == 'bar' ||
        cat.contains('drink') ||
        cat.contains('beverage') ||
        cat.contains('bar') ||
        cat.contains('juice') ||
        cat.contains('cocktail') ||
        cat.contains('mocktail') ||
        cat.contains('liquor') ||
        cat.contains('wine') ||
        cat.contains('beer');
  }

  /// Print a KOT ticket (unified or separate Food & Drinks KOTs based on database configuration or parameter)
  Future<PrinterResult> printKot({
    required String restaurantName,
    required String tableName,
    required List<CartItemModel> items,
    required bool isRunningKot,
    int? orderId,
    DateTime? timestamp,
    String? customerName,
    String? customerPhone,
    String? orderTypeLabel,
    bool? printKotSeparate,
  }) async {
    bool shouldSplit = printKotSeparate ?? false;
    if (printKotSeparate == null) {
      try {
        final rest = await PosDatabase.instance.getRestaurantDetails();
        shouldSplit = rest.printKotSeparate;
      } catch (_) {
        shouldSplit = false;
      }
    }

    if (shouldSplit) {
      final foodItems = items.where((c) => !isDrinkItem(c)).toList();
      final drinkItems = items.where((c) => isDrinkItem(c)).toList();

      final newFood = foodItems
          .where((c) => !c.isExisting || (c.isExisting && c.newQuantity > 0))
          .toList();
      final newDrinks = drinkItems
          .where((c) => !c.isExisting || (c.isExisting && c.newQuantity > 0))
          .toList();

      final bool printFood;
      final bool printDrinks;

      if (isRunningKot && (newFood.isNotEmpty || newDrinks.isNotEmpty)) {
        printFood = newFood.isNotEmpty;
        printDrinks = newDrinks.isNotEmpty;
      } else {
        printFood = foodItems.isNotEmpty;
        printDrinks = drinkItems.isNotEmpty;
      }

      if (printFood && printDrinks) {
        final foodTicket = formatKotTicket(
          restaurantName: restaurantName,
          tableName: tableName,
          items: foodItems,
          isRunningKot: isRunningKot,
          orderId: orderId,
          timestamp: timestamp,
          customerName: customerName,
          customerPhone: customerPhone,
          orderTypeLabel: orderTypeLabel,
          kotSection: 'FOOD',
        );
        final foodRes = await printRawText(foodTicket, docTitle: 'KOT Food - $tableName');

        // Allow printer buffer to complete first ticket cut
        await Future.delayed(const Duration(milliseconds: 250));

        final drinksTicket = formatKotTicket(
          restaurantName: restaurantName,
          tableName: tableName,
          items: drinkItems,
          isRunningKot: isRunningKot,
          orderId: orderId,
          timestamp: timestamp,
          customerName: customerName,
          customerPhone: customerPhone,
          orderTypeLabel: orderTypeLabel,
          kotSection: 'DRINKS',
        );
        final drinksRes = await printRawText(drinksTicket, docTitle: 'KOT Drinks - $tableName');

        return PrinterResult(
          success: foodRes.success && drinksRes.success,
          message: foodRes.success && drinksRes.success
              ? 'Food & Drinks KOTs printed separately'
              : (!foodRes.success ? foodRes.message : drinksRes.message),
          isRawBtMissing: foodRes.isRawBtMissing || drinksRes.isRawBtMissing,
          formattedText: '${foodRes.formattedText}\n--- CUT / NEXT TICKET ---\n${drinksRes.formattedText}',
        );
      } else if (printFood) {
        final foodTicket = formatKotTicket(
          restaurantName: restaurantName,
          tableName: tableName,
          items: foodItems,
          isRunningKot: isRunningKot,
          orderId: orderId,
          timestamp: timestamp,
          customerName: customerName,
          customerPhone: customerPhone,
          orderTypeLabel: orderTypeLabel,
          kotSection: 'FOOD',
        );
        return await printRawText(foodTicket, docTitle: 'KOT Food - $tableName');
      } else if (printDrinks) {
        final drinksTicket = formatKotTicket(
          restaurantName: restaurantName,
          tableName: tableName,
          items: drinkItems,
          isRunningKot: isRunningKot,
          orderId: orderId,
          timestamp: timestamp,
          customerName: customerName,
          customerPhone: customerPhone,
          orderTypeLabel: orderTypeLabel,
          kotSection: 'DRINKS',
        );
        return await printRawText(drinksTicket, docTitle: 'KOT Drinks - $tableName');
      }
    }

    final ticket = formatKotTicket(
      restaurantName: restaurantName,
      tableName: tableName,
      items: items,
      isRunningKot: isRunningKot,
      orderId: orderId,
      timestamp: timestamp,
      customerName: customerName,
      customerPhone: customerPhone,
      orderTypeLabel: orderTypeLabel,
    );
    return await printRawText(ticket, docTitle: 'KOT - $tableName');
  }

  /// Print a Customer Bill
  Future<PrinterResult> printBill({
    required RestaurantModel restaurant,
    required String destinationName,
    required List<CartItemModel> items,
    required double total,
    required String paymentMethod,
    int? orderId,
    DateTime? timestamp,
    String? customerName,
    String? customerPhone,
    double? foodTotal,
    double? drinksTotal,
    double? taxTotal,
    double? netTotal,
    double? discountAmount,
    double? deliveryCharge,
  }) async {
    final ticket = formatBillReceipt(
      restaurant: restaurant,
      destinationName: destinationName,
      items: items,
      total: total,
      paymentMethod: paymentMethod,
      orderId: orderId,
      timestamp: timestamp,
      customerName: customerName,
      customerPhone: customerPhone,
      foodTotal: foodTotal,
      drinksTotal: drinksTotal,
      taxTotal: taxTotal,
      netTotal: netTotal,
      discountAmount: discountAmount,
      deliveryCharge: deliveryCharge,
    );
    return await printRawText(ticket, docTitle: 'Bill - $destinationName');
  }

  // -------------------------------------------------------------
  // Daily Sales Business Report Ticket Builder
  // -------------------------------------------------------------

  String formatSalesReportTicket({
    required RestaurantModel restaurant,
    required PosReportModel report,
    DateTime? date,
    int width = defaultWidth,
  }) {
    final now = date ?? DateTime.now();
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final buffer = StringBuffer();
    final cur = restaurant.currency;

    buffer.writeln(divider('=', width));
    buffer.writeln(center(restaurant.name.toUpperCase(), width));
    buffer.writeln(center('DAILY SALES REPORT', width));
    buffer.writeln(divider('=', width));
    buffer.writeln(row('Net Sales:', '$cur${report.totalNetSales.toStringAsFixed(2)}', width));
    buffer.writeln(row('Net Tax:', '$cur${report.totalTax.toStringAsFixed(2)}', width));
    buffer.writeln(row('Net Discount:', '$cur${report.totalDiscount.toStringAsFixed(2)}', width));
    buffer.writeln(row('Net Delivery Charge:', '$cur${report.totalDeliveryCharge.toStringAsFixed(2)}', width));
    buffer.writeln(row('Total Business:', '$cur${report.totalRevenue.toStringAsFixed(2)}', width));
    buffer.writeln(divider('-', width));
    buffer.writeln(row('Net Cash:', '$cur${report.totalCash.toStringAsFixed(2)}', width));
    buffer.writeln(row('Net Card:', '$cur${report.totalCard.toStringAsFixed(2)}', width));
    buffer.writeln(row('Net UPI:', '$cur${report.totalUpi.toStringAsFixed(2)}', width));
    buffer.writeln(divider('-', width));
    buffer.writeln(row('Total Business:', '$cur${report.totalRevenue.toStringAsFixed(2)}', width));
    buffer.writeln(row('Date:', dateStr, width));
    if (restaurant.gstnNumber.trim().isNotEmpty) {
      buffer.writeln(divider('-', width));
      buffer.writeln(center('GSTIN: ${restaurant.gstnNumber.trim()}', width));
    }
    buffer.writeln(divider('=', width));
    buffer.writeln(center('*** END OF REPORT ***', width));
    buffer.writeln('\n\n\n\n$escCut'); // Line feeds + ESC/POS Paper Cut

    return buffer.toString();
  }

  /// Print Sales Report via RawBT or share
  Future<PrinterResult> printSalesReport({
    required RestaurantModel restaurant,
    required PosReportModel report,
    DateTime? date,
  }) async {
    final ticket = formatSalesReportTicket(
      restaurant: restaurant,
      report: report,
      date: date,
    );
    return await printRawText(ticket, docTitle: 'Sales Report');
  }

  /// Print Test Ticket
  Future<PrinterResult> printTest({RestaurantModel? restaurant}) async {
    final ticket = formatTestTicket(restaurant: restaurant);
    return await printRawText(ticket, docTitle: 'Thermal Printer Test');
  }

  /// Fallback: Share ticket via system share sheet (WhatsApp, Email, etc.)
  Future<void> shareTicket(String text, {String subject = 'Receipt'}) async {
    final cleanText = text
        .replaceAll(RegExp(r'\x1D\x56[\x00-\xFF]'), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    await SharePlus.instance.share(
      ShareParams(
        text: cleanText,
        subject: subject,
      ),
    );
  }

  /// Open Google Play Store page for RawBT
  Future<bool> openRawBtOnPlayStore() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _rawbtChannel.invokeMethod<bool>('openRawBtPlayStore');
        return result ?? false;
      } catch (e) {
        debugPrint('Error opening Play Store: $e');
      }
    }
    return false;
  }

  /// Show a realistic virtual thermal paper slip on screen (no physical printer required)
  static void showVirtualReceiptDialog(
    BuildContext context,
    String ticketText, {
    String title = 'Thermal Paper Preview',
  }) {
    final cleanText = ticketText
        .replaceAll(RegExp(r'\x1D\x56[\x00-\xFF]'), '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Color(0xFF0F172A)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: (MediaQuery.sizeOf(ctx).height * 0.72).clamp(240.0, 680.0),
          ),
          child: Container(
            width: double.maxFinite,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F6), // Thermal paper roll tint
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade400),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                cleanText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  color: Colors.black87,
                  height: 1.25,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: cleanText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Receipt text copied to clipboard!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Text'),
          ),
          TextButton.icon(
            onPressed: () {
              PrinterService.instance.shareTicket(ticketText, subject: title);
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text('Share'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

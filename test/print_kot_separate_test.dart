import 'package:flutter_test/flutter_test.dart';
import 'package:pos/models/menu_item_model.dart';
import 'package:pos/models/restaurant_model.dart';
import 'package:pos/services/printer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Print KOT Separate & Auto-Cutter Tests', () {
    const foodItem1 = MenuItemModel(
      id: 1,
      categoryId: 1,
      categoryName: 'Main Course',
      name: 'Paneer Butter Masala',
      sitdownPrice: 220,
      itemType: 'veg',
      kitchenType: 'hot_kitchen',
    );

    const foodItem2 = MenuItemModel(
      id: 2,
      categoryId: 1,
      categoryName: 'Starters',
      name: 'Chicken Tikka',
      sitdownPrice: 280,
      itemType: 'non-veg',
      kitchenType: 'hot_kitchen',
    );

    const drinkItem1 = MenuItemModel(
      id: 3,
      categoryId: 2,
      categoryName: 'Beverages',
      name: 'Fresh Lime Soda',
      sitdownPrice: 80,
      itemType: 'beverage',
      kitchenType: 'bar',
    );

    const drinkItem2 = MenuItemModel(
      id: 4,
      categoryId: 3,
      categoryName: 'Bar Drinks',
      name: 'Mojito Cocktail',
      sitdownPrice: 220,
      itemType: 'veg',
      kitchenType: 'bar',
    );

    test('RestaurantModel: serializes and deserializes print_kot correctly', () {
      final modelOff = RestaurantModel(
        id: 1,
        name: 'Test Rest',
        phone: '1234567890',
        address: 'Test Address',
        printKotSeparate: false,
        createdAt: '2026-11-06T10:00:00',
        updatedAt: '2026-11-06T10:00:00',
      );
      final mapOff = modelOff.toMap();
      expect(mapOff['print_kot'], equals(0));

      final fromMapOff = RestaurantModel.fromMap(mapOff);
      expect(fromMapOff.printKotSeparate, isFalse);

      final modelOn = modelOff.copyWith(printKotSeparate: true);
      final mapOn = modelOn.toMap();
      expect(mapOn['print_kot'], equals(1));

      final fromMapOn = RestaurantModel.fromMap(mapOn);
      expect(fromMapOn.printKotSeparate, isTrue);

      // Handle case where SQLite or API returns 'print_KOT'
      final legacyMap = {
        'restaurant_id': 1,
        'restaurant_name': 'Legacy',
        'print_KOT': 1,
      };
      final fromLegacy = RestaurantModel.fromMap(legacyMap);
      expect(fromLegacy.printKotSeparate, isTrue);
    });

    test('PrinterService.isDrinkItem: properly distinguishes food from bar/drinks', () {
      final cartFood1 = CartItemModel(item: foodItem1, quantity: 1);
      final cartFood2 = CartItemModel(item: foodItem2, quantity: 2);
      final cartDrink1 = CartItemModel(item: drinkItem1, quantity: 1);
      final cartDrink2 = CartItemModel(item: drinkItem2, quantity: 1);

      expect(PrinterService.isDrinkItem(cartFood1), isFalse);
      expect(PrinterService.isDrinkItem(cartFood2), isFalse);
      expect(PrinterService.isDrinkItem(cartDrink1), isTrue);
      expect(PrinterService.isDrinkItem(cartDrink2), isTrue);
    });

    test('formatKotTicket: includes paper cut command and section headers', () {
      final cartFood = [CartItemModel(item: foodItem1, quantity: 2)];
      final ticket = PrinterService.instance.formatKotTicket(
        restaurantName: 'Sam POS Rest',
        tableName: 'Table 5',
        items: cartFood,
        isRunningKot: false,
        kotSection: 'FOOD',
      );

      expect(ticket.contains('KITCHEN ORDER TICKET (FOOD)'), isTrue);
      expect(ticket.contains('*** CHEF COPY (FOOD) ***'), isTrue);
      expect(ticket.contains(PrinterService.escCut), isTrue);

      final cartDrinks = [CartItemModel(item: drinkItem1, quantity: 3)];
      final drinksTicket = PrinterService.instance.formatKotTicket(
        restaurantName: 'Sam POS Rest',
        tableName: 'Table 5',
        items: cartDrinks,
        isRunningKot: false,
        kotSection: 'DRINKS',
      );

      expect(drinksTicket.contains('KITCHEN ORDER TICKET (DRINKS)'), isTrue);
      expect(drinksTicket.contains('*** BAR COPY (DRINKS) ***'), isTrue);
      expect(drinksTicket.contains(PrinterService.escCut), isTrue);
    });

    test('formatBillReceipt: ends with ESC/POS auto-cut sequence', () {
      const rest = RestaurantModel(
        id: 1,
        name: 'Fine Dine',
        phone: '9845012345',
        address: 'Downtown',
        createdAt: '',
        updatedAt: '',
      );

      final bill = PrinterService.instance.formatBillReceipt(
        restaurant: rest,
        destinationName: 'Table 1',
        items: [CartItemModel(item: foodItem1, quantity: 1)],
        total: 220,
        paymentMethod: 'Cash',
      );

      expect(bill.contains(PrinterService.escCut), isTrue);
    });

    test('printKot: when printKotSeparate is false (0), prints single unified KOT', () async {
      final cart = [
        CartItemModel(item: foodItem1, quantity: 2),
        CartItemModel(item: drinkItem1, quantity: 1),
      ];

      final result = await PrinterService.instance.printKot(
        restaurantName: 'Test Kitchen',
        tableName: 'Table 3',
        items: cart,
        isRunningKot: false,
        printKotSeparate: false,
      );

      expect(result.success, isTrue);
      expect(result.formattedText.contains('KITCHEN ORDER TICKET\n'), isTrue);
      expect(result.formattedText.contains('Paneer Butter Masala'), isTrue);
      expect(result.formattedText.contains('Fresh Lime Soda'), isTrue);
      expect(result.formattedText.contains('--- CUT / NEXT TICKET ---'), isFalse);
    });

    test('printKot: when printKotSeparate is true (1) with food & drinks, splits into 2 KOTs with cut', () async {
      final cart = [
        CartItemModel(item: foodItem1, quantity: 2),
        CartItemModel(item: drinkItem1, quantity: 3),
      ];

      final result = await PrinterService.instance.printKot(
        restaurantName: 'Test Kitchen',
        tableName: 'Table 7',
        items: cart,
        isRunningKot: false,
        printKotSeparate: true,
      );

      expect(result.success, isTrue);
      expect(result.message, equals('Food & Drinks KOTs printed separately'));
      expect(result.formattedText.contains('KITCHEN ORDER TICKET (FOOD)'), isTrue);
      expect(result.formattedText.contains('CHEF COPY (FOOD)'), isTrue);
      expect(result.formattedText.contains('Paneer Butter Masala'), isTrue);
      expect(result.formattedText.contains('--- CUT / NEXT TICKET ---'), isTrue);
      expect(result.formattedText.contains('KITCHEN ORDER TICKET (DRINKS)'), isTrue);
      expect(result.formattedText.contains('BAR COPY (DRINKS)'), isTrue);
      expect(result.formattedText.contains('Fresh Lime Soda'), isTrue);
    });

    test('printKot: when printKotSeparate is true (1) but only food exists, prints only food KOT', () async {
      final cart = [
        CartItemModel(item: foodItem1, quantity: 1),
        CartItemModel(item: foodItem2, quantity: 1),
      ];

      final result = await PrinterService.instance.printKot(
        restaurantName: 'Test Kitchen',
        tableName: 'Table 2',
        items: cart,
        isRunningKot: false,
        printKotSeparate: true,
      );

      expect(result.success, isTrue);
      expect(result.formattedText.contains('KITCHEN ORDER TICKET (FOOD)'), isTrue);
      expect(result.formattedText.contains('KITCHEN ORDER TICKET (DRINKS)'), isFalse);
    });

    test('printKot: when printKotSeparate is true (1) but only drinks exist, prints only drinks KOT', () async {
      final cart = [
        CartItemModel(item: drinkItem1, quantity: 2),
        CartItemModel(item: drinkItem2, quantity: 1),
      ];

      final result = await PrinterService.instance.printKot(
        restaurantName: 'Test Kitchen',
        tableName: 'Table 9',
        items: cart,
        isRunningKot: false,
        printKotSeparate: true,
      );

      expect(result.success, isTrue);
      expect(result.formattedText.contains('KITCHEN ORDER TICKET (DRINKS)'), isTrue);
      expect(result.formattedText.contains('KITCHEN ORDER TICKET (FOOD)'), isFalse);
    });
  });
}


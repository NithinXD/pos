import 'package:flutter/material.dart';
import '../models/table_model.dart';
import '../models/menu_item_model.dart';
import '../models/restaurant_model.dart';
import '../widgets/table_card.dart';
import '../widgets/table_active_order_sheet.dart';
import '../widgets/parcel_settlement_sheet.dart';
import '../widgets/settings_password_dialog.dart';
import '../database/pos_database.dart';
import '../services/printer_service.dart';
import 'menu_ordering_screen.dart';
import 'settings_hub_screen.dart';
import 'reports_screen.dart';
import 'orders_screen.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  // Current active mode: sit down vs parcel
  OrderType _selectedMode = OrderType.sitDown;

  // Bottom Navigation Index (0: Home, 1: Reports, 2: Settings)
  int _currentNavIndex = 0;

  // Sit-down tables (mix of green/closed and red/open)
  late List<TableModel> _sitDownTables;

  // Parcel orders: ONLY OPEN orders are kept here per Sam Biswas's requirement
  late List<TableModel> _openParcelOrders;

  // Search filter for Parcel screen
  String _parcelSearchQuery = '';
  final TextEditingController _parcelSearchController = TextEditingController();

  RestaurantModel? _restaurant;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadFromDatabase();
  }

  Future<void> _loadFromDatabase() async {
    try {
      final sitDown = await PosDatabase.instance.getSitDownTables();
      final parcels = await PosDatabase.instance.getOpenParcelOrders();
      final rest = await PosDatabase.instance.getRestaurantDetails();
      if (mounted) {
        setState(() {
          _sitDownTables = sitDown;
          _openParcelOrders = parcels;
          _restaurant = rest;
        });
      }
    } catch (e) {
      debugPrint('Database load fallback: $e');
    }
  }

  void _initializeData() {
    // Sit-down tables matching wireframe layout:
    _sitDownTables = [
      const TableModel(
        id: 1,
        name: 'Table 1',
        tableNumber: 1,
        status: TableOrderStatus.closed, // Green
        customerPhone: '1000000001',
      ),
      const TableModel(
        id: 10,
        name: 'Table 10',
        tableNumber: 10,
        status: TableOrderStatus.closed, // Green
        customerPhone: '1000000010',
      ),
      TableModel(
        id: 2,
        name: 'Table 2',
        tableNumber: 2,
        status: TableOrderStatus.open, // Red
        customerPhone: '1000000002',
        currentTotal: 1850.0,
        itemCount: 4,
        seatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
        activeCart: [
          CartItemModel(
            item: const MenuItemModel(
              id: 1,
              categoryId: 1,
              categoryName: 'Appetizers',
              name: 'Paneer Tikka',
              sitdownPrice: 240.0,
            ),
            quantity: 2,
            existingQuantity: 2,
          ),
          CartItemModel(
            item: const MenuItemModel(
              id: 5,
              categoryId: 2,
              categoryName: 'Main Course',
              name: 'Paneer Butter Masala',
              sitdownPrice: 280.0,
            ),
            quantity: 3,
            existingQuantity: 3,
          ),
          CartItemModel(
            item: const MenuItemModel(
              id: 9,
              categoryId: 3,
              categoryName: 'Breads & Rice',
              name: 'Butter Naan',
              sitdownPrice: 45.0,
            ),
            quantity: 6,
            existingQuantity: 6,
          ),
        ],
      ),
      const TableModel(
        id: 3,
        name: 'Table 3',
        tableNumber: 3,
        status: TableOrderStatus.closed, // Green
        customerPhone: '1000000003',
      ),
      const TableModel(
        id: 4,
        name: 'Table 4',
        tableNumber: 4,
        status: TableOrderStatus.closed, // Green
        customerPhone: '1000000004',
      ),
      TableModel(
        id: 5,
        name: 'Table 5',
        tableNumber: 5,
        status: TableOrderStatus.open, // Red
        customerPhone: '1000000005',
        currentTotal: 3420.0,
        itemCount: 6,
        seatedAt: DateTime.now().subtract(const Duration(minutes: 35)),
        activeCart: [
          CartItemModel(
            item: const MenuItemModel(
              id: 7,
              categoryId: 2,
              categoryName: 'Main Course',
              name: 'Butter Chicken Masala',
              sitdownPrice: 360.0,
            ),
            quantity: 2,
            existingQuantity: 2,
          ),
          CartItemModel(
            item: const MenuItemModel(
              id: 12,
              categoryId: 3,
              categoryName: 'Breads & Rice',
              name: 'Chicken Dum Biryani',
              sitdownPrice: 310.0,
            ),
            quantity: 4,
            existingQuantity: 4,
          ),
        ],
      ),
      const TableModel(
        id: 6,
        name: 'Table 6',
        tableNumber: 6,
        status: TableOrderStatus.closed, // Green
        customerPhone: '1000000006',
      ),
      TableModel(
        id: 8,
        name: 'table 8',
        tableNumber: 8,
        status: TableOrderStatus.open, // Red
        customerPhone: '1000000008',
        currentTotal: 4899.0,
        itemCount: 8,
        seatedAt: DateTime.now().subtract(const Duration(minutes: 50)),
        activeCart: [
          CartItemModel(
            item: const MenuItemModel(
              id: 3,
              categoryId: 1,
              categoryName: 'Appetizers',
              name: 'Chicken Malai Tikka',
              sitdownPrice: 320.0,
            ),
            quantity: 3,
            existingQuantity: 3,
          ),
          CartItemModel(
            item: const MenuItemModel(
              id: 7,
              categoryId: 2,
              categoryName: 'Main Course',
              name: 'Butter Chicken Masala',
              sitdownPrice: 360.0,
            ),
            quantity: 4,
            existingQuantity: 4,
          ),
          CartItemModel(
            item: const MenuItemModel(
              id: 9,
              categoryId: 3,
              categoryName: 'Breads & Rice',
              name: 'Butter Naan',
              sitdownPrice: 45.0,
            ),
            quantity: 10,
            existingQuantity: 10,
          ),
        ],
      ),
      const TableModel(
        id: 9,
        name: 'Table 9',
        tableNumber: 9,
        status: TableOrderStatus.closed, // Green
        customerPhone: '1000000009',
      ),
      const TableModel(
        id: 11,
        name: 'Table 10',
        tableNumber: 10,
        status: TableOrderStatus.closed, // Green
        customerPhone: '1000000010',
      ),
    ];

    // Parcel open orders matching wireframe:
    _openParcelOrders = [
      TableModel(
        id: 201,
        name: 'Parcel #1',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'wasd',
        customerPhone: '1234567890',
        currentTotal: 440.0,
        itemCount: 2,
        activeCart: [
          CartItemModel(
            item: const MenuItemModel(
              id: 1,
              categoryId: 1,
              categoryName: 'Appetizers',
              name: 'Paneer Tikka',
              sitdownPrice: 240.0,
              takeawayPrice: 230.0,
            ),
            quantity: 1,
            existingQuantity: 1,
            isTakeaway: true,
          ),
          CartItemModel(
            item: const MenuItemModel(
              id: 6,
              categoryId: 2,
              categoryName: 'Main Course',
              name: 'Dal Makhani Slow-Cooked',
              sitdownPrice: 220.0,
              takeawayPrice: 210.0,
            ),
            quantity: 1,
            existingQuantity: 1,
            isTakeaway: true,
          ),
        ],
      ),
      TableModel(
        id: 202,
        name: 'Parcel #2',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'was',
        customerPhone: '9876543210',
        currentTotal: 430.0,
        itemCount: 2,
        activeCart: [
          CartItemModel(
            item: const MenuItemModel(
              id: 2,
              categoryId: 1,
              categoryName: 'Appetizers',
              name: 'Crispy Corn Salt & Pepper',
              sitdownPrice: 180.0,
              takeawayPrice: 170.0,
            ),
            quantity: 1,
            existingQuantity: 1,
            isTakeaway: true,
          ),
          CartItemModel(
            item: const MenuItemModel(
              id: 8,
              categoryId: 2,
              categoryName: 'Main Course',
              name: 'Kadhai Paneer Special',
              sitdownPrice: 270.0,
              takeawayPrice: 260.0,
            ),
            quantity: 1,
            existingQuantity: 1,
            isTakeaway: true,
          ),
        ],
      ),
      TableModel(
        id: 203,
        name: 'Parcel #3',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'aaaa',
        customerPhone: '12345678',
        currentTotal: 830.0,
        itemCount: 6,
        activeCart: [
          CartItemModel(
            item: const MenuItemModel(
              id: 7,
              categoryId: 2,
              categoryName: 'Main Course',
              name: 'Butter Chicken Masala',
              sitdownPrice: 360.0,
              takeawayPrice: 350.0,
            ),
            quantity: 1,
            existingQuantity: 1,
            isTakeaway: true,
          ),
          CartItemModel(
            item: const MenuItemModel(
              id: 12,
              categoryId: 3,
              categoryName: 'Breads & Rice',
              name: 'Chicken Dum Biryani',
              sitdownPrice: 310.0,
              takeawayPrice: 300.0,
            ),
            quantity: 1,
            existingQuantity: 1,
            isTakeaway: true,
          ),
          CartItemModel(
            item: const MenuItemModel(
              id: 9,
              categoryId: 3,
              categoryName: 'Breads & Rice',
              name: 'Butter Naan',
              sitdownPrice: 45.0,
              takeawayPrice: 45.0,
            ),
            quantity: 4,
            existingQuantity: 4,
            isTakeaway: true,
          ),
        ],
      ),
      const TableModel(
        id: 204,
        name: 'Parcel #4',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'bbbb',
        customerPhone: '1234567',
        currentTotal: 1250.0,
        itemCount: 4,
      ),
      const TableModel(
        id: 205,
        name: 'Parcel #5',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'bbbb',
        customerPhone: '1234567',
        currentTotal: 450.0,
        itemCount: 1,
      ),
      const TableModel(
        id: 206,
        name: 'Parcel #6',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'bbbb',
        customerPhone: '1234567',
        currentTotal: 620.0,
        itemCount: 2,
      ),
      const TableModel(
        id: 207,
        name: 'Parcel #7',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'bbbb',
        customerPhone: '1234567',
        currentTotal: 980.0,
        itemCount: 3,
      ),
      const TableModel(
        id: 208,
        name: 'Parcel #8',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'bbbb',
        customerPhone: '1234567',
        currentTotal: 340.0,
        itemCount: 1,
      ),
      const TableModel(
        id: 209,
        name: 'Parcel #9',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'bbbb',
        customerPhone: '1234567',
        currentTotal: 1100.0,
        itemCount: 4,
      ),
      const TableModel(
        id: 210,
        name: 'Parcel #10',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'bbbb',
        customerPhone: '1234567',
        currentTotal: 720.0,
        itemCount: 2,
      ),
      const TableModel(
        id: 211,
        name: 'Parcel #11',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'bbbb',
        customerPhone: '1234567',
        currentTotal: 530.0,
        itemCount: 2,
      ),
      const TableModel(
        id: 212,
        name: 'Parcel #12',
        tableNumber: 0,
        status: TableOrderStatus.open,
        orderType: OrderType.parcel,
        customerName: 'bbbb',
        customerPhone: '1234567',
        currentTotal: 1450.0,
        itemCount: 5,
      ),
    ];
  }

  // Handle table tap
  void _onTableCardTapped(int index, TableModel table) {
    if (table.isClosed) {
      _navigateToMenuOrdering(index, table);
    } else {
      _showActiveOrderSheet(index, table);
    }
  }

  // Quick print customer receipt directly from table/parcel card (per Sam Biswas requirement)
  Future<void> _quickPrintReceipt(TableModel table) async {
    try {
      final rest = await PosDatabase.instance.getRestaurantDetails();
      var cart = table.activeCart;
      if (cart.isEmpty && table.activeOrderId != null) {
        cart = await PosDatabase.instance.getOrderItems(table.activeOrderId!);
      }
      if (cart.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No active items to print for ${table.name}'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final netTotal = cart.fold(0.0, (sum, i) => sum + i.totalPrice);
      final taxTotal = cart.fold(0.0, (sum, i) => sum + (i.totalPrice * (i.item.taxRate / 100.0)));
      final discount = table.discountAmount;
      final delivery = table.deliveryCharge;
      final total = ((netTotal - discount) + taxTotal + delivery).clamp(0.0, double.infinity);

      final res = await PrinterService.instance.printBill(
        restaurant: rest,
        destinationName: table.isParcel ? 'PARCEL: ${table.customerName ?? "Takeaway"}' : table.name,
        items: cart,
        total: total,
        netTotal: netTotal,
        taxTotal: taxTotal,
        discountAmount: discount,
        deliveryCharge: delivery,
        paymentMethod: 'Unpaid / Pending Bill',
        orderId: table.activeOrderId,
        customerName: table.customerName,
        customerPhone: table.customerPhone,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(res.success ? Icons.check_circle : Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  res.success
                      ? 'Receipt printed for ${table.isParcel ? "Parcel: ${table.customerName ?? 'Takeaway'}" : table.name}! Give bill to customer.'
                      : 'Print error: ${res.message}',
                ),
              ),
            ],
          ),
          backgroundColor: res.success ? const Color(0xFF0284C7) : const Color(0xFFDC2626),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Error quick printing receipt: $e');
    }
  }

  // Navigate to Menu & Order Screen
  void _navigateToMenuOrdering(int index, TableModel table) {
    final targetIndex = _sitDownTables.indexWhere((t) => t.tableNumber == table.tableNumber);
    final freshTable = targetIndex != -1 ? _sitDownTables[targetIndex] : table;
    final resolvedIndex = targetIndex != -1 ? targetIndex : index;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuOrderingScreen(
          table: freshTable,
          onOrderHeld: (cartItems, [discountAmount = 0.0, deliveryCharge = 0.0, orderComments = '', isPercent = false, percentValue = 0.0]) async {
            await _holdOrderAndMarkRed(
              resolvedIndex,
              cartItems,
              discountAmount,
              0.0, // Delivery charge disabled for sit down tables
              orderComments,
              freshTable.activeOrderId,
              isPercent,
              percentValue,
            );
          },
          onSettleOrder: (paymentMethod, [discountAmount = 0.0, deliveryCharge = 0.0, orderComments = '', isPercent = false, percentValue = 0.0]) {
            _settleAndReleaseTable(resolvedIndex, paymentMethod, discountAmount, 0.0, orderComments, isPercent, percentValue);
          },
        ),
      ),
    );
  }

  // Update table to RED (Open) on HOLD and persist to SQLite
  Future<void> _holdOrderAndMarkRed(
    int index,
    List<CartItemModel> cartItems, [
    double discountAmount = 0.0,
    double deliveryCharge = 0.0,
    String orderComments = '',
    int? activeOrderId,
    bool isPercent = false,
    double percentValue = 0.0,
  ]) async {
    final targetIndex = _sitDownTables.indexWhere((t) => t.tableNumber == (index < _sitDownTables.length ? _sitDownTables[index].tableNumber : index));
    final resolvedIndex = targetIndex != -1 ? targetIndex : (index < _sitDownTables.length ? index : 0);
    final table = _sitDownTables[resolvedIndex];
    int? targetOrderId = activeOrderId ?? table.activeOrderId;
    if ((targetOrderId == null || targetOrderId <= 0) && table.isOpen) {
      targetOrderId = await PosDatabase.instance.getActiveSitDownOrderId(table.tableNumber);
    }

    // Filter to only new items (fresh dishes or additional quantities on held dishes)
    final newItems = cartItems
        .where((c) => !c.isExisting || (c.isExisting && c.newQuantity > 0))
        .toList();

    try {
      if (targetOrderId != null && targetOrderId > 0 && table.isOpen) {
        if (newItems.isEmpty) {
          // Sam Biswas logic: if(number of new items == 0) { calculateDiscount; updateDiscount() }
          await PosDatabase.instance.updateOrderDiscountAndMeta(
            orderId: targetOrderId,
            discountAmount: discountAmount,
            isPercent: isPercent,
            percentValue: percentValue,
            deliveryCharge: 0.0, // Delivery charge disabled for sit down tables
            orderComments: orderComments,
          );
        } else {
          // Sam Biswas logic: if(number of new items > 0) { add new items to order item table; calculateDiscount(); updateDiscount(); PrintNewItems() }
          await PosDatabase.instance.addNewItemsToSitDownOrder(
            orderId: targetOrderId,
            tableNumber: table.tableNumber,
            newItems: newItems,
            discountAmount: discountAmount,
            isPercent: isPercent,
            percentValue: percentValue,
            deliveryCharge: 0.0, // Delivery charge disabled for sit down tables
            orderComments: orderComments,
          );
        }
      } else {
        // Initial order creation when table is green
        await PosDatabase.instance.holdSitDownOrder(
          table.tableNumber,
          cartItems,
          discountAmount: discountAmount,
          isPercent: isPercent,
          percentValue: percentValue,
          deliveryCharge: 0.0, // Delivery charge disabled for sit down tables
          orderComments: orderComments,
          activeOrderId: targetOrderId,
        );
      }
      await _loadFromDatabase();
    } catch (e) {
      debugPrint('Error saving order to SQLite: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newItems.isEmpty && table.isOpen
              ? '${table.name}: Order discount and details updated!'
              : '${table.name} order held & KOT printed! Saved to SQLite. Table is now RED (Open).',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: newItems.isEmpty && table.isOpen ? const Color(0xFF00796B) : const Color(0xFF7A0C0C),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Open active order sheet for RED tables
  void _showActiveOrderSheet(int index, TableModel table) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final targetIndex = _sitDownTables.indexWhere((t) => t.tableNumber == table.tableNumber);
        final freshTable = targetIndex != -1 ? _sitDownTables[targetIndex] : table;
        final resolvedIndex = targetIndex != -1 ? targetIndex : index;

        return TableActiveOrderSheet(
          table: freshTable,
          currency: _restaurant?.currency ?? '₹',
          onAddMoreItems: () {
            final latestTable = _sitDownTables.firstWhere((t) => t.tableNumber == table.tableNumber, orElse: () => freshTable);
            final latestIndex = _sitDownTables.indexWhere((t) => t.tableNumber == table.tableNumber);
            _navigateToMenuOrdering(latestIndex != -1 ? latestIndex : resolvedIndex, latestTable);
          },
          onDiscountChanged: (newDiscount, [isPercent = false, percentValue = 0.0]) async {
            final latestIndex = _sitDownTables.indexWhere((t) => t.tableNumber == table.tableNumber);
            final currentTable = latestIndex != -1 ? _sitDownTables[latestIndex] : freshTable;
            setState(() {
              if (latestIndex != -1) {
                _sitDownTables[latestIndex] = currentTable.copyWith(
                  discountAmount: newDiscount,
                  discountPercent: isPercent ? percentValue : 0.0,
                );
              }
            });
            try {
              int? orderId = currentTable.activeOrderId;
              if (orderId == null || orderId <= 0) {
                orderId = await PosDatabase.instance.getActiveSitDownOrderId(table.tableNumber);
              }
              if (orderId != null && orderId > 0) {
                await PosDatabase.instance.updateDiscount(
                  orderId: orderId,
                  isPercent: isPercent,
                  discountAmount: newDiscount,
                  percentValue: percentValue,
                  deliveryCharge: currentTable.deliveryCharge,
                  orderComments: currentTable.orderComments,
                );
              } else {
                await PosDatabase.instance.updateSitDownTableDiscount(
                  tableNumber: table.tableNumber,
                  discountAmount: newDiscount,
                  isPercent: isPercent,
                  percentValue: percentValue,
                  deliveryCharge: currentTable.deliveryCharge,
                  orderComments: currentTable.orderComments,
                );
              }
              await _loadFromDatabase();
            } catch (e) {
              debugPrint('Error updating discount in SQLite: $e');
            }
          },
          onDeliveryChargeChanged: (newDeliveryCharge) async {
            final latestIndex = _sitDownTables.indexWhere((t) => t.tableNumber == table.tableNumber);
            final currentTable = latestIndex != -1 ? _sitDownTables[latestIndex] : freshTable;
            setState(() {
              if (latestIndex != -1) {
                _sitDownTables[latestIndex] = currentTable.copyWith(
                  deliveryCharge: newDeliveryCharge,
                );
              }
            });
            try {
              if (currentTable.activeOrderId != null && currentTable.activeOrderId! > 0) {
                await PosDatabase.instance.updateOrderDiscountAndMeta(
                  orderId: currentTable.activeOrderId!,
                  discountAmount: currentTable.discountAmount,
                  deliveryCharge: newDeliveryCharge,
                  orderComments: currentTable.orderComments,
                );
              }
              await _loadFromDatabase();
            } catch (e) {
              debugPrint('Error updating delivery charge in SQLite: $e');
            }
          },
          onSettleAndReleaseTable: (method, [discountAmount, deliveryCharge, orderComments]) {
            final latestIndex = _sitDownTables.indexWhere((t) => t.tableNumber == table.tableNumber);
            _settleAndReleaseTable(latestIndex != -1 ? latestIndex : resolvedIndex, method, discountAmount, deliveryCharge, orderComments);
          },
        );
      },
    );
  }

  // Settle bill & reset table to GREEN and update SQLite
  Future<void> _settleAndReleaseTable(
    int index, [
    String paymentMethod = 'Cash',
    double? discountAmount,
    double? deliveryCharge,
    String? orderComments,
    bool? isPercent,
    double? percentValue,
  ]) async {
    final table = _sitDownTables[index];
    final effectiveDiscount = discountAmount ?? table.discountAmount;
    const effectiveDelivery = 0.0; // Delivery charge disabled for sit down tables
    final effectiveComments = orderComments ?? table.orderComments;
    final effectiveIsPercent = isPercent ?? table.isDiscountPercent;
    final effectivePercentValue = percentValue ?? table.discountPercent;
    setState(() {
      _sitDownTables[index] = table.copyWith(
        status: TableOrderStatus.closed,
        currentTotal: 0.0,
        itemCount: 0,
        activeCart: const [],
        seatedAt: null,
        discountAmount: 0.0,
        discountPercent: 0.0,
        deliveryCharge: 0.0,
        orderComments: '',
      );
    });

    try {
      await PosDatabase.instance.settleAndReleaseTable(
        table.tableNumber,
        paymentMethod: paymentMethod,
        discountAmount: effectiveDiscount,
        deliveryCharge: effectiveDelivery,
        orderComments: effectiveComments,
        isPercent: effectiveIsPercent,
        percentValue: effectivePercentValue,
      );
      await _loadFromDatabase();

      // Print Customer Settlement Bill
      final rest = await PosDatabase.instance.getRestaurantDetails();
      if (table.activeCart.isNotEmpty) {
        PrinterService.instance.printBill(
          restaurant: rest,
          destinationName: table.name,
          items: table.activeCart,
          total: ((table.netTotal - effectiveDiscount) + table.taxTotal + effectiveDelivery).clamp(0.0, double.infinity),
          netTotal: table.netTotal,
          taxTotal: table.taxTotal,
          discountAmount: effectiveDiscount,
          deliveryCharge: effectiveDelivery,
          paymentMethod: paymentMethod,
          orderId: table.activeOrderId,
          customerName: table.customerName,
          customerPhone: table.customerPhone,
        );
      }
    } catch (e) {
      debugPrint('Error settling table in SQLite: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${table.name} bill settled via $paymentMethod! Bill printed. Table is now GREEN (Free).',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF005C53),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Close parcel order upon customer pickup & payment and update SQLite
  Future<void> _closeParcelOrder(
    int originalIndex, [
    String paymentMethod = 'Cash',
    double? discountAmount,
    double? deliveryCharge,
    String? orderComments,
    bool? isPercent,
    double? percentValue,
  ]) async {
    final closedParcel = _openParcelOrders[originalIndex];
    final effectiveDiscount = discountAmount ?? closedParcel.discountAmount;
    final effectiveDelivery = deliveryCharge ?? closedParcel.deliveryCharge;
    final effectiveComments = orderComments ?? closedParcel.orderComments;
    setState(() {
      _openParcelOrders.removeAt(originalIndex);
    });

    try {
      final orderId = closedParcel.activeOrderId ?? closedParcel.id;
      await PosDatabase.instance.closeParcelOrder(
        orderId,
        paymentMethod: paymentMethod,
        discountAmount: effectiveDiscount,
        deliveryCharge: effectiveDelivery,
        orderComments: effectiveComments,
        isPercent: isPercent,
        percentValue: percentValue,
      );
      await _loadFromDatabase();

      // Print Customer Receipt for Parcel
      final rest = await PosDatabase.instance.getRestaurantDetails();
      if (closedParcel.activeCart.isNotEmpty) {
        PrinterService.instance.printBill(
          restaurant: rest,
          destinationName: 'PARCEL: ${closedParcel.customerName ?? "Takeaway"}',
          items: closedParcel.activeCart,
          total: ((closedParcel.netTotal - effectiveDiscount) + closedParcel.taxTotal + effectiveDelivery).clamp(0.0, double.infinity),
          netTotal: closedParcel.netTotal,
          taxTotal: closedParcel.taxTotal,
          discountAmount: effectiveDiscount,
          deliveryCharge: effectiveDelivery,
          paymentMethod: paymentMethod,
          orderId: orderId,
          customerName: closedParcel.customerName,
          customerPhone: closedParcel.customerPhone,
        );
      }
    } catch (e) {
      debugPrint('Error closing parcel in SQLite: $e');
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Parcel for ${closedParcel.customerName} (${closedParcel.customerPhone}) collected, bill printed & marked paid.',
        ),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showAddNewParcelDialog() async {
    final rest = _restaurant ?? await PosDatabase.instance.getRestaurantDetails();
    final defaultShopName = rest.name.trim().isNotEmpty ? rest.name.trim() : 'Takeaway';
    final nameController = TextEditingController(text: defaultShopName);
    nameController.selection = TextSelection(baseOffset: 0, extentOffset: nameController.text.length);
    final phoneController = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.takeout_dining, color: Color(0xFF7C5DFA)),
              SizedBox(width: 8),
              Text('New Parcel Order', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter customer details (defaulted to shop name for quick takeaway):',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Customer Name',
                      hintText: defaultShopName,
                      prefixIcon: const Icon(Icons.storefront_rounded, size: 20),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'e.g. 9845012345',
                      prefixIcon: Icon(Icons.phone, size: 20),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                final customerName = nameController.text.trim();
                final customerPhone = phoneController.text.trim();

                if (customerName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter customer name'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                Navigator.pop(dialogContext); // Close dialog

                final newParcel = TableModel(
                  id: DateTime.now().millisecondsSinceEpoch,
                  name: customerName,
                  tableNumber: 0,
                  status: TableOrderStatus.open,
                  orderType: OrderType.parcel,
                  customerName: customerName,
                  customerPhone: customerPhone.isEmpty ? 'No Phone' : customerPhone,
                  currentTotal: 0.0,
                  itemCount: 0,
                  activeCart: const [],
                );

                int? createdParcelId;

                // Open Menu Screen so staff can add food items from menu!
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MenuOrderingScreen(
                      table: newParcel,
                      onOrderHeld: (cartItems, [discountAmount = 0.0, deliveryCharge = 0.0, orderComments = '', isPercent = false, percentValue = 0.0]) async {
                        final messenger = ScaffoldMessenger.of(this.context);
                        try {
                          if (createdParcelId != null && createdParcelId! > 0) {
                            await PosDatabase.instance.updateParcelOrder(
                              createdParcelId!,
                              cartItems,
                              discountAmount: discountAmount,
                              deliveryCharge: deliveryCharge,
                              orderComments: orderComments,
                              isPercent: isPercent,
                              percentValue: percentValue,
                            );
                          } else {
                            createdParcelId = await PosDatabase.instance.createParcelOrder(
                              customerName: customerName,
                              customerPhone: customerPhone,
                              cartItems: cartItems,
                              discountAmount: discountAmount,
                              deliveryCharge: deliveryCharge,
                              orderComments: orderComments,
                              isPercent: isPercent,
                              percentValue: percentValue,
                            );
                          }
                          await _loadFromDatabase();
                        } catch (e) {
                          debugPrint('Error creating parcel in SQLite: $e');
                        }

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Parcel for $customerName held & KOT printed! Saved to SQLite.',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: const Color(0xFF7A0C0C),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.restaurant_menu, size: 18),
              label: const Text('Select Food Items'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C5DFA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        );
      },
    );
  }

  // Open improved parcel settlement sheet with "Add More Food" or "Collect Payment"
  void _showParcelDetails(TableModel parcel) {
    final originalIndex = _openParcelOrders.indexWhere((p) => p.id == parcel.id);
    if (originalIndex == -1) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final currentParcel = _openParcelOrders.firstWhere((p) => p.id == parcel.id, orElse: () => parcel);
        return ParcelSettlementSheet(
          parcel: currentParcel,
          currency: _restaurant?.currency ?? '₹',
          onAddMoreItems: () {
            // Re-open menu with fresh parcel snapshot
            final freshParcel = _openParcelOrders.firstWhere((p) => p.id == parcel.id, orElse: () => currentParcel);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MenuOrderingScreen(
                  table: freshParcel,
                  onOrderHeld: (cartItems, [discountAmount = 0.0, deliveryCharge = 0.0, orderComments = '', isPercent = false, percentValue = 0.0]) async {
                    final orderId = freshParcel.activeOrderId ?? freshParcel.id;

                    final newItems = cartItems
                        .where((c) => !c.isExisting || (c.isExisting && c.newQuantity > 0))
                        .toList();

                    try {
                      if (newItems.isEmpty) {
                        // Sam Biswas logic: if(number of new items == 0) { calculateDiscount; updateDiscount() }
                        await PosDatabase.instance.updateOrderDiscountAndMeta(
                          orderId: orderId,
                          discountAmount: discountAmount,
                          deliveryCharge: deliveryCharge,
                          orderComments: orderComments,
                          isPercent: isPercent,
                          percentValue: percentValue,
                        );
                      } else {
                        // Sam Biswas logic: if(number of new items > 0) { add new items to order item table; calculateDiscount(); updateDiscount(); PrintNewItems() }
                        await PosDatabase.instance.addNewItemsToParcelOrder(
                          orderId: orderId,
                          newItems: newItems,
                          discountAmount: discountAmount,
                          deliveryCharge: deliveryCharge,
                          orderComments: orderComments,
                          isPercent: isPercent,
                          percentValue: percentValue,
                        );
                      }
                      await _loadFromDatabase();
                    } catch (e) {
                      debugPrint('Error updating parcel in SQLite: $e');
                    }
                  },
                  onSettleOrder: (paymentMethod, [discountAmount = 0.0, deliveryCharge = 0.0, orderComments = '', isPercent = false, percentValue = 0.0]) {
                    final currIndex = _openParcelOrders.indexWhere((p) => p.id == parcel.id);
                    _closeParcelOrder(currIndex != -1 ? currIndex : originalIndex, paymentMethod, discountAmount, deliveryCharge, orderComments, isPercent, percentValue);
                  },
                ),
              ),
            );
          },
          onDiscountChanged: (newDiscount, [isPercent = false, percentValue = 0.0]) async {
            final currIndex = _openParcelOrders.indexWhere((p) => p.id == parcel.id);
            final currentParcel = currIndex != -1 ? _openParcelOrders[currIndex] : parcel;
            if (currIndex != -1) {
              setState(() {
                _openParcelOrders[currIndex] = _openParcelOrders[currIndex].copyWith(
                  discountAmount: newDiscount,
                  discountPercent: isPercent ? percentValue : 0.0,
                );
              });
            }
            try {
              final orderId = parcel.activeOrderId ?? parcel.id;
              await PosDatabase.instance.updateDiscount(
                orderId: orderId,
                isPercent: isPercent,
                discountAmount: newDiscount,
                percentValue: percentValue,
                deliveryCharge: currentParcel.deliveryCharge,
                orderComments: currentParcel.orderComments,
              );
              await _loadFromDatabase();
            } catch (e) {
              debugPrint('Error updating parcel discount in SQLite: $e');
            }
          },
          onDeliveryChargeChanged: (newDeliveryCharge) async {
            final currIndex = _openParcelOrders.indexWhere((p) => p.id == parcel.id);
            final currentParcel = currIndex != -1 ? _openParcelOrders[currIndex] : parcel;
            if (currIndex != -1) {
              setState(() {
                _openParcelOrders[currIndex] = _openParcelOrders[currIndex].copyWith(
                  deliveryCharge: newDeliveryCharge,
                );
              });
            }
            try {
              final orderId = parcel.activeOrderId ?? parcel.id;
              await PosDatabase.instance.updateOrderDiscountAndMeta(
                orderId: orderId,
                discountAmount: currentParcel.discountAmount,
                deliveryCharge: newDeliveryCharge,
                orderComments: currentParcel.orderComments,
              );
              await _loadFromDatabase();
            } catch (e) {
              debugPrint('Error updating parcel delivery charge in SQLite: $e');
            }
          },
          onCollectAndClose: (method, [discountAmount, deliveryCharge, orderComments]) {
            final currIndex = _openParcelOrders.indexWhere((p) => p.id == parcel.id);
            _closeParcelOrder(currIndex != -1 ? currIndex : originalIndex, method, discountAmount, deliveryCharge, orderComments);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSitDown = _selectedMode == OrderType.sitDown;

    // Filter parcels by search query if in parcel mode
    final List<TableModel> currentList;
    if (isSitDown) {
      currentList = _sitDownTables;
    } else {
      currentList = _openParcelOrders.where((p) {
        if (_parcelSearchQuery.isEmpty) return true;
        final q = _parcelSearchQuery.toLowerCase();
        final name = (p.customerName ?? p.name).toLowerCase();
        final phone = (p.customerPhone ?? '').toLowerCase();
        return name.contains(q) || phone.contains(q);
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: !isSitDown
          ? FloatingActionButton.extended(
              onPressed: _showAddNewParcelDialog,
              backgroundColor: const Color(0xFF7C5DFA),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('New Parcel', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Top Toggle Bar: [ sit down ] | [ parcel ]
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 6.0),
              child: _buildTopModeToggle(),
            ),

            // Parcel Search Bar (Specific to Parcel Mode for Fast Cashier Lookups)
            if (!isSitDown)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: TextField(
                    controller: _parcelSearchController,
                    onChanged: (val) {
                      setState(() {
                        _parcelSearchQuery = val.trim();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search customer name or phone...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                      suffixIcon: _parcelSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _parcelSearchController.clear();
                                setState(() {
                                  _parcelSearchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),

            // Mode Summary Readout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: isSitDown
                  ? _buildSitDownSummary()
                  : _buildParcelSummary(currentList.length),
            ),

            const SizedBox(height: 6),

            // Responsive Table/Parcel Grid
            Expanded(
              child: currentList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            !isSitDown
                                ? (_parcelSearchQuery.isNotEmpty
                                    ? 'No parcel found matching "$_parcelSearchQuery"'
                                    : 'All Parcels Handed Over!')
                                : 'No tables available',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            !isSitDown
                                ? 'No pending orders waiting for pickup.'
                                : '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[500],
                            ),
                          ),
                          if (!isSitDown && _parcelSearchQuery.isEmpty) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _showAddNewParcelDialog,
                              icon: const Icon(Icons.add),
                              label: const Text('Create New Parcel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C5DFA),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        // Fine-tuned Responsive Column & Aspect Ratio:
                        // Phone (< 600px): 2 columns
                        // Tablet Portrait (600 - 850px): 3 columns
                        // Tablet Landscape (850 - 1150px): 4 columns
                        // Wide Desktop / Terminal (>= 1150px): 5 columns
                        int crossAxisCount = 2;
                        double childAspectRatio = 1.05;
                        if (constraints.maxWidth >= 1150) {
                          crossAxisCount = 5;
                          childAspectRatio = 1.20;
                        } else if (constraints.maxWidth >= 850) {
                          crossAxisCount = 4;
                          childAspectRatio = 1.18;
                        } else if (constraints.maxWidth >= 600) {
                          crossAxisCount = 3;
                          childAspectRatio = 1.14;
                        } else {
                          crossAxisCount = 2;
                          childAspectRatio = constraints.maxWidth < 360 ? 0.98 : 1.05;
                        }

                        final spacing = constraints.maxWidth < 400 ? 10.0 : 14.0;

                        return GridView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing,
                            vertical: 6.0,
                          ),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: spacing,
                            mainAxisSpacing: spacing,
                            childAspectRatio: childAspectRatio,
                          ),
                          itemCount: currentList.length,
                          itemBuilder: (context, index) {
                            final table = currentList[index];
                            return TableCard(
                              table: table,
                              currency: _restaurant?.currency ?? '₹',
                              onTap: () {
                                if (isSitDown) {
                                  _onTableCardTapped(index, table);
                                } else {
                                  _showParcelDetails(table);
                                }
                              },
                              onPrint: table.isOpen ? () => _quickPrintReceipt(table) : null,
                              onLongPress: () {
                                if (isSitDown) {
                                  if (table.isClosed) {
                                    _navigateToMenuOrdering(index, table);
                                  } else {
                                    _settleAndReleaseTable(index);
                                  }
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
            ),

            // Bottom Navigation Bar (Home | Reports | Settings)
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildSitDownSummary() {
    final openCount = _sitDownTables.where((t) => t.isOpen).length;
    final closedCount = _sitDownTables.where((t) => t.isClosed).length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF005C53),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Closed ($closedCount available)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF005C53),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF7A0C0C),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Open ($openCount dining)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A0C0C),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParcelSummary(int visibleCount) {
    final totalPendingAmount =
        _openParcelOrders.fold(0.0, (sum, p) => sum + p.currentTotal);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF7A0C0C),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$visibleCount Open Parcels (${_restaurant?.currency ?? "₹"}${totalPendingAmount.toStringAsFixed(0)} pending)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A0C0C),
              ),
            ),
          ],
        ),
        const Text(
          'Tap card to collect payment',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildTopModeToggle() {
    const activeCyanColor = Color(0xFF67E8F9); // Cyan
    const activePurpleColor = Color(0xFF7C5DFA); // Purple

    final isSitDown = _selectedMode == OrderType.sitDown;

    return LayoutBuilder(
      builder: (context, constraints) {
        final buttonHeight = constraints.maxWidth < 400 ? 48.0 : 52.0;
        final fontSize = constraints.maxWidth < 400 ? 14.0 : 16.0;

        return Container(
          height: buttonHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
          ),
          child: Row(
            children: [
              // "sit down" tab
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMode = OrderType.sitDown;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: isSitDown ? activeCyanColor : Colors.white,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12.0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'sit down',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: isSitDown ? FontWeight.bold : FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),

              // Divider between segments
              Container(
                width: 1.5,
                height: double.infinity,
                color: const Color(0xFF1E293B),
              ),

              // "parcel" tab
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedMode = OrderType.parcel;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: !isSitDown ? activePurpleColor : Colors.white,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(12.0),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'parcel',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: !isSitDown ? FontWeight.bold : FontWeight.w500,
                        color: !isSitDown ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade400, width: 1.2),
        ),
      ),
      child: Row(
        children: [
          _buildNavItem(0, 'Home', Icons.home_outlined, Icons.home),
          Container(
            width: 1.2,
            height: 48,
            color: Colors.grey.shade400,
          ),
          _buildNavItem(1, 'Orders', Icons.receipt_long_outlined, Icons.receipt_long),
          Container(
            width: 1.2,
            height: 48,
            color: Colors.grey.shade400,
          ),
          _buildNavItem(2, 'Reports', Icons.bar_chart_outlined, Icons.bar_chart),
          Container(
            width: 1.2,
            height: 48,
            color: Colors.grey.shade400,
          ),
          _buildNavItem(3, 'Settings', Icons.settings_outlined, Icons.settings),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      int index, String label, IconData icon, IconData activeIcon) {
    final isSelected = _currentNavIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () async {
          if (index == 3) {
            final authorized = await SettingsPasswordDialog.prompt(context);
            if (!authorized) return;
            if (!mounted) return;

            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsHubScreen(isAuthenticated: true)),
            );
            await _loadFromDatabase();
            if (mounted) {
              setState(() {
                _currentNavIndex = 0;
              });
            }
          } else if (index == 2) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            );
            await _loadFromDatabase();
            if (mounted) {
              setState(() {
                _currentNavIndex = 0;
              });
            }
          } else if (index == 1) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrdersScreen()),
            );
            await _loadFromDatabase();
            if (mounted) {
              setState(() {
                _currentNavIndex = 0;
              });
            }
          } else {
            setState(() {
              _currentNavIndex = 0;
            });
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? const Color(0xFF0F172A) : Colors.grey[600],
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0F172A) : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

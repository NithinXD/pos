import 'dart:async';
import 'package:flutter/material.dart';
import '../models/table_model.dart';
import '../models/menu_item_model.dart';
import '../models/restaurant_model.dart';
import '../database/pos_database.dart';
import '../services/printer_service.dart';
import '../widgets/order_discount_dialog.dart';
import '../widgets/delivery_charge_dialog.dart';
import '../widgets/order_comments_dialog.dart';

class MenuOrderingScreen extends StatefulWidget {
  final TableModel table;
  final FutureOr<void> Function(
    List<CartItemModel> cartItems, [
    double discountAmount,
    double deliveryCharge,
    String orderComments,
    bool isPercent,
    double percentValue,
  ]) onOrderHeld;
  final void Function(
    String paymentMethod,
    double discountAmount, [
    double deliveryCharge,
    String orderComments,
    bool isPercent,
    double percentValue,
  ])? onSettleOrder;

  const MenuOrderingScreen({
    super.key,
    required this.table,
    required this.onOrderHeld,
    this.onSettleOrder,
  });

  @override
  State<MenuOrderingScreen> createState() => _MenuOrderingScreenState();
}

class _MenuOrderingScreenState extends State<MenuOrderingScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Active Cart Items for this table
  final Map<int, CartItemModel> _cart = {};

  List<String> _categories = [
    'All',
    'Appetizers',
    'Main Course',
    'Breads & Rice',
    'Beverages',
    'Desserts',
  ];

  List<MenuItemModel> _sampleMenu = [];
  RestaurantModel? _restaurant;

  // Order-level discount state (Sam Biswas: amount or percentage)
  double _orderDiscount = 0.0;
  bool _isDiscountPercent = false;
  double _discountPercent = 0.0;

  // Delivery charge & order comments state (Phase 2)
  double _deliveryCharge = 0.0;
  String _orderComments = '';

  // Guard flag to prevent duplicate concurrent saves during hold/pop
  bool _isSavingOrder = false;
  bool _hasDispatchedOrderHeld = false;

  Future<void> _dispatchOrderHeld() async {
    if (_isSavingOrder) return;
    _isSavingOrder = true;
    _hasDispatchedOrderHeld = true;

    try {
      final res = widget.onOrderHeld(
        _cart.values.toList(),
        _effectiveDiscount,
        widget.table.isParcel ? _deliveryCharge : 0.0,
        _orderComments,
        _isDiscountPercent,
        _discountPercent,
      );
      if (res is Future) {
        await res;
      }
    } finally {
      _isSavingOrder = false;
    }
  }

  String get currency => _restaurant?.currency ?? '₹';

  @override
  void initState() {
    super.initState();
    _orderDiscount = widget.table.discountAmount;
    _discountPercent = widget.table.discountPercent;
    _isDiscountPercent = widget.table.isDiscountPercent;
    _deliveryCharge = widget.table.isParcel ? widget.table.deliveryCharge : 0.0;
    _orderComments = widget.table.orderComments ?? '';
    _initializeMenu();
    _loadMenuFromDatabase();
    // Safely load existing items if table is already open, consolidating duplicates if any exist
    final existingCart = widget.table.activeCart;
    for (var cartItem in existingCart) {
      if (_cart.containsKey(cartItem.item.id)) {
        final prev = _cart[cartItem.item.id]!;
        _cart[cartItem.item.id] = prev.copyWith(
          quantity: prev.quantity + cartItem.quantity,
          existingQuantity: prev.existingQuantity + cartItem.quantity,
        );
      } else {
        _cart[cartItem.item.id] = CartItemModel(
          item: cartItem.item,
          quantity: cartItem.quantity,
          notes: cartItem.notes,
          status: cartItem.status,
          existingQuantity: cartItem.quantity,
          isTakeaway: widget.table.isParcel,
          customUnitPrice: cartItem.customUnitPrice,
        );
      }
    }
  }

  Future<void> _loadMenuFromDatabase() async {
    try {
      final items = await PosDatabase.instance.getMenuItems();
      final cats = await PosDatabase.instance.getCategories();
      final rest = await PosDatabase.instance.getRestaurantDetails();
      if (mounted) {
        setState(() {
          _sampleMenu = items;
          _restaurant = rest;
          if (cats.isNotEmpty) {
            _categories = cats;
            if (!_categories.contains(_selectedCategory)) {
              _selectedCategory = 'All';
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Menu DB load fallback: $e');
    }
  }

  void _initializeMenu() {
    _sampleMenu = const [
      // Appetizers
      MenuItemModel(
        id: 1,
        categoryId: 1,
        categoryName: 'Appetizers',
        name: 'Paneer Tikka',
        sitdownPrice: 240.0,
        takeawayPrice: 230.0,
        itemType: 'veg',
      ),
      MenuItemModel(
        id: 2,
        categoryId: 1,
        categoryName: 'Appetizers',
        name: 'Crispy Corn Salt & Pepper',
        sitdownPrice: 180.0,
        takeawayPrice: 170.0,
        itemType: 'veg',
      ),
      MenuItemModel(
        id: 3,
        categoryId: 1,
        categoryName: 'Appetizers',
        name: 'Chicken Malai Tikka',
        sitdownPrice: 320.0,
        takeawayPrice: 300.0,
        itemType: 'non-veg',
      ),
      MenuItemModel(
        id: 4,
        categoryId: 1,
        categoryName: 'Appetizers',
        name: 'Veg Spring Rolls (6 pcs)',
        sitdownPrice: 190.0,
        takeawayPrice: 180.0,
        itemType: 'veg',
      ),

      // Main Course
      MenuItemModel(
        id: 5,
        categoryId: 2,
        categoryName: 'Main Course',
        name: 'Paneer Butter Masala',
        sitdownPrice: 280.0,
        takeawayPrice: 270.0,
        itemType: 'veg',
      ),
      MenuItemModel(
        id: 6,
        categoryId: 2,
        categoryName: 'Main Course',
        name: 'Dal Makhani Slow-Cooked',
        sitdownPrice: 220.0,
        takeawayPrice: 210.0,
        itemType: 'veg',
      ),
      MenuItemModel(
        id: 7,
        categoryId: 2,
        categoryName: 'Main Course',
        name: 'Butter Chicken Masala',
        sitdownPrice: 360.0,
        takeawayPrice: 350.0,
        itemType: 'non-veg',
      ),
      MenuItemModel(
        id: 8,
        categoryId: 2,
        categoryName: 'Main Course',
        name: 'Kadhai Paneer Special',
        sitdownPrice: 270.0,
        takeawayPrice: 260.0,
        itemType: 'veg',
      ),

      // Breads & Rice
      MenuItemModel(
        id: 9,
        categoryId: 3,
        categoryName: 'Breads & Rice',
        name: 'Butter Naan',
        sitdownPrice: 45.0,
        takeawayPrice: 45.0,
        itemType: 'veg',
      ),
      MenuItemModel(
        id: 10,
        categoryId: 3,
        categoryName: 'Breads & Rice',
        name: 'Garlic Roti',
        sitdownPrice: 40.0,
        takeawayPrice: 40.0,
        itemType: 'veg',
      ),
      MenuItemModel(
        id: 11,
        categoryId: 3,
        categoryName: 'Breads & Rice',
        name: 'Jeera Rice with Ghee',
        sitdownPrice: 150.0,
        takeawayPrice: 140.0,
        itemType: 'veg',
      ),
      MenuItemModel(
        id: 12,
        categoryId: 3,
        categoryName: 'Breads & Rice',
        name: 'Chicken Dum Biryani',
        sitdownPrice: 310.0,
        takeawayPrice: 300.0,
        itemType: 'non-veg',
      ),

      // Beverages
      MenuItemModel(
        id: 13,
        categoryId: 4,
        categoryName: 'Beverages',
        name: 'Fresh Lime Soda (Sweet/Salt)',
        sitdownPrice: 80.0,
        takeawayPrice: 80.0,
        itemType: 'beverage',
      ),
      MenuItemModel(
        id: 14,
        categoryId: 4,
        categoryName: 'Beverages',
        name: 'Mango Lassi Thick',
        sitdownPrice: 110.0,
        takeawayPrice: 110.0,
        itemType: 'beverage',
      ),
      MenuItemModel(
        id: 15,
        categoryId: 4,
        categoryName: 'Beverages',
        name: 'Masala Chai Pot',
        sitdownPrice: 40.0,
        takeawayPrice: 40.0,
        itemType: 'beverage',
      ),

      // Desserts
      MenuItemModel(
        id: 16,
        categoryId: 5,
        categoryName: 'Desserts',
        name: 'Warm Gulab Jamun (2 pcs)',
        sitdownPrice: 90.0,
        takeawayPrice: 90.0,
        itemType: 'veg',
      ),
      MenuItemModel(
        id: 17,
        categoryId: 5,
        categoryName: 'Desserts',
        name: 'Saffron Rasmalai (2 pcs)',
        sitdownPrice: 130.0,
        takeawayPrice: 130.0,
        itemType: 'veg',
      ),
    ];
  }

  void _addItem(MenuItemModel item) {
    setState(() {
      if (_cart.containsKey(item.id)) {
        _cart[item.id]!.quantity++;
      } else {
        _cart[item.id] = CartItemModel(
          item: item,
          quantity: 1,
          existingQuantity: 0, // Freshly added food item
          isTakeaway: widget.table.isParcel,
        );
      }
    });
  }

  void _removeItem(MenuItemModel item) {
    if (!_cart.containsKey(item.id)) return;
    final cartItem = _cart[item.id]!;

    // Cannot delete or decrement existing kitchen-held items
    if (cartItem.isExisting && cartItem.quantity <= cartItem.existingQuantity) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.lock, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${item.name} (${cartItem.existingQuantity}x) is confirmed in kitchen. Cannot delete or reduce.',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF7A0C0C),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      if (cartItem.quantity > cartItem.existingQuantity && cartItem.quantity > 1) {
        cartItem.quantity--;
      } else if (cartItem.existingQuantity == 0 && cartItem.quantity == 1) {
        // New food item can be deleted from cart
        _cart.remove(item.id);
      } else if (cartItem.quantity > 1) {
        cartItem.quantity--;
      }
    });
  }

  int get _totalItemCount {
    return _cart.values.fold(0, (sum, item) => sum + item.quantity);
  }

  double get _taxAmount => _cart.values.fold(0.0, (sum, item) => sum + (item.totalPrice * (item.item.taxRate / 100.0)));
  double get _taxPercent => _netCartTotal > 0 ? (_taxAmount / _netCartTotal) * 100.0 : 0.0;
  double get _netCartTotal => _cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get _totalCartAmount => _netCartTotal;
  double get _effectiveDiscount {
    if (_isDiscountPercent && _discountPercent > 0.0) {
      return (_netCartTotal * (_discountPercent.clamp(0.0, 100.0) / 100.0)).clamp(0.0, _netCartTotal);
    }
    return (_orderDiscount > _netCartTotal ? _netCartTotal : _orderDiscount);
  }
  double get _payableTotal => ((_netCartTotal - _effectiveDiscount) + _taxAmount + (widget.table.isParcel ? _deliveryCharge : 0.0)).clamp(0.0, double.infinity);

  int get _newItemsCount => _cart.values.fold(0, (sum, c) => sum + (c.isExisting ? c.newQuantity : c.quantity));
  bool get _isDiscountChanged =>
      _isDiscountPercent != widget.table.isDiscountPercent ||
      (_discountPercent - widget.table.discountPercent).abs() > 0.001 ||
      (_effectiveDiscount - widget.table.discountAmount).abs() > 0.001;
  bool get _isDeliveryChanged => widget.table.isParcel && (_deliveryCharge - widget.table.deliveryCharge).abs() > 0.001;
  bool get _isCommentsChanged => _orderComments != (widget.table.orderComments ?? '');
  bool get _isMetaChanged => _isDiscountChanged || _isDeliveryChanged || _isCommentsChanged;
  bool get _isOnlyMetaChanged =>
      (widget.table.isOpen || widget.table.activeCart.isNotEmpty || _cart.isNotEmpty) &&
      _newItemsCount == 0 &&
      _isMetaChanged;
  bool get _isOnlyDiscountChanged => _isOnlyMetaChanged;

  Future<void> _showDiscountDialog([StateSetter? modalSetState]) async {
    showDialog(
      context: context,
      builder: (dialogCtx) => OrderDiscountDialog(
        netTotal: _netCartTotal,
        currency: currency,
        initialDiscount: _orderDiscount,
        initialIsPercent: _isDiscountPercent,
        initialPercentValue: _discountPercent,
        onApply: (discountAmount, isPercent, percentValue) async {
          setState(() {
            _orderDiscount = discountAmount;
            _isDiscountPercent = isPercent;
            _discountPercent = percentValue;
          });
          modalSetState?.call(() {});
          if ((widget.table.isOpen || widget.table.activeCart.isNotEmpty) && _newItemsCount == 0) {
            await _dispatchOrderHeld();
          }
        },
        onClear: () async {
          setState(() {
            _orderDiscount = 0.0;
            _isDiscountPercent = false;
            _discountPercent = 0.0;
          });
          modalSetState?.call(() {});
          if ((widget.table.isOpen || widget.table.activeCart.isNotEmpty) && _newItemsCount == 0) {
            await _dispatchOrderHeld();
          }
        },
      ),
    );
  }

  Future<void> _showDeliveryChargeDialog([StateSetter? modalSetState]) async {
    if (!widget.table.isParcel) return; // Delivery charge is disabled for sit down tables
    showDialog(
      context: context,
      builder: (dialogCtx) => DeliveryChargeDialog(
        initialCharge: _deliveryCharge,
        currency: currency,
        onApply: (charge) {
          setState(() {
            _deliveryCharge = charge;
          });
          modalSetState?.call(() {});
        },
        onClear: () {
          setState(() {
            _deliveryCharge = 0.0;
          });
          modalSetState?.call(() {});
        },
      ),
    );
  }

  Future<void> _showOrderCommentsDialog([StateSetter? modalSetState]) async {
    showDialog(
      context: context,
      builder: (dialogCtx) => OrderCommentsDialog(
        initialComments: _orderComments,
        onSave: (comments) {
          setState(() {
            _orderComments = comments;
          });
          modalSetState?.call(() {});
        },
        onClear: () {
          setState(() {
            _orderComments = '';
          });
          modalSetState?.call(() {});
        },
      ),
    );
  }

  /// Settlement dialog to close and settle table directly from Menu Ordering Screen
  Future<void> _showSettleDialog() async {
    String selectedMethod = 'Cash';
    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFF0F172A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Settle & Close ${widget.table.name}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // 1. Net Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Net Total:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        Text('$currency${_netCartTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 2. Discount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isDiscountPercent && _discountPercent > 0
                              ? 'Discount (${_discountPercent.toStringAsFixed(0)}%):'
                              : 'Discount:',
                          style: TextStyle(
                            fontSize: 13,
                            color: _effectiveDiscount > 0 ? const Color(0xFF00796B) : const Color(0xFF64748B),
                            fontWeight: _effectiveDiscount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        Text(
                          _effectiveDiscount > 0
                              ? '-$currency${_effectiveDiscount.toStringAsFixed(2)}'
                              : '$currency 0.00',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _effectiveDiscount > 0 ? const Color(0xFF00796B) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 3. Delivery Charge (Enabled for parcel only)
                    if (widget.table.isParcel) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Delivery Charge:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          Text(
                            '$currency${_deliveryCharge.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _deliveryCharge > 0 ? Colors.teal.shade700 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    // 4. Tax
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tax:', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                        Text('$currency${_taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const Divider(height: 12),
                    // 5. Total Payable
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Payable:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Text(
                          '$currency${_payableTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_orderComments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.comment, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Note: $_orderComments',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade900, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Payment Method:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: ['Cash', 'Card', 'UPI QR'].map((method) {
                  final isSelected = selectedMethod == method;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: ChoiceChip(
                        label: Center(child: Text(method, style: const TextStyle(fontSize: 11))),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() {
                              selectedMethod = method;
                            });
                          }
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _hasDispatchedOrderHeld = true; // Settle order supersedes hold
                Navigator.pop(dialogCtx);
                Navigator.pop(context);
                widget.onSettleOrder?.call(
                  selectedMethod,
                  _effectiveDiscount,
                  widget.table.isParcel ? _deliveryCharge : 0.0,
                  _orderComments,
                  _isDiscountPercent,
                  _discountPercent,
                );
              },
              icon: const Icon(Icons.print, size: 16),
              label: const Text('Print & Settle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MenuItemModel> get _filteredMenu {
    return _sampleMenu.where((item) {
      final matchesCategory =
          _selectedCategory == 'All' || item.categoryName == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          item.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  // Trigger Hold / Print KOT workflow as specified by Sam Biswas
  Future<void> _triggerHoldOrder() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cart is empty. Add at least one item to Hold order.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final cartList = _cart.values.toList();
    final newItemsCount = cartList.fold(0, (sum, c) => sum + (c.isExisting ? c.newQuantity : c.quantity));
    final isRunning = widget.table.isOpen || widget.table.activeCart.isNotEmpty;

    // Handle case where staff opened existing table/parcel order, added no new food items, but updated discount, delivery charge, or comments
    if (newItemsCount == 0 && (isRunning || _cart.isNotEmpty)) {
      if (_isMetaChanged) {
        await _dispatchOrderHeld();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${widget.table.name}: Order details updated and saved!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFF00796B),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No new items added or changes to save.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Filter to only new items if re-holding an active running order (PrintNewItems())
    final kotPreviewItems = (isRunning && newItemsCount > 0)
        ? cartList.where((c) => !c.isExisting || (c.isExisting && c.newQuantity > 0)).toList()
        : cartList;

    // Send KOT to thermal printer via RawBT
    PrinterResult printResult = await PrinterService.instance.printKot(
      restaurantName: _restaurant?.name ?? '',
      tableName: widget.table.name,
      items: kotPreviewItems,
      isRunningKot: isRunning,
      orderId: widget.table.activeOrderId,
      customerName: widget.table.customerName,
      customerPhone: widget.table.customerPhone,
      orderTypeLabel: widget.table.isParcel ? 'PARCEL ORDER' : 'SITDOWN ORDER',
    );

    if (!mounted) return;

    final kotPreviewTotal = (isRunning && newItemsCount > 0)
        ? kotPreviewItems.fold(
            0.0,
            (sum, c) =>
                sum +
                c.unitPrice *
                    (c.isExisting ? c.newQuantity : c.quantity))
        : _totalCartAmount;

    // Show instant KOT Print preview dialog with real print actions
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.print, color: Color(0xFF0F172A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'KOT Printing: ${widget.table.name}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'KITCHEN TICKET (KOT)',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              if (newItemsCount > 0 && widget.table.isOpen) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'RUNNING KOT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Divider(height: 12),
                          Text(
                            'Table: ${widget.table.name}  |  ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          ...kotPreviewItems.map((c) {
                            final qty = (isRunning && c.isExisting)
                                ? c.newQuantity
                                : c.quantity;
                            final price = c.unitPrice * qty;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '$qty x ${c.item.name}${isRunning ? ' (NEW)' : ''}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF16A34A),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text('$currency${price.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  isRunning
                                      ? 'NEW ITEMS TOTAL:'
                                      : 'TOTAL EST.:',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text('$currency${kotPreviewTotal.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Printer Status Feedback Banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: printResult.success
                            ? const Color(0xFFDCFCE7)
                            : (printResult.isRawBtMissing
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFFEE2E2)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            printResult.success
                                ? Icons.check_circle
                                : (printResult.isRawBtMissing
                                    ? Icons.warning_amber_rounded
                                    : Icons.error_outline),
                            color: printResult.success
                                ? const Color(0xFF16A34A)
                                : (printResult.isRawBtMissing
                                    ? const Color(0xFFD97706)
                                    : const Color(0xFFDC2626)),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              printResult.message,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: printResult.success
                                    ? const Color(0xFF15803D)
                                    : (printResult.isRawBtMissing
                                        ? const Color(0xFF92400E)
                                        : const Color(0xFFB91C1C)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (printResult.isRawBtMissing) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                PrinterService.instance.openRawBtOnPlayStore();
                              },
                              icon: const Icon(Icons.download, size: 16),
                              label: const Text('Get RawBT', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                PrinterService.instance.shareTicket(
                                  printResult.formattedText,
                                  subject: 'KOT - ${widget.table.name}',
                                );
                              },
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Share Ticket', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    PrinterService.showVirtualReceiptDialog(
                      context,
                      printResult.formattedText,
                      title: 'KOT Slip - ${widget.table.name}',
                    );
                  },
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('View Slip'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final res = await PrinterService.instance.printKot(
                      restaurantName: _restaurant?.name ?? '',
                      tableName: widget.table.name,
                      items: cartList,
                      isRunningKot: isRunning,
                      orderId: widget.table.activeOrderId,
                      customerName: widget.table.customerName,
                      customerPhone: widget.table.customerPhone,
                      orderTypeLabel: widget.table.isParcel ? 'PARCEL ORDER' : 'SITDOWN ORDER',
                    );
                    setDialogState(() {
                      printResult = res;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Reprint KOT'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog
                    await _dispatchOrderHeld();
                    if (context.mounted) {
                      Navigator.pop(context); // Return to Tables Screen
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Done & Return to Tables'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCartRow(CartItemModel cartItem, {VoidCallback? onQtyChanged}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Dish Name and Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildDietaryBadge(cartItem.item.isVeg),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cartItem.item.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$currency${cartItem.totalPrice.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 2: Status / Unit Info on Left, Controls on Right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Status badge and unit price
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (cartItem.isExisting)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock, size: 10, color: Color(0xFFB91C1C)),
                            SizedBox(width: 3),
                            Text(
                              'HELD',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: const Text(
                          '✨ NEW',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ),
                    Text(
                      cartItem.isExisting
                          ? (cartItem.newQuantity > 0
                              ? '${cartItem.existingQuantity} held + ${cartItem.newQuantity} new'
                              : '$currency${cartItem.unitPrice.toStringAsFixed(0)} ea • Held')
                          : '$currency${cartItem.unitPrice.toStringAsFixed(0)} each',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Right: Quantity buttons and Delete
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Minus button
                  InkWell(
                    onTap: () {
                      _removeItem(cartItem.item);
                      onQtyChanged?.call();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cartItem.isExisting && !cartItem.canDecrement
                            ? Colors.grey.shade100
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Icon(
                        cartItem.isExisting && !cartItem.canDecrement
                            ? Icons.lock_outline
                            : Icons.remove,
                        size: 15,
                        color: cartItem.isExisting && !cartItem.canDecrement
                            ? Colors.grey.shade400
                            : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 28),
                    alignment: Alignment.center,
                    child: Text(
                      '${cartItem.quantity}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  // Plus button
                  InkWell(
                    onTap: () {
                      _addItem(cartItem.item);
                      onQtyChanged?.call();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(
                        Icons.add,
                        size: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  if (!cartItem.isExisting) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _cart.remove(cartItem.item.id);
                        });
                        onQtyChanged?.call();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          size: 15,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCartSheet() {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomNavPad = MediaQuery.paddingOf(context).bottom;
    final cartListHeight = (screenHeight * 0.42).clamp(180.0, 440.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 580),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + (keyboardHeight > 0 ? 4 : bottomNavPad)),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Cart: ${widget.table.name}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _showOrderCommentsDialog(setModalState),
                                    icon: Icon(
                                      _orderComments.isNotEmpty ? Icons.note_alt : Icons.note_alt_outlined,
                                      size: 14,
                                      color: _orderComments.isNotEmpty ? Colors.blue.shade700 : Colors.grey.shade700,
                                    ),
                                    label: Text(
                                      _orderComments.isNotEmpty ? 'Note Added' : 'Add Note',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _orderComments.isNotEmpty ? Colors.blue.shade700 : Colors.grey.shade700,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                      side: BorderSide(
                                        color: _orderComments.isNotEmpty ? Colors.blue.shade300 : Colors.grey.shade300,
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      backgroundColor: _orderComments.isNotEmpty ? Colors.blue.shade50 : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$_totalItemCount Items',
                                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_orderComments.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.comment, size: 14, color: Colors.blue.shade700),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Note: $_orderComments',
                                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontStyle: FontStyle.italic),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Divider(height: 20),
                          if (_cart.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30.0),
                              child: Center(child: Text('Your cart is empty')),
                            )
                          else
                            ConstrainedBox(
                              constraints: BoxConstraints(maxHeight: cartListHeight),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: _cart.values.length,
                                separatorBuilder: (context, index) => const Divider(height: 12),
                                itemBuilder: (context, index) {
                                  final cartItem = _cart.values.elementAt(index);
                                  return _buildCartRow(cartItem, onQtyChanged: () {
                                    setModalState(() {});
                                    setState(() {});
                                  });
                                },
                              ),
                            ),
                          const Divider(height: 20),
                          // 5-line breakdown per Sam Biswas: Net Total, Discount, Delivery Charge, Tax, Total Payable
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Net Total:',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                              Text('$currency${_netCartTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _isDiscountPercent
                                    ? 'Discount (${_discountPercent.toStringAsFixed(0)}%):'
                                    : 'Discount:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _effectiveDiscount > 0 ? const Color(0xFF00796B) : const Color(0xFF64748B),
                                  fontWeight: _effectiveDiscount > 0 ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              Text(
                                _effectiveDiscount > 0
                                    ? '-$currency${_effectiveDiscount.toStringAsFixed(2)}'
                                    : '$currency 0.00',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _effectiveDiscount > 0 ? FontWeight.bold : FontWeight.w600,
                                  color: _effectiveDiscount > 0 ? const Color(0xFF00796B) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Delivery Charge:',
                                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                              Text(
                                widget.table.isParcel
                                    ? '$currency${_deliveryCharge.toStringAsFixed(2)}'
                                    : '$currency 0.00',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: (widget.table.isParcel && _deliveryCharge > 0) ? FontWeight.bold : FontWeight.w600,
                                  color: (widget.table.isParcel && _deliveryCharge > 0) ? Colors.teal.shade700 : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _taxPercent > 0 ? 'Tax (${_taxPercent.toStringAsFixed(1)}%):' : 'Tax:',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                              Text('$currency${_taxAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                            ],
                          ),
                          const Divider(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Payable:',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              Text('$currency${_payableTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A))),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showDiscountDialog(setModalState),
                                  icon: const Icon(Icons.discount_outlined, size: 15),
                                  label: Text(
                                    _effectiveDiscount > 0
                                        ? 'DISC: $currency${_effectiveDiscount.toStringAsFixed(0)}'
                                        : 'DISCOUNT',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    foregroundColor: const Color(0xFF00796B),
                                    side: const BorderSide(color: Color(0xFF00796B), width: 1.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 3,
                                child: Tooltip(
                                  message: widget.table.isParcel
                                      ? 'Delivery Charge'
                                      : 'Delivery charge is disabled for sit down tables',
                                  child: OutlinedButton.icon(
                                    onPressed: widget.table.isParcel
                                        ? () => _showDeliveryChargeDialog(setModalState)
                                        : null,
                                    icon: Icon(
                                      widget.table.isParcel ? Icons.delivery_dining : Icons.block,
                                      size: 16,
                                      color: widget.table.isParcel ? Colors.teal.shade700 : const Color(0xFF94A3B8),
                                    ),
                                    label: Text(
                                      widget.table.isParcel && _deliveryCharge > 0
                                          ? 'DEL: $currency${_deliveryCharge.toStringAsFixed(0)}'
                                          : 'Del Chg',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: widget.table.isParcel ? Colors.teal.shade700 : const Color(0xFF94A3B8),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      foregroundColor: Colors.teal.shade700,
                                      disabledForegroundColor: const Color(0xFF94A3B8),
                                      side: BorderSide(
                                        color: widget.table.isParcel ? Colors.teal.shade700 : const Color(0xFFCBD5E1),
                                        width: 1.5,
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                flex: 5,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _triggerHoldOrder();
                                  },
                                  icon: Icon(
                                    _isOnlyMetaChanged
                                        ? Icons.check_circle_outline
                                        : Icons.pause_circle_filled,
                                    size: 17,
                                  ),
                                  label: Text(
                                    _isOnlyMetaChanged
                                        ? 'SAVE ORDER'
                                        : 'HOLD & PRINT KOT',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: _isOnlyMetaChanged
                                        ? const Color(0xFF00796B)
                                        : const Color(0xFF16A34A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if ((widget.table.isOpen || widget.table.activeCart.isNotEmpty) && widget.onSettleOrder != null) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showSettleDialog();
                                },
                                icon: const Icon(Icons.print, size: 16),
                                label: Text(
                                  'PRINT BILL & SETTLE ($currency${_payableTotal.toStringAsFixed(_payableTotal % 1 == 0 ? 0 : 2)})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Live Pinned Cart Sidebar on Tablet Landscape screens
  Widget _buildCartSidebar() {
    return Container(
      width: 380,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.table.name.toUpperCase(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.table.customerPhone != null
                            ? 'Customer: ${widget.table.customerPhone}'
                            : 'Channel: ${widget.table.isParcel ? "Parcel / Takeaway" : "Sit-Down"}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showOrderCommentsDialog,
                      icon: Icon(
                        _orderComments.isNotEmpty ? Icons.note_alt : Icons.note_alt_outlined,
                        size: 14,
                        color: _orderComments.isNotEmpty ? Colors.blue.shade700 : Colors.grey.shade700,
                      ),
                      label: Text(
                        _orderComments.isNotEmpty ? 'Note Added' : 'Add Note',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _orderComments.isNotEmpty ? Colors.blue.shade700 : Colors.grey.shade700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(
                          color: _orderComments.isNotEmpty ? Colors.blue.shade300 : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        backgroundColor: _orderComments.isNotEmpty ? Colors.blue.shade50 : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_totalItemCount Items',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_orderComments.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  Icon(Icons.comment, size: 14, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Note: $_orderComments',
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade900, fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // Cart Items List
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('Cart is empty', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Tap any dish on the left to add', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _cart.values.length,
                    separatorBuilder: (context, index) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final cartItem = _cart.values.elementAt(index);
                      return _buildCartRow(cartItem, onQtyChanged: () => setState(() {}));
                    },
                  ),
          ),

          // Sticky Bottom Summary & HOLD Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  // 5-line breakdown per Sam Biswas: Net Total, Discount, Delivery Charge, Tax, Total Payable
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Net Total:',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      Text(
                        '$currency${_netCartTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isDiscountPercent
                            ? 'Discount (${_discountPercent.toStringAsFixed(0)}%):'
                            : 'Discount:',
                        style: TextStyle(
                          fontSize: 13,
                          color: _effectiveDiscount > 0 ? const Color(0xFF00796B) : const Color(0xFF64748B),
                          fontWeight: _effectiveDiscount > 0 ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      Text(
                        _effectiveDiscount > 0
                            ? '-$currency${_effectiveDiscount.toStringAsFixed(2)}'
                            : '$currency 0.00',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _effectiveDiscount > 0 ? FontWeight.bold : FontWeight.w600,
                          color: _effectiveDiscount > 0 ? const Color(0xFF00796B) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Delivery Charge:',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      Text(
                        widget.table.isParcel
                            ? '$currency${_deliveryCharge.toStringAsFixed(2)}'
                            : '$currency 0.00',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: (widget.table.isParcel && _deliveryCharge > 0) ? FontWeight.bold : FontWeight.w600,
                          color: (widget.table.isParcel && _deliveryCharge > 0) ? Colors.teal.shade700 : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _taxPercent > 0 ? 'Tax (${_taxPercent.toStringAsFixed(1)}%):' : 'Tax:',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '$currency${_taxAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                    ],
                  ),
                  const Divider(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Payable:',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '$currency${_payableTotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: OutlinedButton.icon(
                          onPressed: _showDiscountDialog,
                          icon: const Icon(Icons.discount_outlined, size: 15),
                          label: Text(
                            _effectiveDiscount > 0
                                ? 'DISC: $currency${_effectiveDiscount.toStringAsFixed(0)}'
                                : 'DISCOUNT',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            foregroundColor: const Color(0xFF00796B),
                            side: const BorderSide(color: Color(0xFF00796B), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 3,
                        child: Tooltip(
                          message: widget.table.isParcel
                              ? 'Delivery Charge'
                              : 'Delivery charge is disabled for sit down tables',
                          child: OutlinedButton.icon(
                            onPressed: widget.table.isParcel
                                ? _showDeliveryChargeDialog
                                : null,
                            icon: Icon(
                              widget.table.isParcel ? Icons.delivery_dining : Icons.block,
                              size: 16,
                              color: widget.table.isParcel ? Colors.teal.shade700 : const Color(0xFF94A3B8),
                            ),
                            label: Text(
                              widget.table.isParcel && _deliveryCharge > 0
                                  ? 'DEL: $currency${_deliveryCharge.toStringAsFixed(0)}'
                                  : 'Del Chg',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: widget.table.isParcel ? Colors.teal.shade700 : const Color(0xFF94A3B8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              foregroundColor: Colors.teal.shade700,
                              disabledForegroundColor: const Color(0xFF94A3B8),
                              side: BorderSide(
                                color: widget.table.isParcel ? Colors.teal.shade700 : const Color(0xFFCBD5E1),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 5,
                        child: ElevatedButton.icon(
                          onPressed: (_totalItemCount > 0 || _isOnlyMetaChanged) ? _triggerHoldOrder : null,
                          icon: Icon(
                            _isOnlyMetaChanged
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_filled,
                            size: 17,
                          ),
                          label: Text(
                            _isOnlyMetaChanged
                                ? 'SAVE ORDER'
                                : 'HOLD & PRINT KOT',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: _isOnlyMetaChanged
                                ? const Color(0xFF00796B)
                                : const Color(0xFF16A34A),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[300],
                            disabledForegroundColor: Colors.grey[500],
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((widget.table.isOpen || widget.table.activeCart.isNotEmpty) && widget.onSettleOrder != null) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showSettleDialog,
                        icon: const Icon(Icons.print, size: 16),
                        label: Text(
                          'PRINT BILL & SETTLE ($currency${_payableTotal.toStringAsFixed(_payableTotal % 1 == 0 ? 0 : 2)})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWideTablet = screenWidth >= 880;

    final menuContent = Column(
      children: [
        // Search Bar ("Search for Dishes...")
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search for Dishes...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Horizontal Category Pills
        SizedBox(
          height: 42,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                selectedColor: const Color(0xFF0F172A),
                backgroundColor: const Color(0xFFF1F5F9),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  }
                },
              );
            },
          ),
        ),

        const SizedBox(height: 8),

        // Dishes List / Responsive Grid
        Expanded(
          child: _filteredMenu.isEmpty
              ? Center(
                  child: Text(
                    'No dishes found matching "$_searchQuery"',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isGrid = constraints.maxWidth >= 550;
                    final cols = constraints.maxWidth >= 950
                        ? 3
                        : (constraints.maxWidth >= 550 ? 2 : 1);

                    if (isGrid) {
                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, isWideTablet ? 20 : 80),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.8,
                        ),
                        itemCount: _filteredMenu.length,
                        itemBuilder: (context, index) {
                          final item = _filteredMenu[index];
                          return _buildDishCard(item);
                        },
                      );
                    }

                    // Mobile list view
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                      itemCount: _filteredMenu.length,
                      separatorBuilder: (context, index) => const Divider(height: 8),
                      itemBuilder: (context, index) {
                        final item = _filteredMenu[index];
                        return _buildDishCard(item);
                      },
                    );
                  },
                ),
        ),

        // Bottom Sticky Cart & HOLD Action Bar (mobile/portrait only)
        if (!isWideTablet) _buildBottomActionBar(),
      ],
    );

    return PopScope(
      canPop: !_isSavingOrder && !(!_hasDispatchedOrderHeld && _isMetaChanged),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!_hasDispatchedOrderHeld && _isMetaChanged) {
          await _dispatchOrderHeld();
          if (context.mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            onPressed: () async {
              if (!_hasDispatchedOrderHeld && _isMetaChanged) {
                await _dispatchOrderHeld();
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.table.name.toUpperCase(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                widget.table.customerPhone != null
                    ? 'Customer: ${widget.table.customerPhone}'
                    : 'Channel: ${widget.table.isParcel ? "Parcel / Takeaway" : "Sit-Down"}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            if (!isWideTablet)
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restaurant_menu,
                          color: Color(0xFF0F172A), size: 26),
                      onPressed: _showCartSheet,
                    ),
                    if (_totalItemCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Text(
                            '$_totalItemCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: isWideTablet
              ? Row(
                  children: [
                    Expanded(child: menuContent),
                    _buildCartSidebar(),
                  ],
                )
              : menuContent,
        ),
      ),
    );
  }

  Widget _buildDishCard(MenuItemModel item) {
    final inCart = _cart.containsKey(item.id);
    final cartItem = inCart ? _cart[item.id]! : null;
    final qty = inCart ? cartItem!.quantity : 0;
    final isExisting = cartItem?.isExisting ?? false;
    final canDecrement = cartItem?.canDecrement ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: inCart ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: inCart ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0),
          width: inCart ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Dietary Veg / Non-Veg badge
          _buildDietaryBadge(item.isVeg),
          const SizedBox(width: 10),

          // Dish details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (isExisting)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          cartItem!.newQuantity > 0
                              ? '🔒 Held: ${cartItem.existingQuantity} (+${cartItem.newQuantity})'
                              : '🔒 Held: ${cartItem.existingQuantity}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$currency${item.priceFor(isTakeaway: widget.table.isParcel).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00796B),
                      ),
                    ),
                    if (widget.table.isParcel && item.takeawayPrice > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Takeaway',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7C5DFA),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Add / Counter Controls
          if (!inCart)
            ElevatedButton(
              onPressed: () => _addItem(item),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('ADD',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _removeItem(item),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(
                        isExisting && !canDecrement ? Icons.lock : Icons.remove,
                        size: 16,
                        color: isExisting && !canDecrement
                            ? Colors.white60
                            : Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    '$qty',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  InkWell(
                    onTap: () => _addItem(item),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDietaryBadge(bool isVeg) {
    final color = isVeg ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // Sticky bottom action bar with "HOLD"
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cart preview summary (clickable to open cart sheet)
          InkWell(
            onTap: _showCartSheet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      '$_totalItemCount Items',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_up, size: 16, color: Colors.grey),
                  ],
                ),
                Text(
                  '$currency${_payableTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Discount Button beside HOLD & PRINT KOT
          OutlinedButton.icon(
            onPressed: _showDiscountDialog,
            icon: const Icon(Icons.discount_outlined, size: 16),
            label: Text(
              _effectiveDiscount > 0
                  ? 'DISC: $currency${_effectiveDiscount.toStringAsFixed(0)}'
                  : 'DISC',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              foregroundColor: const Color(0xFF00796B),
              side: const BorderSide(color: Color(0xFF00796B), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),

          const SizedBox(width: 8),

          // Big Prominent "HOLD" Button (Core requirement from Sam)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _totalItemCount > 0 ? _triggerHoldOrder : null,
              icon: Icon(
                _isOnlyDiscountChanged
                    ? Icons.check_circle_outline
                    : Icons.pause_circle_filled,
                size: 18,
              ),
              label: Text(
                _isOnlyDiscountChanged
                    ? 'SAVE DISCOUNT'
                    : 'HOLD & PRINT',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isOnlyDiscountChanged
                    ? const Color(0xFF00796B)
                    : const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

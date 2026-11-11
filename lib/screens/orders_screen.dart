import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/pos_database.dart';
import '../models/report_model.dart';
import '../models/restaurant_model.dart';
import '../models/menu_item_model.dart';
import '../services/printer_service.dart';
import 'reports_screen.dart';
import 'settings_hub_screen.dart';
import '../widgets/settings_password_dialog.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  DateTime _selectedDate = DateTime.now();
  List<CompletedOrderSummary> _orders = [];
  RestaurantModel? _restaurant;
  bool _isLoading = true;
  String _filterType = 'all'; // 'all', 'table', 'parcel'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Bottom Navigation Index (1 = Orders)
  final int _currentNavIndex = 1;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final report = await PosDatabase.instance.getSalesReport(
        period: ReportPeriod.daily,
        targetDate: _selectedDate,
      );
      final rest = await PosDatabase.instance.getRestaurantDetails();
      if (mounted) {
        setState(() {
          // Orders are already sorted newest first (last order first) by SQLite query
          _orders = report.completedOrders;
          _restaurant = rest;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading closed orders: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  void _navigateDay(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
    });
    _loadOrders();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      _loadOrders();
    }
  }

  String _formatCurrency(double amount) {
    final cur = _restaurant?.currency ?? '₹';
    final formatter = NumberFormat('#,##,##0', 'en_IN');
    return '$cur${formatter.format(amount.round())}';
  }

  Future<void> _reprintReceipt(CompletedOrderSummary o) async {
    try {
      final rest = await PosDatabase.instance.getRestaurantDetails();
      final items = await PosDatabase.instance.getOrderItems(o.orderId);

      // Query order directly from SQLite to guarantee we have the exact saved values for discount and delivery charge
      final freshOrderRows = await PosDatabase.instance.database.then(
        (db) => db.query('order_table', where: 'order_id = ?', whereArgs: [o.orderId], limit: 1),
      );
      final freshOrder = freshOrderRows.isNotEmpty ? freshOrderRows.first : null;

      final double discountAmount = freshOrder != null
          ? ((freshOrder['order_discount'] as num?)?.toDouble() ??
             (freshOrder['order_discount_amount'] as num?)?.toDouble() ??
             o.discountAmount)
          : o.discountAmount;

      final double deliveryCharge = freshOrder != null
          ? ((freshOrder['order_delivery_charge'] as num?)?.toDouble() ?? o.deliveryCharge)
          : o.deliveryCharge;

      final billItems = items.isNotEmpty
          ? items
          : [
              CartItemModel(
                item: MenuItemModel(
                  id: 0,
                  categoryId: 1,
                  categoryName: 'General',
                  name: o.isSitDown ? 'Dine-In Order' : 'Takeaway Order',
                  sitdownPrice: o.totalAmount,
                ),
                quantity: o.itemCount > 0 ? o.itemCount : 1,
              ),
            ];

      final destination = o.isSitDown
          ? 'Table ${o.tableNumber}'
          : 'PARCEL: ${o.customerName.isNotEmpty ? o.customerName : "Takeaway"}';

      final printResult = await PrinterService.instance.printBill(
        restaurant: rest,
        destinationName: destination,
        items: billItems,
        total: o.totalAmount,
        paymentMethod: o.paymentDisplay,
        orderId: o.orderId,
        timestamp: o.settledAt,
        customerName: o.customerName,
        customerPhone: o.customerPhone,
        foodTotal: o.foodAmount,
        drinksTotal: o.drinksAmount,
        netTotal: o.netAmount,
        taxTotal: o.taxAmount,
        discountAmount: discountAmount,
        deliveryCharge: deliveryCharge,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                printResult.success ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  printResult.success
                      ? 'Receipt for ${o.isSitDown ? "Table ${o.tableNumber}" : o.customerName} sent to printer!'
                      : 'Reprint notice: ${printResult.message}',
                ),
              ),
            ],
          ),
          backgroundColor:
              printResult.success ? const Color(0xFF16A34A) : Colors.orange.shade800,
          action: SnackBarAction(
            label: 'View Slip',
            textColor: Colors.white,
            onPressed: () {
              PrinterService.showVirtualReceiptDialog(
                context,
                printResult.formattedText,
                title: 'Receipt Copy - Order #${o.orderId}',
              );
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('Error reprinting receipt: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reprint: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showChangePaymentDialog(CompletedOrderSummary o) async {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade400, width: 1.5),
          ),
          backgroundColor: const Color(0xFFF8FAFC),
          child: Container(
            width: 280,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPaymentChoiceButton(
                  label: 'CASH',
                  onTap: () => _updatePaymentMethod(o, 'Cash', dialogCtx),
                ),
                const SizedBox(height: 14),
                _buildPaymentChoiceButton(
                  label: 'CARD',
                  onTap: () => _updatePaymentMethod(o, 'Card', dialogCtx),
                ),
                const SizedBox(height: 14),
                _buildPaymentChoiceButton(
                  label: 'UPI',
                  onTap: () => _updatePaymentMethod(o, 'UPI QR', dialogCtx),
                ),
                const SizedBox(height: 14),
                _buildPaymentChoiceButton(
                  label: 'CANCEL',
                  onTap: () => Navigator.pop(dialogCtx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentChoiceButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7DEBF8),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.black, width: 1.2),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  Future<void> _updatePaymentMethod(
    CompletedOrderSummary o,
    String newMethod,
    BuildContext dialogCtx,
  ) async {
    Navigator.pop(dialogCtx);
    try {
      await PosDatabase.instance.updateOrderPaymentMethod(o.orderId, newMethod);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment mode for Order #${o.orderId} updated to $newMethod!'),
          backgroundColor: const Color(0xFF16A34A),
          duration: const Duration(seconds: 3),
        ),
      );
      _loadOrders();
    } catch (e) {
      debugPrint('Error updating payment method: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update payment method: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  void _showOrderItemsPreview(CompletedOrderSummary o) async {
    final items = await PosDatabase.instance.getOrderItems(o.orderId);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          o.isSitDown
                              ? 'Table ${o.tableNumber} - Order #${o.orderId}'
                              : 'Parcel: ${o.customerName} (#${o.orderId})',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Settled ${DateFormat('dd MMM, h:mm a').format(o.settledAt)} via ${o.paymentDisplay}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 20),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text(
                        'Total: ${_formatCurrency(o.totalAmount)} (${o.itemCount} items)',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const Divider(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Row(
                          children: [
                            Text(
                              '${item.quantity}x',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.item.name,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Text(
                              '${_restaurant?.currency ?? "₹"}${item.totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Net Bill Amount:',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    Text(
                      _formatCurrency(o.netAmount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Tax:',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    Text(
                      _formatCurrency(o.taxAmount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Bill Amount:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text(
                      _formatCurrency(o.totalAmount),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _reprintReceipt(o);
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Reprint Receipt',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTodaySelected = _isToday(_selectedDate);

    // Filter by type (table vs parcel) and search query
    final filteredOrders = _orders.where((o) {
      if (_filterType == 'table' && !o.isSitDown) return false;
      if (_filterType == 'parcel' && o.isSitDown) return false;

      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTable = 'table ${o.tableNumber}'.contains(query);
        final matchName = o.customerName.toLowerCase().contains(query);
        final matchPhone = o.customerPhone.toLowerCase().contains(query);
        final matchId = '#${o.orderId}'.contains(query) || '${o.orderId}'.contains(query);
        return matchTable || matchName || matchPhone || matchId;
      }

      return true;
    }).toList();

    final totalRevenue = filteredOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final tableOrdersCount = _orders.where((o) => o.isSitDown).length;
    final parcelOrdersCount = _orders.where((o) => !o.isSitDown).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Closed Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              isTodaySelected
                  ? "Today's Settled Orders (Last order first)"
                  : '${DateFormat('EEE, dd MMM yyyy').format(_selectedDate)} (Last order first)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Choose Date',
            icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFF0F172A)),
            onPressed: _pickDate,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
            onPressed: _loadOrders,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Column(
        children: [
          // Top Date Navigation & Summary Banner
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                // Date Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _navigateDay(-1),
                      tooltip: 'Previous Day',
                    ),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.today_rounded,
                              size: 18,
                              color: isTodaySelected
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF0F172A),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isTodaySelected
                                  ? "Today (${DateFormat('dd MMM').format(_selectedDate)})"
                                  : DateFormat('EEE, dd MMM yyyy')
                                      .format(_selectedDate),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isTodaySelected
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, size: 18),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _navigateDay(1),
                      tooltip: 'Next Day',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Search Bar
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
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
                      hintText: 'Search table #, customer name, order #...',
                      hintStyle:
                          TextStyle(color: Colors.grey[500], fontSize: 13),
                      prefixIcon: const Icon(Icons.search,
                          size: 18, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Chips Row
                Row(
                  children: [
                    _buildFilterChip('all', 'All (${_orders.length})', null),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'table',
                      'Tables ($tableOrdersCount)',
                      const Color(0xFF16A34A),
                      bgColor: const Color(0xFFF0FDF4),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'parcel',
                      'Parcels ($parcelOrdersCount)',
                      const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                    ),
                    const Spacer(),
                    Text(
                      _formatCurrency(totalRevenue),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Main Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadOrders,
                    child: filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 56,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No closed orders matching "$_searchQuery"'
                                      : 'No closed orders found for this date',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'When tables or parcels are settled and paid,\nthey will automatically appear here with last order first.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                            itemCount: filteredOrders.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final order = filteredOrders[index];
                              return _buildOrderCard(order);
                            },
                          ),
                  ),
          ),

          // Bottom Navigation Bar
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String type, String label, Color? accentColor,
      {Color? bgColor}) {
    final isSelected = _filterType == type;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _filterType = type;
          });
        }
      },
      selectedColor: accentColor ?? const Color(0xFF0F172A),
      backgroundColor: bgColor ?? const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? Colors.white
            : (accentColor ?? const Color(0xFF334155)),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected
              ? (accentColor ?? const Color(0xFF0F172A))
              : Colors.grey.shade300,
        ),
      ),
    );
  }

  /// Order Card:
  /// - Tables in LIGHT GREEN colour
  /// - Parcel orders in LIGHT RED colour
  /// - Includes prominent "Reprint Receipt" button
  Widget _buildOrderCard(CompletedOrderSummary o) {
    final isSitDown = o.isSitDown;

    // Theme colors as requested by Sam Biswas:
    // "the tables will be in light green colour the parcel orders will be in light red colour."
    final Color cardBg =
        isSitDown ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2);
    final Color cardBorder =
        isSitDown ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5);
    final Color accentColor =
        isSitDown ? const Color(0xFF15803D) : const Color(0xFFDC2626);
    final Color badgeBg =
        isSitDown ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);

    final title = isSitDown
        ? 'TABLE ${o.tableNumber}'
        : 'PARCEL - ${o.customerName.isNotEmpty ? o.customerName : "Takeaway"}';

    final subtitle = isSitDown
        ? 'Dine-In • Settled ${DateFormat('h:mm a').format(o.settledAt)}'
        : 'Takeaway • ${o.customerPhone.isNotEmpty ? "${o.customerPhone} • " : ""}Settled ${DateFormat('h:mm a').format(o.settledAt)}';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showOrderItemsPreview(o),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Type & Name, Payment Badge & Order #
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Box
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        isSitDown
                            ? Icons.table_restaurant_rounded
                            : Icons.takeout_dining_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Order Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Text(
                                  '#${o.orderId}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Amount Display
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(o.totalAmount),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: accentColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            o.paymentDisplay.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Container(
                  height: 1,
                  color: cardBorder.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 10),

                // Bottom Row: Items Breakdown on Left, Reprint Receipt Button on Right
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Items and Food/Drinks breakdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${o.itemCount} items',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          [
                            'Net: ${_formatCurrency(o.netAmount)}',
                            if (o.discountAmount > 0) 'Disc: -${_formatCurrency(o.discountAmount)}',
                            if (o.deliveryCharge > 0) 'Del: ${_formatCurrency(o.deliveryCharge)}',
                            'Tax: ${_formatCurrency(o.taxAmount)}',
                          ].join(' • '),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Action Buttons: Change Payment + Reprint Receipt
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.end,
                      children: [
                        // CHANGE PAYMENT BUTTON
                        OutlinedButton(
                          onPressed: () => _showChangePaymentDialog(o),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFF0F172A), width: 1.2),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Change Payment',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),

                        // REPRINT RECEIPT BUTTON
                        ElevatedButton.icon(
                          onPressed: () => _reprintReceipt(o),
                          icon: const Icon(Icons.print_rounded, size: 15),
                          label: const Text(
                            'Reprint Receipt',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom Navigation Bar: Home | Orders | Reports | Settings
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

  Widget _buildNavItem(int index, String label, IconData icon, IconData activeIcon) {
    final isSelected = _currentNavIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () async {
          if (index == 0) {
            Navigator.pop(context); // Return to Tables Screen
          } else if (index == 2) {
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            );
          } else if (index == 3) {
            final authorized = await SettingsPasswordDialog.prompt(context);
            if (!authorized) return;
            if (!mounted) return;

            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SettingsHubScreen(isAuthenticated: true)),
            );
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

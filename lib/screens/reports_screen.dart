import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/pos_database.dart';
import '../models/report_model.dart';
import '../models/restaurant_model.dart';
import '../models/menu_item_model.dart';
import '../services/excel_export_service.dart';
import '../services/printer_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.daily;
  DateTime _targetDate = DateTime.now();
  PosReportModel? _report;
  RestaurantModel? _restaurant;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    try {
      final report = await PosDatabase.instance.getSalesReport(
        period: _selectedPeriod,
        targetDate: _targetDate,
      );
      final rest = await PosDatabase.instance.getRestaurantDetails();
      if (mounted) {
        setState(() {
          _report = report;
          _restaurant = rest;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sales report: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onPeriodChanged(ReportPeriod period) {
    if (_selectedPeriod == period) return;
    setState(() {
      _selectedPeriod = period;
    });
    _loadReport();
  }

  void _navigateDate(int delta) {
    setState(() {
      if (_selectedPeriod == ReportPeriod.daily) {
        _targetDate = _targetDate.add(Duration(days: delta));
      } else {
        _targetDate = _targetDate.add(Duration(days: delta * 7));
      }
    });
    _loadReport();
  }

  void _resetToCurrent() {
    setState(() {
      _targetDate = DateTime.now();
    });
    _loadReport();
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
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
        _targetDate = picked;
      });
      _loadReport();
    }
  }

  bool _isCurrentPeriod() {
    final now = DateTime.now();
    if (_selectedPeriod == ReportPeriod.daily) {
      return _targetDate.year == now.year &&
          _targetDate.month == now.month &&
          _targetDate.day == now.day;
    } else {
      // Current week check
      final mondayOffset = now.weekday - 1;
      final startOfCurrentWeek =
          DateTime(now.year, now.month, now.day - mondayOffset);
      final targetMondayOffset = _targetDate.weekday - 1;
      final startOfTargetWeek = DateTime(
          _targetDate.year, _targetDate.month, _targetDate.day - targetMondayOffset);
      return startOfCurrentWeek.year == startOfTargetWeek.year &&
          startOfCurrentWeek.month == startOfTargetWeek.month &&
          startOfCurrentWeek.day == startOfTargetWeek.day;
    }
  }

  String _formatCurrency(double amount) {
    final cur = _restaurant?.currency ?? '₹';
    final formatter = NumberFormat('#,##,##0', 'en_IN');
    return '$cur${formatter.format(amount.round())}';
  }

  Future<void> _reprintOrder(CompletedOrderSummary o) async {
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

      // If no items in database (e.g. legacy test records), fallback to a placeholder item matching total
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

      final printResult = await PrinterService.instance.printBill(
        restaurant: rest,
        destinationName: o.isSitDown ? 'Table ${o.tableNumber}' : 'PARCEL: ${o.customerName}',
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
                      ? 'Order #${o.orderId} receipt sent to printer!'
                      : 'Reprint notice: ${printResult.message}',
                ),
              ),
            ],
          ),
          backgroundColor: printResult.success ? const Color(0xFF16A34A) : Colors.orange.shade800,
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
      debugPrint('Error reprinting order: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to reprint: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _printReportTicket() async {
    if (_report == null) return;
    try {
      final rest = _restaurant ?? await PosDatabase.instance.getRestaurantDetails();
      final res = await PrinterService.instance.printSalesReport(
        restaurant: rest,
        report: _report!,
        date: _targetDate,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
        ),
      );

      PrinterService.showVirtualReceiptDialog(
        context,
        res.formattedText,
        title: 'Daily Sales Report Ticket',
      );
    } catch (e) {
      debugPrint('Error printing sales report ticket: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Business Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Sales performance, payments & category analytics',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Print Report Ticket',
            icon: const Icon(Icons.print_rounded, color: Color(0xFF0F172A)),
            onPressed: _printReportTicket,
          ),
          IconButton(
            tooltip: 'Export Database to Excel (.xlsx)',
            icon: const Icon(Icons.table_chart_rounded, color: Color(0xFF16A34A)),
            onPressed: () => ExcelExportService.exportAndShare(context),
          ),
          IconButton(
            tooltip: 'Choose Date',
            icon: const Icon(Icons.calendar_month_outlined, color: Color(0xFF0F172A)),
            onPressed: _pickCustomDate,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: Color(0xFF0F172A)),
            onPressed: _loadReport,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Period Selector (Daily vs Weekly only)
                  _buildPeriodToggle(),
                  const SizedBox(height: 12),

                  // 2. Date Navigation Bar
                  _buildDateNavigator(),
                  const SizedBox(height: 16),

                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_report != null) ...[
                    // 3. Hero Summary: Total Gross Business & Order Count
                    _buildHeroCard(_report!),
                    const SizedBox(height: 20),

                    // 4. Payment Business Breakdown (Cash, Card, UPI)
                    _buildPaymentBreakdownSection(_report!),
                    const SizedBox(height: 20),

                    // 5. Item-Wise Daily Sales Breakdown (Sam Biswas requirement 4)
                    _buildItemWiseSalesSection(_report!),
                    const SizedBox(height: 20),

                    // 6. Category Breakdown (Food vs Drinks)
                    _buildFoodDrinksBreakdownSection(_report!),
                    const SizedBox(height: 20),

                    // 6. Full Database Excel Export Card (1 file, 6 tabs)
                    _buildExcelExportCard(),
                    const SizedBox(height: 20),

                    // 7. Completed Orders Log for the Period
                    _buildCompletedOrdersSection(_report!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Segmented Sliding Toggle for Daily vs Weekly Reports ONLY
  Widget _buildPeriodToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildPeriodButton(
              period: ReportPeriod.daily,
              label: 'Daily Report',
              icon: Icons.today_rounded,
            ),
          ),
          Expanded(
            child: _buildPeriodButton(
              period: ReportPeriod.weekly,
              label: 'Weekly Report',
              icon: Icons.date_range_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodButton({
    required ReportPeriod period,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () => _onPeriodChanged(period),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFF0F172A) : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Date Navigator Bar (< [Date Display] > + Today/This Week shortcut)
  Widget _buildDateNavigator() {
    final isCurrent = _isCurrentPeriod();
    final String dateLabel;
    if (_selectedPeriod == ReportPeriod.daily) {
      dateLabel = DateFormat('EEEE, d MMM yyyy').format(_targetDate);
    } else {
      if (_report != null) {
        final start = DateFormat('d MMM').format(_report!.startDate);
        final end = DateFormat('d MMM yyyy').format(_report!.endDate);
        dateLabel = '$start - $end';
      } else {
        dateLabel = 'Week of ${DateFormat('d MMM yyyy').format(_targetDate)}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Color(0xFF0F172A)),
            onPressed: () => _navigateDate(-1),
            tooltip: _selectedPeriod == ReportPeriod.daily ? 'Previous Day' : 'Previous Week',
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_outlined, size: 16, color: Color(0xFF0F172A)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrent) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF86EFAC)),
                    ),
                    child: Text(
                      _selectedPeriod == ReportPeriod.daily ? 'TODAY' : 'THIS WEEK',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isCurrent)
            TextButton(
              onPressed: _resetToCurrent,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _selectedPeriod == ReportPeriod.daily ? 'Today' : 'This Week',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Color(0xFF0F172A)),
            onPressed: () => _navigateDate(1),
            tooltip: _selectedPeriod == ReportPeriod.daily ? 'Next Day' : 'Next Week',
          ),
        ],
      ),
    );
  }

  /// Hero Summary: Total Gross Sales & Total Number of Orders
  Widget _buildHeroCard(PosReportModel report) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedPeriod == ReportPeriod.daily
                        ? 'TOTAL DAILY BUSINESS'
                        : 'TOTAL WEEKLY BUSINESS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade400,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              // Orders Completed Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      size: 14,
                      color: Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${report.totalOrders} ${report.totalOrders == 1 ? 'Order' : 'Orders'}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Total Revenue Display
          Text(
            _formatCurrency(report.totalRevenue),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          // Breakdown requested by Sam Biswas: Total Tax below Total Business, then another line Total Sales
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_outlined, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Text(
                          'Total Sales (Net):',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade300,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatCurrency(report.totalNetSales),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.account_balance_outlined, size: 14, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 6),
                        Text(
                          'Total Tax:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade300,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatCurrency(report.totalTax),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFDE68A),
                      ),
                    ),
                  ],
                ),
                if (report.totalDiscount > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.discount_outlined, size: 14, color: Color(0xFF34D399)),
                          const SizedBox(width: 6),
                          Text(
                            'Total Discount:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade300,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '-${_formatCurrency(report.totalDiscount)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6EE7B7),
                        ),
                      ),
                    ],
                  ),
                ],
                if (report.totalDeliveryCharge > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.delivery_dining, size: 14, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 6),
                          Text(
                            'Delivery Charges:',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade300,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '+${_formatCurrency(report.totalDeliveryCharge)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFDE68A),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Sub-metrics row: Average Order Value & Period Scope
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Avg Order Value:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatCurrency(report.averageOrderValue),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Text(
                  _selectedPeriod == ReportPeriod.daily
                      ? 'Net + Tax + Del Chg - Disc = Total'
                      : '7-Day Aggregation',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _printReportTicket,
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text(
                'PRINT SALES REPORT TICKET',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section: Total Cash, Total Card, Total UPI Business
  Widget _buildPaymentBreakdownSection(PosReportModel report) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance_wallet_rounded,
                    size: 18, color: Color(0xFF0F172A)),
                SizedBox(width: 8),
                Text(
                  'Payment Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Text(
              'Cash • Card • UPI',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Visual Proportion Bar
        if (report.totalRevenue > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (report.totalCashBusiness > 0)
                    Expanded(
                      flex: (report.cashPercentage * 10).round().clamp(1, 1000),
                      child: Container(color: const Color(0xFF10B981)),
                    ),
                  if (report.totalCardBusiness > 0)
                    Expanded(
                      flex: (report.cardPercentage * 10).round().clamp(1, 1000),
                      child: Container(color: const Color(0xFF3B82F6)),
                    ),
                  if (report.totalUpiBusiness > 0)
                    Expanded(
                      flex: (report.upiPercentage * 10).round().clamp(1, 1000),
                      child: Container(color: const Color(0xFF8B5CF6)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 3 Cards: Total Cash, Total Card, Total UPI
        Row(
          children: [
            // Total Cash Business Card
            Expanded(
              child: _buildMetricCard(
                title: 'Total Cash',
                amount: report.totalCashBusiness,
                percentage: report.cashPercentage,
                icon: Icons.payments_rounded,
                accentColor: const Color(0xFF10B981), // Emerald
                bgColor: const Color(0xFFECFDF5),
              ),
            ),
            const SizedBox(width: 10),

            // Total Card Business Card
            Expanded(
              child: _buildMetricCard(
                title: 'Total Card',
                amount: report.totalCardBusiness,
                percentage: report.cardPercentage,
                icon: Icons.credit_card_rounded,
                accentColor: const Color(0xFF3B82F6), // Royal Blue
                bgColor: const Color(0xFFEFF6FF),
              ),
            ),
            const SizedBox(width: 10),

            // Total UPI Business Card
            Expanded(
              child: _buildMetricCard(
                title: 'Total UPI',
                amount: report.totalUpiBusiness,
                percentage: report.upiPercentage,
                icon: Icons.qr_code_2_rounded,
                accentColor: const Color(0xFF8B5CF6), // Purple
                bgColor: const Color(0xFFF5F3FF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Section: Item-Wise Daily Sales Breakdown (Item name, Category, Qty Sold, Revenue)
  Widget _buildItemWiseSalesSection(PosReportModel report) {
    final items = report.itemSales;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_outlined, color: Color(0xFF7C5DFA), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Item-Wise Sales Breakdown',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length} ${items.length == 1 ? "Item" : "Items"} Sold',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7C5DFA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                'No item-level sales recorded for this period.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => Divider(height: 16, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final item = items[index];
                return Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: index < 3 ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${index + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: index < 3 ? const Color(0xFFB45309) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.itemName,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.categoryName,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Text(
                        '${item.quantitySold} sold',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatCurrency(item.totalRevenue),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  /// Section: Total Food Business & Total Drinks Business
  Widget _buildFoodDrinksBreakdownSection(PosReportModel report) {
    final catTotal = report.totalFoodBusiness + report.totalDrinksBusiness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.restaurant_menu_rounded,
                    size: 18, color: Color(0xFF0F172A)),
                SizedBox(width: 8),
                Text(
                  'Food vs Drinks Business',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Text(
              'Item Categories',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Visual Proportion Bar
        if (catTotal > 0) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (report.totalFoodBusiness > 0)
                    Expanded(
                      flex: (report.foodPercentage * 10).round().clamp(1, 1000),
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  if (report.totalDrinksBusiness > 0)
                    Expanded(
                      flex: (report.drinksPercentage * 10).round().clamp(1, 1000),
                      child: Container(color: const Color(0xFF06B6D4)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 2 Cards: Total Food Business and Total Drinks Business
        Row(
          children: [
            // Total Food Business
            Expanded(
              child: _buildMetricCard(
                title: 'Total Food',
                amount: report.totalFoodBusiness,
                percentage: report.foodPercentage,
                icon: Icons.restaurant_rounded,
                accentColor: const Color(0xFFF59E0B), // Warm Amber
                bgColor: const Color(0xFFFFFBEB),
              ),
            ),
            const SizedBox(width: 12),

            // Total Drinks Business
            Expanded(
              child: _buildMetricCard(
                title: 'Total Drinks',
                amount: report.totalDrinksBusiness,
                percentage: report.drinksPercentage,
                icon: Icons.local_bar_rounded,
                accentColor: const Color(0xFF06B6D4), // Cyan
                bgColor: const Color(0xFFECFEFF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Metric Card Component
  Widget _buildMetricCard({
    required String title,
    required double amount,
    required double percentage,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatCurrency(amount),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section: Settled Orders History for this Period
  Widget _buildCompletedOrdersSection(PosReportModel report) {
    final orders = report.completedOrders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 18, color: Color(0xFF0F172A)),
                const SizedBox(width: 8),
                Text(
                  'Completed Orders (${orders.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Text(
              _selectedPeriod == ReportPeriod.daily ? 'Today\'s Log' : 'Week\'s Log',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (orders.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_outlined,
                    size: 44,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No completed orders for this period',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'When sit-down tables or takeaway parcels are settled and paid,\ntheir sales records will automatically populate here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final o = orders[index];
              final isSitDown = o.isSitDown;
              final orderTitle = isSitDown
                  ? 'Table ${o.tableNumber}'
                  : 'Takeaway - ${o.customerName}';

              // Payment badge config
              final Color badgeColor;
              final Color badgeBg;
              switch (o.paymentType) {
                case 'card':
                  badgeColor = const Color(0xFF2563EB);
                  badgeBg = const Color(0xFFEFF6FF);
                  break;
                case 'upi_qr':
                  badgeColor = const Color(0xFF7C3AED);
                  badgeBg = const Color(0xFFF5F3FF);
                  break;
                default:
                  badgeColor = const Color(0xFF16A34A);
                  badgeBg = const Color(0xFFECFDF5);
                  break;
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    // Icon Box
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSitDown
                            ? const Color(0xFF0F172A).withValues(alpha: 0.06)
                            : const Color(0xFF7C5DFA).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isSitDown
                            ? Icons.table_restaurant_rounded
                            : Icons.takeout_dining_rounded,
                        color: isSitDown
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF7C5DFA),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Order Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  orderTitle,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Payment Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: badgeColor.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  o.paymentDisplay.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: badgeColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '${o.itemCount} items',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                ' • Settled ${DateFormat('h:mm a').format(o.settledAt)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Amount & Reprint Action
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(o.totalAmount),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          o.discountAmount > 0
                              ? 'Net ${_formatCurrency(o.netAmount)} | Disc -${_formatCurrency(o.discountAmount)} | Tax ${_formatCurrency(o.taxAmount)}'
                              : 'Net ${_formatCurrency(o.netAmount)} | Tax ${_formatCurrency(o.taxAmount)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _reprintOrder(o),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.print_rounded, size: 13, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Reprint',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  /// Action Card: Export 1 Excel File with 6 Tabs for All Tables and Records
  Widget _buildExcelExportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Export Database (.xlsx)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '1 Excel workbook • 6 tabs with all tables & records',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Generates an Excel spreadsheet with 6 separate sheets: restaurant_table, customer_table, category_table, item_table, order_table, and order_items_table.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.green.shade900,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => ExcelExportService.exportAndShare(context),
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text(
                'Generate & Share XLSX (6 Tabs)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

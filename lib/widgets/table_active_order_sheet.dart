import 'dart:async';
import 'package:flutter/material.dart';
import '../models/table_model.dart';
import '../database/pos_database.dart';
import '../services/printer_service.dart';
import 'order_discount_dialog.dart';

class TableActiveOrderSheet extends StatefulWidget {
  final TableModel table;
  final VoidCallback onAddMoreItems;
  final void Function(String paymentMethod, [double? discountAmount, double? deliveryCharge, String? orderComments]) onSettleAndReleaseTable;
  final FutureOr<void> Function(double newDiscount, [bool isPercent, double percentValue])? onDiscountChanged;
  final FutureOr<void> Function(double newDeliveryCharge)? onDeliveryChargeChanged;
  final String currency;

  const TableActiveOrderSheet({
    super.key,
    required this.table,
    required this.onAddMoreItems,
    required this.onSettleAndReleaseTable,
    this.onDiscountChanged,
    this.onDeliveryChargeChanged,
    this.currency = '₹',
  });

  @override
  State<TableActiveOrderSheet> createState() => _TableActiveOrderSheetState();
}

class _TableActiveOrderSheetState extends State<TableActiveOrderSheet> {
  String _selectedPaymentMethod = 'Cash';
  late double _discountAmount;
  bool _isDiscountPercent = false;
  double _discountPercent = 0.0;
  late double _deliveryCharge;

  @override
  void initState() {
    super.initState();
    _discountAmount = widget.table.discountAmount;
    _discountPercent = widget.table.discountPercent;
    _isDiscountPercent = widget.table.isDiscountPercent;
    _deliveryCharge = 0.0; // Delivery charge disabled for sit down tables
  }

  @override
  void didUpdateWidget(covariant TableActiveOrderSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.table.discountAmount - oldWidget.table.discountAmount).abs() > 0.001) {
      _discountAmount = widget.table.discountAmount;
    }
    if ((widget.table.discountPercent - oldWidget.table.discountPercent).abs() > 0.001) {
      _discountPercent = widget.table.discountPercent;
      _isDiscountPercent = widget.table.isDiscountPercent;
    }
    _deliveryCharge = 0.0; // Delivery charge disabled for sit down tables
  }

  double get _netTotal => widget.table.netTotal;
  double get _effectiveDiscount => _discountAmount.clamp(0.0, _netTotal);
  double get _taxTotal => widget.table.taxTotal;
  double get _totalWithTax => ((_netTotal - _effectiveDiscount) + _taxTotal).clamp(0.0, double.infinity);

  Future<void> _openDiscountDialog() async {
    showDialog(
      context: context,
      builder: (dialogCtx) => OrderDiscountDialog(
        netTotal: _netTotal,
        currency: widget.currency,
        initialDiscount: _discountAmount,
        initialIsPercent: _isDiscountPercent,
        initialPercentValue: _discountPercent,
        onApply: (discountAmount, isPercent, percentValue) async {
          setState(() {
            _discountAmount = discountAmount;
            _isDiscountPercent = isPercent;
            _discountPercent = percentValue;
          });
          if (widget.onDiscountChanged != null) {
            await widget.onDiscountChanged!(_discountAmount, isPercent, percentValue);
          }
        },
        onClear: () async {
          setState(() {
            _discountAmount = 0.0;
            _isDiscountPercent = false;
            _discountPercent = 0.0;
          });
          if (widget.onDiscountChanged != null) {
            await widget.onDiscountChanged!(0.0, false, 0.0);
          }
        },
      ),
    );
  }

  Future<void> _printCustomerReceipt() async {
    try {
      final rest = await PosDatabase.instance.getRestaurantDetails();
      final res = await PrinterService.instance.printBill(
        restaurant: rest,
        destinationName: widget.table.name,
        items: widget.table.activeCart,
        total: _totalWithTax,
        netTotal: _netTotal,
        taxTotal: _taxTotal,
        discountAmount: _effectiveDiscount,
        deliveryCharge: _deliveryCharge,
        paymentMethod: _selectedPaymentMethod,
        orderId: widget.table.activeOrderId,
        customerName: widget.table.customerName,
        customerPhone: widget.table.customerPhone,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                res.success ? Icons.check_circle : Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  res.success
                      ? 'Receipt printed for ${widget.table.name}! Provide bill to customer and settle once payment method is chosen.'
                      : 'Print error: ${res.message}',
                ),
              ),
            ],
          ),
          backgroundColor: res.success ? const Color(0xFF0284C7) : const Color(0xFFDC2626),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      debugPrint('Error printing customer receipt: $e');
    }
  }

  String _formatSessionSubtitle(TableModel table) {
    final parts = <String>[];

    final phone = table.customerPhone;
    if (phone != null && phone.isNotEmpty && !phone.startsWith('100000000')) {
      parts.add('Customer: $phone');
    } else {
      parts.add('Dine-In');
    }

    if (table.seatedAt != null) {
      final diff = DateTime.now().difference(table.seatedAt!);
      if (diff.inMinutes < 1) {
        parts.add('Seated just now');
      } else if (diff.inMinutes < 60) {
        parts.add('Seated ${diff.inMinutes}m ago');
      } else if (diff.inHours < 24) {
        final hours = diff.inHours;
        final mins = diff.inMinutes % 60;
        parts.add(mins > 0 ? 'Seated ${hours}h ${mins}m ago' : 'Seated ${hours}h ago');
      } else {
        parts.add('Seated ${diff.inDays}d ago');
      }
    }

    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    final cart = table.activeCart;
    final total = table.currentTotal;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomNavPad = MediaQuery.paddingOf(context).bottom;
    final itemsListMaxHeight = (screenHeight * 0.32).clamp(160.0, 360.0);

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardHeight),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
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
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header: Table + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      table.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    Text(
                      _formatSessionSubtitle(table),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade400),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 8),
                      SizedBox(width: 5),
                      Text(
                        'OPEN ORDER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB91C1C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 22),

            // Itemized Bill Preview
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: itemsListMaxHeight),
              child: cart.isEmpty
                  ? Center(
                      child: Text(
                        'Order total: ${widget.currency}${total.toStringAsFixed(0)} (Standard Session)',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: cart.length,
                            separatorBuilder: (context, index) => const Divider(height: 8),
                            itemBuilder: (context, index) {
                              final item = cart[index];
                              return Row(
                                children: [
                                  const Icon(Icons.lock, size: 12, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${item.quantity}x ${item.item.name}',
                                      style: const TextStyle(
                                          fontSize: 13, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFFFCA5A5)),
                                    ),
                                    child: const Text(
                                      'HELD',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFB91C1C),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${widget.currency}${item.totalPrice.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, size: 12, color: Color(0xFF64748B)),
                              SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'Existing items cannot be deleted. Tap "Add Food Items" to add new dishes.',
                                  style: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),

            const Divider(height: 16),

            // Four Lines per Sam Biswas: Net Bill Amount, Discount, Total Tax, Total Bill Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Net Bill Amount:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                Text(
                  '${widget.currency}${_netTotal.toStringAsFixed(_netTotal % 1 == 0 ? 0 : 2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            InkWell(
              onTap: _openDiscountDialog,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          _isDiscountPercent && _discountPercent > 0
                              ? 'Discount (${_discountPercent.toStringAsFixed(0)}%):'
                              : 'Discount:',
                          style: TextStyle(
                            fontSize: 13,
                            color: _effectiveDiscount > 0 ? const Color(0xFF00796B) : const Color(0xFF64748B),
                            fontWeight: _effectiveDiscount > 0 ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _effectiveDiscount > 0
                                ? const Color(0xFFE0F2F1)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _effectiveDiscount > 0
                                  ? const Color(0xFF80CBC4)
                                  : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit,
                                size: 10,
                                color: _effectiveDiscount > 0
                                    ? const Color(0xFF00796B)
                                    : const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _effectiveDiscount > 0 ? 'Edit' : 'Add',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _effectiveDiscount > 0
                                      ? const Color(0xFF00796B)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _effectiveDiscount > 0
                          ? '-${widget.currency}${_effectiveDiscount.toStringAsFixed(2)}'
                          : '${widget.currency}0.00',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _effectiveDiscount > 0 ? FontWeight.bold : FontWeight.w600,
                        color: _effectiveDiscount > 0 ? const Color(0xFF00796B) : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            // Delivery Charge Row (Disabled for Sit-Down Dine-In Tables)
            Tooltip(
              message: 'Delivery charge is disabled for sit down tables',
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Delivery Charge:',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.block,
                                size: 10,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Disabled',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '${widget.currency}0.00',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Tax:',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                Text(
                  '${widget.currency}${_taxTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
            if (widget.table.orderComments != null && widget.table.orderComments!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.comment_outlined, size: 14, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Note: ${widget.table.orderComments!.trim()}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Bill Amount:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${widget.currency}${_totalWithTax.toStringAsFixed(_totalWithTax % 1 == 0 ? 0 : 2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Payment method selector
            const Text(
              'Settlement Method:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: ['Cash', 'Card', 'UPI QR'].map((method) {
                final isSelected = _selectedPaymentMethod == method;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Center(child: Text(method)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF0F172A),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedPaymentMethod = method;
                          });
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            const SizedBox(height: 14),

            // Top action buttons row: Add Items & Reprint KOT
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onAddMoreItems();
                    },
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text('Add Items'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Color(0xFF0F172A), width: 1.2),
                      foregroundColor: const Color(0xFF0F172A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final rest = await PosDatabase.instance.getRestaurantDetails();
                      final res = await PrinterService.instance.printKot(
                        restaurantName: rest.name,
                        tableName: table.name,
                        items: cart,
                        isRunningKot: true,
                        orderId: table.activeOrderId,
                        customerName: table.customerName,
                        customerPhone: table.customerPhone,
                        orderTypeLabel: table.isParcel ? 'PARCEL ORDER' : 'SITDOWN ORDER',
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          backgroundColor: res.success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long, size: 16),
                    label: const Text('Reprint KOT'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: const Color(0xFFB45309),
                      side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                      backgroundColor: const Color(0xFFFFFBEB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Customer Bill & Settlement Row: Print Receipt and Print and Settle
            Row(
              children: [
                // "Print Receipt" (Gives bill to customer before receiving payment)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _printCustomerReceipt,
                    icon: const Icon(Icons.receipt_rounded, size: 18),
                    label: const Text(
                      'Print Receipt',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // "Print and Settle" (Receives payment and closes the table)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onSettleAndReleaseTable(
                        _selectedPaymentMethod,
                        _effectiveDiscount,
                        0.0, // Delivery charge disabled for sit down tables
                        widget.table.orderComments,
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                    label: Text(
                      'Print and Settle (${widget.currency}${_totalWithTax.toStringAsFixed(_totalWithTax % 1 == 0 ? 0 : 2)})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
),
);
  }
}

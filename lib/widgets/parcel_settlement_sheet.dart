import 'dart:async';
import 'package:flutter/material.dart';
import '../models/table_model.dart';
import '../database/pos_database.dart';
import '../services/printer_service.dart';
import 'order_discount_dialog.dart';
import 'delivery_charge_dialog.dart';

class ParcelSettlementSheet extends StatefulWidget {
  final TableModel parcel;
  final void Function(String paymentMethod, [double? discountAmount, double? deliveryCharge, String? orderComments]) onCollectAndClose;
  final FutureOr<void> Function(double newDiscount, [bool isPercent, double percentValue])? onDiscountChanged;
  final FutureOr<void> Function(double newDeliveryCharge)? onDeliveryChargeChanged;
  final VoidCallback? onAddMoreItems;
  final String currency;

  const ParcelSettlementSheet({
    super.key,
    required this.parcel,
    required this.onCollectAndClose,
    this.onDiscountChanged,
    this.onDeliveryChargeChanged,
    this.onAddMoreItems,
    this.currency = '₹',
  });

  @override
  State<ParcelSettlementSheet> createState() => _ParcelSettlementSheetState();
}

class _ParcelSettlementSheetState extends State<ParcelSettlementSheet> {
  String _selectedPaymentMethod = 'Cash';
  double? _cashTendered;
  late double _discountAmount;
  bool _isDiscountPercent = false;
  double _discountPercent = 0.0;
  late double _deliveryCharge;

  @override
  void initState() {
    super.initState();
    _discountAmount = widget.parcel.discountAmount;
    _discountPercent = widget.parcel.discountPercent;
    _isDiscountPercent = widget.parcel.isDiscountPercent;
    _deliveryCharge = widget.parcel.deliveryCharge;
    final netTotal = widget.parcel.activeCart.isNotEmpty
        ? widget.parcel.activeCart.fold(0.0, (sum, i) => sum + i.totalPrice)
        : widget.parcel.currentTotal;
    final taxTotal = widget.parcel.activeCart.isNotEmpty
        ? widget.parcel.activeCart.fold(0.0, (sum, i) => sum + (i.totalPrice * (i.item.taxRate / 100.0)))
        : 0.0;
    final effectiveDiscount = _discountAmount.clamp(0.0, netTotal);
    _cashTendered = ((netTotal - effectiveDiscount) + taxTotal + _deliveryCharge).clamp(0.0, double.infinity);
  }

  @override
  void didUpdateWidget(covariant ParcelSettlementSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.parcel.discountAmount - oldWidget.parcel.discountAmount).abs() > 0.001) {
      _discountAmount = widget.parcel.discountAmount;
    }
    if ((widget.parcel.discountPercent - oldWidget.parcel.discountPercent).abs() > 0.001) {
      _discountPercent = widget.parcel.discountPercent;
      _isDiscountPercent = widget.parcel.isDiscountPercent;
    }
    if ((widget.parcel.deliveryCharge - oldWidget.parcel.deliveryCharge).abs() > 0.001) {
      _deliveryCharge = widget.parcel.deliveryCharge;
    }
  }

  Future<void> _openDeliveryChargeDialog(double netTotal, double taxTotal) async {
    showDialog(
      context: context,
      builder: (dialogCtx) => DeliveryChargeDialog(
        currentCharge: _deliveryCharge,
        currency: widget.currency,
        onApply: (newCharge) {
          setState(() {
            _deliveryCharge = newCharge;
            final effectiveDiscount = _discountAmount.clamp(0.0, netTotal);
            final newTotal = ((netTotal - effectiveDiscount) + taxTotal + _deliveryCharge).clamp(0.0, double.infinity);
            _cashTendered = newTotal;
          });
          widget.onDeliveryChargeChanged?.call(newCharge);
        },
      ),
    );
  }

  Future<void> _openDiscountDialog(double netTotal) async {
    showDialog(
      context: context,
      builder: (dialogCtx) => OrderDiscountDialog(
        netTotal: netTotal,
        currency: widget.currency,
        initialDiscount: _discountAmount,
        initialIsPercent: _isDiscountPercent,
        initialPercentValue: _discountPercent,
        onApply: (discountAmount, isPercent, percentValue) async { // <-- Add async here
          setState(() {
            _discountAmount = discountAmount;
            _isDiscountPercent = isPercent;
            _discountPercent = percentValue;
            final taxTotal = widget.parcel.activeCart.isNotEmpty
                ? widget.parcel.activeCart.fold(0.0, (sum, i) => sum + (i.totalPrice * (i.item.taxRate / 100.0)))
                : 0.0;
            final effectiveDiscount = _discountAmount.clamp(0.0, netTotal);
            final newTotal = ((netTotal - effectiveDiscount) + taxTotal + _deliveryCharge).clamp(0.0, double.infinity);
            _cashTendered = newTotal;
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
            final taxTotal = widget.parcel.activeCart.isNotEmpty
                ? widget.parcel.activeCart.fold(0.0, (sum, i) => sum + (i.totalPrice * (i.item.taxRate / 100.0)))
                : 0.0;
            final newTotal = (netTotal + taxTotal + _deliveryCharge).clamp(0.0, double.infinity);
            _cashTendered = newTotal;
          });
          if (widget.onDiscountChanged != null) {
            await widget.onDiscountChanged!(0.0, false, 0.0);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parcel = widget.parcel;
    final netTotal = parcel.activeCart.isNotEmpty
        ? parcel.activeCart.fold(0.0, (sum, i) => sum + i.totalPrice)
        : parcel.currentTotal;
    final taxTotal = parcel.activeCart.isNotEmpty
        ? parcel.activeCart.fold(0.0, (sum, i) => sum + (i.totalPrice * (i.item.taxRate / 100.0)))
        : 0.0;
    final discountAmount = _discountAmount.clamp(0.0, netTotal);
    final totalBillAmount = ((netTotal - discountAmount) + taxTotal + _deliveryCharge).clamp(0.0, double.infinity);

    final token = '#P${parcel.id % 100 > 0 ? (parcel.id % 100).toString().padLeft(2, '0') : "01"}';

    final changeDue = (_cashTendered != null && _cashTendered! >= totalBillAmount)
        ? _cashTendered! - totalBillAmount
        : 0.0;

    final screenHeight = MediaQuery.sizeOf(context).height;
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final bottomNavPad = MediaQuery.paddingOf(context).bottom;
    final itemsListMaxHeight = (screenHeight * 0.28).clamp(100.0, 260.0);

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
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Token & Customer Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C5DFA), // Purple matching parcel tab
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        token,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parcel.customerName ?? 'Takeaway Guest',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                              parcel.customerPhone ?? 'No Phone Provided',
                              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Colors.red, size: 8),
                      SizedBox(width: 5),
                      Text(
                        'OPEN PARCEL',
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

            const Divider(height: 24),

            // Order items summary card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${parcel.itemCount > 0 ? parcel.itemCount : (parcel.activeCart.isNotEmpty ? parcel.activeCart.length : 2)} Food Items Ordered',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const Text(
                        'Counter Pickup',
                        style: TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (parcel.activeCart.isNotEmpty) ...[
                    const Divider(height: 14),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: itemsListMaxHeight),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: parcel.activeCart.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final item = parcel.activeCart[index];
                          return Row(
                            children: [
                              const Icon(Icons.lock, size: 11, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${item.quantity}x ${item.item.name}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: const Text(
                                  'HELD',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFB91C1C),
                                  ),
                                ),
                              ),
                              Text(
                                '${widget.currency}${item.totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const Divider(height: 14),

                  // Four Lines per Sam Biswas: Net Bill Amount, Discount, Total Tax, Total Bill Amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Net Bill Amount:',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${widget.currency}${netTotal.toStringAsFixed(netTotal % 1 == 0 ? 0 : 2)}',
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
                    onTap: () => _openDiscountDialog(netTotal),
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
                                  color: discountAmount > 0 ? const Color(0xFF00796B) : const Color(0xFF64748B),
                                  fontWeight: discountAmount > 0 ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: discountAmount > 0
                                      ? const Color(0xFFE0F2F1)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: discountAmount > 0
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
                                      color: discountAmount > 0
                                          ? const Color(0xFF00796B)
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      discountAmount > 0 ? 'Edit' : 'Add',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: discountAmount > 0
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
                            discountAmount > 0
                                ? '-${widget.currency}${discountAmount.toStringAsFixed(2)}'
                                : '${widget.currency}0.00',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: discountAmount > 0 ? FontWeight.bold : FontWeight.w600,
                              color: discountAmount > 0 ? const Color(0xFF00796B) : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  InkWell(
                    onTap: () => _openDeliveryChargeDialog(netTotal, taxTotal),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Delivery Charge:',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _deliveryCharge > 0 ? const Color(0xFFD97706) : const Color(0xFF64748B),
                                  fontWeight: _deliveryCharge > 0 ? FontWeight.bold : FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _deliveryCharge > 0
                                      ? const Color(0xFFFEF3C7)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _deliveryCharge > 0
                                        ? const Color(0xFFFCD34D)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.delivery_dining,
                                      size: 10,
                                      color: _deliveryCharge > 0
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      _deliveryCharge > 0 ? 'Edit' : 'Add',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _deliveryCharge > 0
                                            ? const Color(0xFFD97706)
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _deliveryCharge > 0
                                ? '+${widget.currency}${_deliveryCharge.toStringAsFixed(2)}'
                                : '${widget.currency}0.00',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: _deliveryCharge > 0 ? FontWeight.bold : FontWeight.w600,
                              color: _deliveryCharge > 0 ? const Color(0xFFD97706) : const Color(0xFF334155),
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
                        '${widget.currency}${taxTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                  if (widget.parcel.orderComments != null && widget.parcel.orderComments!.trim().isNotEmpty) ...[
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
                              'Note: ${widget.parcel.orderComments!.trim()}',
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
                        '${widget.currency}${totalBillAmount.toStringAsFixed(totalBillAmount % 1 == 0 ? 0 : 2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Payment Mode Selector
            const Text(
              'Customer Payment Mode:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 8),
            Row(
              children: ['Cash', 'UPI QR', 'Card'].map((method) {
                final isSelected = _selectedPaymentMethod == method;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ChoiceChip(
                      label: Center(child: Text(method)),
                      selected: isSelected,
                      selectedColor: const Color(0xFF7C5DFA),
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
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

            // Cash Tender Shortcuts (if Cash is selected)
            if (_selectedPaymentMethod == 'Cash') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Cash Given:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const Spacer(),
                  _buildQuickCashButton(totalBillAmount, 'Exact'),
                  const SizedBox(width: 6),
                  _buildQuickCashButton((totalBillAmount / 500).ceil() * 500.0, '${widget.currency}${((totalBillAmount / 500).ceil() * 500).toStringAsFixed(0)}'),
                  const SizedBox(width: 6),
                  _buildQuickCashButton(((totalBillAmount / 1000).ceil() * 1000.0).clamp(1000.0, 5000.0), '${widget.currency}${((totalBillAmount / 1000).ceil() * 1000).clamp(1000.0, 5000.0).toStringAsFixed(0)}'),
                ],
              ),
              if (changeDue > 0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Change to Return Customer:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
                      Text('${widget.currency}${changeDue.toStringAsFixed(changeDue % 1 == 0 ? 0 : 2)}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E40AF))),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 14),

            // Reprint KOT button
            OutlinedButton.icon(
              onPressed: () async {
                final rest = await PosDatabase.instance.getRestaurantDetails();
                final res = await PrinterService.instance.printKot(
                  restaurantName: rest.name,
                  tableName: 'PARCEL: ${parcel.customerName ?? "Takeaway"}',
                  items: parcel.activeCart,
                  isRunningKot: false,
                  orderId: parcel.activeOrderId,
                  customerName: parcel.customerName,
                  customerPhone: parcel.customerPhone,
                  orderTypeLabel: 'PARCEL ORDER',
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
              label: const Text('Reprint KOT for Kitchen'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                foregroundColor: const Color(0xFF7C5DFA),
                side: const BorderSide(color: Color(0xFF7C5DFA)),
                backgroundColor: const Color(0xFFF5F3FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            const SizedBox(height: 14),

            // Main Actions: Add Food & Collect Payment
            Row(
              children: [
                if (widget.onAddMoreItems != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onAddMoreItems!();
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Add Food'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Color(0xFF7C5DFA), width: 1.5),
                        foregroundColor: const Color(0xFF7C5DFA),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (widget.onAddMoreItems != null) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onCollectAndClose(
                        _selectedPaymentMethod,
                        discountAmount,
                        _deliveryCharge,
                        widget.parcel.orderComments,
                      );
                    },
                    icon: const Icon(Icons.check_circle, size: 20),
                    label: Text(
                      'COLLECT ${widget.currency}${totalBillAmount.toStringAsFixed(totalBillAmount % 1 == 0 ? 0 : 2)} & CLOSE',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFF16A34A), // Vibrant green
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildQuickCashButton(double amount, String label) {
    final isSelected = _cashTendered == amount;
    return OutlinedButton(
      onPressed: () {
        setState(() {
          _cashTendered = amount;
        });
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        side: BorderSide(color: isSelected ? const Color(0xFF7C5DFA) : Colors.grey.shade400, width: isSelected ? 1.5 : 1),
        backgroundColor: isSelected ? const Color(0xFFEDE9FE) : Colors.white,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? const Color(0xFF7C5DFA) : Colors.black87,
        ),
      ),
    );
  }
}

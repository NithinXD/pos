import 'package:flutter/material.dart';
import '../models/table_model.dart';

class OrderDetailsSheet extends StatefulWidget {
  final TableModel table;
  final ValueChanged<TableOrderStatus> onStatusChanged;
  final VoidCallback? onAddOrder;
  final VoidCallback? onCloseParcelOrder;
  final String currency;

  const OrderDetailsSheet({
    super.key,
    required this.table,
    required this.onStatusChanged,
    this.onAddOrder,
    this.onCloseParcelOrder,
    this.currency = '₹',
  });

  @override
  State<OrderDetailsSheet> createState() => _OrderDetailsSheetState();
}

class _OrderDetailsSheetState extends State<OrderDetailsSheet> {
  String _selectedPaymentMethod = 'Cash';

  @override
  Widget build(BuildContext context) {
    final table = widget.table;
    final isOpen = table.isOpen;
    final isParcel = table.isParcel;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isParcel
                          ? (table.customerName ?? table.name)
                          : table.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isParcel
                          ? 'Phone: ${table.customerPhone ?? "N/A"}'
                          : (table.customerPhone != null
                              ? 'Virtual Phone: ${table.customerPhone}'
                              : 'Table ID: #${table.tableNumber}'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? const Color(0xFFFFEBEE)
                        : const Color(0xFFE0F2F1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isOpen ? Colors.red : const Color(0xFF00796B),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOpen ? Colors.red : const Color(0xFF00796B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isParcel
                            ? 'PARCEL READY'
                            : (isOpen ? 'OPEN ORDER' : 'CLOSED / FREE'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isOpen ? Colors.red[900] : const Color(0xFF004D40),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Order stats summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('Items', '${table.itemCount} items'),
                  Container(height: 30, width: 1, color: Colors.grey[300]),
                  _buildStatColumn(
                    'Total Bill Amount',
                    '${widget.currency}${table.totalWithTax.toStringAsFixed(table.totalWithTax % 1 == 0 ? 0 : 2)}',
                  ),
                  Container(height: 30, width: 1, color: Colors.grey[300]),
                  _buildStatColumn(
                    'Channel',
                    isParcel ? 'Takeaway' : 'Dine-In',
                  ),
                ],
              ),
            ),
            if (table.activeCart.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ordered Dishes (Held in Kitchen):',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                        Text(
                          'No delete option',
                          style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const Divider(height: 12),
                    ...table.activeCart.map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Row(
                            children: [
                              const Icon(Icons.lock, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${c.quantity}x ${c.item.name}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: const Text(
                                  'HELD',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB91C1C)),
                                ),
                              ),
                              Text('${widget.currency}${c.totalPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Parcel Specific Settlement Flow
            if (isParcel) ...[
              const Text(
                'Select Payment Method:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['Cash', 'Card', 'UPI QR'].map((method) {
                  final isSelected = _selectedPaymentMethod == method;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ChoiceChip(
                        label: Center(child: Text(method)),
                        selected: isSelected,
                        selectedColor: const Color(0xFF7952DE),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
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
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.onCloseParcelOrder != null) {
                    widget.onCloseParcelOrder!();
                  }
                },
                icon: const Icon(Icons.check_circle, size: 20),
                label: Text(
                  'Collect ${widget.currency}${table.totalWithTax.toStringAsFixed(table.totalWithTax % 1 == 0 ? 0 : 2)} ($_selectedPaymentMethod) & Close Parcel',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ] else ...[
              // Sit-down table actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onStatusChanged(
                          isOpen
                              ? TableOrderStatus.closed
                              : TableOrderStatus.open,
                        );
                      },
                      icon: Icon(
                        isOpen ? Icons.check_circle_outline : Icons.restaurant,
                        size: 18,
                      ),
                      label: Text(
                        isOpen ? 'Mark Closed (Green)' : 'Mark Open (Red)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isOpen ? const Color(0xFF00796B) : Colors.red,
                          width: 1.5,
                        ),
                        foregroundColor:
                            isOpen ? const Color(0xFF00796B) : Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        if (widget.onAddOrder != null) {
                          widget.onAddOrder!();
                        }
                      },
                      icon: Icon(
                        isOpen ? Icons.receipt_long : Icons.add,
                        size: 18,
                      ),
                      label: Text(
                        isOpen ? 'View Order' : 'Start Order',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

enum DiscountType { amount, percent }

class OrderDiscountDialog extends StatefulWidget {
  final double netTotal;
  final String currency;
  final double initialDiscount;
  final bool initialIsPercent;
  final double initialPercentValue;
  final void Function(double discountAmount, bool isPercent, double percentValue) onApply;
  final VoidCallback onClear;

  const OrderDiscountDialog({
    super.key,
    required this.netTotal,
    this.currency = '₹',
    this.initialDiscount = 0.0,
    this.initialIsPercent = false,
    this.initialPercentValue = 0.0,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<OrderDiscountDialog> createState() => _OrderDiscountDialogState();
}

class _OrderDiscountDialogState extends State<OrderDiscountDialog> {
  late DiscountType _discountType;
  String _inputBuffer = '';
  bool _isFreshInput = false;

  @override
  void initState() {
    super.initState();
    _discountType = widget.initialIsPercent ? DiscountType.percent : DiscountType.amount;
    if (widget.initialIsPercent && widget.initialPercentValue > 0) {
      _inputBuffer = widget.initialPercentValue % 1 == 0
          ? widget.initialPercentValue.toInt().toString()
          : widget.initialPercentValue.toString();
      _isFreshInput = true;
    } else if (widget.initialDiscount > 0) {
      _inputBuffer = widget.initialDiscount % 1 == 0
          ? widget.initialDiscount.toInt().toString()
          : widget.initialDiscount.toString();
      _isFreshInput = true;
    }
  }

  double get _numericInput => double.tryParse(_inputBuffer) ?? 0.0;

  double get _calculatedDiscount {
    if (_discountType == DiscountType.amount) {
      return _numericInput.clamp(0.0, widget.netTotal);
    } else {
      final pct = _numericInput.clamp(0.0, 100.0);
      return (widget.netTotal * (pct / 100.0));
    }
  }

  void _onKeyPress(String key) {
    setState(() {
      if (_isFreshInput) {
        _isFreshInput = false;
        _inputBuffer = '';
      }
      if (key == '.') {
        if (!_inputBuffer.contains('.')) {
          if (_inputBuffer.isEmpty) {
            _inputBuffer = '0.';
          } else {
            _inputBuffer += '.';
          }
        }
      } else {
        // Prevent typing more than 2 decimal digits
        if (_inputBuffer.contains('.')) {
          final parts = _inputBuffer.split('.');
          if (parts.length > 1 && parts[1].length >= 2) {
            return;
          }
        }
        if (_inputBuffer == '0') {
          _inputBuffer = key;
        } else {
          _inputBuffer += key;
        }
      }
    });
  }

  void _onBackspace() {
    setState(() {
      _isFreshInput = false;
      if (_inputBuffer.isNotEmpty) {
        _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
      }
    });
  }

  void _onClearAll() {
    setState(() {
      _isFreshInput = false;
      _inputBuffer = '';
    });
  }

  void _apply() {
    final discount = _calculatedDiscount;
    if (_discountType == DiscountType.percent) {
      final pct = _numericInput.clamp(0.0, 100.0);
      widget.onApply(discount, true, pct);
    } else {
      widget.onApply(discount, false, 0.0);
    }
    Navigator.of(context).pop();
  }

  void _remove() {
    widget.onClear();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isAmount = _discountType == DiscountType.amount;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Apply Order Discount',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Top 2 Tabs: Amount and Percent (matching JS Paint mockup)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        label: 'Amount',
                        icon: Icons.currency_rupee,
                        isSelected: isAmount,
                        onTap: () {
                          setState(() {
                            _discountType = DiscountType.amount;
                            _inputBuffer = '';
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        label: 'Percent',
                        icon: Icons.percent,
                        isSelected: !isAmount,
                        onTap: () {
                          setState(() {
                            _discountType = DiscountType.percent;
                            _inputBuffer = '';
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3x4 Numpad Grid (matching mockup)
              _buildNumpad(),

              const SizedBox(height: 16),

              // Discount Banner in Teal (matching mockup colored bottom bar)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B), // Deep teal matching mockup
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00796B).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Discount:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      isAmount
                          ? '${widget.currency}${_calculatedDiscount.toStringAsFixed(2)}'
                          : '${_numericInput.clamp(0.0, 100.0).toStringAsFixed(_numericInput % 1 == 0 ? 0 : 2)}% (${widget.currency}${_calculatedDiscount.toStringAsFixed(2)})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons: Clear (if discount exists) / Cancel and Apply
              Row(
                children: [
                  if (widget.initialDiscount > 0) ...[
                    OutlinedButton(
                      onPressed: _remove,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Remove Discount', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00796B),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[300],
                        disabledForegroundColor: Colors.grey[500],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? const Color(0xFF00796B) : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    return Column(
      children: [
        _buildNumpadRow(['1', '2', '3']),
        const SizedBox(height: 8),
        _buildNumpadRow(['4', '5', '6']),
        const SizedBox(height: 8),
        _buildNumpadRow(['7', '8', '9']),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildNumpadKey('.')),
            const SizedBox(width: 8),
            Expanded(child: _buildNumpadKey('0')),
            const SizedBox(width: 8),
            Expanded(child: _buildBackspaceKey()),
          ],
        ),
      ],
    );
  }

  Widget _buildNumpadRow(List<String> keys) {
    return Row(
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _buildNumpadKey(keys[i])),
        ],
      ],
    );
  }

  Widget _buildNumpadKey(String label) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _onKeyPress(label),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return Material(
      color: const Color(0xFF00796B), // Colored action button matching mockup teal
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: _onBackspace,
        onLongPress: _onClearAll,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.backspace_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

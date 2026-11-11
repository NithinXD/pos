import 'package:flutter/material.dart';
import '../database/pos_database.dart';
import '../models/delivery_zone_model.dart';
import '../screens/delivery_zones_screen.dart';

class DeliveryChargeDialog extends StatefulWidget {
  final double initialCharge;
  final String currency;
  final void Function(double charge) onApply;
  final VoidCallback? onClear;

  const DeliveryChargeDialog({
    super.key,
    double initialCharge = 0.0,
    double? currentCharge,
    this.currency = '₹',
    required this.onApply,
    this.onClear,
  }) : initialCharge = currentCharge ?? initialCharge;

  @override
  State<DeliveryChargeDialog> createState() => _DeliveryChargeDialogState();
}

class _DeliveryChargeDialogState extends State<DeliveryChargeDialog> {
  String _inputBuffer = '';
  List<DeliveryZoneModel> _zones = [];
  bool _isLoadingZones = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialCharge > 0) {
      _inputBuffer = widget.initialCharge % 1 == 0
          ? widget.initialCharge.toInt().toString()
          : widget.initialCharge.toString();
    }
    _loadDeliveryZones();
  }

  Future<void> _loadDeliveryZones() async {
    try {
      final zones = await PosDatabase.instance.getDeliveryZones();
      if (mounted) {
        setState(() {
          _zones = zones;
          _isLoadingZones = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingZones = false);
      }
    }
  }

  double get _numericInput => double.tryParse(_inputBuffer) ?? 0.0;

  void _onKeyPress(String key) {
    setState(() {
      if (key == '.') {
        if (!_inputBuffer.contains('.')) {
          if (_inputBuffer.isEmpty) {
            _inputBuffer = '0.';
          } else {
            _inputBuffer += '.';
          }
        }
      } else {
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
      if (_inputBuffer.isNotEmpty) {
        _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
      }
    });
  }

  void _onClearAll() {
    setState(() {
      _inputBuffer = '';
    });
  }

  void _selectZone(DeliveryZoneModel zone) {
    setState(() {
      _inputBuffer = zone.deliveryCharge % 1 == 0
          ? zone.deliveryCharge.toInt().toString()
          : zone.deliveryCharge.toStringAsFixed(2);
    });
  }

  void _apply() {
    widget.onApply(_numericInput);
    Navigator.of(context).pop();
  }

  void _remove() {
    if (widget.onClear != null) {
      widget.onClear!();
    } else {
      widget.onApply(0.0);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delivery_dining, color: Colors.teal, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery Charge',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Select zone or enter custom charge',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Delivery Zones Quick Select
                if (_isLoadingZones)
                  const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)))
                else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'DELIVERY ZONES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.8,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DeliveryZonesScreen()),
                          );
                          _loadDeliveryZones();
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune_rounded, size: 14, color: Colors.teal.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'Manage Zones',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_zones.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'No zones configured yet',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          TextButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const DeliveryZonesScreen()),
                              );
                              _loadDeliveryZones();
                            },
                            child: const Text('+ Add Zone', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _zones.map((z) {
                        final isSelected = (_numericInput - z.deliveryCharge).abs() < 0.01 && _numericInput > 0;
                        return ChoiceChip(
                          label: Text(
                            '${z.deliveryArea}: ${widget.currency}${z.deliveryCharge.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? Colors.white : Colors.teal.shade900,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.teal.shade700,
                          backgroundColor: Colors.teal.shade50,
                          side: BorderSide(
                            color: isSelected ? Colors.teal.shade700 : Colors.teal.shade200,
                          ),
                          onSelected: (_) => _selectZone(z),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                ],

                // 3. Display Field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${widget.currency} ${_numericInput.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          if (_inputBuffer.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _onClearAll,
                              child: Icon(Icons.cancel, color: Colors.grey.shade500, size: 20),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Number Pad
                _buildNumpad(),
                const SizedBox(height: 20),

                // 5. Actions
                Row(
                  children: [
                    if (widget.initialCharge > 0 || _numericInput > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _remove,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            side: BorderSide(color: Colors.red.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _apply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Apply', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
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

  Widget _buildNumpad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '⌫'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Material(
                    color: key == '⌫' ? Colors.grey.shade200 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        if (key == '⌫') {
                          _onBackspace();
                        } else {
                          _onKeyPress(key);
                        }
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        child: key == '⌫'
                            ? const Icon(Icons.backspace_outlined, size: 20, color: Colors.black87)
                            : Text(
                                key,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

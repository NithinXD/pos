import 'package:flutter/material.dart';

class OrderCommentsDialog extends StatefulWidget {
  final String initialComments;
  final ValueChanged<String> onSave;
  final VoidCallback onClear;

  const OrderCommentsDialog({
    super.key,
    required this.initialComments,
    required this.onSave,
    required this.onClear,
  });

  @override
  State<OrderCommentsDialog> createState() => _OrderCommentsDialogState();
}

class _OrderCommentsDialogState extends State<OrderCommentsDialog> {
  late final TextEditingController _controller;

  final List<String> _quickSuggestions = const [
    'Less Spicy',
    'Extra Spicy',
    'No Onion & Garlic',
    'Extra Napkins',
    'Cutlery Required',
    'Fast Track Order',
    'Call Before Delivery',
    'Pack Separately',
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialComments);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _appendSuggestion(String suggestion) {
    final currentText = _controller.text.trim();
    if (currentText.isEmpty) {
      _controller.text = suggestion;
    } else if (!currentText.contains(suggestion)) {
      _controller.text = '$currentText, $suggestion';
    }
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.note_alt_outlined, color: Colors.blue.shade700, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order Comments',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Kitchen instructions & special requests',
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

                // Quick suggestions
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'QUICK NOTES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickSuggestions.map((tag) {
                    final isAdded = _controller.text.contains(tag);
                    return ActionChip(
                      label: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isAdded ? Colors.blue.shade800 : Colors.grey.shade800,
                        ),
                      ),
                      backgroundColor: isAdded ? Colors.blue.shade50 : Colors.grey.shade100,
                      side: BorderSide(
                        color: isAdded ? Colors.blue.shade300 : Colors.grey.shade300,
                      ),
                      onPressed: () => _appendSuggestion(tag),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Text field
                TextField(
                  controller: _controller,
                  maxLines: 4,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Enter order instructions here...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Actions
                Row(
                  children: [
                    if (widget.initialComments.isNotEmpty || _controller.text.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            widget.onClear();
                            Navigator.of(context).pop();
                          },
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
                        onPressed: () {
                          widget.onSave(_controller.text.trim());
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Save Note', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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
}

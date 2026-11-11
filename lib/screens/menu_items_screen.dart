import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/pos_database.dart';
import '../models/menu_item_model.dart';
import '../models/category_model.dart';
import '../models/restaurant_model.dart';
import '../services/excel_import_service.dart';

class MenuItemsScreen extends StatefulWidget {
  const MenuItemsScreen({super.key});

  @override
  State<MenuItemsScreen> createState() => _MenuItemsScreenState();
}

class _MenuItemsScreenState extends State<MenuItemsScreen> {
  List<MenuItemModel> _items = [];
  List<CategoryModel> _categories = [];
  RestaurantModel? _restaurant;
  bool _isLoading = true;

  String get currency => _restaurant?.currency ?? '₹';

  String _searchQuery = '';
  int? _selectedCategoryId; // null = all
  String _selectedStatusFilter = 'All'; // 'All', 'Enabled', 'Disabled'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final items = await PosDatabase.instance.getAllMenuItems();
      final cats = await PosDatabase.instance.getAllCategories();
      final rest = await PosDatabase.instance.getRestaurantDetails();
      if (mounted) {
        setState(() {
          _items = items;
          _categories = cats;
          _restaurant = rest;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load menu items: $e')),
        );
      }
    }
  }

  Future<void> _toggleItemStatus(MenuItemModel item, bool isEnabled) async {
    final newStatus = isEnabled ? 1 : 0;
    try {
      await PosDatabase.instance.toggleMenuItemStatus(item.id, newStatus);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${item.name} is now ${isEnabled ? "Enabled" : "Disabled"} (hidden from cart)',
            ),
            backgroundColor: isEnabled ? const Color(0xFF0F172A) : Colors.grey.shade800,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update item status: $e')),
        );
      }
    }
  }

  void _showAddEditItemSheet([MenuItemModel? itemToEdit]) {
    final isEditing = itemToEdit != null;

    final nameController = TextEditingController(text: isEditing ? itemToEdit.name : '');
    final sitdownPriceController = TextEditingController(
      text: isEditing ? itemToEdit.sitdownPrice.toStringAsFixed(0) : '',
    );
    final takeawayPriceController = TextEditingController(
      text: isEditing ? itemToEdit.takeawayPrice.toStringAsFixed(0) : '',
    );
    final deliveryPriceController = TextEditingController(
      text: isEditing ? itemToEdit.deliveryPrice.toStringAsFixed(0) : '',
    );
    final taxRateController = TextEditingController(
      text: isEditing ? itemToEdit.taxRate.toStringAsFixed(1) : '5.0',
    );
    final quantityController = TextEditingController(
      text: isEditing ? itemToEdit.quantity.toString() : '100',
    );

    int selectedCatId = isEditing
        ? itemToEdit.categoryId
        : (_categories.isNotEmpty ? _categories.first.id : 1);
    String selectedType = isEditing ? itemToEdit.itemType : 'veg';
    String selectedKitchen = isEditing ? itemToEdit.kitchenType : 'hot_kitchen';
    int status = isEditing ? itemToEdit.status : 1;

    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
            final screenHeight = MediaQuery.sizeOf(context).height;
            final availableHeight = screenHeight - keyboardHeight;
            final sheetHeight = (availableHeight * 0.90).clamp(340.0, screenHeight * 0.90);

            return Padding(
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Container(
                    height: sheetHeight,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        // Pinned Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEditing ? 'Edit Menu Item' : 'Add New Menu Item',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isEditing
                                        ? 'Update dish details (No delete allowed)'
                                        : 'Add dish with Dine-in, Takeaway & Delivery prices',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

                        // Scrollable Form Body
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            child: Form(
                              key: formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Category Dropdown
                                  const Text(
                                    'Category *',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _categories.any((c) => c.id == selectedCatId) ? selectedCatId : null,
                                        isExpanded: true,
                                        hint: const Text('Select Category'),
                                        items: _categories.map((c) {
                                          return DropdownMenuItem<int>(
                                            value: c.id,
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: _parseHexColor(c.colorHex),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  c.name,
                                                  style: TextStyle(
                                                    color: c.isEnabled ? Colors.black87 : Colors.grey,
                                                  ),
                                                ),
                                                if (!c.isEnabled)
                                                  const Text(
                                                    ' (Disabled)',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setSheetState(() => selectedCatId = val);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Item Name
                                  const Text(
                                    'Item Name *',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: nameController,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Paneer Butter Masala, Cold Coffee',
                                      prefixIcon: const Icon(Icons.restaurant, size: 20),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Please enter item name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Food Type & Kitchen Type Row
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Food Type
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Food Type',
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: ['veg', 'non-veg', 'vegan', 'beverage'].map((type) {
                                                final isSelected = selectedType == type;
                                                return ChoiceChip(
                                                  label: Text(
                                                    type.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: isSelected ? Colors.white : const Color(0xFF334155),
                                                    ),
                                                  ),
                                                  selected: isSelected,
                                                  selectedColor: _typeColor(type),
                                                  backgroundColor: const Color(0xFFF1F5F9),
                                                  onSelected: (selected) {
                                                    if (selected) {
                                                      setSheetState(() => selectedType = type);
                                                    }
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Kitchen Type
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Kitchen Station',
                                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: ['hot_kitchen', 'bar', 'cold_kitchen', 'bakery'].map((kt) {
                                                final isSelected = selectedKitchen == kt;
                                                return ChoiceChip(
                                                  label: Text(
                                                    kt.replaceAll('_', ' ').toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: isSelected ? Colors.white : const Color(0xFF334155),
                                                    ),
                                                  ),
                                                  selected: isSelected,
                                                  selectedColor: const Color(0xFF0F172A),
                                                  backgroundColor: const Color(0xFFF1F5F9),
                                                  onSelected: (selected) {
                                                    if (selected) {
                                                      setSheetState(() => selectedKitchen = kt);
                                                    }
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Pricing Row (Sit-down, Takeaway, Delivery)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Dine-In Price ($currency) *',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                            ),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: sitdownPriceController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: InputDecoration(
                                                hintText: '240',
                                                filled: true,
                                                fillColor: const Color(0xFFF8FAFC),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              ),
                                              validator: (val) {
                                                if (val == null || val.trim().isEmpty) return 'Required';
                                                if (double.tryParse(val) == null) return 'Invalid';
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Takeaway ($currency)',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                            ),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: takeawayPriceController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: InputDecoration(
                                                hintText: '230',
                                                filled: true,
                                                fillColor: const Color(0xFFF8FAFC),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Delivery ($currency)',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                            ),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: deliveryPriceController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: InputDecoration(
                                                hintText: '250',
                                                filled: true,
                                                fillColor: const Color(0xFFF8FAFC),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Tax Rate & Stock
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Tax Rate (%)',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                            ),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: taxRateController,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              decoration: InputDecoration(
                                                hintText: '5.0',
                                                filled: true,
                                                fillColor: const Color(0xFFF8FAFC),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Stock Quantity',
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                            ),
                                            const SizedBox(height: 6),
                                            TextFormField(
                                              controller: quantityController,
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              decoration: InputDecoration(
                                                hintText: '100',
                                                filled: true,
                                                fillColor: const Color(0xFFF8FAFC),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Status Toggle
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Item Status',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                            ),
                                            Text(
                                              status == 1
                                                  ? 'Enabled (Shown in POS cart & menu)'
                                                  : 'Disabled (Hidden from POS cart & menu)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: status == 1 ? const Color(0xFF10B981) : Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Switch(
                                          value: status == 1,
                                          activeTrackColor: const Color(0xFF10B981),
                                          activeThumbColor: Colors.white,
                                          onChanged: (val) {
                                            setSheetState(() => status = val ? 1 : 0);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Pinned Sticky Footer - ALWAYS VISIBLE AT BOTTOM!
                        SafeArea(
                          top: false,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(top: BorderSide(color: Colors.grey.shade200)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  offset: const Offset(0, -3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: Colors.grey.shade300),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        if (!formKey.currentState!.validate()) return;

                                        final sdPrice = double.tryParse(sitdownPriceController.text.trim()) ?? 0.0;
                                        final taPrice = double.tryParse(takeawayPriceController.text.trim()) ?? sdPrice;
                                        final dlPrice = double.tryParse(deliveryPriceController.text.trim()) ?? sdPrice;
                                        final taxRate = double.tryParse(taxRateController.text.trim()) ?? 5.0;
                                        final qty = int.tryParse(quantityController.text.trim()) ?? 100;

                                        final catName = _categories
                                            .firstWhere((c) => c.id == selectedCatId, orElse: () => const CategoryModel(id: 1, name: 'General'))
                                            .name;

                                        final item = MenuItemModel(
                                          id: isEditing ? itemToEdit.id : 0,
                                          categoryId: selectedCatId,
                                          categoryName: catName,
                                          name: nameController.text.trim(),
                                          sitdownPrice: sdPrice,
                                          takeawayPrice: taPrice,
                                          deliveryPrice: dlPrice,
                                          taxRate: taxRate,
                                          quantity: qty,
                                          itemType: selectedType,
                                          kitchenType: selectedKitchen,
                                          status: status,
                                          isAvailable: status == 1,
                                        );

                                        final nav = Navigator.of(context);
                                        final messenger = ScaffoldMessenger.of(context);

                                        try {
                                          if (isEditing) {
                                            await PosDatabase.instance.updateMenuItem(item);
                                          } else {
                                            await PosDatabase.instance.addMenuItem(item);
                                          }

                                          nav.pop();
                                          await _loadData();
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isEditing
                                                    ? 'Item "${item.name}" updated successfully!'
                                                    : 'Item "${item.name}" created successfully!',
                                              ),
                                              backgroundColor: const Color(0xFF0F172A),
                                            ),
                                          );
                                        } catch (e) {
                                          messenger.showSnackBar(
                                            SnackBar(content: Text('Error saving item: $e')),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.check, size: 18),
                                      label: Text(
                                        isEditing ? 'Save Changes' : 'Create Menu Item',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0F172A),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'veg':
        return const Color(0xFF16A34A);
      case 'non-veg':
        return const Color(0xFFDC2626);
      case 'vegan':
        return const Color(0xFF059669);
      case 'beverage':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _parseHexColor(String hex) {
    String cleanHex = hex.replaceAll('#', '');
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    return Color(int.tryParse('0x$cleanHex') ?? 0xFF4CAF50);
  }

  List<MenuItemModel> get _filteredItems {
    return _items.where((item) {
      // Search
      if (_searchQuery.isNotEmpty) {
        if (!item.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      // Category filter
      if (_selectedCategoryId != null) {
        if (item.categoryId != _selectedCategoryId) {
          return false;
        }
      }
      // Status filter
      if (_selectedStatusFilter == 'Enabled') {
        return item.status == 1;
      } else if (_selectedStatusFilter == 'Disabled') {
        return item.status == 0;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final enabledCount = _items.where((i) => i.status == 1).length;
    final disabledCount = _items.where((i) => i.status == 0).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Menu Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Manage dishes, prices & availability',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Import Menu from Excel',
            icon: const Icon(Icons.file_upload_outlined, color: Color(0xFF2563EB)),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final summary = await ExcelImportService.pickAndImportMenu();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(summary.message),
                  backgroundColor: summary.success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  duration: const Duration(seconds: 4),
                ),
              );
              if (mounted) {
                _loadData();
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditItemSheet(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFEFF6FF),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF2563EB), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Items cannot be deleted. Enabled items are shown in the cart page; disabled items are hidden.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                  ),
                ),
              ],
            ),
          ),

          // Search and Filters
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Box
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search items by name...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Horizontal Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // All Categories Chip
                      GestureDetector(
                        onTap: () => setState(() => _selectedCategoryId = null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _selectedCategoryId == null ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'All Categories',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: _selectedCategoryId == null ? FontWeight.bold : FontWeight.w500,
                              color: _selectedCategoryId == null ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      ..._categories.map((c) {
                        final isSelected = _selectedCategoryId == c.id;
                        final color = _parseHexColor(c.colorHex);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCategoryId = c.id),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected ? null : Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    c.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? Colors.white : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Status Filter
                Row(
                  children: [
                    _buildStatusChip('All', 'All (${_items.length})'),
                    const SizedBox(width: 8),
                    _buildStatusChip('Enabled', 'Enabled ($enabledCount)'),
                    const SizedBox(width: 8),
                    _buildStatusChip('Disabled', 'Disabled ($disabledCount)'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Items List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No items match "$_searchQuery"'
                                  : 'No menu items found',
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isEnabled = item.status == 1;

                          // Check if its parent category is disabled
                          final parentCategory = _categories.firstWhere(
                            (c) => c.id == item.categoryId,
                            orElse: () => const CategoryModel(id: 0, name: '', status: 1),
                          );
                          final isParentCategoryDisabled = parentCategory.status == 0;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isEnabled && !isParentCategoryDisabled
                                    ? const Color(0xFFE2E8F0)
                                    : Colors.grey.shade300,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: Type icon, Item Name, Category, Edit, Toggle
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Veg / Non-Veg Indicator
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2.0),
                                        child: _buildFoodTypeIndicator(item.itemType),
                                      ),
                                      const SizedBox(width: 10),

                                      // Item Name and Badges
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: isEnabled
                                                    ? const Color(0xFF0F172A)
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                // Category Badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    item.categoryName,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF475569),
                                                    ),
                                                  ),
                                                ),
                                                // Kitchen Station Badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    item.kitchenType.replaceAll('_', ' ').toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ),
                                                // Warning if category is disabled
                                                if (isParentCategoryDisabled)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFFEF3C7),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'Category Disabled (Hidden)',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFFB45309),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Edit Button
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                        color: const Color(0xFF0F172A),
                                        tooltip: 'Edit Item',
                                        onPressed: () => _showAddEditItemSheet(item),
                                      ),

                                      // Status Switch
                                      Switch(
                                        value: isEnabled,
                                        activeTrackColor: const Color(0xFF10B981),
                                        activeThumbColor: Colors.white,
                                        onChanged: (val) => _toggleItemStatus(item, val),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Price Details Row
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildPriceTag('Dine-In', item.sitdownPrice),
                                        _buildPriceTag('Takeaway', item.takeawayPrice),
                                        _buildPriceTag('Delivery', item.deliveryPrice),
                                        Text(
                                          'Tax: ${item.taxRate.toStringAsFixed(0)}%',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodTypeIndicator(String type) {
    Color color = _typeColor(type);

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: type == 'veg' ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }

  Widget _buildPriceTag(String label, double price) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          '$currency${price.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String value, String label) {
    final isSelected = _selectedStatusFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatusFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

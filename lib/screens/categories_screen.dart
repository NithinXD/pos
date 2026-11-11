import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/pos_database.dart';
import '../models/category_model.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Enabled', 'Disabled'

  final List<String> _paletteColors = [
    '#FF7043', // Deep Orange
    '#26A69A', // Teal
    '#AB47BC', // Purple
    '#42A5F5', // Blue
    '#EC407A', // Pink
    '#FFA726', // Amber
    '#66BB6A', // Green
    '#78909C', // Blue Grey
    '#5C6BC0', // Indigo
    '#8D6E63', // Brown
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final list = await PosDatabase.instance.getAllCategories();
      if (mounted) {
        setState(() {
          _categories = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load categories: $e')),
        );
      }
    }
  }

  Future<void> _toggleStatus(CategoryModel category, bool isEnabled) async {
    final newStatus = isEnabled ? 1 : 0;
    try {
      await PosDatabase.instance.toggleCategoryStatus(category.id, newStatus);
      await _loadCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${category.name} is now ${isEnabled ? "Enabled" : "Disabled"} (hidden from cart)',
            ),
            backgroundColor: isEnabled ? const Color(0xFF0F172A) : Colors.grey.shade800,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  void _showAddEditCategorySheet([CategoryModel? categoryToEdit]) {
    final isEditing = categoryToEdit != null;

    final nameController = TextEditingController(text: isEditing ? categoryToEdit.name : '');
    final positionController = TextEditingController(
      text: isEditing ? categoryToEdit.position.toString() : (_categories.length + 1).toString(),
    );

    String selectedColor = isEditing ? categoryToEdit.colorHex : _paletteColors.first;
    String selectedType = isEditing ? categoryToEdit.type : 'food';
    int status = isEditing ? categoryToEdit.status : 1;

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
            final sheetHeight = (availableHeight * 0.88).clamp(320.0, screenHeight * 0.88);
            final Color currentColor = _parseHexColor(selectedColor);

            return Padding(
              padding: EdgeInsets.only(bottom: keyboardHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
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
                                    isEditing ? 'Edit Category' : 'Create New Category',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isEditing
                                        ? 'Update category settings (No delete allowed)'
                                        : 'Add a new group for menu ordering',
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
                                  // Category Name
                                  const Text(
                                    'Category Name *',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: nameController,
                                    decoration: InputDecoration(
                                      hintText: 'e.g. Starters, Main Course, Drinks',
                                      prefixIcon: const Icon(Icons.label_outline, size: 20),
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
                                        return 'Please enter a category name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Display Position
                                  const Text(
                                    'Display Position / Order *',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: positionController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: InputDecoration(
                                      hintText: '1, 2, 3...',
                                      prefixIcon: const Icon(Icons.sort, size: 20),
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
                                        return 'Enter position number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  // Category Type
                                  const Text(
                                    'Category Type',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: ['food', 'drinks', 'desserts', 'retail'].map((type) {
                                      final isSelected = selectedType == type;
                                      return ChoiceChip(
                                        label: Text(
                                          type.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected ? Colors.white : const Color(0xFF334155),
                                          ),
                                        ),
                                        selected: isSelected,
                                        selectedColor: const Color(0xFF0F172A),
                                        backgroundColor: const Color(0xFFF1F5F9),
                                        onSelected: (selected) {
                                          if (selected) {
                                            setSheetState(() => selectedType = type);
                                          }
                                        },
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),

                                  // Category Color Swatches
                                  Row(
                                    children: [
                                      const Text(
                                        'Category Color',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: currentColor,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.grey.shade300),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: _paletteColors.map((hex) {
                                      final color = _parseHexColor(hex);
                                      final isSelected = selectedColor.toUpperCase() == hex.toUpperCase();
                                      return GestureDetector(
                                        onTap: () {
                                          setSheetState(() => selectedColor = hex);
                                        },
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
                                              width: isSelected ? 3 : 1,
                                            ),
                                            boxShadow: [
                                              if (isSelected)
                                                BoxShadow(
                                                  color: color.withValues(alpha: 0.4),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                            ],
                                          ),
                                          child: isSelected
                                              ? const Icon(Icons.check, size: 20, color: Colors.white)
                                              : null,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),

                                  // Enable/Disable Status Switch
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
                                              'Category Status',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                            ),
                                            Text(
                                              status == 1
                                                  ? 'Enabled (Visible in POS cart & menu)'
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
                                        final pos = int.tryParse(positionController.text.trim()) ?? 0;

                                        final category = CategoryModel(
                                          id: isEditing ? categoryToEdit.id : 0,
                                          name: nameController.text.trim(),
                                          position: pos,
                                          colorHex: selectedColor,
                                          type: selectedType,
                                          status: status,
                                        );

                                        final nav = Navigator.of(context);
                                        final messenger = ScaffoldMessenger.of(context);

                                        try {
                                          if (isEditing) {
                                            await PosDatabase.instance.updateCategory(category);
                                          } else {
                                            await PosDatabase.instance.addCategory(category);
                                          }

                                          nav.pop();
                                          await _loadCategories();
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isEditing
                                                    ? 'Category "${category.name}" updated successfully!'
                                                    : 'Category "${category.name}" added successfully!',
                                              ),
                                              backgroundColor: const Color(0xFF0F172A),
                                            ),
                                          );
                                        } catch (e) {
                                          messenger.showSnackBar(
                                            SnackBar(content: Text('Error saving category: $e')),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.check, size: 18),
                                      label: Text(
                                        isEditing ? 'Save Changes' : 'Create Category',
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

  Color _parseHexColor(String hex) {
    String cleanHex = hex.replaceAll('#', '');
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    return Color(int.tryParse('0x$cleanHex') ?? 0xFF4CAF50);
  }

  List<CategoryModel> get _filteredCategories {
    return _categories.where((c) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        if (!c.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return false;
        }
      }
      // Status filter
      if (_selectedFilter == 'Enabled') {
        return c.status == 1;
      } else if (_selectedFilter == 'Disabled') {
        return c.status == 0;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCategories;
    final enabledCount = _categories.where((c) => c.status == 1).length;
    final disabledCount = _categories.where((c) => c.status == 0).length;

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
              'Menu Categories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Add, edit & enable/disable food groups',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddEditCategorySheet(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Category'),
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
                    'Categories cannot be deleted. Enabled categories are shown in cart page; disabled ones are hidden.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar & Filter Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Search Box
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search categories by name...',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Status Filter Chips
                Row(
                  children: [
                    _buildFilterChip('All', 'All (${_categories.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Enabled', 'Enabled ($enabledCount)'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Disabled', 'Disabled ($disabledCount)'),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Categories List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.category_outlined, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No categories match "$_searchQuery"'
                                  : 'No categories found',
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
                          final cat = filtered[index];
                          final catColor = _parseHexColor(cat.colorHex);
                          final isEnabled = cat.status == 1;

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isEnabled ? const Color(0xFFE2E8F0) : Colors.grey.shade300,
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
                              child: Row(
                                children: [
                                  // Color Indicator
                                  Container(
                                    width: 14,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: catColor,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Name and Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              cat.name,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: isEnabled
                                                    ? const Color(0xFF0F172A)
                                                    : Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isEnabled
                                                    ? const Color(0xFFDCFCE7)
                                                    : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isEnabled ? 'Enabled' : 'Disabled',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: isEnabled
                                                      ? const Color(0xFF15803D)
                                                      : Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              'Order: #${cat.position}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
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
                                                cat.type.toUpperCase(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF475569),
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
                                    tooltip: 'Edit Category',
                                    onPressed: () => _showAddEditCategorySheet(cat),
                                  ),

                                  // Status Switch
                                  Switch(
                                    value: isEnabled,
                                    activeTrackColor: const Color(0xFF10B981),
                                    activeThumbColor: Colors.white,
                                    onChanged: (val) => _toggleStatus(cat, val),
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

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
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

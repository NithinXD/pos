import 'package:flutter/material.dart';
import '../database/pos_database.dart';
import '../models/restaurant_model.dart';
import 'restaurant_details_screen.dart';
import 'categories_screen.dart';
import 'menu_items_screen.dart';
import 'first_time_setup_screen.dart';
import 'reports_screen.dart';
import 'delivery_zones_screen.dart';
import '../services/excel_export_service.dart';
import '../services/excel_import_service.dart';
import '../services/printer_service.dart';
import '../direct_printer_app.dart';

class SettingsHubScreen extends StatefulWidget {
  final bool isAuthenticated;
  const SettingsHubScreen({super.key, this.isAuthenticated = false});

  @override
  State<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends State<SettingsHubScreen> {
  RestaurantModel? _restaurant;
  int _categoryCount = 0;
  int _enabledCategoryCount = 0;
  int _itemCount = 0;
  int _enabledItemCount = 0;
  int _zoneCount = 0;
  bool _isLoading = true;

  late bool _isUnlocked;
  final TextEditingController _lockPasswordController = TextEditingController();
  bool _lockObscureText = true;
  String? _lockError;

  @override
  void initState() {
    super.initState();
    _isUnlocked = widget.isAuthenticated;
    if (_isUnlocked) {
      _loadOverviewData();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _lockPasswordController.dispose();
    super.dispose();
  }

  void _verifyLockPassword() {
    final entered = _lockPasswordController.text.trim();
    if (entered == 'pheludar1234') {
      setState(() {
        _isUnlocked = true;
        _lockError = null;
      });
      _loadOverviewData();
    } else {
      setState(() {
        _lockError = 'Incorrect password. Access denied.';
        _lockPasswordController.clear();
      });
    }
  }

  Widget _buildLockScreen() {
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
        title: const Text(
          'POS Administration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFBFDBFE), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFF1D4ED8),
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Admin Authorization Required',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter manager password to access settings and menu configuration.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _lockPasswordController,
                      autofocus: true,
                      obscureText: _lockObscureText,
                      textCapitalization: TextCapitalization.none,
                      autocorrect: false,
                      enableSuggestions: false,
                      onSubmitted: (_) => _verifyLockPassword(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter password',
                        errorText: _lockError,
                        prefixIcon: const Icon(Icons.password_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _lockObscureText ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _lockObscureText = !_lockObscureText;
                            });
                          },
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _verifyLockPassword,
                        icon: const Icon(Icons.lock_open_rounded, size: 18),
                        label: const Text(
                          'Unlock Settings',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadOverviewData() async {
    setState(() => _isLoading = true);
    try {
      final res = await PosDatabase.instance.getRestaurantDetails();
      final cats = await PosDatabase.instance.getAllCategories();
      final items = await PosDatabase.instance.getAllMenuItems();
      final zones = await PosDatabase.instance.getDeliveryZones();

      if (mounted) {
        setState(() {
          _restaurant = res;
          _categoryCount = cats.length;
          _enabledCategoryCount = cats.where((c) => c.status == 1).length;
          _itemCount = items.length;
          _enabledItemCount = items.where((i) => i.status == 1).length;
          _zoneCount = zones.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isUnlocked) {
      return _buildLockScreen();
    }

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
              'POS Administration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'Manage restaurant, categories and menu items',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOverviewData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Builder(
                      builder: (context) {
                        final screenWidth = MediaQuery.sizeOf(context).width;
                        final isTablet = screenWidth >= 680;

                        final card1 = _buildModuleCard(
                          icon: Icons.storefront_rounded,
                          iconBg: const Color(0xFFEFF6FF),
                          iconColor: const Color(0xFF2563EB),
                          title: 'Restaurant Details',
                          subtitle: 'Edit business profile, address, tables count & currency (Update only)',
                          stats: '${_restaurant?.numberOfTables ?? 10} Dine-In Tables configured',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RestaurantDetailsScreen()),
                            );
                            _loadOverviewData();
                          },
                        );

                        final card2 = _buildModuleCard(
                          icon: Icons.category_rounded,
                          iconBg: const Color(0xFFF0FDF4),
                          iconColor: const Color(0xFF16A34A),
                          title: 'Menu Categories',
                          subtitle: 'Add, edit, color-code, and enable/disable food groups (No delete allowed)',
                          stats: '$_enabledCategoryCount of $_categoryCount categories enabled',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                            );
                            _loadOverviewData();
                          },
                        );

                        final card3 = _buildModuleCard(
                          icon: Icons.restaurant_menu_rounded,
                          iconBg: const Color(0xFFFAF5FF),
                          iconColor: const Color(0xFF9333EA),
                          title: 'Menu Items',
                          subtitle: 'Add dishes, edit prices (dine-in/takeaway/delivery) & toggle availability',
                          stats: '$_enabledItemCount of $_itemCount items enabled in cart',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MenuItemsScreen()),
                            );
                            _loadOverviewData();
                          },
                        );

                        final card4 = _buildModuleCard(
                          icon: Icons.bar_chart_rounded,
                          iconBg: const Color(0xFFE0F2FE),
                          iconColor: const Color(0xFF0284C7),
                          title: 'Sales & Business Reports',
                          subtitle: 'Daily & weekly reports, cash/card/upi & food/drinks totals',
                          stats: 'Daily & Weekly Insights',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ReportsScreen()),
                            );
                          },
                        );

                        final card5 = _buildModuleCard(
                          icon: Icons.table_chart_rounded,
                          iconBg: const Color(0xFFDCFCE7),
                          iconColor: const Color(0xFF16A34A),
                          title: 'Export Database (.xlsx)',
                          subtitle: '1 file with 6 tabs for all tables & records (inspect/backup)',
                          stats: '6 Tables Export',
                          onTap: () {
                            ExcelExportService.exportAndShare(context);
                          },
                        );

                        final card6 = _buildModuleCard(
                          icon: Icons.print_rounded,
                          iconBg: const Color(0xFFFEF3C7),
                          iconColor: const Color(0xFFD97706),
                          title: 'Thermal Printer & KOT',
                          subtitle: 'Direct ESC/POS Driver (Bluetooth, USB OTG, WiFi)',
                          stats: '100% Direct Driver • Zero RawBT',
                          onTap: () {
                            _showPrinterSettingsDialog(context);
                          },
                        );

                        final card7 = _buildModuleCard(
                          icon: Icons.file_upload_outlined,
                          iconBg: const Color(0xFFEFF6FF),
                          iconColor: const Color(0xFF2563EB),
                          title: 'Upload Menu from Excel',
                          subtitle: 'Bulk import categories & menu dishes from .xlsx or .xls file',
                          stats: 'Excel Menu Upload',
                          onTap: () async {
                            final summary = await ExcelImportService.pickAndImportMenu(context);
                            if (!context.mounted) return;
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Row(
                                  children: [
                                    Icon(
                                      summary.success ? Icons.check_circle_rounded : Icons.info_outline,
                                      color: summary.success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(summary.success ? 'Import Complete' : 'Import Notice'),
                                  ],
                                ),
                                content: Text(summary.message),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            _loadOverviewData();
                          },
                        );

                        final card8 = _buildModuleCard(
                          icon: Icons.delivery_dining_rounded,
                          iconBg: const Color(0xFFFEF3C7),
                          iconColor: const Color(0xFFD97706),
                          title: 'Delivery Zones & Charges',
                          subtitle: 'Add, edit area names & set fixed delivery charges for parcel orders',
                          stats: '$_zoneCount Delivery Zones configured',
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DeliveryZonesScreen()),
                            );
                            _loadOverviewData();
                          },
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Restaurant Overview Hero Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _restaurant?.status.toUpperCase() ?? 'ACTIVE',
                                          style: const TextStyle(
                                            color: Color(0xFF34D399),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.white70, size: 20),
                                        tooltip: 'Edit Restaurant Details',
                                        onPressed: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const RestaurantDetailsScreen()),
                                          );
                                          _loadOverviewData();
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _restaurant?.name ?? 'Restaurant',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, color: Colors.white60, size: 14),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          _restaurant?.address ?? '',
                                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      _buildMiniBadge(
                                        Icons.table_bar_outlined,
                                        '${_restaurant?.numberOfTables ?? 10} Tables',
                                      ),
                                      const SizedBox(width: 12),
                                      _buildMiniBadge(
                                        Icons.currency_rupee,
                                        'Currency: ${_restaurant?.currency ?? "₹"}',
                                      ),
                                      const SizedBox(width: 12),
                                      _buildMiniBadge(
                                        Icons.phone_outlined,
                                        _restaurant?.phone ?? '',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Section Title
                            const Text(
                              'Management Modules',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Modules: 2-column on tablet, 1-column on phone
                            if (isTablet) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: card1),
                                  const SizedBox(width: 14),
                                  Expanded(child: card2),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: card3),
                                  const SizedBox(width: 14),
                                  Expanded(child: card4),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: card5),
                                  const SizedBox(width: 14),
                                  Expanded(child: card6),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: card7),
                                  const SizedBox(width: 14),
                                  Expanded(child: card8),
                                ],
                              ),
                            ] else ...[
                              card1,
                              const SizedBox(height: 12),
                              card2,
                              const SizedBox(height: 12),
                              card3,
                              const SizedBox(height: 12),
                              card4,
                              const SizedBox(height: 12),
                              card5,
                              const SizedBox(height: 12),
                              card6,
                              const SizedBox(height: 12),
                              card7,
                              const SizedBox(height: 12),
                              card8,
                            ],
                            const SizedBox(height: 24),

                            // Data Policy Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.gavel_rounded, size: 18, color: Color(0xFF475569)),
                                      SizedBox(width: 8),
                                      Text(
                                        'POS Data Safety & Audit Policy',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '• Restaurant Details: Only update is allowed (no deletion).\n'
                                    '• Categories: Add and edit allowed (no deletion). Use the status toggle to show or hide in cart.\n'
                                    '• Menu Items: Add and edit allowed (no deletion). Use enable/disable toggle to show or hide in cart.\n'
                                    'This guarantees historical kitchen tickets, orders, and sales reports remain intact.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Quick Re-run Setup Wizard Button
                            OutlinedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const FirstTimeSetupScreen()),
                                );
                                _loadOverviewData();
                              },
                              icon: const Icon(Icons.restart_alt_rounded, size: 18),
                              label: const Text('Re-run Initial Setup Wizard'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF334155),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildMiniBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white70),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String stats,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stats,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showPrinterSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        List<Map<String, String>> btPrinters = [];
        bool isLoadingBt = false;
        List<Map<String, dynamic>> usbPrinters = [];
        bool isLoadingUsb = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void loadBtPrinters() async {
              setDialogState(() => isLoadingBt = true);
              final list = await PrinterService.getPairedBluetoothPrinters();
              setDialogState(() {
                btPrinters = list;
                isLoadingBt = false;
                if (list.isNotEmpty &&
                    (PrinterService.selectedBluetoothAddress == null ||
                        !list.any((p) => p['address'] == PrinterService.selectedBluetoothAddress))) {
                  PrinterService.selectedBluetoothAddress = list.first['address'];
                  PrinterService.selectedBluetoothName = list.first['name'];
                }
              });
            }

            void loadUsbPrinters() async {
              setDialogState(() => isLoadingUsb = true);
              final list = await PrinterService.getAttachedUsbPrinters();
              setDialogState(() {
                usbPrinters = list;
                isLoadingUsb = false;
                if (list.isNotEmpty &&
                    (PrinterService.selectedUsbDeviceId == null ||
                        !list.any((p) => p['deviceId'] == PrinterService.selectedUsbDeviceId))) {
                  PrinterService.selectedUsbDeviceId = list.first['deviceId'] as int?;
                  PrinterService.selectedUsbDeviceName = list.first['name'] as String?;
                  PrinterService.persistSettings(
                    usbDeviceId: PrinterService.selectedUsbDeviceId,
                    usbDeviceName: PrinterService.selectedUsbDeviceName,
                  );
                }
              });
            }

            if (PrinterService.activeMode == PrinterConnectionMode.bluetoothDirect &&
                btPrinters.isEmpty &&
                !isLoadingBt) {
              loadBtPrinters();
            }

            if (PrinterService.activeMode == PrinterConnectionMode.usbDirect &&
                usbPrinters.isEmpty &&
                !isLoadingUsb) {
              loadUsbPrinters();
            }
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.print_rounded, color: Color(0xFFD97706)),
                  SizedBox(width: 10),
                  Text('Thermal Printer & KOT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.tune, size: 16, color: Color(0xFF0284C7)),
                              SizedBox(width: 6),
                              Text('Printer Mode Toggle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<PrinterConnectionMode>(
                            initialValue: PrinterService.activeMode,
                            decoration: InputDecoration(
                              labelText: 'Active Printer Engine',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: PrinterConnectionMode.bluetoothDirect,
                                child: Text('Direct Bluetooth SPP'),
                              ),
                              DropdownMenuItem(
                                value: PrinterConnectionMode.usbDirect,
                                child: Text('Direct USB OTG'),
                              ),
                              DropdownMenuItem(
                                value: PrinterConnectionMode.wifiDirect,
                                child: Text('Direct WiFi / LAN Socket (Port 9100)'),
                              ),
                            ],
                            onChanged: (mode) {
                              if (mode != null) {
                                setDialogState(() {
                                  PrinterService.activeMode = mode;
                                });
                                PrinterService.persistSettings(mode: mode);
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            PrinterService.activeMode == PrinterConnectionMode.bluetoothDirect
                                ? 'Streams ESC/POS commands directly to paired Bluetooth printer without third-party apps.'
                                : PrinterService.activeMode == PrinterConnectionMode.usbDirect
                                    ? 'Streams ESC/POS commands directly via USB OTG cable.'
                                    : 'Sends ESC/POS commands directly to network printer over TCP socket.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                          ),
                          if (PrinterService.activeMode == PrinterConnectionMode.bluetoothDirect) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Select Paired Printer:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                TextButton.icon(
                                  onPressed: isLoadingBt ? null : loadBtPrinters,
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (isLoadingBt)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                              )
                            else if (btPrinters.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: const Text(
                                  'No paired Bluetooth printers found.\nPlease pair your thermal printer in Android Bluetooth Settings first.',
                                  style: TextStyle(fontSize: 11, color: Colors.brown),
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                initialValue: PrinterService.selectedBluetoothAddress,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: btPrinters.map((p) {
                                  return DropdownMenuItem<String>(
                                    value: p['address'],
                                    child: Text(
                                      '${p['name']} (${p['address']})',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (addr) {
                                  if (addr != null) {
                                    setDialogState(() {
                                      PrinterService.selectedBluetoothAddress = addr;
                                      final match = btPrinters.firstWhere((p) => p['address'] == addr, orElse: () => {});
                                      PrinterService.selectedBluetoothName = match['name'];
                                    });
                                    final match = btPrinters.firstWhere((p) => p['address'] == addr, orElse: () => {});
                                    PrinterService.persistSettings(
                                      btAddress: addr,
                                      btName: match['name'],
                                    );
                                  }
                                },
                              ),
                          ],
                          if (PrinterService.activeMode == PrinterConnectionMode.usbDirect) ...[
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Select Attached USB Printer:',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                TextButton.icon(
                                  onPressed: isLoadingUsb ? null : loadUsbPrinters,
                                  icon: const Icon(Icons.refresh, size: 14),
                                  label: const Text('Refresh', style: TextStyle(fontSize: 11)),
                                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (isLoadingUsb)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                              )
                            else if (usbPrinters.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.amber.shade200),
                                ),
                                child: const Text(
                                  'No USB thermal printers detected.\nPlease connect your printer via USB OTG cable and ensure it is turned on.',
                                  style: TextStyle(fontSize: 11, color: Colors.brown),
                                ),
                              )
                            else
                              DropdownButtonFormField<int>(
                                initialValue: usbPrinters.any((p) => p['deviceId'] == PrinterService.selectedUsbDeviceId)
                                    ? PrinterService.selectedUsbDeviceId
                                    : (usbPrinters.isNotEmpty ? usbPrinters.first['deviceId'] as int? : null),
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: usbPrinters.map((p) {
                                  final devId = p['deviceId'] as int;
                                  final name = p['name'] as String? ?? 'USB Printer';
                                  return DropdownMenuItem<int>(
                                    value: devId,
                                    child: Text(
                                      '$name (ID: $devId)',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (devId) {
                                  if (devId != null) {
                                    final match = usbPrinters.firstWhere((p) => p['deviceId'] == devId, orElse: () => {});
                                    final name = match['name'] as String? ?? 'USB Printer';
                                    setDialogState(() {
                                      PrinterService.selectedUsbDeviceId = devId;
                                      PrinterService.selectedUsbDeviceName = name;
                                    });
                                    PrinterService.persistSettings(
                                      usbDeviceId: devId,
                                      usbDeviceName: name,
                                    );
                                  }
                                },
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Direct Hardware Connection:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '• Bluetooth: Turn on printer & pair in Android Bluetooth settings.\n'
                      '• USB OTG: Plug USB cable directly into tablet/phone.\n'
                      '• WiFi: Connect printer to same local network.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF334155), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    // Direct Printer Tester Launcher
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DirectPrinterHomePage()),
                        );
                      },
                      icon: const Icon(Icons.bolt, size: 18),
                      label: const Text('Open Direct Printer Tester App'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Test Print Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        final res = await PrinterService.instance.printTest(restaurant: _restaurant);
                        if (!dialogCtx.mounted) return;
                        ScaffoldMessenger.of(dialogCtx).showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: res.success ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                          ),
                        );
                      },
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Send Test Print Ticket'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // View Virtual Paper Slip (No printer needed)
                    OutlinedButton.icon(
                      onPressed: () {
                        final ticket = PrinterService.instance.formatTestTicket(restaurant: _restaurant);
                        PrinterService.showVirtualReceiptDialog(dialogCtx, ticket, title: 'Virtual Test Ticket');
                      },
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                      label: const Text('View Virtual Ticket (No Printer)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

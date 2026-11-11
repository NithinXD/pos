import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DirectPrinterApp());
}

/// Standalone Direct Thermal Printer Test Application (Zero RawBT dependency)
class DirectPrinterApp extends StatelessWidget {
  const DirectPrinterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Direct Thermal Printer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const DirectPrinterHomePage(),
    );
  }
}

enum ConnectionMode { wifi, bluetooth, usb }

class DirectPrinterHomePage extends StatefulWidget {
  const DirectPrinterHomePage({super.key});

  @override
  State<DirectPrinterHomePage> createState() => _DirectPrinterHomePageState();
}

class _DirectPrinterHomePageState extends State<DirectPrinterHomePage> {
  static const MethodChannel _directChannel = MethodChannel('direct.printer.channel');

  // ESC/POS Command Constants
  static const List<int> escInit = [0x1B, 0x40];
  static const List<int> escCenter = [0x1B, 0x61, 0x01];
  static const List<int> escDoubleSize = [0x1D, 0x21, 0x11];
  static const List<int> escNormalSize = [0x1D, 0x21, 0x00];
  static const List<int> escBoldOn = [0x1B, 0x45, 0x01];
  static const List<int> escBoldOff = [0x1B, 0x45, 0x00];
  static const List<int> escCut = [0x1D, 0x56, 0x01];

  final TextEditingController _textController =
      TextEditingController(text: 'hi this is working');
  final TextEditingController _ipController =
      TextEditingController(text: '192.168.1.100');
  final TextEditingController _portController =
      TextEditingController(text: '9100');

  ConnectionMode _connectionMode = ConnectionMode.bluetooth;

  // Bluetooth state
  List<Map<String, String>> _bluetoothDevices = [];
  String? _selectedBtAddress;
  bool _isLoadingBt = false;

  // USB state
  List<Map<String, dynamic>> _usbDevices = [];
  int? _selectedUsbDeviceId;
  bool _isLoadingUsb = false;

  // Formatting state
  bool _isDoubleSize = true;
  bool _isBold = true;
  bool _includePaperCut = true;
  int _paperWidth = 32; // 32 for 58mm, 48 for 80mm

  bool _isPrinting = false;
  String? _lastStatusMessage;
  bool _lastStatusSuccess = true;

  @override
  void initState() {
    super.initState();
    _loadBluetoothDevices();
    _loadUsbDevices();
  }

  @override
  void dispose() {
    _textController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadBluetoothDevices() async {
    if (!kIsWeb && Platform.isAndroid) {
      setState(() => _isLoadingBt = true);
      try {
        final List<dynamic>? res =
            await _directChannel.invokeMethod<List<dynamic>>('getBluetoothDevices');
        if (res != null) {
          final parsed = res
              .map((e) => Map<String, String>.from(e as Map))
              .toList();
          setState(() {
            _bluetoothDevices = parsed;
            if (parsed.isNotEmpty && _selectedBtAddress == null) {
              _selectedBtAddress = parsed.first['address'];
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading paired Bluetooth devices: $e');
      } finally {
        setState(() => _isLoadingBt = false);
      }
    }
  }

  Future<void> _loadUsbDevices() async {
    if (!kIsWeb && Platform.isAndroid) {
      setState(() => _isLoadingUsb = true);
      try {
        final List<dynamic>? res =
            await _directChannel.invokeMethod<List<dynamic>>('getUsbPrinters');
        if (res != null) {
          final parsed = res
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          setState(() {
            _usbDevices = parsed;
            if (parsed.isNotEmpty && _selectedUsbDeviceId == null) {
              _selectedUsbDeviceId = parsed.first['deviceId'] as int?;
            }
          });
        }
      } catch (e) {
        debugPrint('Error loading USB printers: $e');
      } finally {
        setState(() => _isLoadingUsb = false);
      }
    }
  }

  Uint8List _generateEscPosBytes({
    String? customMessage,
    bool? autoCut,
  }) {
    final bytes = <int>[];
    final message = (customMessage ?? _textController.text).trim().isEmpty
        ? 'hi this is working'
        : (customMessage ?? _textController.text).trim();
    final shouldCut = autoCut ?? _includePaperCut;
    final timeStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

    // 1. ESC @ (Initialize printer)
    bytes.addAll(escInit);

    // 2. ESC a 1 (Center alignment)
    bytes.addAll(escCenter);

    // Header Banner
    bytes.addAll(latin1.encode('=' * _paperWidth + '\n'));
    bytes.addAll(latin1.encode('DIRECT THERMAL PRINTER\n'));
    bytes.addAll(latin1.encode('HARDWARE TEST SLIP\n'));
    bytes.addAll(latin1.encode('=' * _paperWidth + '\n\n'));

    // 3. Message: "HI THIS IS WORKING"
    if (_isDoubleSize) {
      bytes.addAll(escDoubleSize); // GS ! 0x11
    } else if (_isBold) {
      bytes.addAll(escBoldOn); // ESC E 1
    }

    bytes.addAll(latin1.encode('${message.toUpperCase()}\n\n'));

    // Reset styles
    bytes.addAll(escNormalSize);
    bytes.addAll(escBoldOff);

    // 4. Details
    bytes.addAll(latin1.encode('-' * _paperWidth + '\n'));
    bytes.addAll(latin1.encode('Time: $timeStr\n'));
    bytes.addAll(latin1.encode('Width: $_paperWidth cols (${_paperWidth == 32 ? "58mm" : "80mm"})\n'));
    bytes.addAll(latin1.encode('Driver: 100% Direct ESC/POS\n'));
    bytes.addAll(latin1.encode('Mode: ${_connectionMode.name.toUpperCase()} (NO RawBT)\n'));
    bytes.addAll(latin1.encode('=' * _paperWidth + '\n'));
    bytes.addAll(latin1.encode('*** TEST COMPLETED ***\n'));

    // 5. Line feeds & Auto Paper Cut (GS V 1)
    if (shouldCut) {
      bytes.addAll(latin1.encode('\n\n\n\n'));
      bytes.addAll(escCut);
    } else {
      bytes.addAll(latin1.encode('\n\n\n\n'));
    }

    return Uint8List.fromList(bytes);
  }

  Future<void> _directPrint() async {
    setState(() {
      _isPrinting = true;
      _lastStatusMessage = null;
    });

    final bytes = _generateEscPosBytes();

    try {
      switch (_connectionMode) {
        // Mode 1: Direct Network / WiFi (TCP Socket, Port 9100)
        case ConnectionMode.wifi:
          final ip = _ipController.text.trim();
          final port = int.tryParse(_portController.text.trim()) ?? 9100;
          if (ip.isEmpty) throw Exception('Please enter printer IP address');

          final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 4));
          socket.add(bytes);
          await socket.flush();
          await socket.close();
          setState(() {
            _lastStatusSuccess = true;
            _lastStatusMessage = 'Printed directly over WiFi/Network ($ip:$port)';
          });
          break;

        // Mode 2: Direct Bluetooth (SPP / RFCOMM Socket)
        case ConnectionMode.bluetooth:
          if (!kIsWeb && Platform.isAndroid) {
            if (_selectedBtAddress == null || _selectedBtAddress!.isEmpty) {
              throw Exception('No paired Bluetooth thermal printer selected. Pair printer in Android Bluetooth Settings first.');
            }
            final result = await _directChannel.invokeMethod<String>('printBluetoothDirect', {
              'address': _selectedBtAddress,
              'bytes': bytes,
            });
            setState(() {
              _lastStatusSuccess = true;
              _lastStatusMessage = result ?? 'Printed directly via Bluetooth!';
            });
          } else {
            // Desktop simulation
            debugPrint('=== DIRECT BLUETOOTH SIMULATED PRINT (${bytes.length} bytes) ===');
            await Future.delayed(const Duration(milliseconds: 300));
            setState(() {
              _lastStatusSuccess = true;
              _lastStatusMessage = 'Simulated Bluetooth print on ${Platform.operatingSystem} (${bytes.length} ESC/POS bytes sent directly)';
            });
          }
          break;

        // Mode 3: Direct USB (USB Host Bulk Transfer)
        case ConnectionMode.usb:
          if (!kIsWeb && Platform.isAndroid) {
            if (_selectedUsbDeviceId == null) {
              throw Exception('No connected USB printer detected. Connect printer via USB OTG cable and tap Refresh.');
            }
            final result = await _directChannel.invokeMethod<String>('printUsbDirect', {
              'deviceId': _selectedUsbDeviceId,
              'bytes': bytes,
            });
            setState(() {
              _lastStatusSuccess = true;
              _lastStatusMessage = result ?? 'Printed directly via USB!';
            });
          } else {
            // Desktop simulation
            debugPrint('=== DIRECT USB SIMULATED PRINT (${bytes.length} bytes) ===');
            await Future.delayed(const Duration(milliseconds: 300));
            setState(() {
              _lastStatusSuccess = true;
              _lastStatusMessage = 'Simulated USB print on ${Platform.operatingSystem} (${bytes.length} ESC/POS bytes sent directly)';
            });
          }
          break;
      }
    } catch (e) {
      setState(() {
        _lastStatusSuccess = false;
        _lastStatusMessage = 'Print Failed: $e';
      });
    } finally {
      setState(() => _isPrinting = false);
    }
  }

  void _showSlipPreview() {
    final previewText = StringBuffer();
    final message = _textController.text.trim().isEmpty ? 'hi this is working' : _textController.text.trim();
    final timeStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

    previewText.writeln('=' * _paperWidth);
    previewText.writeln('    DIRECT THERMAL PRINTER');
    previewText.writeln('      HARDWARE TEST SLIP');
    previewText.writeln('=' * _paperWidth);
    previewText.writeln();
    previewText.writeln('    *** ${message.toUpperCase()} ***');
    previewText.writeln();
    previewText.writeln('-' * _paperWidth);
    previewText.writeln('Time:   $timeStr');
    previewText.writeln('Driver: Direct ESC/POS Driver');
    previewText.writeln('Mode:   ${_connectionMode.name.toUpperCase()} (NO RawBT)');
    previewText.writeln('Status: 100% DIRECT HARDWARE');
    previewText.writeln('=' * _paperWidth);
    previewText.writeln('     *** TEST COMPLETED ***');
    if (_includePaperCut) {
      previewText.writeln('\n\n[AUTO PAPER CUT]');
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: Color(0xFF0F172A)),
            SizedBox(width: 8),
            Text('Thermal Paper Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF9F6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              previewText.toString(),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Colors.black87,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.print_rounded, size: 22),
            SizedBox(width: 10),
            Text('Direct Thermal Printer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Preview Slip',
            icon: const Icon(Icons.receipt_long),
            onPressed: _showSlipPreview,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. DIRECT PRINT CALLOUT CARD
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.bolt, color: Color(0xFF2563EB), size: 22),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Direct Thermal Printing',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      '100% Direct Driver • Zero RawBT Dependency',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF16A34A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Connects directly to your thermal printer via Bluetooth, USB OTG, or WiFi Socket without needing any third-party app.',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.35),
                          ),
                          const SizedBox(height: 18),

                          // BIG DIRECT PRINT BUTTON
                          SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _isPrinting ? null : _directPrint,
                              icon: _isPrinting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Icon(Icons.print, size: 24),
                              label: Text(
                                _isPrinting ? 'PRINTING DIRECTLY...' : 'DIRECT PRINT: "HI THIS IS WORKING"',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Status Banner
                  if (_lastStatusMessage != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: _lastStatusSuccess ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _lastStatusSuccess ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _lastStatusSuccess ? Icons.check_circle : Icons.error_outline,
                            color: _lastStatusSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _lastStatusSuccess ? 'Printer Response' : 'Printer Error',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: _lastStatusSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _lastStatusMessage!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: _lastStatusSuccess ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // 2. HARDWARE CONNECTION MODE SELECTOR
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Printer Direct Connection',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 12),

                          SegmentedButton<ConnectionMode>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: ConnectionMode.bluetooth,
                                icon: Icon(Icons.bluetooth, size: 16),
                                label: Text('Bluetooth', style: TextStyle(fontSize: 12)),
                              ),
                              ButtonSegment(
                                value: ConnectionMode.wifi,
                                icon: Icon(Icons.wifi, size: 16),
                                label: Text('WiFi / LAN', style: TextStyle(fontSize: 12)),
                              ),
                              ButtonSegment(
                                value: ConnectionMode.usb,
                                icon: Icon(Icons.usb, size: 16),
                                label: Text('USB OTG', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                            selected: {_connectionMode},
                            onSelectionChanged: (set) {
                              setState(() => _connectionMode = set.first);
                            },
                          ),

                          const SizedBox(height: 16),

                          // BLUETOOTH CONTROLS
                          if (_connectionMode == ConnectionMode.bluetooth) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Paired Bluetooth Printers:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                TextButton.icon(
                                  onPressed: _isLoadingBt ? null : _loadBluetoothDevices,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Refresh'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (_bluetoothDevices.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'No paired Bluetooth thermal printers detected.\nPlease pair your Bluetooth printer in Android Settings ➔ Bluetooth, then tap Refresh.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                initialValue: _selectedBtAddress,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                items: _bluetoothDevices.map((d) {
                                  return DropdownMenuItem<String>(
                                    value: d['address'],
                                    child: Text('${d['name']} (${d['address']})', style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedBtAddress = val);
                                },
                              ),
                          ],

                          // WIFI / NETWORK CONTROLS
                          if (_connectionMode == ConnectionMode.wifi) ...[
                            const Text('Printer Network IP & Port (RAW TCP):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _ipController,
                                    decoration: InputDecoration(
                                      labelText: 'Printer IP',
                                      hintText: '192.168.1.100',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _portController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Port',
                                      hintText: '9100',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // USB CONTROLS
                          if (_connectionMode == ConnectionMode.usb) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Attached USB Printers:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                TextButton.icon(
                                  onPressed: _isLoadingUsb ? null : _loadUsbDevices,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Scan USB'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            if (_usbDevices.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'No USB thermal printers found.\nConnect your printer via USB OTG adapter and tap Scan USB.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              )
                            else
                              DropdownButtonFormField<int>(
                                initialValue: _selectedUsbDeviceId,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                items: _usbDevices.map((d) {
                                  return DropdownMenuItem<int>(
                                    value: d['deviceId'] as int?,
                                    child: Text('${d['name']}', style: const TextStyle(fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedUsbDeviceId = val);
                                },
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3. MESSAGE & FORMATTING
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Print Message & Formatting',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 12),

                          TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              labelText: 'Test Message',
                              hintText: 'e.g. hi this is working',
                              prefixIcon: const Icon(Icons.edit_note, size: 22),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                            ),
                          ),

                          const SizedBox(height: 14),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Double Size Font (Large for Chef/KOT)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: const Text('ESC/POS command: GS ! 0x11', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            value: _isDoubleSize,
                            activeTrackColor: const Color(0xFF38BDF8),
                            activeThumbColor: const Color(0xFF0F172A),
                            onChanged: (val) => setState(() => _isDoubleSize = val),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Bold Font', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: const Text('ESC/POS command: ESC E 1', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            value: _isBold,
                            activeTrackColor: const Color(0xFF38BDF8),
                            activeThumbColor: const Color(0xFF0F172A),
                            onChanged: (val) => setState(() => _isBold = val),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Auto Paper Cut at End', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                            subtitle: const Text('ESC/POS command: GS V 1', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            value: _includePaperCut,
                            activeTrackColor: const Color(0xFF38BDF8),
                            activeThumbColor: const Color(0xFF0F172A),
                            onChanged: (val) => setState(() => _includePaperCut = val),
                          ),

                          const SizedBox(height: 8),
                          const Text('Paper Width:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 32, label: Text('58mm (32 cols)')),
                              ButtonSegment(value: 48, label: Text('80mm (48 cols)')),
                            ],
                            selected: {_paperWidth},
                            onSelectionChanged: (set) => setState(() => _paperWidth = set.first),
                          ),

                          const SizedBox(height: 18),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _showSlipPreview,
                                  icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                                  label: const Text('Preview Slip'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    foregroundColor: const Color(0xFF0F172A),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isPrinting ? null : _directPrint,
                                  icon: const Icon(Icons.print_outlined, size: 18),
                                  label: const Text('Print Now'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
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
      ),
    );
  }
}

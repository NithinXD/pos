// import 'dart:typed_data';
// import 'package:usb_serial/usb_serial.dart';
// import 'package:esc_pos_utils/esc_pos_utils.dart';

// class USBPrinterService {
//   UsbPort? _usbPort;

//   Future<List<UsbDevice>> getUsbDevices() async {
//     return await UsbSerial.listDevices();
//   }

//   Future<bool> connectToPrinter(UsbDevice device) async {
//     _usbPort = await device.create();
//     if (_usbPort == null) return false;
//     bool opened = await _usbPort!.open();
//     if (!opened) {
//       disconnect();
//       return false;
//     }
//     _usbPort!.setDTR(true); // For specific printer requirements
//     _usbPort!.setRTS(true);
//     return true;
//   }

//   Future<bool> printReceipt(String shopName, String orderNumber,
//       List<Map<String, dynamic>> items, double total) async {
//     final profile = await CapabilityProfile.load();
//     final generator = Generator(PaperSize.mm80, profile);
//     List<int> bytes = [];

//     // Add formatted receipt content
//     bytes += generator.text(shopName, styles: PosStyles(bold: true));
//     bytes += generator.text('Order #: $orderNumber');
//     bytes += generator.hr();
//     for (var item in items) {
//       bytes += generator.row([
//         PosColumn(text: item['name'], width: 6),
//         PosColumn(text: '${item['quantity']} x ${item['price']}', width: 6),
//       ]);
//     }
//     bytes += generator.hr();
//     bytes += generator.text('TOTAL: \$${total.toStringAsFixed(2)}',
//         styles: PosStyles(bold: true));
//     bytes += generator.cut();

//     // Send bytes to USB printer
//     if (_usbPort != null) {
//       try {
//         await _usbPort!.write(Uint8List.fromList(bytes));
//         return true; // Indicate success
//       } catch (e) {
//         print('Error writing to USB printer: $e');
//         return false; // Indicate failure
//       }
//     }
//     return false; // Return false if USB port is not available
//   }

//   void disconnect() {
//     _usbPort?.close();
//     _usbPort = null;
//   }
// }

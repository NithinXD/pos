import 'package:flutter/services.dart';
import '../models/order.dart';
import '../services/api_service.dart';

class PrinterService {
  static const MethodChannel _platform = MethodChannel('rawbt.intent.channel');
  final ApiService _apiService = ApiService();

  /// Fetches order details and prints the receipt
  Future<void> fetchAndPrintReceipt(Order order) async {
    try {
      // Fetch order details
      final response = await _apiService.fetchOrderDetails(order.orderId);
        final response1 = await _apiService.fetchOrderDetails1(order.orderId);
        print(response1);
    String name =response1['shopdetails']['shop']['shop_name'];
      String  address =response1['shopdetails']['shop']['street'] +','+response1['shopdetails']['shop']['post_code'] +','+response1['shopdetails']['shop']['county'];
      String    phone =response1['shopdetails']['shop']['telephone'];
       String    fax =response1['shopdetails']['shop']['fax'];
    
      List<OrderDetail> orderDetails = response.items.values.toList();

      // Print the receipt
      await printReceipt(order, orderDetails,name,address,phone,fax);
    } catch (e) {
      print('Failed to fetch or print order details: $e');
    }
  }

  /// Prints the receipt with provided order and order details
  Future<void> printReceipt(Order order, List<OrderDetail>? orderDetails,String name,String address, String phone,String fax) async {
    if (orderDetails == null) return;

    String receiptData = _formatReceipt(order, orderDetails,name,address,phone,fax);

    try {
      await _platform.invokeMethod('sendToRawBT', <String, dynamic>{
        'text': receiptData,
        'type': 'text/plain',
      });
      print('Print sent to RawBT');
    } on PlatformException catch (e) {
      print('Failed to print: ${e.message}');
    }
  }

  String _formatReceipt(Order order, List<OrderDetail> orderDetails,String name,String address, String phone,String fax) {
    String receipt = '';

    // Shop Details
    receipt += '--------------------------------\n';
    receipt += '${name}\n'; // Ensure this field is populated
    receipt += '${address}\n';
    receipt += '${phone}\n';
     receipt += 'VAT ID :${fax}\n';
    receipt += '--------------------------------\n';

    // Order Details
    receipt += 'Order #${order.orderId}\n';
    receipt += 'Date: ${order.orderTime}\n';
    receipt += 'Customer: ${order.customerName}\n';
    receipt += 'Phone: ${order.customerPhone}\n';
    receipt += 'Address: ${order.customerAddress}\n';
    receipt += '--------------------------------\n';

    // ESC/POS commands
    const String normalStyle = '\x1B\x21\x00'; // Normal text
    const String heightStyle = '\x1B\x21\x10'; // Double height only
    const int totalWidth = 48; // Total receipt width
    const int priceWidth = 10; // Width reserved for price
    const int itemNameWidth = totalWidth - priceWidth - 1; // Remaining width for item name

    // Order Items
    receipt += 'Order Items:\n';

    for (var item in orderDetails) {
      String itemName = '${item.quantity}x ${item.itemName}';
      String price = '€${(item.price * item.quantity).toStringAsFixed(2)}';

      // Apply double height style for items
      receipt += heightStyle;

      // Wrap item name
      List<String> wrappedLines = _wrapText(itemName, itemNameWidth);

      // Add the first line with the price aligned to the right
      receipt += wrappedLines[0].padRight(itemNameWidth) + price.padLeft(priceWidth) + '\n';

      // Add remaining lines for the item name
      for (int i = 1; i < wrappedLines.length; i++) {
        receipt += wrappedLines[i] + '\n';
      }

      // Add extras or notes
      if (item.extras.isNotEmpty) {
        for (var extra in item.extras) {
          receipt += '  + $extra\n';
        }
      }
      if (item.notes.isNotEmpty) {
        receipt += '  Note: ${item.notes}\n';
      }

      // Reset style to normal after each item
      receipt += normalStyle;
    }

    // Order Summary
    receipt += '--------------------------------\n';
    receipt += 'Sub Total:'.padRight(itemNameWidth) +
        '€${order.total.toStringAsFixed(2)}'.padLeft(priceWidth) +
        '\n';

    receipt += 'Discount:'.padRight(itemNameWidth) +
        '-€${order.discount.toStringAsFixed(2)}'.padLeft(priceWidth) +
        '\n';

    receipt += 'Delivery Charge:'.padRight(itemNameWidth) +
        '€${order.deliveryFee.toStringAsFixed(2)}'.padLeft(priceWidth) +
        '\n';

    // Final Total
    double finalTotal = order.total + order.deliveryFee - order.discount;
    receipt += 'Order Total:'.padRight(itemNameWidth) +
        '€${finalTotal.toStringAsFixed(2)}'.padLeft(priceWidth) +
        '\n';

    // Gross Total Business
    double grossTotalBusiness = order.total + order.deliveryFee - order.discount;
    receipt += 'Gross Total Business:'.padRight(itemNameWidth) +
        '€${grossTotalBusiness.toStringAsFixed(2)}'.padLeft(priceWidth) +
        '\n';

    // Footer
    receipt += '--------------------------------\n';
    receipt += 'Payment Type: ${order.paymentType}\n';
    receipt += 'Thank You for Your Customs!\n';
    
      // Paper Cut Command
  receipt += '\n\n\n\n\n\n\n\n\n\n\n';
  receipt += '\x1D\x56\x42\x00'; // ESC/POS command for a partial cut


    return receipt;
  }

  /// Helper to wrap text into multiple lines
  List<String> _wrapText(String text, int width) {
    List<String> lines = [];
    StringBuffer currentLine = StringBuffer();

    for (String word in text.split(' ')) {
      if ((currentLine.length + word.length + 1) > width) {
        lines.add(currentLine.toString());
        currentLine.clear();
      }
      if (currentLine.isNotEmpty) {
        currentLine.write(' ');
      }
      currentLine.write(word);
    }

    if (currentLine.isNotEmpty) {
      lines.add(currentLine.toString());
    }

    return lines;
  }
}

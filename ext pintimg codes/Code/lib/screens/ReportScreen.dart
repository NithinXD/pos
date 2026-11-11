import 'package:flutter/material.dart';
import 'package:flutterbill/screens/booking.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/database_service.dart';
import 'ZonesScreen.dart';
import 'orders_Screen.dart';
import 'package:flutter/services.dart';

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final TextEditingController _dateController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic> _reportData = {};
  Map<String, dynamic> _reportDetails = {};
  Map<String, String> _shopDetails = {};
  final DatabaseService _databaseService = DatabaseService();
  String? _shopId;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    _dateController.text = _getTodayDate(); // Set default date to today
    _shopId = await _databaseService.getShopId(); // Fetch shopId from database
    if (_shopId != null) {
      _fetchReport(_dateController.text); // Fetch report for today's date
    } else {
      _logError('Shop ID not found');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Shop ID not found.')),
      );
    }
  }

  String _getTodayDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchReport(String date) async {
    if (_shopId == null) {
      _logError('Shop ID is null.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Shop ID is null.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final Uri apiUrl = Uri.parse(
        'https://www.takeawayordering.com/appserver/appserver.php?tag=getreport&shop_id=$_shopId&report_date=$date',
      );

      _logInfo('Fetching report from $apiUrl');

      final response = await http.get(apiUrl);

      if (response.statusCode == 200) {
        final cleanedResponse = response.body.trim();
        final data = json.decode(cleanedResponse);

        print('API response: $data');

        // Extract shop details
        if (data['shopdetails'] != null) {
          final shopData = data['shopdetails'][_shopId];
          setState(() {
            _shopDetails = {
              'shopName': shopData['shop_name'] ?? '',
              'address': shopData['street'] ?? '',
              'phone': shopData['telephone'] ?? '',
              'email': shopData['email'] ?? '',
            };
          });
        }

        // Process other report data
        if (data['success'] == 1 || data['success'] == -4) {
          setState(() {
            _reportData = {
              'cashOrders': data['cashorder'] ?? 0,
              'cardOrders': data['cardorder'] ?? 0,
              'collectionOrders': data['collection'] ?? 0,
              'deliveryOrders': data['delivery'] ?? 0,
              'totalOrders': data['totalorders'] ?? 0,
              'cashBusiness': data['cashbusiness'] ?? 0.0,
              'cardBusiness': data['cardbusiness'] ?? 0.0,
              'totalBusiness': data['totalbusiness'] ?? 0.0,
              'cashDeliveryCharge': data['cashdeliverycharge'] ?? 0.0,
              'cardDeliveryCharge': data['carddeliverycharge'] ?? 0.0,
              'totalDeliveryCharge': data['totaldeliverycharge'] ?? 0.0,
              'totalDiscount': data['totaldiscount'] ?? 0.0, // Add this line
            };

            // Calculate Gross Total Business
            double grossTotalBusiness = _reportData['totalBusiness'] +
                _reportData['totalDeliveryCharge'] -
                _reportData['totalDiscount'];
            _reportData['grossTotalBusiness'] = grossTotalBusiness;

            // Add order details
            _reportDetails = data['reportdetails'] ?? {};
          });
        } else {
          _logWarning('No report data available for this date.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No report data available for this date.')),
          );
        }
      } else {
        _logError('Failed to fetch report. Status code: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch report. Status code: ${response.statusCode}')),
        );
      }
    } catch (e) {
      _logError('Error fetching report: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching report: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logInfo(String message) {
    print('INFO: $message');
  }

  void _onBottomNavTap(int index) {
    setState(() {
    });

    switch (index) {
      case 0:
        // Stay on ReportScreen
        break;
            case 1:
               Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingsScreen(
                    shopId: _shopId!, 
              employeePhone: "wingsbox",
              employeePin: "2go2hell",
                  ),
                ),
              );
              break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ZonesScreen()),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => OrdersScreen()),
        );
        break;
    }
  }

  void _logWarning(String message) {
    print('WARNING: $message');
  }

  void _logError(String message) {
    print('ERROR: $message');
  }

  double _convertToDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _printReport() async {
    if (_reportData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No report data to print.')),
      );
      return;
    }

    String receiptData = _formatReportForPrinting();

    try {
      const platform = MethodChannel('rawbt.intent.channel');
      await platform.invokeMethod('sendToRawBT', <String, dynamic>{
        'text': receiptData,
        'type': 'text/plain',
      });
      _logInfo('Print sent to RawBT');
    } catch (e) {
      _logError('Failed to print: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error printing report: $e')),
      );
    }
  }

  String _formatReportForPrinting() {
    String receipt = '';

    // Header: Shop Details
    receipt += '--------------------------------\n';
    receipt += '           SHOP REPORT          \n';
    receipt += '--------------------------------\n';
    receipt += '${_shopDetails['shopName']}\n';
    receipt += '${_shopDetails['address']}\n';
    receipt += '${_shopDetails['phone']}\n';
    receipt += '${_shopDetails['email']}\n';
    receipt += '--------------------------------\n';
    // Date
    receipt += 'Date: ${_dateController.text}\n';
    receipt += '--------------------------------\n';

    // Order Details
    receipt += 'ORDER DETAILS:\n';
    receipt += '--------------------------------\n';
    receipt += 'Cash Orders: ${_reportData['cashOrders']}\n';
    receipt += 'Card Orders: ${_reportData['cardOrders']}\n';
    receipt += 'Collection Orders: ${_reportData['collectionOrders']}\n';
    receipt += 'Delivery Orders: ${_reportData['deliveryOrders']}\n';
    receipt += 'Total Orders: ${_reportData['totalOrders']}\n';
    receipt += '--------------------------------\n';

    // Business Summary
    receipt += 'BUSINESS SUMMARY:\n';
    receipt += '--------------------------------\n';
    receipt += 'Cash Business: €${_convertToDouble(_reportData['cashBusiness']).toStringAsFixed(2)}\n';
    receipt += 'Card Business: €${_convertToDouble(_reportData['cardBusiness']).toStringAsFixed(2)}\n';
    receipt += 'Total Business: €${_convertToDouble(_reportData['totalBusiness']).toStringAsFixed(2)}\n';
    receipt += '--------------------------------\n';
  // Business Summary
    receipt += 'GROSS BUSINESS SUMMARY:\n';
    receipt += '--------------------------------\n';
    receipt += 'Total Discount: €${_convertToDouble(_reportData['totalDiscount']).toStringAsFixed(2)}\n';
    receipt += 'Gross Total Business: €${_convertToDouble(_reportData['grossTotalBusiness']).toStringAsFixed(2)}\n';
    receipt += '--------------------------------\n';

 // Business Summary
    receipt += 'VAT SUMMARY:\n';
    receipt += '--------------------------------\n';
    receipt += 'Total Food VAT: €${_convertToDouble(_reportData['foodvat']).toStringAsFixed(2)}\n';
    receipt += 'Total Drinks VAT: €${_convertToDouble(_reportData['drinksvat']).toStringAsFixed(2)}\n';
    receipt += 'Total VAT: €${_convertToDouble(_reportData['totalvat']).toStringAsFixed(2)}\n';
    receipt += '--------------------------------\n';


    // Delivery Charges
    receipt += 'DELIVERY CHARGES:\n';
    receipt += '--------------------------------\n';
    receipt += 'Cash Delivery Charge: €${_convertToDouble(_reportData['cashDeliveryCharge']).toStringAsFixed(2)}\n';
    receipt += 'Card Delivery Charge: €${_convertToDouble(_reportData['cardDeliveryCharge']).toStringAsFixed(2)}\n';
    receipt += 'Total Delivery Charge: €${_convertToDouble(_reportData['totalDeliveryCharge']).toStringAsFixed(2)}\n';
    receipt += '--------------------------------\n';

    // Footer
    receipt += 'THANK YOU FOR YOUR BUSINESS!\n';
    receipt += '--------------------------------\n';
      // Paper Cut Command
  receipt += '\n\n\n\n\n\n\n\n\n\n\n';
  receipt += '\x1D\x56\x42\x00'; // ESC/POS command for a partial cut


    return receipt;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopSection(),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportData.isNotEmpty
                    ? _buildReportSummary()
                    : const Center(child: Text('No data available')),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Report',
          ),
           BottomNavigationBarItem(
            icon: Icon(Icons.event_available),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Zones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt),
            label: 'Orders',
          ),
        ],
        currentIndex: 0,
        onTap: _onBottomNavTap,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
    );
  }

  Widget _buildTopSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.center,
          child: TextField(
            controller: _dateController,
            readOnly: true,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              labelText: 'Select Date',
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    final formattedDate =
                        "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
                    _dateController.text = formattedDate;
                    _fetchReport(formattedDate);
                  }
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () => _fetchReport(_dateController.text),
              child: const Text('Get Report'),
            ),
            ElevatedButton(
              onPressed: () => _printReport(),
              child: const Text('Print Report'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportSummary() {
    return Expanded(
      child: ListView(
        children: [
          _buildSectionCard(
            'Order Details',
            {
              'Number of Cash Orders': _reportData['cashOrders'],
              'Number of Card Orders': _reportData['cardOrders'],
              'Number of Collection Orders': _reportData['collectionOrders'],
              'Number of Delivery Orders': _reportData['deliveryOrders'],
              'Total Number of Orders': _reportData['totalOrders'],
            },
          ),
          _buildSectionCard(
            'Business Summary',
            {
              'Total Cash Business': "€${_convertToDouble(_reportData['cashBusiness']).toStringAsFixed(2)}",
              'Total Card Business': "€${_convertToDouble(_reportData['cardBusiness']).toStringAsFixed(2)}",
              'Total Business': "€${_convertToDouble(_reportData['totalBusiness']).toStringAsFixed(2)}",
            },
          ),
          _buildSectionCard(
            'Delivery Charges Summary',
            {
              'Total Cash Delivery Charge': "€${_convertToDouble(_reportData['cashDeliveryCharge']).toStringAsFixed(2)}",
              'Total Card Delivery Charge': "€${_convertToDouble(_reportData['cardDeliveryCharge']).toStringAsFixed(2)}",
              'Total Delivery Charge': "€${_convertToDouble(_reportData['totalDeliveryCharge']).toStringAsFixed(2)}",
            },
          ),
           _buildSectionCard(
            'Gross Business Summary',
            {
              'Total Discount': "€${_convertToDouble(_reportData['totalDiscount']).toStringAsFixed(2)}",
              'Gross Total Business': "€${_convertToDouble(_reportData['grossTotalBusiness']).toStringAsFixed(2)}",
            },
          ),
          _buildSectionCard(
            'VAT Summary',
            {
              'Total Food VAT': "€${_convertToDouble(_reportData['foodvat']).toStringAsFixed(2)}",
              'Total Drinks VAT': "€${_convertToDouble(_reportData['drinksvat']).toStringAsFixed(2)}",
               'Total VAT': "€${_convertToDouble(_reportData['totalvat']).toStringAsFixed(2)}",
            },
          ),
          if (_reportDetails.isNotEmpty) _buildOrderDetailsList(_reportDetails),
        ],
      ),
    );
  }

  Widget _buildOrderDetailsList(Map<String, dynamic> reportDetails) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Details Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...reportDetails.entries.map((entry) {
              final details = entry.value as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Order ID: ${details['od_id']}"),
                    Text("Total: €${_convertToDouble(details['od_total']).toStringAsFixed(2)}"),
                    Text("Delivery Charge: €${_convertToDouble(details['od_delivery_charge']).toStringAsFixed(2)}"),
                    Text("Payment Type: ${details['od_payment_type']}"),
                    const Divider(),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(String title, Map<String, dynamic> details) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...details.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key),
                      Text(entry.value.toString()),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

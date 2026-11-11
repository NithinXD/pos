import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutterbill/screens/booking.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/order.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'ReportScreen.dart';
import 'ZonesScreen.dart';
import '../services/printer_service.dart';
import 'package:http/http.dart' as http;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class OrdersScreen extends StatefulWidget {
  final String? shopId;
  final String? employeePhone;
  final String? employeePin;

  const OrdersScreen({
    Key? key,
    this.shopId,
    this.employeePhone,
    this.employeePin,
  }) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final ApiService _apiService = ApiService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final DatabaseService _databaseService = DatabaseService();
  final PrinterService _printerService = PrinterService();
  Timer? _continuousNotificationTimer;
  Timer? _timer;
  List<Order> _orders = [];
  bool _isLoading = true,loaded=true;
  String? _error;
  String? _shopId;
  String? _employeePhone;
  String? _employeePin;
  final Map<String, bool> _printStatus = {};
  final Set<String> _notifiedOrders = {};

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _initCredentials();
    _startPeriodicFetch();
    _startContinuousNotifications();
  }

 Future<void> _printOrder(Order order) async {
  
  try {
    setState(() {
      _printStatus[order.orderId] = true;
    });

    // Ensure the PrinterService uses the correct shop details
    await _printerService.fetchAndPrintReceipt(order);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Order #${order.orderId} sent to printer.')),
    );
  } catch (e) {
    setState(() {
      _printStatus[order.orderId] = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to print order #${order.orderId}: $e')),
    );
  }
}


  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _initCredentials() async {
    try {
      _shopId = widget.shopId;
      _employeePhone = widget.employeePhone;
      _employeePin = widget.employeePin;

      if (_shopId == null || _employeePhone == null || _employeePin == null) {
        final savedId = await _databaseService.getShopId();
        final savedPhone = await _databaseService.getEmployeePhone();
        final savedPin = await _databaseService.getEmployeePin();

        if (savedId == null || savedId.isEmpty) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/');
            return;
          }
        }
        _shopId = savedId;
        _employeePhone = savedPhone;
        _employeePin = savedPin;
      }

      await _fetchOrders();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error initializing: $e';
          _isLoading = false;
          loaded=false;
        });
      }
    }
  }

  void _startPeriodicFetch() {
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchOrders();
    });
  }

  Future<void> sendNotification() async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'unprinted_orders_channel',
      'Unprinted Orders',
      channelDescription: 'Notifications for unprinted orders reminder',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Unprinted orders need your attention!',
      ongoing: true,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await flutterLocalNotificationsPlugin.show(
      notificationId,
      'Unprinted Orders',
      'Unprinted orders: Print now',
      notificationDetails,
    );
  }

  Future<void> _playNotificationSound() async {
    try {
      final byteData = await rootBundle.load('assets/sounds/beep.mp3');
      final audioBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/notification.mp3');
      await tempFile.writeAsBytes(audioBytes, flush: true);

      await _audioPlayer.setFilePath(tempFile.path);
      _audioPlayer.play();
    } catch (e) {
      print("Error loading or playing sound: $e");
    }
  }

  void _startContinuousNotifications() {
    _continuousNotificationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      bool hasUnprintedOrders = false;

      for (var order in _orders) {
        final isPrinted = _printStatus[order.orderId] ?? false;

        if (!isPrinted) {
          hasUnprintedOrders = true;
          _showOrderNotification(order);
        }
      }

      if (hasUnprintedOrders) {
        sendNotification();
        _playNotificationSound();
      }
    });
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.fetchOrders();

      if (!mounted) return;

      final newOrders = response.orders.values.toList();
      _notifiedOrders.clear();

      for (var order in newOrders) {
        final isPrinted = order.orderPrinted != "0";
        _printStatus[order.orderId] = isPrinted;

        if (!isPrinted) {
          _notifiedOrders.add(order.orderId);
        }
      }

      setState(() {
        _orders = newOrders;
        _isLoading = false;
        loaded=false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch orders: $e';
        _isLoading = false;
        loaded=false;
      });
    }
  }

  Future<void> _showOrderNotification(Order order) async {
    if (_notifiedOrders.contains(order.orderId)) return;

    final notificationTitle = 'Unprinted Order';
    final notificationBody = 'Order #${order.orderId} is waiting to be printed.';

    await flutterLocalNotificationsPlugin.show(
      order.orderId.hashCode,
      notificationTitle,
      notificationBody,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'order_channel',
          'Order Notifications',
          channelDescription: 'Notifications for unprinted orders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );

    _notifiedOrders.add(order.orderId);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _continuousNotificationTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    try {
      await _databaseService.saveShopId('');
      await _databaseService.saveEmployeePhone('');
      await _databaseService.saveEmployeePin('');

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_employeePhone != null ? 'Order Pad - $_employeePhone' : 'Order Pad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _buildBody(),
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
        onTap: (int index) {
          switch (index) {
            case 0:
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ReportScreen()),
              );
              break;
              case 1:
               Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingsScreen(
                    shopId: _shopId!, // Replace with actual shop ID
                    employeePhone:_employeePhone!,
                    employeePin:_employeePin!,
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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => OrdersScreen(
                    shopId: _shopId,
                     employeePhone:_employeePhone!,
                    employeePin:_employeePin!,
                  ),
                ),
              );
              break;
          }
        },
        selectedItemColor: Colors.grey,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchOrders,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return const Center(
        child: Text('No orders found'),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final isPrinted = _printStatus[order.orderId] ?? false;

          return Card(
            color: isPrinted ? const Color(0xFF88C3CF) : Colors.orange[100],
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                color: isPrinted ? Colors.blue : Colors.red,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/order-details',
                  arguments: order,
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerPhone,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              order.customerName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              order.email,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Total: €${order.total.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Address: ${order.customerAddress}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Delivery Charge: €${order.deliveryFee.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                         Text(
                          order.paymentType,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${order.orderType}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                       
                      ],
                    ),
                   
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order ID: ${order.orderId}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPrinted ? Colors.green : Colors.red,
                          ),
                          onPressed: () async {
                            try {
                              await _printOrder(order);

                              final savedId = await _databaseService.getShopId();
                              final savedPhone = await _databaseService.getEmployeePhone();
                              final savedPin = await _databaseService.getEmployeePin();
                              final orderId = order.orderId;

                              final apiUrl =
                                  'https://www.takeawayordering.com/appserver/appserver.php?tag=updateprintstatus'
                                  '&employee_phone=$savedPhone&employee_pin=$savedPin&shop_id=$savedId&order_id=$orderId';

                              final response = await http.get(Uri.parse(apiUrl));

                              if (response.statusCode == 200) {
                                print('Print status updated successfully: ${response.body}');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Print status updated successfully!')),
                                );
                                setState(() {
                                  _printStatus[order.orderId] = true;
                                });
                              } else {
                                print('Failed to update print status: ${response.body}');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Failed to update print status.')),
                                );
                              }
                            } catch (e) {
                              print('Error occurred while updating print status: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('An error occurred: $e')),
                              );
                            }
                          },
                          child: const Text('Print Receipt'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

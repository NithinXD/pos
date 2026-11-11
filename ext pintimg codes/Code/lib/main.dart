import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/shop_id_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/order_details_screen.dart';
import 'models/order.dart';
import 'services/api_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final ApiService _apiService = ApiService(); // Initialize ApiService

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await checkForOrdersAndNotify();
    return Future.value(true);
  });
}

Future<void> checkForOrdersAndNotify() async {
  // Fetch orders from ApiService
  final response = await _apiService.fetchOrders(); // Using ApiService to fetch orders

  for (var order in response.orders.values) {
    if (order.orderPrinted != "0") {
      await flutterLocalNotificationsPlugin.show(
        order.orderId.hashCode,
        'New Order',
        'Order #${order.orderId} is ready.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'order_channel', // ID
            'Order Notifications', // Name
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize WorkManager
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  Workmanager().registerPeriodicTask("1", "checkOrdersTask",
      frequency: const Duration(minutes: 15)); // Adjust as needed

  // Initialize flutter_local_notifications
  var initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  var initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Disables the debug banner
      title: 'Flutter Bill',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
        ),
        cardTheme: const CardTheme(
          elevation: 2,
          margin: EdgeInsets.symmetric(vertical: 8),
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (context) => const ShopIdScreen(),
            );
          case '/orders':
            if (settings.arguments is Map) {
              final args = settings.arguments as Map;
              return MaterialPageRoute(
                builder: (context) => OrdersScreen(
                  shopId: args['shopId']?.toString(),
                  employeePhone: args['employeePhone']?.toString(),
                  employeePin: args['employeePin']?.toString(),
                ),
              );
            }
            return MaterialPageRoute(
              builder: (context) => const ShopIdScreen(),
            );
          case '/order-details':
            if (settings.arguments is Order) {
              return MaterialPageRoute(
                builder: (context) => OrderDetailsScreen(
                  order: settings.arguments as Order,
                ),
              );
            }
            return MaterialPageRoute(
              builder: (context) => const ShopIdScreen(),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const ShopIdScreen(),
            );
        }
      },
    );
  }
}
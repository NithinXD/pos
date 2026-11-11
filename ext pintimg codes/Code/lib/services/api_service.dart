import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order.dart';
import '../services/database_service.dart';

class ApiService {
  static const String baseUrl = 'https://www.takeawayordering.com/appserver/appserver.php';
  final _databaseService = DatabaseService();
  List<Order> _previousOrders = []; // Track previous orders for comparison

  Future<String?> _getEmployeePhone() async => await _databaseService.getEmployeePhone();
  Future<String?> _getEmployeePin() async => await _databaseService.getEmployeePin();
  Future<String?> _getShopId() async => await _databaseService.getShopId();

  void _logRequest(String endpoint, Map<String, String?> params) {
    print('\nAPI Request to $endpoint:');
    print('Parameters:');
    params.forEach((key, value) => print('$key: $value'));
  }

  void _logResponse(String endpoint, http.Response response) {
    print('\nAPI Response from $endpoint:');
    print('Status Code: ${response.statusCode}');
    print('Body: ${response.body}');
  }

  void _logError(String operation, dynamic error) {
    print('\nError in $operation:');
    print('Error details: $error');
    print('Stack trace: ${StackTrace.current}');
  }

  Future<OrderResponse> fetchOrders() async {
    try {
      final shopId = await _getShopId();
      final employeePhone = await _getEmployeePhone();
      final employeePin = await _getEmployeePin();

      final params = {
        'tag': 'todaysorders',
        'employee_phone': employeePhone,
        'employee_pin': employeePin,
        'shop_id': shopId,
      };

      _logRequest('fetchOrders', params);

      final url = '$baseUrl?tag=todaysorders&employee_phone=$employeePhone&employee_pin=$employeePin&shop_id=$shopId';
      print(url);
      final response = await http.get(Uri.parse(url));
      print('Body: ${response.body}');

      _logResponse('fetchOrders', response);
      jsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return OrderResponse.fromJson(data);
      } else {
        throw Exception('Failed to load orders: ${response.statusCode}');
      }
    } catch (e) {
      _logError('fetchOrders', e);
      return OrderResponse(
        orders: {},
        success: false,
        message: 'Error fetching orders: $e',
      );
    }
  }

  Future<OrderDetailsResponse> fetchOrderDetails(String orderId) async {
    try {
      final shopId = await _getShopId();
      final employeePhone = await _getEmployeePhone();
      final employeePin = await _getEmployeePin();

      final params = {
        'tag': 'todaysorders',
        'employee_phone': employeePhone,
        'employee_pin': employeePin,
        'shop_id': shopId,
        'order_id': orderId,
      };

      _logRequest('fetchOrderDetails', params);

      final url = '$baseUrl?tag=tableitemdetails&employee_phone=$employeePhone&employee_pin=$employeePin&shop_id=$shopId&order_id=$orderId';
      final response = await http.get(Uri.parse(url));

      print('fetchOrderDetails : ${json.decode(response.body)}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return OrderDetailsResponse.fromJson(data);
      } else {
        throw Exception('Failed to load order details: ${response.statusCode}');
      }
    } catch (e) {
      _logError('fetchOrderDetails', e);
      return OrderDetailsResponse(
        items: {},
        success: false,
        message: 'Error fetching order details: $e',
      );
    }
  }

  Future<Map<String, dynamic>> fetchOrderDetails1(String orderId) async {
  try {
    // Fetch shop ID, employee phone, and employee pin
    final shopId = await _getShopId();
    final employeePhone = await _getEmployeePhone();
    final employeePin = await _getEmployeePin();

     

    // Build the request URL
    final url = '$baseUrl?tag=tableitemdetails&employee_phone=$employeePhone'
        '&employee_pin=$employeePin&shop_id=$shopId&order_id=$orderId';

    // Make the GET request
    final response = await http.get(Uri.parse(url));


    // Check if the request was successful
    if (response.statusCode == 200) {
      // Decode and return the JSON response
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      // Handle HTTP errors
      throw Exception('Failed to load order details: ${response.statusCode}');
    }
  } catch (e) {
    // Log errors and return an error response
    _logError('fetchOrderDetails', e);
    return {
      'success': false,
      'message': 'Error fetching order details: $e',
      'data': null,
    };
  }
}


  Future<List<Order>> fetchNewOrders() async {
    try {
      final currentOrdersResponse = await fetchOrders();

      // Assuming OrderResponse contains a map of orderId and Order objects.
      final currentOrders = currentOrdersResponse.orders.values.toList();

      // Compare the previous orders with the current orders to find new ones
      final newOrders = currentOrders.where((order) {
        return !_previousOrders.any((prevOrder) => prevOrder.orderId == order.orderId);
      }).toList();

      // Update previous orders to the current orders for future comparison
      _previousOrders = currentOrders;

      print('New orders found: ${newOrders.length}');
      return newOrders;
    } catch (e) {
      _logError('fetchNewOrders', e);
      return [];
    }
  }
}

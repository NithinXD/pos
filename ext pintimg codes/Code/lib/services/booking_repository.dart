// booking_repository.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:intl/intl.dart';

class BookingRepository {
  final String shopId;
  final String employeePhone;
  final String employeePin;

  BookingRepository({
    required this.shopId,
    required this.employeePhone,
    required this.employeePin,
  });

  Future<List<Map<String, dynamic>>> fetchBookings(DateTime date,String type) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final url =
        type=='All'?'https://www.takeawayordering.com/appserver/appserver.php?tag=getbookings&employee_phone=$employeePhone&employee_pin=$employeePin&shop_id=$shopId&booking_date=$formattedDate': 
        'https://www.takeawayordering.com/appserver/appserver.php?tag=getbookingsbydate&employee_phone=$employeePhone&employee_pin=$employeePin&shop_id=$shopId&booking_date=$formattedDate';
  print(url);
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200 && response.body.isNotEmpty) {
      final data = json.decode(response.body);
      if (data['success'] == 1) {
        final bookingDetails = data['bookingdetails'] as Map<String, dynamic>;
        return bookingDetails.values.map((e) => e as Map<String, dynamic>).toList();
      }
      else  if (data['success'] == -2) {
        return [];
      } else {
        throw Exception('Failed to load bookings');
      }
    } else {
      throw Exception('Failed to load bookings');
    }
  }

  Future<void> updateStatus(String bookingId, String status) async {
    final url =
        'https://www.takeawayordering.com/appserver/appserver.php?tag=updatebookingstatus&employee_phone=$employeePhone&employee_pin=$employeePin&shop_id=$shopId&booking_id=$bookingId&booking_status=$status';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to update status');
    }
  }

  Future<void> sendEmail(String bookingId) async {
    final url =
        'https://www.takeawayordering.com/appserver/appserver.php?tag=sendemailbooking&employee_phone=$employeePhone&employee_pin=$employeePin&shop_id=$shopId&booking_id=$bookingId&booking_status=SENDEMAIL';
     print(url);
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to send email');
    }
  }

  Future<void> sendSMS(String bookingId) async {
    final url =
        'https://www.takeawayordering.com/appserver/appserver.php?tag=sendsmsbooking&employee_phone=$employeePhone&employee_pin=$employeePin&shop_id=$shopId&booking_id=$bookingId&booking_status=SENDSMS';
    print(url);
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw Exception('Failed to send SMS');
    }
  }


Future<void> editBooking(
  String bookingId,
  String name,
  String phone,
  String email,
  String numberOfPersons,
  DateTime bookingDate,
  TimeOfDay bookingTime,
  String voucherCode,
  String type,
) async {
  // Validate required fields
  if (name.isEmpty || phone.isEmpty || email.isEmpty || numberOfPersons.isEmpty) {
    throw Exception('Please fill all required fields: name, phone, email, and number of persons.');
  }

  final String formattedDate = DateFormat('yyyy-MM-dd').format(bookingDate);
  final String formattedTime = '${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}';

  // Construct the URL based on the type
  final String url = type == 'add'
      ? 'https://www.takeawayordering.com/appserver/appserver.php?tag=createbooking&employee_phone=$employeePhone&employee_pin=$employeePin&shop_id=$shopId&reservation_name=$name&reservation_phone=$phone&reservation_number=$numberOfPersons&reservation_date=$formattedDate&reservation_time=$formattedTime&reservation_email=$email&voucher_code=${voucherCode.isNotEmpty ? voucherCode : ''}'
      : 'https://www.takeawayordering.com/appserver/appserver.php?tag=editbooking&employee_phone=$employeePhone&employee_pin=$employeePin&shop_id=$shopId&booking_id=$bookingId&reservation_name=$name&reservation_phone=$phone&reservation_number=$numberOfPersons&reservation_date=$formattedDate&reservation_time=$formattedTime&reservation_email=$email&voucher_code=${voucherCode.isNotEmpty ?voucherCode : ''}';
print(url);
  // Make the HTTP request
  final response = await http.get(Uri.parse(url));
  print(response.body);
  if (response.statusCode != 200) {
    throw Exception(type == 'add' ? 'Failed to add booking' : 'Failed to edit booking');
  }
}

}

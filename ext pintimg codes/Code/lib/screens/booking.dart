import 'package:flutter/material.dart';
import 'package:flutterbill/services/booking_repository.dart';
import 'package:intl/intl.dart';

class BookingsScreen extends StatefulWidget {
  final String shopId;
  final String employeePhone;
  final String employeePin;

  const BookingsScreen({
    Key? key,
    required this.shopId,
    required this.employeePhone,
    required this.employeePin,
  }) : super(key: key);

  @override
  _BookingsScreenState createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  late BookingRepository bookingRepository;
  DateTime selectedDate = DateTime.now();
  List<Map<String, dynamic>> bookings = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    bookingRepository = BookingRepository(
      shopId: widget.shopId,
      employeePhone: widget.employeePhone,
      employeePin: widget.employeePin,
    );
    _fetchBookings(selectedDate, 'All');
  }

  Future<void> _fetchBookings(DateTime date, String type) async {
    setState(() {
      isLoading = true;
    });

    try {
      bookings = await bookingRepository.fetchBookings(date, type);
    } catch (e) {
      _showSnackBar('Error fetching bookings: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _updateStatus(String bookingId, String status) async {
    Navigator.pop(context);
    try {
      await bookingRepository.updateStatus(bookingId, status);
      _showSnackBar('Status updated to $status');
      await _fetchBookings(selectedDate, 'All');
    } catch (e) {
      _showSnackBar('Error updating status: $e');
    }
  }

  void _sendEmail(String bookingId) async {
    try {
      await bookingRepository.sendEmail(bookingId);
      _showSnackBar('Email sent');
    } catch (e) {
      _showSnackBar('Error sending email: $e');
    }
  }

  void _sendSMS(String bookingId) async {
    try {
      await bookingRepository.sendSMS(bookingId);
      _showSnackBar('SMS sent');
    } catch (e) {
      _showSnackBar('Error sending SMS: $e');
    }
  }

  TimeOfDay _parseTime(String timeString) {
    final parts = timeString.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _editBooking(
    String bookingId,
    String name,
    String phone,
    String email,
    String numberOfPersons,
    DateTime bookingDate,
    String bookingTime,
    String voucherCode,
    String type,
  ) async {
    try {
      final timeOfDay = _parseTime(bookingTime);
      await bookingRepository.editBooking(
        bookingId,
        name,
        phone,
        email,
        numberOfPersons,
        bookingDate,
        timeOfDay,
        voucherCode,
        type,
      );
      _showSnackBar("Booking updated successfully!");
      await _fetchBookings(selectedDate, 'All');
    } catch (e) {
      _showSnackBar('Error editing booking: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showStatusBottomSheet(String bookingId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Update Status",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: const Text("ARRIVED"),
                  onTap: () => _updateStatus(bookingId, "ARRIVED"),
                ),
                ListTile(
                  leading: const Icon(Icons.cancel, color: Colors.red),
                  title: const Text("NOSHOW"),
                  onTap: () => _updateStatus(bookingId, "NOSHOW"),
                ),
                ListTile(
                  leading: const Icon(Icons.remove_circle, color: Colors.orange),
                  title: const Text("CANCELLED"),
                  onTap: () => _updateStatus(bookingId, "CANCELLED"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
void _showEditBookingDialog(BuildContext context, Map<String, dynamic> booking, String id, String type) {
  final nameController = TextEditingController(text: booking['reservation_name'] ?? '');
  final phoneController = TextEditingController(text: booking['reservation_phone'] ?? '');
  final emailController = TextEditingController(text: booking['reservation_email'] ?? '');
  final personsController = TextEditingController(text: booking['reservation_number']?.toString() ?? '');
  final voucherController = TextEditingController(text: booking['voucher_code'] ?? '');
  DateTime bookingDate = booking['reservation_date'] != null ? DateTime.parse(booking['reservation_date']) : DateTime.now();
  final timeParts = booking['reservation_time']?.split(':') ?? ['11', '00'];
  final formattedTime = '${timeParts[0]}:${timeParts[1]}';
  String selectedTimeSlot = formattedTime;

  final List<String> timeSlots = [
    "11:00", "11:30", "12:00", "12:30", "13:00", "13:30", "14:00", "14:30",
    "15:00", "15:30", "16:00", "16:30", "17:00", "17:30", "18:00", "18:30",
    "19:00", "19:30", "20:00", "20:30", "21:00", "21:30", "22:00", "22:30"
  ];

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            title: Text(
              type == "add" ? "Create Booking" : "Edit Booking",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.black,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBrutalistTextField("Customer Name", nameController),
                  _buildBrutalistTextField("Customer Phone", phoneController, keyboardType: TextInputType.number),
                  _buildBrutalistTextField("Customer Email", emailController),
                  _buildBrutalistTextField("Number of Persons", personsController, keyboardType: TextInputType.number),
                  _buildBrutalistTextField("Reservation Voucher Code", voucherController),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "Booking Date",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: Text(
                      DateFormat('yyyy-MM-dd').format(bookingDate),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: bookingDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        setDialogState(() {
                          bookingDate = pickedDate;
                        });
                      }
                    },
                  ),
                  Wrap(
                    spacing: 8.0,
                    children: timeSlots.map((String time) {
                      return ChoiceChip(
                        label: Text(
                          time,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        selected: selectedTimeSlot == time,
                        onSelected: (bool selected) {
                          setDialogState(() {
                            selectedTimeSlot = time;
                          });
                        },
                        backgroundColor: Colors.grey[300],
                        selectedColor: Colors.black,
                        labelStyle: TextStyle(
                          color: selectedTimeSlot == time ? Colors.white : Colors.black,
                        ),
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "CANCEL",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isEmpty ||
                      phoneController.text.isEmpty ||
                      emailController.text.isEmpty ||
                      personsController.text.isEmpty) {
                    _showSnackBar("Please fill all required fields.");
                  } else {
                    _editBooking(
                      id,
                      nameController.text,
                      phoneController.text,
                      emailController.text,
                      personsController.text,
                      bookingDate,
                      selectedTimeSlot,
                      voucherController.text,
                      type,
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  type == "add" ? "CREATE" : "UPDATE",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildBrutalistTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
      ),
    ),
  );
}
 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.grey[200],
        title: const Text(
          'BOOKINGS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton(
              onPressed: () => _showEditBookingDialog(context, {}, '', 'add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
              ),
              child: const Icon(Icons.add_box, color: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header with Date Picker
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Date: ${DateFormat('yyyy-MM-dd').format(selectedDate)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          selectedDate = pickedDate;
                        });
                        _fetchBookings(selectedDate, 'Singal');
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Bookings List
            isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : bookings.isEmpty
                    ? const Center(
                        child: Text(
                          'No bookings found.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: bookings.length,
                          itemBuilder: (context, index) {
                            final booking = bookings[index];

                            // Determine the color based on a specific key, e.g., booking status
                            Color cardColor;
                            if (booking['reservation_status'] == 'ARRIVED') {
                              cardColor = Colors.green[100]!;
                            } else if (booking['reservation_status'] == 'NOSHOW') {
                              cardColor = Colors.red[100]!;
                            } else if (booking['reservation_status'] == 'CANCELLED') {
                              cardColor = Colors.grey[300]!;
                            } else {
                              cardColor = Colors.white; // Default color
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: cardColor,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: Colors.black, width: 2),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      booking['reservation_name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Phone: ${booking['reservation_phone']}'),
                                    Text('Email: ${booking['reservation_email']}'),
                                    Text('Date: ${booking['reservation_date']} | Time: ${booking['reservation_time']}'),
                                    Text('Persons: ${booking['reservation_number']}'),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        ElevatedButton(
                                          onPressed: () => _sendEmail(booking['id']),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _getButtonColor(booking['reservation_status']),
                                          ),
                                          child: const Icon(Icons.mail, color: Colors.white),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => _sendSMS(booking['id']),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _getButtonColor(booking['reservation_status']),
                                          ),
                                          child: const Icon(Icons.sms, color: Colors.white),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => _showStatusBottomSheet(booking['id']),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _getButtonColor(booking['reservation_status']),
                                          ),
                                          child: const Icon(Icons.update, color: Colors.white),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => _showEditBookingDialog(context, booking, booking['id'], 'update'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: _getButtonColor(booking['reservation_status']),
                                          ),
                                          child: const Icon(Icons.edit, color: Colors.white),
                                        ),
                                      ],
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
      ),
    );
  }

  Color _getButtonColor(String status) {
    switch (status) {
      case 'ARRIVED':
        return Colors.green;
      case 'NOSHOW':
        return Colors.red;
      case 'CANCELLED':
        return Colors.orange;
      default:
        return Colors.black; // Default color
    }
  }
}

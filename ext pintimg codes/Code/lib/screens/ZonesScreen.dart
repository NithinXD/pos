import 'package:flutter/material.dart';
import 'package:flutterbill/screens/booking.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/database_service.dart';
import 'ReportScreen.dart';
import 'orders_Screen.dart';

class ZonesScreen extends StatefulWidget {
  @override
  _ZonesScreenState createState() => _ZonesScreenState();
}

class _ZonesScreenState extends State<ZonesScreen> {
  final List<Map<String, dynamic>> _zones = [];
  bool _isLoading = true;
  String? _shopId;

  final DatabaseService _databaseService = DatabaseService();

  @override
  void initState() {
    super.initState();
    _initializeShopIdAndFetchZones();
  }

  Future<void> _initializeShopIdAndFetchZones() async {
    _shopId = await _getShopId();
    if (_shopId != null) {
      _fetchZones();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shop ID not found in the database')),
      );
    }
  }

  Future<String?> _getShopId() async => await _databaseService.getShopId();

  Future<void> _fetchZones() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://www.takeawayordering.com/appserver/appserver.php?tag=deliveryzones&shop_id=$_shopId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == 1) {
          final deliveryZones = data['deliveryzones'] as Map<String, dynamic>;
          setState(() {
            _zones.clear();
            _zones.addAll(deliveryZones.values.map((zone) {
              return {
                'id': int.parse(zone['id']),
                'zone': zone['name'],
                'charge': double.parse(zone['deliverycharge']),
                'payable': double.parse(zone['deliverypayment']),
                'status': zone['zone_status'] != "0" ? 'Active' : 'Inactive',
                'justeatdeliverycharge':double.parse(zone['justeatdeliverycharge']),
              };
            }).toList());
          });
        }
      } else {
        throw Exception('Failed to fetch zones');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch zones: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onFooterItemTapped(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ReportScreen()),
        );
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
        Navigator.pushReplacement(
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
              employeePhone: "wingsbox",
              employeePin: "2go2hell",
            ),
          ),
        );
        break;
    }
  }

  Future<void> _changeZoneStatus(int zoneId, String currentStatus) async {
    final newStatus = currentStatus == 'Active' ? '0' : '1';
    final apiUrl =
        'https://www.takeawayordering.com/appserver/appserver.php?tag=updatezonestatus&employee_phone=wingsbox&employee_pin=2go2hell&shop_id=$_shopId&zone_id=$zoneId&zone_status=$newStatus';

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == 1) {
          setState(() {
            final index = _zones.indexWhere((zone) => zone['id'] == zoneId);
            if (index != -1) {
              _zones[index]['status'] = newStatus == '1' ? 'Active' : 'Inactive';
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status updated successfully')),
          );
        } else {
          throw Exception('Failed to change status');
        }
      } else {
        throw Exception('Failed to change status');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  void _editZone(Map<String, dynamic> zone) {
    final zoneController = TextEditingController(text: zone['zone']);
    final chargeController =
        TextEditingController(text: zone['charge'].toStringAsFixed(2));
    final payableController =
        TextEditingController(text: zone['payable'].toStringAsFixed(2));
    final justEatChargeController = TextEditingController(text: zone['justeatdeliverycharge'].toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Zone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: zoneController,
                decoration: const InputDecoration(labelText: 'Zone Name'),
              ),
              TextField(
                controller: chargeController,
                decoration: const InputDecoration(labelText: 'Delivery Charge'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: payableController,
                decoration: const InputDecoration(labelText: 'Payable'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: justEatChargeController,
                decoration:
                    const InputDecoration(labelText: 'Just Eat Delivery Charge'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_shopId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shop ID not available')),
                  );
                  return;
                }

                final deliveryCharge =
                    double.parse(chargeController.text).toStringAsFixed(2);
                final deliveryPayment =
                    double.parse(payableController.text).toStringAsFixed(2);
                final justEatCharge =
                    double.parse(justEatChargeController.text).toStringAsFixed(2);

                final apiUrl =
                    'https://www.takeawayordering.com/appserver/appserver.php?tag=editdeliveryzone&employee_phone=wingsbox&employee_pin=2go2hell&shop_id=$_shopId&delivery_zone_name=${zoneController.text}&delivery_charge=$deliveryCharge&delivery_payment=$deliveryPayment&jeat_delivery_charge=$justEatCharge&zone_id=${zone['id']}';

                try {
                  final response = await http.get(Uri.parse(apiUrl));
                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['success'] == 1) {
                      Navigator.pop(context);
                      _fetchZones(); // Refresh zones
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Zone updated successfully')),
                      );
                    } else {
                      throw Exception('Failed to update zone');
                    }
                  } else {
                    throw Exception('Failed to update zone');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _addZone() {
    final zoneController = TextEditingController();
    final chargeController = TextEditingController();
    final payableController = TextEditingController();
    final justEatChargeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Zone'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: zoneController,
                decoration: const InputDecoration(labelText: 'Zone Name'),
              ),
              TextField(
                controller: chargeController,
                decoration: const InputDecoration(labelText: 'Delivery Charge'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: payableController,
                decoration: const InputDecoration(labelText: 'Payable'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: justEatChargeController,
                decoration:
                    const InputDecoration(labelText: 'Just Eat Delivery Charge'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_shopId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Shop ID not available')),
                  );
                  return;
                }

                final deliveryCharge =
                    double.parse(chargeController.text).toStringAsFixed(2);
                final deliveryPayment =
                    double.parse(payableController.text).toStringAsFixed(2);
                final justEatCharge =
                    double.parse(justEatChargeController.text).toStringAsFixed(2);

                final apiUrl =
                    'https://www.takeawayordering.com/appserver/appserver.php?tag=createdeliveryzone&employee_phone=wingsbox&employee_pin=2go2hell&shop_id=$_shopId&delivery_zone_name=${zoneController.text}&delivery_charge=$deliveryCharge&delivery_payment=$deliveryPayment&jeat_delivery_charge=$justEatCharge';

                try {
                  final response = await http.get(Uri.parse(apiUrl));
                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['success'] == 1) {
                      Navigator.pop(context);
                      _fetchZones();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Zone added successfully')),
                      );
                    } else {
                      throw Exception('Failed to add zone');
                    }
                  } else {
                    throw Exception('Failed to add zone');
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zones'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _zones.length,
              itemBuilder: (context, index) {
                final zone = _zones[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${zone['zone']}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _editZone(zone),
                              child: const Text('Edit'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                'Delivery Charge: €${zone['charge'].toStringAsFixed(2)}'),
                            Text('Payable: €${zone['payable'].toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Status: ${zone['status']}'),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: zone['status'] == 'Active'
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              onPressed: () =>
                                  _changeZoneStatus(zone['id'], zone['status']),
                              child: Text(
                                zone['status'] == 'Active'
                                    ? 'Deactivate'
                                    : 'Activate',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addZone(),
        child: const Icon(Icons.add),
        tooltip: 'Add Delivery Zone',
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
        currentIndex: 2, // Set 'Zones' as the selected item
        onTap: _onFooterItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
    );
  }
}

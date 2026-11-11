import 'package:flutter/material.dart';
import '../services/database_service.dart';

class ShopIdScreen extends StatefulWidget {
  const ShopIdScreen({Key? key}) : super(key: key);

  @override
  State<ShopIdScreen> createState() => _ShopIdScreenState();
}

class _ShopIdScreenState extends State<ShopIdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _appIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController(); // Renamed for clarity
  final _databaseService = DatabaseService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkExistingCredentials();
  }

  Future<void> _checkExistingCredentials() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final appId = await _databaseService.getShopId();
      final username = await _databaseService.getEmployeePhone(); // Corrected
      final password = await _databaseService.getEmployeePin(); // Corrected

      if (!mounted) return;

      if (appId != null && appId.isNotEmpty && 
          username != null && password != null) {
        final args = <String, dynamic>{
          'shopId': appId,
          'employeePhone': username, // Corrected
          'employeePin': password, // Corrected
        };
        Navigator.pushReplacementNamed(context, '/orders', arguments: args);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking credentials: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveCredentials() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() {
        _isLoading = true;
      });

      await _databaseService.saveShopId(_appIdController.text);
      await _databaseService.saveEmployeePhone(_usernameController.text); // Corrected
      await _databaseService.saveEmployeePin(_passwordController.text); // Corrected

      if (!mounted) return;
      final args = <String, dynamic>{
        'shopId': _appIdController.text,
        'employeePhone': _usernameController.text, // Corrected
        'employeePin': _passwordController.text, // Corrected
      };
      Navigator.pushReplacementNamed(context, '/orders', arguments: args);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving credentials: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Credentials'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextFormField(
                      controller: _appIdController,
                      decoration: const InputDecoration(
                        labelText: 'App ID',
                        border: OutlineInputBorder(),
                        hintText: 'Enter your App ID',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter an App ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                        hintText: 'Enter your Username',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a Username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        hintText: 'Enter your Password',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your Password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveCredentials,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

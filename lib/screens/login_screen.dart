import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/custom_modals.dart';
import '../widgets/barcode_scanner_widget.dart';
import 'home_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _noMejaController = TextEditingController();
  String? _selectedGroup;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Lock orientation to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _noMejaController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final result = await _authService.login(
          _usernameController.text,
          _passwordController.text,
          _noMejaController.text,
        );

        if (result['success']) {
          // Show success message and navigate to home screen
          if (mounted) {
            await CustomModals.showSuccessModal(
              context: context,
              message: 'Login berhasil!',
              onPressed: () {
                Navigator.pop(context); // Close modal
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
            );
          }
        } else {
          if (mounted) {
            await CustomModals.showFailedModal(
              context: context,
              message: result['message'] ?? 'Login gagal',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          await CustomModals.showFailedModal(
            context: context,
            message: 'Error: $e',
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryGreen,
              AppColors.primaryBlue,
            ],
          ),
        ),
        child: Row(
          children: [
            // Left curved white part (approximately 25% of width)
            Expanded(
              flex: 3,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(300),
                    bottomRight: Radius.circular(300),
                  ),
                ),
              ),
            ),
            
            // Center part for logo and form (approximately 50% of width)
            Expanded(
              flex: 6,
              child: Container(
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo and form section
                    Container(
                      width: size.width * 0.5,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/logo.png',
                                width: 80,
                                height: 80,
                              ),
                              const SizedBox(width: 10),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CRF',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                  Text(
                                    'Cash Replenish Form',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: AppColors.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Login text
                          const Text(
                            'Login Yout Account',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Form
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Username/ID/Email/HP
                                const Text(
                                  'User ID/Email/No.Hp',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: _usernameController,
                                  enabled: true, // FORCE: Always enabled
                                  readOnly: false, // FORCE: Not read-only
                                  enableInteractiveSelection: true, // FORCE: Always enable
                                  enableSuggestions: kIsWeb, // Enable on web
                                  decoration: InputDecoration(
                                    hintText: 'Enter your User ID, Email or Phone Number',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                    suffixIcon: const Icon(Icons.person),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your username';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 15),
                                
                                // Password
                                const Text(
                                  'Password',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: _passwordController,
                                  enabled: true, // FORCE: Always enabled
                                  readOnly: false, // FORCE: Not read-only
                                  enableInteractiveSelection: true, // FORCE: Always enable
                                  enableSuggestions: kIsWeb, // Enable on web
                                  obscureText: !_isPasswordVisible,
                                  decoration: InputDecoration(
                                    hintText: 'Enter your password',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible = !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 15),
                                
                                // No. Meja
                                const Text(
                                  'No. Meja',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                TextFormField(
                                  controller: _noMejaController,
                                  enabled: true, // FORCE: Always enabled
                                  readOnly: false, // FORCE: Not read-only
                                  enableInteractiveSelection: true, // FORCE: Always enable
                                  enableSuggestions: kIsWeb, // Enable on web
                                  decoration: InputDecoration(
                                    hintText: 'Enter table number',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                    suffixIcon: GestureDetector(
                                      onTap: _openTableNumberScanner,
                                      child: const Icon(Icons.qr_code_scanner),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter table number';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 15),
                                
                                // Group dropdown
                                const Text(
                                  'Group',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                DropdownButtonFormField<String>(
                                  value: _selectedGroup,
                                  decoration: InputDecoration(
                                    hintText: 'Select group',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'Admin',
                                      child: Text('Admin'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'User',
                                      child: Text('User'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'Supervisor',
                                      child: Text('Supervisor'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGroup = value;
                                    });
                                  },
                                ),
                                
                                const SizedBox(height: 30),
                                
                                // Login button
                                Center(
                                  child: SizedBox(
                                    width: 200,
                                    height: 50,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _login,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const CircularProgressIndicator(color: Colors.white)
                                          : const Text(
                                              'Login',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Android ID text at bottom
                    const Text(
                      'Android ID : 1234Uas61234',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Right white space (approximately 25% of width)
            const Expanded(
              flex: 3,
              child: SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  // Open barcode scanner for table number input
  Future<void> _openTableNumberScanner() async {
    try {
      print('Opening barcode scanner for table number');
      
      // Navigate to barcode scanner
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => BarcodeScannerWidget(
            title: 'Scan No. Meja',
            onBarcodeDetected: (String barcode) {
              print('Table number barcode detected: $barcode');
              
              // Fill the field with scanned barcode
              setState(() {
                _noMejaController.text = barcode;
              });
            },
          ),
        ),
      );
      
      // Handle result after scanner closes
      if (result != null && result.isNotEmpty) {
        // Show success message after scanner is closed
        CustomModals.showSuccessModal(
          context: context,
          message: 'No. Meja berhasil diisi: $result',
        );
      }
    } catch (e) {
      print('Error opening barcode scanner: $e');
      CustomModals.showFailedModal(
        context: context,
        message: 'Gagal membuka scanner: ${e.toString()}',
      );
    }
  }
}
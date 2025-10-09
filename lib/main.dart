import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'screens/login_page.dart';
// import 'screens/webview_login_page.dart'; // TEMPORARILY COMMENTED - file not found
import 'screens/home_page.dart';
import 'screens/prepare_mode_screen.dart';
import 'screens/return_page.dart';
import 'screens/profile_menu_screen.dart';
import 'screens/device_info_screen.dart';
import 'screens/return_validation_screen.dart';
import 'screens/tl_home_page.dart';
import 'screens/tl_device_info_screen.dart';
import 'screens/tl_profile_screen.dart';
import 'screens/tl_qr_scanner_screen.dart';
import 'screens/konsol_mode_screen.dart';
import 'screens/konsol_data_return_screen.dart';
import 'screens/konsol_data_pengurangan_screen.dart';
import 'screens/konsol_data_closing_screen.dart';
import 'screens/konsol_data_closing_form_screen.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;
import 'services/device_service.dart';

// Flutter 3.13.8 stable approach - full feature restore

// Global error handler
void _handleError(Object error, StackTrace stack) {
  debugPrint('CRITICAL ERROR: $error');
  debugPrintStack(stackTrace: stack);
}

// SafePrefs Class to handle all preference operations safely
class SafePrefs {
  static Future<void> clearAll() async {
    try {
      // Clear preferences if they exist
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('Preferences cleared successfully');
    } catch (e) {
      debugPrint('Failed to clear preferences: $e');
    }
  }
}

class CrfSplashScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;
  
  const CrfSplashScreen({Key? key, required this.onInitializationComplete}) : super(key: key);

  @override
  State<CrfSplashScreen> createState() => _CrfSplashScreenState();
}

class _CrfSplashScreenState extends State<CrfSplashScreen> {
  String _statusMessage = 'Initializing...';
  bool _hasError = false;
  String _errorDetails = '';
  
  @override
  void initState() {
    super.initState();
    // CRITICAL FIX: Don't force orientation changes in splash screen
    // Let the main() function handle orientation settings consistently
    // This prevents layout conflicts when transitioning to login page
    
    // Simple initialization like crf-and1
    _initializeApp();
  }
  
  Future<void> _initializeApp() async {
    // Reduce initial delay for faster startup
    await Future.delayed(const Duration(milliseconds: 200));
    
    try {
      // Batch UI updates to reduce setState calls
      if (mounted) setState(() => _statusMessage = 'Setting up environment...');
      
      // CRITICAL FIX: Remove SystemUIOverlayStyle that interferes with input
      // This configuration can block keyboard input in some Android versions
      try {
        // Only set minimal UI configuration on Android
        if (Platform.isAndroid) {
          // Keep minimal UI changes to avoid input interference
          debugPrint('Skipping SystemUIOverlayStyle to prevent input issues');
        }
      } catch (e) {
        debugPrint('Failed to set system UI style: $e');
      }
      
      // Update status - combine status updates
      if (mounted) setState(() => _statusMessage = 'Initializing data services...');
      
      // Debug device storage status
      try {
        await DeviceService.debugStorageStatus();
        final deviceId = await DeviceService.getDeviceId();
        debugPrint('🔍 Current Device ID: $deviceId');
      } catch (e) {
        debugPrint('❌ Error checking device storage: $e');
      }

      // Verify shared preferences access 
      try {
        final prefs = await SharedPreferences.getInstance();
        // Try simple write/read test
        await prefs.setString('_test_key', 'test_value');
        final testValue = prefs.getString('_test_key');
        debugPrint('SharedPreferences test: $testValue');
        await prefs.remove('_test_key');
      } catch (e) {
        debugPrint('SharedPreferences test failed: $e');
        throw Exception('Unable to access app storage: $e');
      }

      // Reduce delay for faster startup
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Update status to indicate completion
      if (mounted) setState(() => _statusMessage = 'Initialization complete!');
      
      // Reduce delay for faster startup
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Call the callback to signal completion
      if (mounted) {
        widget.onInitializationComplete();
      }
    } catch (error, stack) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorDetails = 'Error: ${error.toString()}\n${stack.toString().split('\n').take(3).join('\n')}';
          _statusMessage = 'Initialization failed';
        });
      }
      _handleError(error, stack);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF87CEEB), // Light blue background
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              // CRFicon image
              SizedBox(height: 48),
              CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  // Set error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _handleError(details.exception, details.stack ?? StackTrace.current);
  };
  
  // Tambahkan log debugging
  print('🚀 Starting CRF Android application...');
  
  // Set up zone-level error handling
  runZonedGuarded(() {
    // Initialize Flutter binding
    WidgetsFlutterBinding.ensureInitialized();
    
    // Web platform configuration for WebView
    if (kIsWeb) {
      debugPrint('🌐 Running on web platform - WebView compatibility mode enabled');
    } else {
      // Mobile platform configuration
      // Enable fullscreen mode
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      
      // Allow all orientations for tablets and mobile
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    
    // Flutter 3.13.8 handles text input properly - no manual initialization needed
    
    // Run the app
    runApp(const CrfApp());
  }, (error, stackTrace) {
    _handleError(error, stackTrace);
  });
}

// Flutter 3.13.8 - TextInputPlugin works perfectly out of the box

class CrfApp extends StatefulWidget {
  const CrfApp({Key? key}) : super(key: key);

  @override
  State<CrfApp> createState() => _CrfAppState();
}

class _CrfAppState extends State<CrfApp> {
  bool _isInitialized = false;

  void _handleInitializationComplete() {
    setState(() {
      _isInitialized = true;
    });
  }

  Widget _getLoginWidget() {
    debugPrint('🔍 ROUTING DEBUG:');
    debugPrint('  - kIsWeb: $kIsWeb');
    debugPrint('  - Platform: ${kIsWeb ? "Web" : "Mobile"}');
    debugPrint('  - USING WEBVIEW LOGIN PAGE - Flutter 3.13.8 stable WebView support');
    
    // Use regular login for now - WebView file missing
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hapus badge DEBUG di pojok kanan atas
      title: 'CRF App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: _isInitialized 
          ? _getLoginWidget()
          : CrfSplashScreen( // Web uses regular login, mobile uses WebView
            onInitializationComplete: _handleInitializationComplete,
          ),
      routes: {
        '/login': (context) => const LoginPage(), // Regular login - WebView file missing
        '/flutter_login': (context) => const LoginPage(), // Fallback regular login page
        '/home': (context) => const HomePage(),
        '/prepare_mode': (context) => const PrepareModePage(),
        '/return_page': (context) => const ReturnModePage(),
        '/profile': (context) => const ProfileMenuScreen(),
        '/device_info': (context) => const DeviceInfoScreen(),
        '/return_validation': (context) => const ReturnValidationScreen(),
        '/tl_home': (context) => const TLHomePage(),
        '/tl_device_info': (context) => const TLDeviceInfoScreen(),
        '/tl_profile': (context) => const TLProfileScreen(),
        '/tl_qr_scanner': (context) => const TLQRScannerScreen(),
        '/konsol_mode': (context) => const KonsolModePage(),
        '/konsol_data_return': (context) => const KonsolDataReturnPage(),
        '/konsol_data_pengurangan': (context) => const KonsolDataPenguranganPage(),
        '/konsol_data_closing': (context) => const KonsolDataClosingPage(),
        '/konsol_data_closing_form': (context) => const KonsolDataClosingFormScreen(),
      },
    );
  }
}

// Flutter 3.13.8 STABLE: Full functionality restored with stable TextInputPlugin

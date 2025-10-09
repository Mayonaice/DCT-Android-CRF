import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'home_page.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../widgets/custom_modals.dart';
import '../widgets/barcode_scanner_widget.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _noMejaController = TextEditingController();
  
  // Simple focus nodes for navigation
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _noMejaFocusNode = FocusNode();
  
  String? _selectedBranch;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isLoadingBranches = false;
  String? _passwordError; // For manual validation to avoid TextFormField crash
  List<Map<String, dynamic>> _availableBranches = [];
  String _androidId = 'Loading...';
  
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    
    // Debug logging untuk web
    debugPrint('🎯 LOGIN_PAGE.DART INITIATED');
    debugPrint('  - kIsWeb: $kIsWeb');
    debugPrint('  - This should be the CORRECT login page for web');

    // Keep placeholder minimal; real 16-hex will be loaded by _loadAndroidId()
    // Removed 'Device-xxxxxxxx' to avoid wrong format leaking to UI

    // CRITICAL FIX: Remove SystemChrome calls that cause crashes on SDK 34
    // SystemChrome.setSystemUIOverlayStyle interferes with keyboard input
    
    // EMERGENCY INPUT STABILITY MODE
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emergencyInputStabilityMode();
    });

    // Simple setup - let Flutter handle input naturally
    // Add focus listeners for all fields (similar to ID CRF in prepare_mode)
    _usernameFocusNode.addListener(_onFocusChanged);
    _passwordFocusNode.addListener(_onFocusChanged);
    _noMejaFocusNode.addListener(_onFocusChanged);
    
    // Add listeners to clear branches when any field changes
    _usernameController.addListener(_clearBranchesOnFieldChange);
    _passwordController.addListener(_clearBranchesOnFieldChange);

    _checkLoginStatus();
    _loadAndroidId();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await _authService.isLoggedIn();
    if (isLoggedIn && mounted) {
      final userData = await _authService.getUserData();
      String userRole = '';
      if (userData != null) {
        userRole = (userData['roleID'] ?? userData['RoleID'] ?? userData['role'] ?? userData['Role'] ?? userData['userRole'] ?? userData['UserRole'] ?? userData['position'] ?? userData['Position'] ?? '').toString().toUpperCase();
      }

      if (userRole == 'CRF_TL') {
        Navigator.of(context).pushReplacementNamed('/tl_home');
      } else {
        // Keep landscape as per manifest
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    }
  }

  Future<void> _loadAndroidId() async {
    try {
      // Allow a bit more time to resolve stored/shared preferences
      final deviceId = await DeviceService.getDeviceId().timeout(const Duration(seconds: 5), onTimeout: () {
        // Safe fallback: 16-hex derived from timestamp hash (not prefixed)
        final ts = DateTime.now().millisecondsSinceEpoch.toString();
        // Simple hex from ascii bytes then trim to 16
        final hex = ts.codeUnits.map((e) => e.toRadixString(16)).join();
        return hex.substring(0, 16);
      });
      if (mounted) {
        setState(() {
          _androidId = deviceId;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    // Remove focus listeners first
    _usernameFocusNode.removeListener(_onFocusChanged);
    _passwordFocusNode.removeListener(_onFocusChanged);
    _noMejaFocusNode.removeListener(_onFocusChanged);
    
    // Remove controller listeners
    _usernameController.removeListener(_clearBranchesOnFieldChange);
    _passwordController.removeListener(_clearBranchesOnFieldChange);
    
    // Dispose controllers
    _usernameController.dispose();
    _passwordController.dispose();
    _noMejaController.dispose();
    
    // Dispose focus nodes (only once)
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _noMejaFocusNode.dispose();
    
    super.dispose();
  }

  bool _isModalShowing = false;
  bool _inputChangedAfterModal = false;

  // Function removed - now using focus listener approach like prepare_mode
  
  void _clearBranchesOnFieldChange() {
    if ((_availableBranches.isNotEmpty || _selectedBranch != null) && mounted) {
      setState(() {
        _availableBranches.clear();
        _selectedBranch = null;
      });
    }
  }
  
  void _onFocusChanged() {
    print('DEBUG: Focus changed - Username: ${_usernameFocusNode.hasFocus}, Password: ${_passwordFocusNode.hasFocus}, NoMeja: ${_noMejaFocusNode.hasFocus}');
    
    // Add small delay to ensure focus state is stable
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      
      // Check if no field is currently focused (user moved away from all fields)
      bool noFieldFocused = !_usernameFocusNode.hasFocus && 
                           !_passwordFocusNode.hasFocus && 
                           !_noMejaFocusNode.hasFocus;
      
      print('DEBUG: noFieldFocused: $noFieldFocused (after delay)');
      
      if (noFieldFocused) {
        // Check if all three fields are filled
        bool allFieldsFilled = _usernameController.text.trim().isNotEmpty &&
            _passwordController.text.trim().isNotEmpty &&
            _noMejaController.text.trim().isNotEmpty;
        
        print('DEBUG: Field values - Username: "${_usernameController.text.trim()}", Password: "${_passwordController.text.trim()}", NoMeja: "${_noMejaController.text.trim()}"');
        print('DEBUG: allFieldsFilled: $allFieldsFilled, _isLoadingBranches: $_isLoadingBranches, _isModalShowing: $_isModalShowing');
        
        if (allFieldsFilled && !_isLoadingBranches && !_isModalShowing) {
          // Clear existing branches when triggering new fetch
          if ((_availableBranches.isNotEmpty || _selectedBranch != null) && mounted) {
            setState(() {
              _availableBranches.clear();
              _selectedBranch = null;
            });
          }
          print('DEBUG: ✅ ALL CONDITIONS MET - Triggering _fetchBranches() from FocusNode');
          if (mounted) {
            _fetchBranches();
          }
        } else {
          print('DEBUG: ❌ CONDITIONS NOT MET - API not triggered');
        }
      }
    });
  }

  Future<void> _fetchBranches() async {
    if (_isLoadingBranches || _isModalShowing) return;

    setState(() {
      _isLoadingBranches = true;
    });

    try {
      final result = await _authService.getUserBranches(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
        _noMejaController.text.trim(),
      );

      if (result['success'] && result['data'] != null) {
        final branches = result['data'] as List<dynamic>;

        setState(() {
          _availableBranches = branches.map((branch) => {
            'branchName': branch['branchName'] ?? branch['BranchName'] ?? '',
            'roleID': branch['roleID'] ?? branch['RoleID'] ?? '',
            'displayText': '${branch['branchName'] ?? branch['BranchName'] ?? ''} (${branch['roleID'] ?? branch['RoleID'] ?? ''})',
          }).toList();

          if (_availableBranches.length == 1) {
            _selectedBranch = _availableBranches.first['displayText'];
          }
        });
      } else {
        setState(() {
          _availableBranches.clear();
          _selectedBranch = null;
        });

        if (_usernameController.text.isNotEmpty &&
            _passwordController.text.isNotEmpty &&
            _noMejaController.text.isNotEmpty) {
          _isModalShowing = true;
          await CustomModals.showFailedModal(
            context: context,
            message: result['message'] ?? 'Tidak dapat menemukan cabang untuk user ini. Periksa kembali username, password, dan nomor meja.',
            onPressed: () {
              Navigator.of(context).pop();
              _isModalShowing = false;
              _inputChangedAfterModal = false;
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_inputChangedAfterModal &&
                    _usernameController.text.isNotEmpty &&
                    _passwordController.text.isNotEmpty &&
                    _noMejaController.text.isNotEmpty) {
                  _fetchBranches();
                }
              });
            },
          );
        }
      }
    } catch (_) {
      setState(() {
        _availableBranches.clear();
        _selectedBranch = null;
      });

      if (_usernameController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty &&
          _noMejaController.text.isNotEmpty) {
        _isModalShowing = true;
        await CustomModals.showFailedModal(
          context: context,
          message: 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
          buttonText: 'Coba Lagi',
          onPressed: () {
            Navigator.of(context).pop();
            _isModalShowing = false;
            _inputChangedAfterModal = false;
            _fetchBranches();
          },
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBranches = false;
        });
      }
    }
  }

  // FINAL EMERGENCY: Simple input stability mode
  void _emergencyInputStabilityMode() async {
    debugPrint('🚨 FINAL EMERGENCY INPUT STABILITY MODE');
    
    try {
      // Multiple focus clearing attempts
      for (int i = 0; i < 3; i++) {
        FocusManager.instance.primaryFocus?.unfocus();
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Clear focus scope if mounted
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
      
      debugPrint('🚨 Final emergency mode completed');
    } catch (e) {
      debugPrint('🚨 Emergency stability error: $e');
    }
  }

  void _ensureInputStability() {
    // LEGACY: Previous fix attempt
    try {
      // Clear any lingering focus issues
      FocusManager.instance.primaryFocus?.unfocus();
      
      // Re-enable input after a brief delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          // Ensure text input is ready
          debugPrint('🔧 Input stability ensured for SDK 34');
        }
      });
    } catch (e) {
      debugPrint('⚠️ Input stability setup failed: $e');
    }
  }

  // Custom validation function that checks fields from top to bottom
  Future<bool> _validateLoginForm() async {
    // Check username first (top field)
    if (_usernameController.text.trim().isEmpty) {
      await CustomModals.showFailedModal(
        context: context,
        message: 'Please enter your username',
      );
      return false;
    }
    
    // Check password second
    if (_passwordController.text.trim().isEmpty) {
      await CustomModals.showFailedModal(
        context: context,
        message: 'Please enter your password',
      );
      return false;
    }
    
    // Check table number third
    if (_noMejaController.text.trim().isEmpty) {
      await CustomModals.showFailedModal(
        context: context,
        message: 'Please enter table number',
      );
      return false;
    }
    
    return true;
  }

  Future<void> _performLogin() async {
    if (_isModalShowing) return;
    
    // Use custom validation instead of form validation
    if (!await _validateLoginForm()) return;

    if (_availableBranches.isEmpty) {
      _isModalShowing = true;
      await CustomModals.showFailedModal(
        context: context,
        message: 'Pastikan semua field sudah benar. Tidak ada cabang CRF yang tersedia untuk user ini.',
        onPressed: () {
          Navigator.of(context).pop();
          _isModalShowing = false;
          _inputChangedAfterModal = false;
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_inputChangedAfterModal &&
                _usernameController.text.isNotEmpty &&
                _passwordController.text.isNotEmpty &&
                _noMejaController.text.isNotEmpty) {
              _fetchBranches();
            }
          });
        },
      );
      return;
    }

    if (_selectedBranch == null && _availableBranches.length > 1) {
      _isModalShowing = true;
      await CustomModals.showFailedModal(
        context: context,
        message: 'Silahkan pilih cabang untuk melanjutkan login.',
        onPressed: () {
          Navigator.of(context).pop();
          _isModalShowing = false;
          _inputChangedAfterModal = false;
        },
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? branchName;
      if (_selectedBranch != null) {
        final selectedBranchData = _availableBranches.firstWhere(
          (branch) => branch['displayText'] == _selectedBranch,
          orElse: () => _availableBranches.first,
        );
        branchName = selectedBranchData['branchName'];
      }

      // Enhanced logging for web debugging
      debugPrint('🌐 WEB LOGIN ATTEMPT:');
      debugPrint('  - Username: ${_usernameController.text.trim()}');
      debugPrint('  - NoMeja: ${_noMejaController.text.trim()}');
      debugPrint('  - Selected Branch: $branchName');
      debugPrint('  - Available Branches: ${_availableBranches.length}');
      
      final result = await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
        _noMejaController.text.trim(),
        selectedBranch: branchName,
      );
      
      debugPrint('🌐 WEB LOGIN RESULT:');
      debugPrint('  - Success: ${result['success']}');
      debugPrint('  - Message: ${result['message']}');
      debugPrint('  - Error Type: ${result['errorType']}');
      debugPrint('  - Full Result: $result');

      final token = await _authService.getToken();
      debugPrint('Token after login: ${token != null ? "Found (${token.length} chars)" : "NULL"}');

      if (result['success']) {
        try { HapticFeedback.mediumImpact(); } catch (_) {}
        _isModalShowing = true;
        await CustomModals.showSuccessModal(
          context: context,
          message: 'Selamat datang di aplikasi CRF',
          buttonText: 'Lanjutkan',
          onPressed: () async {
            Navigator.pop(context);
            _isModalShowing = false;
            _inputChangedAfterModal = false;
            if (mounted) {
              final userData = await _authService.getUserData();
              String userRole = '';
              if (userData != null) {
                userRole = (userData['roleID'] ?? userData['RoleID'] ?? userData['role'] ?? userData['Role'] ?? userData['userRole'] ?? userData['UserRole'] ?? userData['position'] ?? userData['Position'] ?? '').toString().toUpperCase();
              }
              if (userRole == 'CRF_TL') {
                Navigator.of(context).pushReplacementNamed('/tl_home');
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              }
            }
          },
        );
      } else {
        _isModalShowing = true;
        if (result['errorType'] == 'ANDROID_ID_ERROR') {
          await CustomModals.showFailedModal(
            context: context,
            message: result['message'] ?? 'AndroidID belum terdaftar, silahkan hubungi tim COMSEC',
            onPressed: () {
              Navigator.of(context).pop();
              _isModalShowing = false;
              _inputChangedAfterModal = false;
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_inputChangedAfterModal &&
                    _usernameController.text.isNotEmpty &&
                    _passwordController.text.isNotEmpty &&
                    _noMejaController.text.isNotEmpty) {
                  _fetchBranches();
                }
              });
            },
          );
        } else if (result['message']?.toString().contains('Connection error') == true ||
                   result['message']?.toString().contains('Timeout') == true) {
          await CustomModals.showFailedModal(
            context: context,
            message: result['message'] ?? 'Koneksi ke server bermasalah',
            buttonText: 'Coba Lagi',
            onPressed: () {
              Navigator.of(context).pop();
              _isModalShowing = false;
              _inputChangedAfterModal = false;
              _performLogin();
            },
          );
        } else {
          await CustomModals.showFailedModal(
            context: context,
            message: result['message'] ?? 'Username atau password tidak valid',
            onPressed: () {
              Navigator.of(context).pop();
              _isModalShowing = false;
              _inputChangedAfterModal = false;
              Future.delayed(const Duration(milliseconds: 300), () {
                if (_inputChangedAfterModal &&
                    _usernameController.text.isNotEmpty &&
                    _passwordController.text.isNotEmpty &&
                    _noMejaController.text.isNotEmpty) {
                  _fetchBranches();
                }
              });
            },
          );
        }
      }
    } catch (_) {
      _isModalShowing = true;
      await CustomModals.showFailedModal(
        context: context,
        message: 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.',
        buttonText: 'Coba Lagi',
        onPressed: () {
          Navigator.of(context).pop();
          _isModalShowing = false;
          _inputChangedAfterModal = false;
          _performLogin();
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0056A4),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final screenHeight = MediaQuery.of(context).size.height;
            final screenWidth = MediaQuery.of(context).size.width;
            final isLandscape = orientation == Orientation.landscape;
            final isTablet = screenWidth > 600;
            
            return SingleChildScrollView(
              child: Container(
                constraints: BoxConstraints(minHeight: screenHeight),
                width: screenWidth,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/bg-login.png'),
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
                child: isLandscape ? _buildLandscapeLayout(screenWidth, screenHeight, isTablet) : _buildPortraitLayout(screenWidth, screenHeight, isTablet),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(double screenWidth, double screenHeight, bool isTablet) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: isTablet ? screenWidth * 0.5 : screenWidth * 0.85,
          margin: EdgeInsets.only(top: screenHeight * 0.15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: _buildLoginForm(),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 20),
          child: Text(
            'CRF Android App v1.0',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 20, bottom: 20),
          child: Text(
            'Login Yout Account',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0056A4),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                                focusNode: _usernameFocusNode,
                                enabled: true, // FORCE: Always enabled
                                readOnly: false, // FORCE: Not read-only
                                autofillHints: kIsWeb ? null : null, // Keep null for both web and mobile 
                                enableSuggestions: kIsWeb, // Enable suggestions on web for better UX
                                autocorrect: false, // Keep disabled for both
                                enableInteractiveSelection: true, // FORCE: Always enable for all platforms
                                decoration: InputDecoration(
                                  hintText: 'Enter your User ID, Email or Phone Number',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,  // ✅ CRITICAL: Explicit white like crf-and1
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                  suffixIcon: const Icon(Icons.person),
                                ),
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                onEditingComplete: () => _passwordFocusNode.requestFocus(),
                                validator: (value) {
                                  // Remove built-in validation, use custom validation instead
                                  return null;
                                },
                              ),
                              const SizedBox(height: 15),
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
                                focusNode: _passwordFocusNode,
                                enabled: true, // FORCE: Always enabled
                                readOnly: false, // FORCE: Not read-only
                                autofillHints: kIsWeb ? null : null, // Keep null for both web and mobile
                                enableSuggestions: kIsWeb, // Enable suggestions on web for better UX 
                                autocorrect: false, // Keep disabled for both
                                enableInteractiveSelection: true, // FORCE: Always enable for all platforms
                                obscureText: !_isPasswordVisible,
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,  // ✅ CRITICAL: Explicit white like crf-and1
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    ),
                                    onPressed: () {
                                      // CRITICAL FIX: Clear focus first to prevent GitHub Issue #33642 crash
                                      FocusScope.of(context).unfocus();
                                      Future.delayed(const Duration(milliseconds: 50), () {
                                        if (mounted) {
                                          setState(() {
                                            _isPasswordVisible = !_isPasswordVisible;
                                          });
                                          // Add haptic feedback like crf-and1
                                          HapticFeedback.lightImpact();
                                        }
                                      });
                                    },
                                  ),
                                ),
                                keyboardType: TextInputType.visiblePassword,
                                textInputAction: TextInputAction.next,
                                onEditingComplete: () => _noMejaFocusNode.requestFocus(),
                                validator: (value) {
                                  // Remove built-in validation, use custom validation instead
                                  return null;
                                },
                              ),
                              const SizedBox(height: 15),
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
                                focusNode: _noMejaFocusNode,
                                enabled: true, // FORCE: Always enabled
                                readOnly: false, // FORCE: Not read-only
                                autofillHints: kIsWeb ? null : null, // Keep null for both web and mobile
                                enableSuggestions: kIsWeb, // Enable suggestions on web for better UX
                                autocorrect: false, // Keep disabled for both  
                                enableInteractiveSelection: true, // FORCE: Always enable for all platforms
                                decoration: InputDecoration(
                                  hintText: 'Enter table number',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,  // ✅ CRITICAL: Explicit white like crf-and1
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                  suffixIcon: GestureDetector(
                                    onTap: _openTableNumberScanner,
                                    child: const Icon(Icons.qr_code_scanner),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                onEditingComplete: () => FocusScope.of(context).unfocus(),
                                validator: (value) {
                                  // Remove built-in validation, use custom validation instead
                                  return null;
                                },
                              ),
                              const SizedBox(height: 15),
                              const Text(
                                'Group',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              DropdownButtonFormField<String>(
                                value: _selectedBranch,
                                decoration: InputDecoration(
                                  hintText: _isLoadingBranches
                                      ? 'Loading branches...'
                                      : _availableBranches.isEmpty
                                          ? 'Fill all fields above to load branches'
                                          : 'Select branch & role',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  filled: true,
                                  fillColor: _availableBranches.isEmpty ? Colors.grey.shade100 : Colors.white,  // ✅ Like crf-and1
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                                  suffixIcon: _isLoadingBranches 
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Icon(
                                          _availableBranches.isNotEmpty ? Icons.business : Icons.info_outline,
                                          color: _availableBranches.isNotEmpty ? null : Colors.grey,
                                        ),
                                ),
                                items: _availableBranches.map((branch) {
                                  try {
                                    return DropdownMenuItem<String>(
                                      value: branch['displayText'] as String,
                                      child: Text((branch['displayText'] as String?) ?? ''),
                                    );
                                  } catch (_) {
                                    return const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('Error'),
                                    );
                                  }
                                }).toList(),
                                onChanged: _availableBranches.isEmpty ? null : (String? value) {
                                  setState(() {
                                    _selectedBranch = value;
                                  });
                                  // Add haptic feedback like crf-and1
                                  HapticFeedback.selectionClick();
                                },
                                validator: (value) {
                                  if (_availableBranches.isEmpty) {
                                    return 'No branches available. Check your credentials.';
                                  }
                                  if (_availableBranches.length > 1 && value == null) {
                                    return 'Please select a branch';
                                  }
                                  return null;
                                },
                              ),
                              Container(
                                width: double.infinity,
                                height: 50,
                                margin: const EdgeInsets.symmetric(vertical: 30),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _performLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2196F3),  // Like crf-and1
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 3,  // Like crf-and1
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Text(
                      'IMEI = $_androidId',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(double screenWidth, double screenHeight, bool isTablet) {
    // For mobile landscape, use single column layout to avoid cramped space
    if (!isTablet && screenHeight < 500) {
      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.1,
            vertical: 20,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Compact header for mobile landscape
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business,
                    size: 40,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  const SizedBox(width: 15),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CRF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Android App v1.0',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Login form
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxWidth: screenWidth * 0.8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _buildCompactLoginForm(),
              ),
            ],
          ),
        ),
      );
    }
    
    // For tablet landscape, use centered layout without branding
    return Container(
      width: screenWidth,
      height: screenHeight,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.1,
              vertical: screenHeight * 0.05,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Add some top spacing to push form down slightly
                SizedBox(height: screenHeight * 0.08),
                // Login form container
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxWidth: screenWidth * 0.5, // Reasonable width for landscape
                    minWidth: 400,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _buildLoginForm(),
                ),
                // Version info at bottom
                const SizedBox(height: 20),
                Text(
                  'CRF Android App v1.0',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                // Bottom spacing to prevent overflow
                SizedBox(height: screenHeight * 0.05),
              ],
            ),
          ),
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
      
      // Show success message after scanner closes
      if (result != null && result.isNotEmpty) {
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

  Widget _buildCompactLoginForm() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // User ID/Email/No.Hp field
          TextFormField(
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 10.0,
              ),
              hintText: 'User ID / Email / No.Hp',
              hintStyle: const TextStyle(fontSize: 14),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'User ID / Email / No.Hp tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Password field
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: !_isPasswordVisible,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6.0),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 10.0,
              ),
              hintText: 'Kata Sandi',
              hintStyle: const TextStyle(fontSize: 14),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  size: 20,
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
                return 'Kata Sandi tidak boleh kosong';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Table Number and Branch in a row for compact layout
          Row(
            children: [
              Expanded(
                 child: TextFormField(
                   controller: _noMejaController,
                   decoration: InputDecoration(
                     border: OutlineInputBorder(
                       borderRadius: BorderRadius.circular(6.0),
                     ),
                     contentPadding: const EdgeInsets.symmetric(
                       horizontal: 12.0,
                       vertical: 10.0,
                     ),
                     hintText: 'No. Meja',
                     hintStyle: const TextStyle(fontSize: 14),
                     suffixIcon: IconButton(
                       icon: const Icon(Icons.qr_code_scanner, size: 20),
                       onPressed: _openTableNumberScanner,
                     ),
                   ),
                   validator: (value) {
                     if (value == null || value.isEmpty) {
                       return 'No. Meja tidak boleh kosong';
                     }
                     return null;
                   },
                 ),
               ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedBranch,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12.0,
                      vertical: 10.0,
                    ),
                    hintText: 'Cabang',
                    hintStyle: const TextStyle(fontSize: 14),
                  ),
                  items: _availableBranches.map((branch) {
                      return DropdownMenuItem<String>(
                        value: branch['displayText'] as String,
                        child: Text(
                          branch['displayText'] as String,
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                   onChanged: (value) {
                     setState(() {
                       _selectedBranch = value;
                     });
                   },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Pilih cabang';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Login button
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _performLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6.0),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Masuk',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // IMEI display
          Text(
            'IMEI: $_androidId',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
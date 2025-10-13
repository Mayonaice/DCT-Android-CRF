import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/prepare_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../widgets/qr_code_generator_widget.dart';
import '../widgets/custom_modals.dart';
import 'profile_menu_screen.dart';
import 'prepare_summary_page.dart';
import 'dart:async';

class PrepareModePage extends StatefulWidget {
  const PrepareModePage({Key? key}) : super(key: key);

  @override
  State<PrepareModePage> createState() => _PrepareModePageState();
}

class _PrepareModePageState extends State<PrepareModePage> {
  final TextEditingController _idCRFController = TextEditingController();
  final TextEditingController _jamMulaiController = TextEditingController();
  final TextEditingController _tanggalReplenishController = TextEditingController();
  
  // API service
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  String _userName = '';
  String _branchName = '';
  String _userId = '';
  Map<String, dynamic>? _userData;
  
  // Focus node for ID CRF field
  final FocusNode _idCRFFocusNode = FocusNode();
  
  // Data from API
  ATMPrepareReplenishData? _prepareData;
  bool _isLoading = false;
  String _errorMessage = '';
  
  // Dynamic list of catridge controllers
  List<List<TextEditingController>> _catridgeControllers = [];
  
  // Denom values for each catridge
  List<int> _denomValues = [];
  
  // Catridge data from lookup
  List<CatridgeData?> _catridgeData = [];
  
  // Detail catridge data for the right panel
  List<DetailCatridgeItem> _detailCatridgeItems = [];
  
  // Flag to prevent duplicate modal showing
  bool _isDuplicateModalShowing = false;
  
  // Flag to prevent duplicate API calls for Divert fields
  Map<String, bool> _divertApiCallInProgress = {};
  
  // Flag to prevent duplicate API calls for Pocket fields
  Map<String, bool> _pocketApiCallInProgress = {};
  
  // Flag to prevent duplicate seal validation calls for Pocket fields
  Map<String, bool> _pocketSealValidationInProgress = {};
  
  // Flag to prevent duplicate seal validation calls for Divert fields
  Map<String, bool> _divertSealValidationInProgress = {};
  
  // Flag to prevent duplicate listener addition
  bool _divertListenersAdded = false;

  // Divert controllers - UPDATED: Now 3 sections with 5 fields each
  final List<List<TextEditingController>> _divertControllers = [
    // Divert Section 1
    [
    TextEditingController(), // No Catridge
    TextEditingController(), // Seal Catridge
    TextEditingController(), // Bag Code
    TextEditingController(), // Seal Code
    TextEditingController(), // Seal Code Return
    ],
    // Divert Section 2
    [
      TextEditingController(), // No Catridge
      TextEditingController(), // Seal Catridge
      TextEditingController(), // Bag Code
      TextEditingController(), // Seal Code
      TextEditingController(), // Seal Code Return
    ],
    // Divert Section 3
    [
      TextEditingController(), // No Catridge
      TextEditingController(), // Seal Catridge
      TextEditingController(), // Bag Code
      TextEditingController(), // Seal Code
      TextEditingController(), // Seal Code Return
    ],
  ];

  // Track which divert sections are currently active (for green title)
  final List<bool> _divertSectionActive = [false, false, false];

  // Track which divert sections are focused
  final List<List<FocusNode>> _divertFocusNodes = [
    [FocusNode(), FocusNode(), FocusNode(), FocusNode(), FocusNode()],
    [FocusNode(), FocusNode(), FocusNode(), FocusNode(), FocusNode()],
    [FocusNode(), FocusNode(), FocusNode(), FocusNode(), FocusNode()],
  ];

  // Pocket controllers
  final List<TextEditingController> _pocketControllers = [
    TextEditingController(), // No Catridge
    TextEditingController(), // Seal Catridge
    TextEditingController(), // Bag Code
    TextEditingController(), // Seal Code
    TextEditingController(), // Seal Code Return
  ];

  // Track pocket section activity and focus
  bool _pocketSectionActive = false;
  final List<FocusNode> _pocketFocusNodes = [
    FocusNode(), FocusNode(), FocusNode(), FocusNode(), FocusNode()
  ];

  // Track catridge sections activity and focus
  List<bool> _catridgeSectionActive = [];
  List<List<FocusNode>> _catridgeFocusNodes = [];
  
  // Track manual mode for each section
  List<bool> _catridgeManualMode = [];
  List<TextEditingController> _catridgeAlasanControllers = [];
  
  // NEW: Manual mode popup form state
  List<bool> _catridgeShowPopup = [];
  List<TextEditingController> _catridgeRemarkControllers = [];
  List<bool> _catridgeRemarkFilled = [];
  
  // NEW: Field-specific manual mode tracking
  List<bool> _catridgeNoManualMode = []; // For No. Catridge field
  List<bool> _catridgeSealManualMode = []; // For Seal Catridge field
  List<TextEditingController> _catridgeNoAlasanControllers = []; // Alasan for No. Catridge
  List<TextEditingController> _catridgeSealAlasanControllers = []; // Alasan for Seal Catridge
  List<TextEditingController> _catridgeNoRemarkControllers = []; // Remark for No. Catridge
  List<TextEditingController> _catridgeSealRemarkControllers = []; // Remark for Seal Catridge
  List<bool> _catridgeNoRemarkFilled = []; // Remark filled status for No. Catridge
  List<bool> _catridgeSealRemarkFilled = []; // Remark filled status for Seal Catridge
  // OLD: Section-level manual mode (will be replaced with field-specific)
  List<bool> _divertManualMode = [false, false, false];
  List<TextEditingController> _divertAlasanControllers = [
    TextEditingController(), TextEditingController(), TextEditingController()
  ];
  // NEW: Divert remark controllers
  List<TextEditingController> _divertRemarkControllers = [
    TextEditingController(), TextEditingController(), TextEditingController()
  ];
  bool _pocketManualMode = false;
  final TextEditingController _pocketAlasanController = TextEditingController();
  // NEW: Pocket remark controller
  final TextEditingController _pocketRemarkController = TextEditingController();
  
  // NEW: Field-specific manual mode for Divert sections
  List<bool> _divertNoManualMode = [false, false, false]; // For No. Catridge fields
  List<bool> _divertSealManualMode = [false, false, false]; // For Seal Catridge fields
  List<TextEditingController> _divertNoAlasanControllers = [
    TextEditingController(), TextEditingController(), TextEditingController()
  ];
  List<TextEditingController> _divertSealAlasanControllers = [
    TextEditingController(), TextEditingController(), TextEditingController()
  ];
  List<TextEditingController> _divertNoRemarkControllers = [
    TextEditingController(), TextEditingController(), TextEditingController()
  ];
  List<TextEditingController> _divertSealRemarkControllers = [
    TextEditingController(), TextEditingController(), TextEditingController()
  ];
  
  // NEW: Field-specific remark filled tracking for Divert sections
  List<bool> _divertNoRemarkFilled = [false, false, false]; // For No. Catridge remark status
  List<bool> _divertSealRemarkFilled = [false, false, false]; // For Seal Catridge remark status
  
  // NEW: Field-specific manual mode for Pocket section
  bool _pocketNoManualMode = false; // For No. Catridge field
  bool _pocketSealManualMode = false; // For Seal Catridge field
  final TextEditingController _pocketNoAlasanController = TextEditingController();
  final TextEditingController _pocketSealAlasanController = TextEditingController();
  final TextEditingController _pocketNoRemarkController = TextEditingController();
  final TextEditingController _pocketSealRemarkController = TextEditingController();
  
  // NEW: Field-specific remark filled tracking for Pocket section
  bool _pocketNoRemarkFilled = false; // For No. Catridge remark status
  bool _pocketSealRemarkFilled = false; // For Seal Catridge remark status

  // Divert and Pocket data
  List<CatridgeData?> _divertCatridgeData = [null, null, null]; // Support 3 divert sections
  CatridgeData? _pocketCatridgeData;
  List<DetailCatridgeItem?> _divertDetailItems = [null, null, null]; // Support 3 divert sections
  DetailCatridgeItem? _pocketDetailItem;
  
  // Approval form state
  bool _showApprovalForm = false;
  bool _isSubmitting = false;
  final TextEditingController _nikTLController = TextEditingController();
  final TextEditingController _passwordTLController = TextEditingController();
  
  // Debounce timers for auto API calls
  Map<String, Timer?> _debounceTimers = {};

  // NEW: Duplicate validation tracking
  Set<String> _usedValues = <String>{};

  @override
  void initState() {
    super.initState();
    // Lock orientation to landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // Add focus listener for ID CRF field
    _idCRFFocusNode.addListener(() {
      print('DEBUG: ID CRF Focus changed: ${_idCRFFocusNode.hasFocus}, text: ${_idCRFController.text}');
      if (!_idCRFFocusNode.hasFocus && _idCRFController.text.isNotEmpty) {
        print('DEBUG: Triggering _fetchPrepareData() from FocusNode');
        _fetchPrepareData();
      }
    });
    
    // Load user data
    _loadUserData();
    
    // Initialize with one empty catridge
    _initializeCatridgeControllers(1);
    
    // Set current time as jam mulai
    _setCurrentTime();
    
    // Set current date as tanggal replenish
    _setCurrentDate();
    
    // Add listeners to text fields to auto-hide approval form
    // REMOVED: _idCRFController.addListener(_checkAndHideApprovalForm);
    // REMOVED: _jamMulaiController.addListener(_checkAndHideApprovalForm);
    
    // Add focus listeners for section highlighting
    _setupFocusListeners();
    
    // NEW: Add listeners to Divert remark controllers
    for (int i = 0; i < _divertNoRemarkControllers.length; i++) {
      _divertNoRemarkControllers[i].addListener(() => _onDivertRemarkChanged(i, 'no_catridge'));
    }
    for (int i = 0; i < _divertSealRemarkControllers.length; i++) {
      _divertSealRemarkControllers[i].addListener(() => _onDivertRemarkChanged(i, 'seal_catridge'));
    }
    
    // NEW: Add listeners to Pocket remark controllers
    _pocketNoRemarkController.addListener(() => _onPocketRemarkChanged('no_catridge'));
    _pocketSealRemarkController.addListener(() => _onPocketRemarkChanged('seal_catridge'));
  }

  // NEW: Handle divert field changes to trigger manual mode per field
  void _onDivertFieldChanged(int sectionIndex, String fieldType, String value) {
    if (sectionIndex >= 0 && sectionIndex < 3) {
      setState(() {
        if (value.trim().isNotEmpty) {
          // Activate manual mode for specific field type
          if (fieldType == 'catridge' || fieldType == 'no_catridge') {
            _divertNoManualMode[sectionIndex] = true;
          } else if (fieldType == 'seal' || fieldType == 'seal_catridge') {
            _divertSealManualMode[sectionIndex] = true;
          }
        }
        
        // Update DetailCatridgeItem in _detailCatridgeItems when user manually enters data
        int divertIndex = 100 + sectionIndex;
        for (int i = 0; i < _detailCatridgeItems.length; i++) {
          if (_detailCatridgeItems[i].index == divertIndex) {
            // For manual entry, we need to ensure the item has a valid value
            // Set default for other fields
            int currentValue = _detailCatridgeItems[i].value;
            if (currentValue <= 0 && value.trim().isNotEmpty) {
              // Set default value for manual entry (can be updated later by user)
              currentValue = 1;
              
              // Calculate total based on denomination
              int denomAmount = _prepareData?.tipeDenom == 'A100' ? 100000 : 50000;
              int totalNominal = denomAmount * currentValue;
              String formattedTotal = _formatCurrency(totalNominal);
              
              _detailCatridgeItems[i] = DetailCatridgeItem(
                index: _detailCatridgeItems[i].index,
                noCatridge: fieldType == 'no_catridge' ? value.trim() : _detailCatridgeItems[i].noCatridge,
                sealCatridge: fieldType == 'seal_catridge' ? value.trim() : _detailCatridgeItems[i].sealCatridge,
                value: currentValue,
                total: formattedTotal,
                denom: denomAmount == 100000 ? 'Rp 100.000' : 'Rp 50.000',
                bagCode: sectionIndex < _divertControllers.length ? _divertControllers[sectionIndex][2].text.trim() : '',
                sealCode: sectionIndex < _divertControllers.length ? _divertControllers[sectionIndex][3].text.trim() : '',
                sealReturn: sectionIndex < _divertControllers.length ? _divertControllers[sectionIndex][4].text.trim() : '',
              );
              
              // Also update _divertDetailItems if exists
              if (_divertDetailItems[sectionIndex] != null) {
                _divertDetailItems[sectionIndex] = DetailCatridgeItem(
                  index: _divertDetailItems[sectionIndex]!.index,
                  noCatridge: fieldType == 'no_catridge' ? value.trim() : _divertDetailItems[sectionIndex]!.noCatridge,
                  sealCatridge: fieldType == 'seal_catridge' ? value.trim() : _divertDetailItems[sectionIndex]!.sealCatridge,
                  value: currentValue,
                  total: formattedTotal,
                  denom: denomAmount == 100000 ? 'Rp 100.000' : 'Rp 50.000',
                  bagCode: _divertControllers[sectionIndex][2].text.trim(),
                  sealCode: _divertControllers[sectionIndex][3].text.trim(),
                  sealReturn: _divertControllers[sectionIndex][4].text.trim(),
                );
              }
              
              print('🔄 DIVERT MANUAL: Updated item index $divertIndex with default value $currentValue for section $sectionIndex');
            } else {
              // Just update the specific field
              int updatedValue = _detailCatridgeItems[i].value;
              String updatedTotal = _detailCatridgeItems[i].total;
              
              _detailCatridgeItems[i] = DetailCatridgeItem(
                index: _detailCatridgeItems[i].index,
                noCatridge: fieldType == 'no_catridge' ? value.trim() : _detailCatridgeItems[i].noCatridge,
                sealCatridge: fieldType == 'seal_catridge' ? value.trim() : _detailCatridgeItems[i].sealCatridge,
                value: updatedValue,
                total: updatedTotal,
                denom: _detailCatridgeItems[i].denom,
                bagCode: _detailCatridgeItems[i].bagCode,
                sealCode: _detailCatridgeItems[i].sealCode,
                sealReturn: _detailCatridgeItems[i].sealReturn,
              );
              
              // Also update _divertDetailItems if exists
              if (_divertDetailItems[sectionIndex] != null) {
                _divertDetailItems[sectionIndex] = DetailCatridgeItem(
                  index: _divertDetailItems[sectionIndex]!.index,
                  noCatridge: fieldType == 'no_catridge' ? value.trim() : _divertDetailItems[sectionIndex]!.noCatridge,
                  sealCatridge: fieldType == 'seal_catridge' ? value.trim() : _divertDetailItems[sectionIndex]!.sealCatridge,
                  value: updatedValue,
                  total: updatedTotal,
                  denom: _divertDetailItems[sectionIndex]!.denom,
                  bagCode: _divertDetailItems[sectionIndex]!.bagCode,
                  sealCode: _divertDetailItems[sectionIndex]!.sealCode,
                  sealReturn: _divertDetailItems[sectionIndex]!.sealReturn,
                );
              }
              
              print('🔄 DIVERT MANUAL: Updated $fieldType for item index $divertIndex in section $sectionIndex, value: $updatedValue');
            }
            break;
          }
        }
        
        // REMOVED: Reset manual mode logic when field is cleared
        // Manual mode should only be reset after successful scan, not when field changes
      });
    }
  }


  // NEW: Handle divert remark changes to update field-specific remark filled status
  void _onDivertRemarkChanged(int sectionIndex, String fieldType) {
    if (sectionIndex >= 0 && sectionIndex < 3) {
      setState(() {
        if (fieldType == 'no_catridge' || fieldType == 'No. Catridge') {
          // Ensure the list is large enough
          while (_divertNoRemarkFilled.length <= sectionIndex) {
            _divertNoRemarkFilled.add(false);
          }
          _divertNoRemarkFilled[sectionIndex] = 
              sectionIndex < _divertNoRemarkControllers.length && 
              _divertNoRemarkControllers[sectionIndex].text.trim().isNotEmpty &&
              sectionIndex < _divertNoAlasanControllers.length &&
              _divertNoAlasanControllers[sectionIndex].text.trim().isNotEmpty;
        } else if (fieldType == 'seal_catridge' || fieldType == 'Seal Catridge') {
          // Ensure the list is large enough
          while (_divertSealRemarkFilled.length <= sectionIndex) {
            _divertSealRemarkFilled.add(false);
          }
          _divertSealRemarkFilled[sectionIndex] = 
              sectionIndex < _divertSealRemarkControllers.length && 
              _divertSealRemarkControllers[sectionIndex].text.trim().isNotEmpty &&
              sectionIndex < _divertSealAlasanControllers.length &&
              _divertSealAlasanControllers[sectionIndex].text.trim().isNotEmpty;
        }
      });
    }
  }

  // NEW: Handle pocket field changes to trigger manual mode per field
  void _onPocketFieldChanged(String fieldType, String value) {
    setState(() {
      if (value.trim().isNotEmpty) {
        // Activate manual mode for specific field type
        if (fieldType == 'catridge' || fieldType == 'no_catridge') {
          _pocketNoManualMode = true;
        } else if (fieldType == 'seal' || fieldType == 'seal_catridge') {
          _pocketSealManualMode = true;
        }
      }
      // REMOVED: Reset manual mode logic when field is cleared
      // Manual mode should only be reset after successful scan, not when field changes
    });
  }

  // NEW: Handle pocket remark changes to update field-specific remark filled status
  void _onPocketRemarkChanged(String fieldType) {
    setState(() {
      if (fieldType == 'no_catridge' || fieldType == 'No. Catridge') {
        _pocketNoRemarkFilled = _pocketNoRemarkController.text.trim().isNotEmpty &&
                               _pocketNoAlasanController.text.trim().isNotEmpty;
      } else if (fieldType == 'seal_catridge' || fieldType == 'Seal Catridge') {
        _pocketSealRemarkFilled = _pocketSealRemarkController.text.trim().isNotEmpty &&
                                 _pocketSealAlasanController.text.trim().isNotEmpty;
      }
    });
  }

  // NEW: Build divert manual mode icon
  Widget _buildDivertManualIcon(int sectionIndex, String fieldType, bool isSmallScreen) {
    bool isManualMode = false;
    bool hasAlasan = false;
    bool hasRemark = false;
    
    if (fieldType == 'no_catridge') {
      isManualMode = sectionIndex < _divertNoManualMode.length && _divertNoManualMode[sectionIndex];
      hasAlasan = sectionIndex < _divertNoAlasanControllers.length && _divertNoAlasanControllers[sectionIndex].text.isNotEmpty;
      hasRemark = sectionIndex < _divertNoRemarkFilled.length && _divertNoRemarkFilled[sectionIndex];
    } else if (fieldType == 'seal_catridge') {
      isManualMode = sectionIndex < _divertSealManualMode.length && _divertSealManualMode[sectionIndex];
      hasAlasan = sectionIndex < _divertSealAlasanControllers.length && _divertSealAlasanControllers[sectionIndex].text.isNotEmpty;
      hasRemark = sectionIndex < _divertSealRemarkFilled.length && _divertSealRemarkFilled[sectionIndex];
    }
    
    // Icon is green (done) only if manual mode is active AND both alasan and remark are filled
    String iconPath = (isManualMode && hasAlasan && hasRemark) 
        ? 'assets/images/ManualModeIcon_done.png'
        : 'assets/images/ManualModeIcon_notdone.png';
    
    return Image.asset(
      iconPath,
      width: isSmallScreen ? 16 : 20,
      height: isSmallScreen ? 16 : 20,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.edit,
          size: isSmallScreen ? 16 : 20,
          color: (isManualMode && hasAlasan && hasRemark) ? Colors.green : Colors.orange,
        );
      },
    );
  }

  // NEW: Build pocket manual mode icon
  Widget _buildPocketManualIcon(String fieldType, bool isSmallScreen) {
    bool isManualMode = false;
    bool hasAlasan = false;
    bool hasRemark = false;
    
    if (fieldType == 'no_catridge') {
      isManualMode = _pocketNoManualMode;
      hasAlasan = _pocketNoAlasanController.text.isNotEmpty;
      hasRemark = _pocketNoRemarkFilled;
    } else if (fieldType == 'seal_catridge') {
      isManualMode = _pocketSealManualMode;
      hasAlasan = _pocketSealAlasanController.text.isNotEmpty;
      hasRemark = _pocketSealRemarkFilled;
    }
    
    // Icon is green (done) only if manual mode is active AND both alasan and remark are filled
    String iconPath = (isManualMode && hasAlasan && hasRemark) 
        ? 'assets/images/ManualModeIcon_done.png'
        : 'assets/images/ManualModeIcon_notdone.png';
    
    return Image.asset(
      iconPath,
      width: isSmallScreen ? 16 : 20,
      height: isSmallScreen ? 16 : 20,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.edit,
          size: isSmallScreen ? 16 : 20,
          color: (isManualMode && hasAlasan && hasRemark) ? Colors.green : Colors.orange,
        );
      },
    );
  }

  // NEW: Show divert manual mode popup
  void _showDivertManualModePopup(int sectionIndex, String fieldType, Offset? iconPosition) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.width < 600;
        
        Widget dialogWidget = Container(
          width: isSmallScreen ? screenSize.width * 0.9 : 320,
          constraints: BoxConstraints(
            maxHeight: screenSize.height * 0.7,
          ),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Image.asset(
                      'assets/images/ManualModeIcon_notdone.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.edit, size: 20, color: Colors.orange);
                      },
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Detail Manual Divert ${sectionIndex + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                
                // Field display
                TextField(
                  controller: fieldType == 'seal' 
                      ? _divertControllers[sectionIndex][1] 
                      : _divertControllers[sectionIndex][0],
                  decoration: InputDecoration(
                    labelText: fieldType == 'seal' ? 'Seal Catridge' : 'No. Catridge',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                  style: TextStyle(fontSize: 12),
                  readOnly: true,
                ),
                SizedBox(height: 8),
                
                // Alasan dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Alasan',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.black),
                  items: [
                    DropdownMenuItem(value: 'Segel Tidak Terbaca', child: Text('Segel Tidak Terbaca', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Scanner Rusak', child: Text('Scanner Rusak', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Kaset Berbeda', child: Text('Kaset Berbeda', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _divertAlasanControllers[sectionIndex].text = value;
                    }
                  },
                ),
                SizedBox(height: 8),
                
                // Remark field
                TextField(
                  controller: fieldType == 'seal' 
                      ? _divertSealRemarkControllers[sectionIndex]
                      : _divertNoRemarkControllers[sectionIndex],
                  decoration: InputDecoration(
                    labelText: 'Remark',
                    border: OutlineInputBorder(),
                    hintText: 'Wajib diisi',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    labelStyle: TextStyle(fontSize: 12),
                    hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  style: TextStyle(fontSize: 12),
                  maxLines: 2,
                  onChanged: (value) {
                    _onDivertRemarkChanged(sectionIndex, fieldType == 'seal' ? 'seal_catridge' : 'no_catridge');
                  },
                ),
                SizedBox(height: 10),
                
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Tutup', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        
        // Position popup next to icon if position provided
        if (iconPosition != null) {
          return Stack(
            children: [
              Positioned(
                left: (iconPosition.dx + 30).clamp(0.0, screenSize.width - 320),
                top: (iconPosition.dy - 50).clamp(0.0, screenSize.height - 400),
                child: Material(
                  color: Colors.transparent,
                  child: dialogWidget,
                ),
              ),
            ],
          );
        } else {
          return Center(child: Material(color: Colors.transparent, child: dialogWidget));
        }
      },
    );
  }

  // NEW: Show pocket manual mode popup
  void _showPocketManualModePopup(String fieldType, Offset? iconPosition) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.width < 600;
        
        Widget dialogWidget = Container(
          width: isSmallScreen ? screenSize.width * 0.9 : 320,
          constraints: BoxConstraints(
            maxHeight: screenSize.height * 0.7,
          ),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Image.asset(
                      'assets/images/ManualModeIcon_notdone.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.edit, size: 20, color: Colors.orange);
                      },
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Detail Manual Pocket',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                
                // Field display
                TextField(
                  controller: fieldType == 'seal' 
                      ? _pocketControllers[1] 
                      : _pocketControllers[0],
                  decoration: InputDecoration(
                    labelText: fieldType == 'seal' ? 'Seal Catridge' : 'No. Catridge',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                  style: TextStyle(fontSize: 12),
                  readOnly: true,
                ),
                SizedBox(height: 8),
                
                // Alasan dropdown
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Alasan',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    labelStyle: TextStyle(fontSize: 12),
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.black),
                  items: [
                    DropdownMenuItem(value: 'Segel Tidak Terbaca', child: Text('Segel Tidak Terbaca', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Scanner Rusak', child: Text('Scanner Rusak', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Kaset Berbeda', child: Text('Kaset Berbeda', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      _pocketAlasanController.text = value;
                    }
                  },
                ),
                SizedBox(height: 8),
                
                // Remark field
                TextField(
                  controller: fieldType == 'seal' 
                      ? _pocketSealRemarkController
                      : _pocketNoRemarkController,
                  decoration: InputDecoration(
                    labelText: 'Remark',
                    border: OutlineInputBorder(),
                    hintText: 'Wajib diisi',
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    labelStyle: TextStyle(fontSize: 12),
                    hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  style: TextStyle(fontSize: 12),
                  maxLines: 2,
                  onChanged: (value) {
                    _onPocketRemarkChanged(fieldType == 'seal' ? 'seal_catridge' : 'no_catridge');
                  },
                ),
                SizedBox(height: 10),
                
                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Tutup', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        
        // Position popup next to icon if position provided
        if (iconPosition != null) {
          return Stack(
            children: [
              Positioned(
                left: (iconPosition.dx + 30).clamp(0.0, screenSize.width - 320),
                top: (iconPosition.dy - 50).clamp(0.0, screenSize.height - 400),
                child: Material(
                  color: Colors.transparent,
                  child: dialogWidget,
                ),
              ),
            ],
          );
        } else {
          return Center(child: Material(color: Colors.transparent, child: dialogWidget));
        }
      },
    );
  }
  
  // NEW: Duplicate validation functions
  bool _isDuplicateValue(String value, String currentFieldKey) {
    if (value.trim().isEmpty) return false;
    
    // Get all current values from all sections
    Map<String, String> allFieldValues = _getAllFieldValues();
    
    // Remove current field from validation to allow editing same field
    allFieldValues.remove(currentFieldKey);
    
    // Check if value exists in any other field
    return allFieldValues.values.any((existingValue) => 
        existingValue.trim().toLowerCase() == value.trim().toLowerCase());
  }
  
  Map<String, String> _getAllFieldValues() {
    Map<String, String> allValues = {};
    
    // Catridge section values
    for (int i = 0; i < _catridgeControllers.length; i++) {
      if (_catridgeControllers[i].length >= 5) {
        allValues['catridge_${i}_no'] = _catridgeControllers[i][0].text.trim();
        allValues['catridge_${i}_seal'] = _catridgeControllers[i][1].text.trim();
        allValues['catridge_${i}_bag'] = _catridgeControllers[i][2].text.trim();
        allValues['catridge_${i}_seal_code'] = _catridgeControllers[i][3].text.trim();
        allValues['catridge_${i}_seal_return'] = _catridgeControllers[i][4].text.trim();
      }
    }
    
    // Divert section values
    for (int i = 0; i < _divertControllers.length; i++) {
      allValues['divert_${i}_no'] = _divertControllers[i][0].text.trim();
      allValues['divert_${i}_seal'] = _divertControllers[i][1].text.trim();
      allValues['divert_${i}_bag'] = _divertControllers[i][2].text.trim();
      allValues['divert_${i}_seal_code'] = _divertControllers[i][3].text.trim();
      allValues['divert_${i}_seal_return'] = _divertControllers[i][4].text.trim();
    }
    
    // Pocket section values
    allValues['pocket_0_no'] = _pocketControllers[0].text.trim();
    allValues['pocket_0_seal'] = _pocketControllers[1].text.trim();
    allValues['pocket_0_bag'] = _pocketControllers[2].text.trim();
    allValues['pocket_0_seal_code'] = _pocketControllers[3].text.trim();
    allValues['pocket_0_seal_return'] = _pocketControllers[4].text.trim();
    
    // Remove empty values
    allValues.removeWhere((key, value) => value.isEmpty);
    
    return allValues;
  }
  
  void _showDuplicateValidationError(String fieldName, String value) {
    CustomModals.showFailedModal(
      context: context,
      message: 'Kode $fieldName "$value" sudah diinput. Silakan input kode lain.',
      buttonText: 'OK',
      onPressed: () {
        Navigator.of(context).pop();
        // Reset flag when modal is closed
        _isDuplicateModalShowing = false;
      },
    );
  }
  
  bool _validateFieldForDuplicates(String value, String fieldKey, String fieldName) {
    if (_isDuplicateValue(value, fieldKey)) {
      // Use a more robust approach to prevent multiple modals
      if (!_isDuplicateModalShowing) {
        _isDuplicateModalShowing = true;
        // Add a small delay to ensure flag is set before any other calls
        Future.microtask(() {
          _showDuplicateValidationError(fieldName, value);
        });
      }
      return false;
    }
    return true;
  }
  
  // Load user data from login
  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          _userName = userData['userName'] ?? userData['name'] ?? '';
          _userId = userData['userId'] ?? userData['userID'] ?? '';
          _branchName = userData['branchName'] ?? userData['branch'] ?? '';
          _userData = userData;
        });
        debugPrint('🔍 User data loaded - UserName: $_userName, UserID: $_userId');
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  // Method to remove all focus listeners
  void _removeFocusListeners() {
    // Remove divert focus listeners
    for (int i = 0; i < _divertFocusNodes.length; i++) {
      for (int j = 0; j < _divertFocusNodes[i].length; j++) {
        _divertFocusNodes[i][j].removeListener(() {});
      }
    }
    
    // Reset the flag
    _divertListenersAdded = false;
  }

  // Setup focus listeners for section highlighting
  void _setupFocusListeners() {
    // Divert focus listeners
    for (int i = 0; i < _divertFocusNodes.length; i++) {
      for (int j = 0; j < _divertFocusNodes[i].length; j++) {
        _divertFocusNodes[i][j].addListener(() {
          setState(() {
            _divertSectionActive[i] = _divertFocusNodes[i].any((node) => node.hasFocus);
          });
        });
      }
    }
    
    // Pocket focus listeners
    for (int i = 0; i < _pocketFocusNodes.length; i++) {
      _pocketFocusNodes[i].addListener(() {
        setState(() {
          _pocketSectionActive = _pocketFocusNodes.any((node) => node.hasFocus);
        });
      });
    }

    // Add focus listeners for catridge fields API calls
    for (int i = 0; i < _catridgeFocusNodes.length; i++) {
      if (_catridgeFocusNodes[i].length > 0) {
        // No. Catridge field focus listener
        _catridgeFocusNodes[i][0].addListener(() {
          if (!_catridgeFocusNodes[i][0].hasFocus && _catridgeControllers[i][0].text.trim().isNotEmpty) {
            // Check for duplicates before API call
            String fieldKey = 'catridge_${i}_no';
            String fieldName = 'No. Catridge (Catridge ${i + 1})';
            if (_validateFieldForDuplicates(_catridgeControllers[i][0].text.trim(), fieldKey, fieldName)) {
              _lookupCatridgeAndCreateDetail(i, _catridgeControllers[i][0].text.trim());
            } else {
              // Clear the field if duplicate found
              _catridgeControllers[i][0].clear();
            }
          }
        });
        
        // Seal Catridge field focus listener
        if (_catridgeFocusNodes[i].length > 1) {
          _catridgeFocusNodes[i][1].addListener(() {
            if (!_catridgeFocusNodes[i][1].hasFocus && _catridgeControllers[i][1].text.trim().isNotEmpty) {
              // Check for duplicates before API call
              String fieldKey = 'catridge_${i}_seal';
              String fieldName = 'Seal Catridge (Catridge ${i + 1})';
              if (_validateFieldForDuplicates(_catridgeControllers[i][1].text.trim(), fieldKey, fieldName)) {
                _validateSealAndUpdateDetail(i, _catridgeControllers[i][1].text.trim());
              } else {
                // Clear the field if duplicate found
                _catridgeControllers[i][1].clear();
              }
            }
          });
        }
      }
    }

    // Add focus listeners for divert fields API calls - FIXED: Only add listeners once
    if (!_divertListenersAdded) {
      _divertListenersAdded = true;
      for (int i = 0; i < _divertFocusNodes.length; i++) {
        if (_divertFocusNodes[i].length > 0) {
          // No. Catridge field focus listener
          _divertFocusNodes[i][0].addListener(() {
            if (!_divertFocusNodes[i][0].hasFocus && _divertControllers[i][0].text.trim().isNotEmpty) {
              // Check for duplicates before API call
              String fieldKey = 'divert_${i}_no';
              String fieldName = 'No. Catridge (Divert ${i + 1})';
              String apiKey = 'divert_${i}_${_divertControllers[i][0].text.trim()}';
              
              // Skip if API call is already in progress for this field and value
              if (_divertApiCallInProgress[apiKey] == true) {
                print('🔍 DIVERT LOOKUP: Skipping duplicate API call for $apiKey');
                return;
              }
              
              // Skip duplicate validation if modal is already showing to prevent double modals
              if (!_isDuplicateModalShowing && _validateFieldForDuplicates(_divertControllers[i][0].text.trim(), fieldKey, fieldName)) {
                _lookupDivertCatridge(i, _divertControllers[i][0].text.trim());
              } else if (_isDuplicateValue(_divertControllers[i][0].text.trim(), fieldKey)) {
                // Clear the field if duplicate found, but don't show modal again
                _divertControllers[i][0].clear();
              }
            }
          });
          
          // Seal Catridge field focus listener
          if (_divertFocusNodes[i].length > 1) {
            _divertFocusNodes[i][1].addListener(() {
              if (!_divertFocusNodes[i][1].hasFocus && _divertControllers[i][1].text.trim().isNotEmpty) {
                // Check for duplicates before API call
                String fieldKey = 'divert_${i}_seal';
                String fieldName = 'Seal Catridge (Divert ${i + 1})';
                String sealCode = _divertControllers[i][1].text.trim();
                
                // Create unique key for seal validation tracking
                String validationKey = 'divert_${i}_seal_$sealCode';
                
                // Check if seal validation is already in progress for this field and value
                if (_divertSealValidationInProgress[validationKey] == true) {
                  print('Seal validation already in progress for Divert field: $fieldKey with value: $sealCode');
                  return;
                }
                
                // Skip duplicate validation if modal is already showing to prevent double modals
                if (!_isDuplicateModalShowing && _validateFieldForDuplicates(sealCode, fieldKey, fieldName)) {
                  _validateDivertSeal(i, sealCode);
                } else if (_isDuplicateValue(sealCode, fieldKey)) {
                  // Clear the field if duplicate found, but don't show modal again
                  _divertControllers[i][1].clear();
                }
              }
            });
          }
        }
      }
    }

    // Add focus listeners for pocket fields API calls
    if (_pocketFocusNodes.length > 0) {
      // No. Catridge field focus listener
      _pocketFocusNodes[0].addListener(() {
        if (!_pocketFocusNodes[0].hasFocus && _pocketControllers[0].text.trim().isNotEmpty) {
          // Check for duplicates before API call
          String fieldKey = 'pocket_0_no';
          String fieldName = 'No. Catridge (Pocket)';
          String catridgeCode = _pocketControllers[0].text.trim();
          
          // Create unique key for API call tracking
          String apiKey = 'pocket_0_$catridgeCode';
          
          // Check if API call is already in progress for this field and value
          if (_pocketApiCallInProgress[apiKey] == true) {
            print('API call already in progress for Pocket field: $fieldKey with value: $catridgeCode');
            return;
          }
          
          if (_validateFieldForDuplicates(catridgeCode, fieldKey, fieldName)) {
            _lookupPocketCatridge(catridgeCode);
          } else {
            // Clear the field if duplicate found
            _pocketControllers[0].clear();
          }
        }
      });
      
      // Seal Catridge field focus listener
      if (_pocketFocusNodes.length > 1) {
        _pocketFocusNodes[1].addListener(() {
          if (!_pocketFocusNodes[1].hasFocus && _pocketControllers[1].text.trim().isNotEmpty) {
            // Check for duplicates before API call
            String fieldKey = 'pocket_0_seal';
            String fieldName = 'Seal Catridge (Pocket)';
            String sealCode = _pocketControllers[1].text.trim();
            
            // Create unique key for seal validation tracking
            String validationKey = 'pocket_0_seal_$sealCode';
            
            // Check if seal validation is already in progress for this field and value
            if (_pocketSealValidationInProgress[validationKey] == true) {
              print('Seal validation already in progress for Pocket field: $fieldKey with value: $sealCode');
              return;
            }
            
            if (_validateFieldForDuplicates(sealCode, fieldKey, fieldName)) {
              _validatePocketSeal(sealCode);
            } else {
              // Clear the field if duplicate found
              _pocketControllers[1].clear();
            }
          }
        });
      }
    }
    
    // NEW: Add listeners for Divert controllers to trigger manual mode and duplicate validation
    for (int i = 0; i < _divertControllers.length; i++) {
      // NOTE: No. Catridge (index 0) and Seal Catridge (index 1) listeners are already handled 
      // in focus listeners above to prevent duplicate API calls
      
      // Add listener for Bag Code (index 2) with duplicate validation
      _divertControllers[i][2].addListener(() {
        String value = _divertControllers[i][2].text.trim();
        if (value.isNotEmpty) {
          String fieldKey = 'divert_${i}_bag';
          String fieldName = 'Bag Code (Divert ${i + 1})';
          // Skip duplicate validation if modal is already showing to prevent double modals
          if (!_isDuplicateModalShowing && !_validateFieldForDuplicates(value, fieldKey, fieldName)) {
            _divertControllers[i][2].clear();
            return;
          } else if (_isDuplicateModalShowing && _isDuplicateValue(value, fieldKey)) {
            // Clear the field if duplicate found and modal is already showing
            _divertControllers[i][2].clear();
            return;
          }
        }
        _onDivertFieldChanged(i, 'bag_code', value);
      });
      
      // Add listener for Seal Code (index 3) with duplicate validation
      _divertControllers[i][3].addListener(() {
        String value = _divertControllers[i][3].text.trim();
        if (value.isNotEmpty) {
          String fieldKey = 'divert_${i}_seal_code';
          String fieldName = 'Seal Code (Divert ${i + 1})';
          // Skip duplicate validation if modal is already showing to prevent double modals
          if (!_isDuplicateModalShowing && !_validateFieldForDuplicates(value, fieldKey, fieldName)) {
            _divertControllers[i][3].clear();
            return;
          } else if (_isDuplicateModalShowing && _isDuplicateValue(value, fieldKey)) {
            // Clear the field if duplicate found and modal is already showing
            _divertControllers[i][3].clear();
            return;
          }
        }
        _onDivertFieldChanged(i, 'seal_code', value);
      });
      
      // Add listener for Seal Code Return (index 4) with duplicate validation
      _divertControllers[i][4].addListener(() {
        String value = _divertControllers[i][4].text.trim();
        if (value.isNotEmpty) {
          String fieldKey = 'divert_${i}_seal_return';
          String fieldName = 'Seal Code Return (Divert ${i + 1})';
          // Skip duplicate validation if modal is already showing to prevent double modals
          if (!_isDuplicateModalShowing && !_validateFieldForDuplicates(value, fieldKey, fieldName)) {
            _divertControllers[i][4].clear();
            return;
          } else if (_isDuplicateModalShowing && _isDuplicateValue(value, fieldKey)) {
            // Clear the field if duplicate found and modal is already showing
            _divertControllers[i][4].clear();
            return;
          }
        }
        _onDivertFieldChanged(i, 'seal_code_return', value);
      });
    }
    
    // NEW: Add listeners for Pocket controllers to trigger manual mode and duplicate validation
    // NOTE: No. Catridge (index 0) and Seal Catridge (index 1) listeners are already handled 
    // in focus listeners above to prevent duplicate API calls
    
    // Bag Code (index 2) with duplicate validation
    _pocketControllers[2].addListener(() {
      String value = _pocketControllers[2].text.trim();
      if (value.isNotEmpty) {
        String fieldKey = 'pocket_0_bag';
        String fieldName = 'Bag Code (Pocket)';
        if (!_validateFieldForDuplicates(value, fieldKey, fieldName)) {
          _pocketControllers[2].clear();
          return;
        }
      }
      _onPocketFieldChanged('bag_code', value);
    });
    
    // Seal Code (index 3) with duplicate validation
    _pocketControllers[3].addListener(() {
      String value = _pocketControllers[3].text.trim();
      if (value.isNotEmpty) {
        String fieldKey = 'pocket_0_seal_code';
        String fieldName = 'Seal Code (Pocket)';
        if (!_validateFieldForDuplicates(value, fieldKey, fieldName)) {
          _pocketControllers[3].clear();
          return;
        }
      }
      _onPocketFieldChanged('seal_code', value);
    });
    
    // Seal Code Return (index 4) with duplicate validation
    _pocketControllers[4].addListener(() {
      String value = _pocketControllers[4].text.trim();
      if (value.isNotEmpty) {
        String fieldKey = 'pocket_0_seal_return';
        String fieldName = 'Seal Code Return (Pocket)';
        if (!_validateFieldForDuplicates(value, fieldKey, fieldName)) {
          _pocketControllers[4].clear();
          return;
        }
      }
      _onPocketFieldChanged('seal_code_return', value);
    });
  }

  @override
  void dispose() {
    // Cancel all debounce timers
    for (var timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();
    
    // Remove all focus listeners before disposing
    _removeFocusListeners();
    
    _idCRFController.dispose();
    _jamMulaiController.dispose();
    _idCRFFocusNode.dispose();
    
    // Dispose all dynamic controllers
    for (var controllerList in _catridgeControllers) {
      for (var controller in controllerList) {
        controller.dispose();
      }
    }
    
    // Dispose divert controllers
    for (var controllerList in _divertControllers) {
      for (var controller in controllerList) {
        controller.dispose();
      }
    }
    
    // Dispose pocket controllers
    for (var controller in _pocketControllers) {
      controller.dispose();
    }
    
    // Dispose focus nodes
    for (var nodeList in _divertFocusNodes) {
      for (var node in nodeList) {
        node.dispose();
      }
    }
    for (var node in _pocketFocusNodes) {
      node.dispose();
    }
    for (var nodeList in _catridgeFocusNodes) {
      for (var node in nodeList) {
        node.dispose();
      }
    }
    
    // Dispose manual mode controllers
    for (var controller in _catridgeAlasanControllers) {
      controller.dispose();
    }
    for (var controller in _divertAlasanControllers) {
      controller.dispose();
    }
    _pocketAlasanController.dispose();
    
    // NEW: Dispose divert and pocket remark controllers
    for (var controller in _divertRemarkControllers) {
      controller.dispose();
    }
    _pocketRemarkController.dispose();
    
    // NEW: Dispose remark controllers
    for (var controller in _catridgeRemarkControllers) {
      controller.dispose();
    }
    
    // NEW: Dispose field-specific controllers
    for (var controller in _catridgeNoAlasanControllers) {
      controller.dispose();
    }
    for (var controller in _catridgeSealAlasanControllers) {
      controller.dispose();
    }
    for (var controller in _catridgeNoRemarkControllers) {
      controller.dispose();
    }
    for (var controller in _catridgeSealRemarkControllers) {
      controller.dispose();
    }
    
    // NEW: Dispose Divert field-specific controllers
    for (var controller in _divertNoAlasanControllers) {
      controller.dispose();
    }
    for (var controller in _divertSealAlasanControllers) {
      controller.dispose();
    }
    for (var controller in _divertNoRemarkControllers) {
      controller.dispose();
    }
    for (var controller in _divertSealRemarkControllers) {
      controller.dispose();
    }
    
    // NEW: Dispose Pocket field-specific controllers
    _pocketNoAlasanController.dispose();
    _pocketSealAlasanController.dispose();
    _pocketNoRemarkController.dispose();
    _pocketSealRemarkController.dispose();
    
    // Dispose approval form controllers
    _nikTLController.dispose();
    _passwordTLController.dispose();
    _tanggalReplenishController.dispose();
    
    super.dispose();
  }
  
  // Set current time
  void _setCurrentTime() {
    final now = DateTime.now();
    _jamMulaiController.text = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  // Set current date
  void _setCurrentDate() {
    final now = DateTime.now();
    _tanggalReplenishController.text = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }

  // Initialize catridge controllers for the given count
  void _initializeCatridgeControllers(int count) {
    setState(() {
      // Clear existing controllers - dispose first to prevent memory leaks
      for (var controllerList in _catridgeControllers) {
        for (var controller in controllerList) {
          controller.dispose();
        }
      }
      
      // Clear existing focus nodes
      for (var nodeList in _catridgeFocusNodes) {
        for (var node in nodeList) {
          node.dispose();
        }
      }
      
      // Create new list of controllers
      _catridgeControllers = List.generate(
        count,
        (_) => List.generate(
          5, // Each catridge has 5 controllers
          (_) => TextEditingController(),
        ),
      );
      
      // Create new list of focus nodes
      _catridgeFocusNodes = List.generate(
        count,
        (_) => List.generate(
          5, // Each catridge has 5 focus nodes
          (_) => FocusNode(),
        ),
      );
      
      // Initialize section active tracking
      _catridgeSectionActive = List.generate(count, (_) => false);
      
      // Initialize manual mode tracking
      _catridgeManualMode = List.generate(count, (_) => false);
      
      // Clear existing alasan controllers
      for (var controller in _catridgeAlasanControllers) {
        controller.dispose();
      }
      _catridgeAlasanControllers = List.generate(count, (_) => TextEditingController());
      
      // NEW: Initialize popup form state
      _catridgeShowPopup = List.generate(count, (_) => false);
      
      // Clear existing remark controllers
      for (var controller in _catridgeRemarkControllers) {
        controller.dispose();
      }
      _catridgeRemarkControllers = List.generate(count, (_) => TextEditingController());
      _catridgeRemarkFilled = List.generate(count, (_) => false);
      
      // NEW: Initialize field-specific manual mode tracking
      _catridgeNoManualMode = List.generate(count, (_) => false);
      _catridgeSealManualMode = List.generate(count, (_) => false);
      
      // Clear existing field-specific alasan controllers
      for (var controller in _catridgeNoAlasanControllers) {
        controller.dispose();
      }
      for (var controller in _catridgeSealAlasanControllers) {
        controller.dispose();
      }
      _catridgeNoAlasanControllers = List.generate(count, (_) => TextEditingController());
      _catridgeSealAlasanControllers = List.generate(count, (_) => TextEditingController());
      
      // Clear existing field-specific remark controllers
      for (var controller in _catridgeNoRemarkControllers) {
        controller.dispose();
      }
      for (var controller in _catridgeSealRemarkControllers) {
        controller.dispose();
      }
      _catridgeNoRemarkControllers = List.generate(count, (_) => TextEditingController());
      _catridgeSealRemarkControllers = List.generate(count, (_) => TextEditingController());
      _catridgeNoRemarkFilled = List.generate(count, (_) => false);
      _catridgeSealRemarkFilled = List.generate(count, (_) => false);
      
      // Add listeners to all catridge controllers
      for (int i = 0; i < _catridgeControllers.length; i++) {
        for (var controller in _catridgeControllers[i]) {
          // REMOVED: controller.addListener(_checkAndHideApprovalForm);
        }
        
        // NEW: Add special listeners for No. Catridge (index 0) and Seal Catridge (index 1)
        // to trigger manual mode when user starts typing - already handled in focus listeners above
        _catridgeControllers[i][0].addListener(() => _onCatridgeFieldChanged(i, 0));
        _catridgeControllers[i][1].addListener(() => _onCatridgeFieldChanged(i, 1));
        
        // Add listeners for other Catridge fields with duplicate validation
        if (_catridgeControllers[i].length > 2) {
          // Bag Code (index 2) with duplicate validation
          _catridgeControllers[i][2].addListener(() {
            String value = _catridgeControllers[i][2].text.trim();
            if (value.isNotEmpty) {
              String fieldKey = 'catridge_${i}_bag';
              String fieldName = 'Bag Code (Catridge ${i + 1})';
              if (!_validateFieldForDuplicates(value, fieldKey, fieldName)) {
                _catridgeControllers[i][2].clear();
                return;
              }
            }
            _onCatridgeFieldChanged(i, 2);
          });
        }
        
        if (_catridgeControllers[i].length > 3) {
          // Seal Code (index 3) with duplicate validation
          _catridgeControllers[i][3].addListener(() {
            String value = _catridgeControllers[i][3].text.trim();
            if (value.isNotEmpty) {
              String fieldKey = 'catridge_${i}_seal_code';
              String fieldName = 'Seal Code (Catridge ${i + 1})';
              if (!_validateFieldForDuplicates(value, fieldKey, fieldName)) {
                _catridgeControllers[i][3].clear();
                return;
              }
            }
            _onCatridgeFieldChanged(i, 3);
          });
        }
        
        if (_catridgeControllers[i].length > 4) {
          // Seal Code Return (index 4) with duplicate validation
          _catridgeControllers[i][4].addListener(() {
            String value = _catridgeControllers[i][4].text.trim();
            if (value.isNotEmpty) {
              String fieldKey = 'catridge_${i}_seal_return';
              String fieldName = 'Seal Code Return (Catridge ${i + 1})';
              if (!_validateFieldForDuplicates(value, fieldKey, fieldName)) {
                _catridgeControllers[i][4].clear();
                return;
              }
            }
            _onCatridgeFieldChanged(i, 4);
          });
        }
      }
      
      // NEW: Add listeners to field-specific remark controllers to track filled status
      for (int i = 0; i < _catridgeNoRemarkControllers.length; i++) {
        _catridgeNoRemarkControllers[i].addListener(() => _onRemarkChanged(i, 'No. Catridge'));
      }
      for (int i = 0; i < _catridgeSealRemarkControllers.length; i++) {
        _catridgeSealRemarkControllers[i].addListener(() => _onRemarkChanged(i, 'Seal Catridge'));
      }
      
      // Add focus listeners for section highlighting
      for (int i = 0; i < _catridgeFocusNodes.length; i++) {
        for (int j = 0; j < _catridgeFocusNodes[i].length; j++) {
          _catridgeFocusNodes[i][j].addListener(() {
            setState(() {
              _catridgeSectionActive[i] = _catridgeFocusNodes[i].any((node) => node.hasFocus);
            });
          });
        }
      }
      
      // Initialize denom values array - one per catridge
      _denomValues = List.generate(count, (_) => 0);
      
      // Initialize catridge data array - one per catridge
      _catridgeData = List.generate(count, (_) => null);
      
      // Clear detail items for consistency
      _detailCatridgeItems = [];
      
      // IMPORTANT: Re-setup focus listeners for API calls after creating new FocusNodes
      // Remove existing listeners first, then reset flag and re-add
      _removeFocusListeners();
      _setupFocusListeners();
      
      print('Initialized $count catridge controllers and data arrays');
    });
  }
  
  // Clear all data and hide approval form
  void _clearAllData() {
    setState(() {
      // Clear controllers
      _idCRFController.clear();
      _jamMulaiController.clear();
      
      // Clear catridge controllers
      for (var controllerList in _catridgeControllers) {
        for (var controller in controllerList) {
          controller.clear();
        }
      }
      
      // Clear data
      _prepareData = null;
      _detailCatridgeItems.clear();
      _catridgeData.clear();
      _denomValues.clear();
      _errorMessage = '';
      
      // Hide approval form
      _showApprovalForm = false;
      _nikTLController.clear();
      _passwordTLController.clear();
    });
    
    // Reset time to current time
    _setCurrentTime();
  }
  
  // Check if any left side field is empty
  bool _hasAnyLeftFieldEmpty() {
    // Check header fields
    if (_idCRFController.text.trim().isEmpty) return true;
    if (_jamMulaiController.text.trim().isEmpty) return true;
    
    // Check all catridge fields
    for (var controllerList in _catridgeControllers) {
      for (var controller in controllerList) {
        if (controller.text.trim().isEmpty) return true;
      }
    }
    
    // Check if there's no prepare data
    if (_prepareData == null) return true;
    
    // Check if there are no detail catridge items
    if (_detailCatridgeItems.isEmpty) return true;
    
    return false;
  }
  
  // Auto-hide approval form if any left field is empty
  // DEPRECATED: No longer needed with modal validation system
  // void _checkAndHideApprovalForm() {
  //   if (_showApprovalForm && _hasAnyLeftFieldEmpty()) {
  //     setState(() {
  //       _showApprovalForm = false;
  //       _nikTLController.clear();
  //       _passwordTLController.clear();
  //     });
  //   }
  // }
  
  // NEW: Handle catridge field changes to trigger manual mode per field
  void _onCatridgeFieldChanged(int catridgeIndex, int fieldIndex) {
    if (catridgeIndex >= 0 && catridgeIndex < _catridgeControllers.length) {
      String fieldValue = _catridgeControllers[catridgeIndex][fieldIndex].text;
      
      setState(() {
        if (fieldValue.isNotEmpty) {
          // Set manual mode status when user starts typing
          // Set general manual mode status for the catridge section
          if (catridgeIndex < _catridgeManualMode.length) {
            _catridgeManualMode[catridgeIndex] = true;
          }
          
          // Also set field-specific manual mode status
          if (fieldIndex == 0 && catridgeIndex < _catridgeNoManualMode.length) {
            _catridgeNoManualMode[catridgeIndex] = true;
          } else if (fieldIndex == 1 && catridgeIndex < _catridgeSealManualMode.length) {
            _catridgeSealManualMode[catridgeIndex] = true;
          }
        }
        // REMOVED: Reset manual mode logic when field is cleared
        // Manual mode should only be reset after successful scan, not when field changes
      });
    }
  }
  
  // Method to update specific field in DetailCatridgeItem
  void _updateDetailCatridgeItemField(int catridgeIndex, String fieldName, String value) {
    setState(() {
      // Find existing item by index (catridgeIndex + 1)
      int existingIndex = _detailCatridgeItems.indexWhere((item) => item.index == catridgeIndex + 1);
      
      if (existingIndex >= 0) {
        // Update existing item
        DetailCatridgeItem currentItem = _detailCatridgeItems[existingIndex];
        _detailCatridgeItems[existingIndex] = DetailCatridgeItem(
          index: currentItem.index,
          noCatridge: currentItem.noCatridge,
          sealCatridge: currentItem.sealCatridge,
          value: currentItem.value,
          total: currentItem.total,
          denom: currentItem.denom,
          bagCode: fieldName == 'bagCode' ? value : currentItem.bagCode,
          sealCode: fieldName == 'sealCode' ? value : currentItem.sealCode,
          sealReturn: fieldName == 'sealReturn' ? value : currentItem.sealReturn,
        );
        print('🔄 CATRIDGE FIELD: Updated existing item at index $existingIndex with $fieldName: $value');
      } else {
        // Create new item if not exists
        String noCatridge = '';
        if (catridgeIndex < _catridgeControllers.length && _catridgeControllers[catridgeIndex].isNotEmpty) {
          noCatridge = _catridgeControllers[catridgeIndex][0].text.trim();
        }
        
        DetailCatridgeItem newItem = DetailCatridgeItem(
          index: catridgeIndex + 1,
          noCatridge: noCatridge,
          sealCatridge: '',
          value: 0,
          total: '0',
          denom: '',
          bagCode: fieldName == 'bagCode' ? value : '',
          sealCode: fieldName == 'sealCode' ? value : '',
          sealReturn: fieldName == 'sealReturn' ? value : '',
        );
        
        _detailCatridgeItems.add(newItem);
        _detailCatridgeItems.sort((a, b) => a.index.compareTo(b.index));
        print('🔄 CATRIDGE FIELD: Created new item for catridge $catridgeIndex with $fieldName: $value');
      }
    });
  }
  
  // Method to update specific field in DetailDivertItem
  void _updateDetailDivertItemField(int divertIndex, String fieldName, String value) {
    setState(() {
      // Ensure _divertDetailItems has enough elements
      while (_divertDetailItems.length <= divertIndex) {
        _divertDetailItems.add(null);
      }
      
      DetailCatridgeItem? currentItem = _divertDetailItems[divertIndex];
      
      if (currentItem != null) {
        // Update existing item
        _divertDetailItems[divertIndex] = DetailCatridgeItem(
          index: currentItem.index,
          noCatridge: currentItem.noCatridge,
          sealCatridge: currentItem.sealCatridge,
          value: currentItem.value,
          total: currentItem.total,
          denom: currentItem.denom,
          bagCode: fieldName == 'bagCode' ? value : currentItem.bagCode,
          sealCode: fieldName == 'sealCode' ? value : currentItem.sealCode,
          sealReturn: fieldName == 'sealReturn' ? value : currentItem.sealReturn,
        );
        
        // Also update corresponding item in _detailCatridgeItems
        int detailIndex = _detailCatridgeItems.indexWhere((item) => item.index == currentItem.index);
        if (detailIndex != -1) {
          _detailCatridgeItems[detailIndex] = DetailCatridgeItem(
            index: currentItem.index,
            noCatridge: currentItem.noCatridge,
            sealCatridge: currentItem.sealCatridge,
            value: currentItem.value,
            total: currentItem.total,
            denom: currentItem.denom,
            bagCode: fieldName == 'bagCode' ? value : currentItem.bagCode,
            sealCode: fieldName == 'sealCode' ? value : currentItem.sealCode,
            sealReturn: fieldName == 'sealReturn' ? value : currentItem.sealReturn,
          );
        }
      } else {
        // Create new item if it doesn't exist
        String noCatridge = divertIndex < _divertControllers.length ? _divertControllers[divertIndex][0].text.trim() : '';
        String sealCatridge = divertIndex < _divertControllers.length ? _divertControllers[divertIndex][1].text.trim() : '';
        String bagCode = divertIndex < _divertControllers.length ? _divertControllers[divertIndex][2].text.trim() : '';
        String sealCode = divertIndex < _divertControllers.length ? _divertControllers[divertIndex][3].text.trim() : '';
        String sealReturn = divertIndex < _divertControllers.length ? _divertControllers[divertIndex][4].text.trim() : '';
        
        int itemIndex = 100 + divertIndex; // Divert index starts from 100
        
        DetailCatridgeItem newItem = DetailCatridgeItem(
           index: itemIndex,
           noCatridge: noCatridge,
           sealCatridge: sealCatridge,
           value: 0,
           total: '0',
           denom: '',
           bagCode: fieldName == 'bagCode' ? value : bagCode,
           sealCode: fieldName == 'sealCode' ? value : sealCode,
           sealReturn: fieldName == 'sealReturn' ? value : sealReturn,
         );
        
        _divertDetailItems[divertIndex] = newItem;
        
        // Also add to _detailCatridgeItems
        _detailCatridgeItems.add(newItem);
        
        print('🔄 DIVERT FIELD: Created new divert item for section $divertIndex with $fieldName: $value');
      }
    });
  }
  
  // Method to update specific field in DetailPocketItem
  void _updateDetailPocketItemField(String fieldName, String value) {
    setState(() {
      if (_pocketDetailItem != null) {
        // Update existing item
        _pocketDetailItem = DetailCatridgeItem(
          index: _pocketDetailItem!.index,
          noCatridge: _pocketDetailItem!.noCatridge,
          sealCatridge: _pocketDetailItem!.sealCatridge,
          value: _pocketDetailItem!.value,
          total: _pocketDetailItem!.total,
          denom: _pocketDetailItem!.denom,
          bagCode: fieldName == 'bagCode' ? value : _pocketDetailItem!.bagCode,
          sealCode: fieldName == 'sealCode' ? value : _pocketDetailItem!.sealCode,
          sealReturn: fieldName == 'sealReturn' ? value : _pocketDetailItem!.sealReturn,
        );
        
        // Also update corresponding item in _detailCatridgeItems
        int detailIndex = _detailCatridgeItems.indexWhere((item) => item.index == _pocketDetailItem!.index);
        if (detailIndex != -1) {
          _detailCatridgeItems[detailIndex] = DetailCatridgeItem(
            index: _pocketDetailItem!.index,
            noCatridge: _pocketDetailItem!.noCatridge,
            sealCatridge: _pocketDetailItem!.sealCatridge,
            value: _pocketDetailItem!.value,
            total: _pocketDetailItem!.total,
            denom: _pocketDetailItem!.denom,
            bagCode: fieldName == 'bagCode' ? value : _pocketDetailItem!.bagCode,
            sealCode: fieldName == 'sealCode' ? value : _pocketDetailItem!.sealCode,
            sealReturn: fieldName == 'sealReturn' ? value : _pocketDetailItem!.sealReturn,
          );
        }
      } else {
        // Create new item if it doesn't exist
        String noCatridge = _pocketControllers[0].text.trim();
        String sealCatridge = _pocketControllers[1].text.trim();
        String bagCode = _pocketControllers[2].text.trim();
        String sealCode = _pocketControllers[3].text.trim();
        String sealReturn = _pocketControllers[4].text.trim();
        
        int itemIndex = 200; // Pocket index is 200
        
        DetailCatridgeItem newItem = DetailCatridgeItem(
           index: itemIndex,
           noCatridge: noCatridge,
           sealCatridge: sealCatridge,
           value: 0,
           total: '0',
           denom: '',
           bagCode: fieldName == 'bagCode' ? value : bagCode,
           sealCode: fieldName == 'sealCode' ? value : sealCode,
           sealReturn: fieldName == 'sealReturn' ? value : sealReturn,
         );
        
        _pocketDetailItem = newItem;
        
        // Also add to _detailCatridgeItems
        _detailCatridgeItems.add(newItem);
        
        print('🔄 POCKET FIELD: Created new pocket item with $fieldName: $value');
      }
    });
  }
  
  // NEW: Handle remark field changes to track filled status per field
  void _onRemarkChanged(int catridgeIndex, String fieldType) {
    if (catridgeIndex >= 0) {
      setState(() {
        if (fieldType == 'No. Catridge' && catridgeIndex < _catridgeNoRemarkFilled.length) {
          // Check both remark and alasan are filled for validation
          _catridgeNoRemarkFilled[catridgeIndex] = 
              _catridgeNoRemarkControllers[catridgeIndex].text.trim().isNotEmpty &&
              catridgeIndex < _catridgeNoAlasanControllers.length &&
              _catridgeNoAlasanControllers[catridgeIndex].text.trim().isNotEmpty;
        } else if (fieldType == 'Seal Catridge' && catridgeIndex < _catridgeSealRemarkFilled.length) {
          // Check both remark and alasan are filled for validation
          _catridgeSealRemarkFilled[catridgeIndex] = 
              _catridgeSealRemarkControllers[catridgeIndex].text.trim().isNotEmpty &&
              catridgeIndex < _catridgeSealAlasanControllers.length &&
              _catridgeSealAlasanControllers[catridgeIndex].text.trim().isNotEmpty;
        }
      });
    }
  }
  
  // NEW: Debounce API call method
  void _debounceApiCall(String key, VoidCallback callback) {
    // Cancel existing timer for this key
    _debounceTimers[key]?.cancel();
    
    // Create new timer
    _debounceTimers[key] = Timer(const Duration(milliseconds: 2000), () {
      callback();
      _debounceTimers[key] = null;
    });
  }
  
  // NEW: Check if manual icon should be shown for specific field
  bool _shouldShowManualIcon(int catridgeIndex, String label) {
    // Handle Catridge section (catridgeIndex >= 100 indicates catridge section)
    if (catridgeIndex >= 100) {
      int actualIndex = catridgeIndex - 100;
      if (actualIndex < _catridgeControllers.length) {
        if (label == 'No. Catridge') {
          // Show icon only if field has content AND manual mode is active for No. Catridge
          return _catridgeControllers[actualIndex][0].text.isNotEmpty && 
                 actualIndex < _catridgeNoManualMode.length && 
                 _catridgeNoManualMode[actualIndex];
        } else if (label == 'Seal Catridge') {
          // Show icon only if field has content AND manual mode is active for Seal Catridge
          return _catridgeControllers[actualIndex][1].text.isNotEmpty && 
                 actualIndex < _catridgeSealManualMode.length && 
                 _catridgeSealManualMode[actualIndex];
        }
      }
    }
    // Handle Divert section (catridgeIndex 0-2 for divert sections)
    else if (catridgeIndex >= 0 && catridgeIndex < 3 && catridgeIndex < _divertControllers.length) {
      // Show icon only if field has content AND manual mode is active for specific field
      bool hasContent = false;
      bool isManualMode = false;
      if (label == 'No. Catridge') {
        hasContent = _divertControllers[catridgeIndex][0].text.isNotEmpty;
        isManualMode = catridgeIndex < _divertNoManualMode.length && _divertNoManualMode[catridgeIndex];
      } else if (label == 'Seal Catridge') {
        hasContent = _divertControllers[catridgeIndex][1].text.isNotEmpty;
        isManualMode = catridgeIndex < _divertSealManualMode.length && _divertSealManualMode[catridgeIndex];
      }
      return hasContent && isManualMode;
    }
    // Handle Pocket section (catridgeIndex 50 for pocket)
    else if (catridgeIndex == 50 && _pocketControllers.isNotEmpty) {
      // Show icon only if field has content AND manual mode is active for specific field
      bool hasContent = false;
      bool isManualMode = false;
      if (label == 'No. Catridge') {
        hasContent = _pocketControllers[0].text.isNotEmpty;
        isManualMode = _pocketNoManualMode;
      } else if (label == 'Seal Catridge') {
        hasContent = _pocketControllers[1].text.isNotEmpty;
        isManualMode = _pocketSealManualMode;
      }
      return hasContent && isManualMode;
    }
    
    return false;
  }
  
  // NEW: Build field-specific manual mode icon
  Widget _buildFieldSpecificManualIcon(int catridgeIndex, String label, bool isSmallScreen) {
    // Check if remark is filled for this specific field
    bool isRemarkFilled = false;
    
    // Handle Catridge section (catridgeIndex >= 100 indicates catridge section)
    if (catridgeIndex >= 100) {
      int actualIndex = catridgeIndex - 100;
      if (actualIndex < _catridgeControllers.length) {
        if (label == 'No. Catridge') {
          isRemarkFilled = actualIndex < _catridgeNoRemarkFilled.length && _catridgeNoRemarkFilled[actualIndex];
        } else if (label == 'Seal Catridge') {
          isRemarkFilled = actualIndex < _catridgeSealRemarkFilled.length && _catridgeSealRemarkFilled[actualIndex];
        }
      }
    }
    // Handle Divert section (catridgeIndex 0-2 for divert sections)
    else if (catridgeIndex >= 0 && catridgeIndex < 3 && catridgeIndex < _divertControllers.length) {
      // For divert, check if remark is filled for specific field
      if (label == 'No. Catridge') {
        isRemarkFilled = catridgeIndex < _divertNoRemarkFilled.length && _divertNoRemarkFilled[catridgeIndex];
      } else if (label == 'Seal Catridge') {
        isRemarkFilled = catridgeIndex < _divertSealRemarkFilled.length && _divertSealRemarkFilled[catridgeIndex];
      }
    }
    // Handle Pocket section (catridgeIndex 50 for pocket)
    else if (catridgeIndex == 50 && _pocketControllers.isNotEmpty) {
      // For pocket, check if remark is filled for specific field
      if (label == 'No. Catridge') {
        isRemarkFilled = _pocketNoRemarkFilled;
      } else if (label == 'Seal Catridge') {
        isRemarkFilled = _pocketSealRemarkFilled;
      }
    }
    
    // Always show ManualModeIcon_notdone.png when field has content, ManualModeIcon_done.png when remark filled
    String iconPath = isRemarkFilled 
        ? 'assets/images/ManualModeIcon_done.png'
        : 'assets/images/ManualModeIcon_notdone.png';
    
    return Image.asset(
      iconPath,
      width: isSmallScreen ? 20 : 24,
      height: isSmallScreen ? 20 : 24,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to icon if image not found
        return Icon(
          Icons.edit,
          size: isSmallScreen ? 20 : 24,
          color: isRemarkFilled ? Colors.green : Colors.grey,
        );
      },
    );
  }
  
  // NEW: Build manual mode icon based on status
   Widget _buildManualModeIcon(int catridgeIndex, bool isSmallScreen) {
     // Check if manual mode is active and remark is filled
     bool isManualMode = catridgeIndex < _catridgeManualMode.length && _catridgeManualMode[catridgeIndex];
     bool isRemarkFilled = catridgeIndex < _catridgeRemarkFilled.length && _catridgeRemarkFilled[catridgeIndex];
     
     String iconPath;
     if (isManualMode && isRemarkFilled) {
       iconPath = 'assets/images/ManualModeIcon_done.png';
     } else if (isManualMode) {
       iconPath = 'assets/images/ManualModeIcon_notdone.png';
     } else {
       // Default edit icon when not in manual mode
       return Icon(
         Icons.edit,
         size: isSmallScreen ? 20 : 24,
         color: Colors.grey,
       );
     }
     
     return Image.asset(
       iconPath,
       width: isSmallScreen ? 20 : 24,
       height: isSmallScreen ? 20 : 24,
       errorBuilder: (context, error, stackTrace) {
         // Fallback to icon if image not found
         return Icon(
           Icons.edit,
           size: isSmallScreen ? 20 : 24,
           color: isManualMode ? (isRemarkFilled ? Colors.green : Colors.orange) : Colors.grey,
         );
       },
     );
   }
   
   // NEW: Show manual mode popup form positioned next to icon
   void _showManualModePopup(int catridgeIndex, [String? fieldType, Offset? iconPosition]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Get screen size for responsive design
        final screenSize = MediaQuery.of(context).size;
        final isSmallScreen = screenSize.width < 600;
        
        // Determine section type based on catridgeIndex
        String sectionType = 'catridge';
        TextEditingController fieldController;
        TextEditingController alasanController;
        TextEditingController remarkController;
        
        if (catridgeIndex >= 100) {
          // Catridge section (catridgeIndex >= 100)
          int actualIndex = catridgeIndex - 100;
          sectionType = 'catridge';
          fieldController = fieldType == 'Seal Catridge' 
              ? _catridgeControllers[actualIndex][1] 
              : _catridgeControllers[actualIndex][0];
          alasanController = fieldType == 'No. Catridge' 
              ? _catridgeNoAlasanControllers[actualIndex]
              : _catridgeSealAlasanControllers[actualIndex];
          remarkController = fieldType == 'No. Catridge' 
              ? _catridgeNoRemarkControllers[actualIndex]
              : _catridgeSealRemarkControllers[actualIndex];
        } else if (catridgeIndex >= 0 && catridgeIndex < 3 && catridgeIndex < _divertControllers.length) {
          // Divert section (catridgeIndex 0-2)
          sectionType = 'divert';
          fieldController = fieldType == 'Seal Catridge' 
              ? _divertControllers[catridgeIndex][1] 
              : _divertControllers[catridgeIndex][0];
          // Gunakan controller alasan dan remark yang terpisah
          if (fieldType == 'No. Catridge') {
            alasanController = _divertNoAlasanControllers[catridgeIndex];
            remarkController = _divertNoRemarkControllers[catridgeIndex];
          } else { // Seal Catridge
            alasanController = _divertSealAlasanControllers[catridgeIndex];
            remarkController = _divertSealRemarkControllers[catridgeIndex];
          }
        } else if (catridgeIndex == 50) {
          // Pocket section (catridgeIndex 50)
          sectionType = 'pocket';
          fieldController = fieldType == 'Seal Catridge' 
              ? _pocketControllers[1] 
              : _pocketControllers[0];
          // Gunakan controller alasan dan remark yang terpisah
          if (fieldType == 'No. Catridge') {
            alasanController = _pocketNoAlasanController;
            remarkController = _pocketNoRemarkController;
          } else { // Seal Catridge
            alasanController = _pocketSealAlasanController;
            remarkController = _pocketSealRemarkController;
          }
        } else {
          // Default fallback
          sectionType = 'unknown';
          fieldController = TextEditingController();
          alasanController = TextEditingController();
          remarkController = TextEditingController();
        }
        
        // Calculate position next to icon if provided
        Widget dialogWidget = StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Container(
              width: isSmallScreen ? screenSize.width * 0.9 : 320, // Smaller width
              constraints: BoxConstraints(
                maxHeight: screenSize.height * 0.7, // Prevent overflow
              ),
              padding: EdgeInsets.all(12), // Reduced padding
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView( // Add scroll support
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with icon (compact)
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/ManualModeIcon_notdone.png',
                            width: 20, // Smaller icon
                            height: 20,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.edit, size: 20, color: Colors.orange);
                            },
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Detail Manual ${sectionType.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 14, // Smaller font
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10), // Reduced spacing
                      
                      // Inline No. Catridge field
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              'No. Catridge',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(' : ', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: Text(
                              fieldController.text.isNotEmpty ? fieldController.text : 'ATM XXXXXX',
                              style: TextStyle(fontSize: 12, color: fieldController.text.isNotEmpty ? Colors.black : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      
                      // Inline Alasan field with dropdown
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              'Alasan',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(' : ', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: alasanController.text.isNotEmpty ? alasanController.text : null,
                                hint: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Pilih alasan',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ),
                                    Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                                  ],
                                ),
                                isExpanded: true,
                                style: TextStyle(fontSize: 12, color: Colors.black),
                                items: [
                                  DropdownMenuItem(value: 'Segel Tidak Terbaca', child: Text('Segel Tidak Terbaca', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Scanner Rusak', child: Text('Scanner Rusak', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Kaset Berbeda', child: Text('Kaset Berbeda', style: TextStyle(fontSize: 12))),
                                ],
                                onChanged: (value) {
                                  if (value != null) {
                                    // Update dialog state immediately for UI refresh
                                    setDialogState(() {
                                      alasanController.text = value;
                                    });
                                    
                                    // Update main widget state for data persistence
                                    setState(() {
                                      // Update status remark filled berdasarkan section
                                      if (sectionType == 'divert') {
                                        if (catridgeIndex >= 0 && catridgeIndex < 3) {
                                          if (fieldType == 'No. Catridge' || fieldType == null) {
                                            _divertNoAlasanControllers[catridgeIndex].text = value;
                                            _divertNoRemarkFilled[catridgeIndex] = 
                                                _divertNoRemarkControllers[catridgeIndex].text.trim().isNotEmpty &&
                                                _divertNoAlasanControllers[catridgeIndex].text.trim().isNotEmpty;
                                          } else if (fieldType == 'Seal Catridge') {
                                            _divertSealAlasanControllers[catridgeIndex].text = value;
                                            _divertSealRemarkFilled[catridgeIndex] = 
                                                _divertSealRemarkControllers[catridgeIndex].text.trim().isNotEmpty &&
                                                _divertSealAlasanControllers[catridgeIndex].text.trim().isNotEmpty;
                                          }
                                        }
                                      } else if (sectionType == 'pocket') {
                                        if (fieldType == 'No. Catridge' || fieldType == null) {
                                          _pocketNoAlasanController.text = value;
                                          _pocketNoRemarkFilled = _pocketNoRemarkController.text.trim().isNotEmpty &&
                                                             _pocketNoAlasanController.text.trim().isNotEmpty;
                                        } else if (fieldType == 'Seal Catridge') {
                                          _pocketSealAlasanController.text = value;
                                          _pocketSealRemarkFilled = _pocketSealRemarkController.text.trim().isNotEmpty &&
                                                               _pocketSealAlasanController.text.trim().isNotEmpty;
                                        }
                                      } else if (sectionType == 'catridge') {
                                        if (fieldType == 'No. Catridge' || fieldType == null) {
                                          _catridgeNoAlasanControllers[catridgeIndex].text = value;
                                          _catridgeNoRemarkFilled[catridgeIndex] = 
                                              _catridgeNoRemarkControllers[catridgeIndex].text.trim().isNotEmpty &&
                                              _catridgeNoAlasanControllers[catridgeIndex].text.trim().isNotEmpty;
                                        } else if (fieldType == 'Seal Catridge') {
                                          _catridgeSealAlasanControllers[catridgeIndex].text = value;
                                          _catridgeSealRemarkFilled[catridgeIndex] = 
                                              _catridgeSealRemarkControllers[catridgeIndex].text.trim().isNotEmpty &&
                                              _catridgeSealAlasanControllers[catridgeIndex].text.trim().isNotEmpty;
                                        }
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                  
                  // Divider line
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 12),
                    height: 1,
                    color: Colors.grey[300],
                  ),
                  
                  // Inline Remark field with larger input area
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              'Remark',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(' : ', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 60, // Larger height for remark input
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: TextField(
                          controller: remarkController,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Wajib diisi',
                            hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          style: TextStyle(fontSize: 12),
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          onChanged: (value) {
                            setState(() {
                              // Update field-specific remark filled status based on section
                              if (sectionType == 'catridge') {
                                _onRemarkChanged(catridgeIndex, fieldType ?? 'No. Catridge');
                              } else if (sectionType == 'divert') {
                                // Update divert remark status directly here
                                if (catridgeIndex >= 0 && catridgeIndex < 3) {
                                  if (fieldType == 'No. Catridge' || fieldType == null) {
                                    _divertNoRemarkControllers[catridgeIndex].text = value;
                                    _divertNoRemarkFilled[catridgeIndex] = 
                                        _divertNoRemarkControllers[catridgeIndex].text.trim().isNotEmpty &&
                                        _divertNoAlasanControllers[catridgeIndex].text.trim().isNotEmpty;
                                  } else if (fieldType == 'Seal Catridge') {
                                    _divertSealRemarkControllers[catridgeIndex].text = value;
                                    _divertSealRemarkFilled[catridgeIndex] = 
                                        _divertSealRemarkControllers[catridgeIndex].text.trim().isNotEmpty &&
                                        _divertSealAlasanControllers[catridgeIndex].text.trim().isNotEmpty;
                                  }
                                }
                              } else if (sectionType == 'pocket') {
                                // Update pocket remark status directly here
                                if (fieldType == 'No. Catridge' || fieldType == null) {
                                  _pocketNoRemarkController.text = value;
                                  _pocketNoRemarkFilled = _pocketNoRemarkController.text.trim().isNotEmpty &&
                                                         _pocketNoAlasanController.text.trim().isNotEmpty;
                                } else if (fieldType == 'Seal Catridge') {
                                  _pocketSealRemarkController.text = value;
                                  _pocketSealRemarkFilled = _pocketSealRemarkController.text.trim().isNotEmpty &&
                                                           _pocketSealAlasanController.text.trim().isNotEmpty;
                                }
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  
                  // Buttons (compact)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('Tutup', style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
              );
            },
          );
        
        // Position dialog next to icon if position provided
        if (iconPosition != null) {
          return Stack(
            children: [
              // Transparent barrier
              GestureDetector(
                onTap: () {}, // Prevent closing on tap outside
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.transparent,
                ),
              ),
              // Positioned dialog
              Positioned(
                left: iconPosition.dx.clamp(0, screenSize.width - 320), // Ensure popup stays within screen bounds
                top: iconPosition.dy.clamp(50, screenSize.height - 400), // Ensure popup stays within screen bounds
                child: Material(
                  color: Colors.transparent,
                  child: dialogWidget,
                ),
              ),
            ],
          );
        } else {
          // Fallback to center dialog
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: dialogWidget,
          );
        }
      },
    );
  }
  
  // Step 1: Lookup catridge and create initial detail item
  Future<void> _lookupCatridgeAndCreateDetail(int catridgeIndex, String catridgeCode) async {
    if (catridgeCode.isEmpty || !mounted) {
      print('🔍 CATRIDGE LOOKUP: Skipped - catridgeCode empty or widget not mounted (index: $catridgeIndex)');
      return;
    }
    
    print('🔍 CATRIDGE LOOKUP: Starting lookup for catridge: $catridgeCode (index: $catridgeIndex)');
    
    try {
      print('=== STEP 1: LOOKUP CATRIDGE ===');
      print('Catridge Index: $catridgeIndex');
      print('Catridge Code: $catridgeCode');
      
      // Get branch code
      String branchCode = "1"; // Default
      if (_prepareData != null && _prepareData!.branchCode.isNotEmpty) {
        branchCode = _prepareData!.branchCode;
      }
      
      // Get required standValue from prepare data for validation
      int? requiredStandValue = _prepareData?.standValue;
      
      // Get list of existing catridge codes
      List<String> existingCatridges = [];
      for (var item in _detailCatridgeItems) {
        if (item.noCatridge.isNotEmpty) {
          existingCatridges.add(item.noCatridge);
        }
      }
      // Add divert catridges from all sections
      for (int i = 0; i < _divertDetailItems.length; i++) {
        if (_divertDetailItems[i]?.noCatridge.isNotEmpty == true) {
          existingCatridges.add(_divertDetailItems[i]!.noCatridge);
        }
      }
      if (_pocketDetailItem?.noCatridge.isNotEmpty == true) {
        existingCatridges.add(_pocketDetailItem!.noCatridge);
      }
      
      // Remove the current catridge from existing list if we're updating
      if (_catridgeControllers.length > catridgeIndex && 
          _catridgeControllers[catridgeIndex][0].text.isNotEmpty &&
          existingCatridges.contains(_catridgeControllers[catridgeIndex][0].text)) {
        existingCatridges.remove(_catridgeControllers[catridgeIndex][0].text);
      }
      
      print('Using requiredStandValue for validation: $requiredStandValue');
      print('Using branchCode: $branchCode');
      print('Existing catridges: $existingCatridges');
      
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });
      
      // API call to get catridge details with comprehensive validation
      print('🔍 CATRIDGE LOOKUP: Calling API getCatridgeDetails...');
      final response = await _apiService.getCatridgeDetails(
        branchCode, 
        catridgeCode, 
        requiredStandValue: requiredStandValue,
        requiredType: 'C', // Main catridge must be type C
        existingCatridges: existingCatridges,
        idTool: _idCRFController.text.trim(), // Pass ID CRF as IdTool parameter
      );
      
      setState(() {
        _isLoading = false;
      });
      
      print('🔍 CATRIDGE LOOKUP: API Response - success: ${response.success}, message: ${response.message}');
      print('🔍 CATRIDGE LOOKUP: Response data type: ${response.data?.runtimeType}, length: ${response.data is List ? (response.data as List).length : 'N/A'}');
      print('Catridge lookup response: ${response.success}, message: ${response.message}');
      
      if (response.success && response.data != null && response.data is List && response.data.length > 0 && mounted) {
        print('🔍 CATRIDGE LOOKUP: Processing response with ${response.data.length} catridges');
        print('Found ${response.data.length} catridges');
        
        // Enhanced data validation
        final dataList = response.data as List;
        final firstItem = dataList[0];
        
        if (firstItem == null) {
          throw Exception('First item in response data is null');
        }
        
        if (firstItem is! Map<String, dynamic>) {
          throw Exception('First item is not a Map<String, dynamic>, got: ${firstItem.runtimeType}');
        }
        
        print('🔍 CATRIDGE LOOKUP: First item keys: ${firstItem.keys.toList()}');
        print('First catridge data: $firstItem');
        
        // Safe parsing with enhanced error handling
        final catridgeData = CatridgeData.fromJson(firstItem);
        print('🔍 CATRIDGE LOOKUP: Parsed CatridgeData - code: ${catridgeData.code}, standValue: ${catridgeData.standValue}, type: ${catridgeData.typeCatridge}');
        print('Parsed catridge: Code=${catridgeData.code}, StandValue=${catridgeData.standValue}');
        
        // Validate that this is actually a Catridge type
        if (catridgeData.typeCatridge.toUpperCase() != 'C') {
          throw Exception('Catridge type mismatch: expected C (Catridge), got ${catridgeData.typeCatridge}');
        }
        
        // Safe standValue handling
        if (catridgeData.standValue.isNaN || catridgeData.standValue.isInfinite) {
          throw Exception('Invalid standValue: ${catridgeData.standValue}');
        }
        
        // Calculate denom amount
        String tipeDenom = _prepareData?.tipeDenom ?? 'A50';
        int denomAmount = 0;
        String denomText = '';
        
        if (tipeDenom == 'A50') {
          denomAmount = 50000;
          denomText = 'Rp 50.000';
        } else if (tipeDenom == 'A100') {
          denomAmount = 100000;
          denomText = 'Rp 100.000';
        } else {
          denomAmount = 50000;
          denomText = 'Rp 50.000';
        }
        
        // Use standValue from prepare data or catridge data
        int actualStandValue = _prepareData?.standValue ?? catridgeData.standValue.round();
        
        // Calculate total
        int totalNominal = denomAmount * actualStandValue;
        String formattedTotal = _formatCurrency(totalNominal);
        
        // Auto-populate seal if available from prepare data
        String autoSeal = '';
        if (_prepareData != null && catridgeIndex == 0) {
          // For first catridge, try to use seal from prepare data
          if (_prepareData!.catridgeSeal.isNotEmpty) {
            autoSeal = _prepareData!.catridgeSeal;
            // Also populate the controller
            if (_catridgeControllers.length > catridgeIndex && _catridgeControllers[catridgeIndex].length > 1) {
              _catridgeControllers[catridgeIndex][1].text = autoSeal;
            }
          }
        }
        
        // Create initial detail item
        final detailItem = DetailCatridgeItem(
          index: catridgeIndex + 1,
          noCatridge: catridgeData.code, // Use the code from the response
          sealCatridge: autoSeal, // Auto-populated or empty
          value: actualStandValue,
          total: formattedTotal,
          denom: denomText,
          bagCode: '',
          sealCode: '',
          sealReturn: '',
        );
        
        setState(() {
          // Store catridge data for reference
          if (catridgeIndex >= 0 && catridgeIndex < _catridgeData.length) {
            _catridgeData[catridgeIndex] = catridgeData;
          } else {
            // Ensure catridgeData list is large enough
            while (_catridgeData.length <= catridgeIndex) {
              _catridgeData.add(null);
            }
            _catridgeData[catridgeIndex] = catridgeData;
          }
          
          // NEW: Override manual data when scan barcode is successful
          if (_catridgeControllers.length > catridgeIndex) {
            _catridgeControllers[catridgeIndex][0].text = catridgeData.code;
            
            // Manual mode reset is now handled in scanner callback
            print('✅ SUCCESS: Catridge data populated for catridge $catridgeIndex');
          }
          
          // Check if item already exists for this index
          int existingIndex = _detailCatridgeItems.indexWhere((item) => item.index == catridgeIndex + 1);
          if (existingIndex >= 0) {
            // Update existing item but keep seal if already filled
            var existingItem = _detailCatridgeItems[existingIndex];
            _detailCatridgeItems[existingIndex] = DetailCatridgeItem(
              index: detailItem.index,
              noCatridge: detailItem.noCatridge,
              sealCatridge: existingItem.sealCatridge.isNotEmpty ? existingItem.sealCatridge : autoSeal,
              value: detailItem.value,
              total: detailItem.total,
              denom: detailItem.denom,
              bagCode: existingItem.bagCode,
              sealCode: existingItem.sealCode,
              sealReturn: existingItem.sealReturn,
            );
            print('Updated existing detail item at index $existingIndex');
          } else {
            // Add new item
            _detailCatridgeItems.add(detailItem);
            print('Added new detail item: ${detailItem.noCatridge}');
          }
          
          // Sort by index
          _detailCatridgeItems.sort((a, b) => a.index.compareTo(b.index));
          print('Total detail items now: ${_detailCatridgeItems.length}');
          
          // Update denom values array for consistency
          if (catridgeIndex >= 0 && catridgeIndex < _denomValues.length) {
            _denomValues[catridgeIndex] = actualStandValue;
          } else {
            // Ensure denomValues list is large enough
            while (_denomValues.length <= catridgeIndex) {
              _denomValues.add(0);
            }
            _denomValues[catridgeIndex] = actualStandValue;
          }
        });
        
        // Check if approval form should be hidden
        // REMOVED: _checkAndHideApprovalForm();
        
        CustomModals.showSuccessModal(
          context: context,
          message: 'Catridge berhasil ditemukan: ${catridgeData.code}',
        );
      } else {
        // Handle API response error or empty data
        String errorMessage = 'Catridge tidak ditemukan';
        if (!response.success && response.message.isNotEmpty) {
          // Use API error message if available
          errorMessage = response.message;
        } else if (response.success && (response.data == null || (response.data is List && response.data.length == 0))) {
          // Empty data with success response (should not happen with new logic)
          errorMessage = 'Catridge tidak ditemukan atau tidak sesuai kriteria';
        }
        
        // Don't create error detail item - just show error message
        // REMOVED: _createErrorDetailItem(catridgeIndex, catridgeCode, errorMessage);
        
        // Check if approval form should be hidden
        // REMOVED: // REMOVED: _checkAndHideApprovalForm();
        
        // Show error to user with reset callback
        CustomModals.showFailedModal(
          context: context,
          message: errorMessage,
          onPressed: () {
            Navigator.of(context).pop();
            // Reset only No. Catridge field since the error is related to catridge validation
            _resetCatridgeAndSealFields(catridgeIndex, resetNoCatridge: true, resetSealCatridge: false);
          },
        );
      }
    } catch (e, stackTrace) {
      print('🔍 CATRIDGE LOOKUP: Exception caught - $e');
      print('🔍 CATRIDGE LOOKUP: Stack trace: $stackTrace');
      
      setState(() {
        _isLoading = false;
      });
      
      // Determine specific error message based on exception type
      String errorMessage;
      if (e.toString().contains('standValue')) {
        errorMessage = 'Nilai standValue tidak valid pada catridge $catridgeCode';
      } else if (e.toString().contains('type mismatch')) {
        errorMessage = 'Tipe catridge tidak sesuai: $catridgeCode';
      } else if (e.toString().contains('Map<String, dynamic>')) {
        errorMessage = 'Format data respons tidak valid untuk catridge $catridgeCode';
      } else if (e.toString().contains('timeout') || e.toString().contains('connection')) {
        errorMessage = 'Koneksi timeout atau masalah jaringan';
      } else {
        errorMessage = 'Terjadi kesalahan: $e';
      }
      
      print('🔍 CATRIDGE LOOKUP: Final error message: $errorMessage');
      print('Error looking up catridge: $e');
      // Don't create error detail item - just show error message
      // REMOVED: _createErrorDetailItem(catridgeIndex, catridgeCode, errorMessage);
      
      // Check if approval form should be hidden
      // REMOVED: _checkAndHideApprovalForm();
      
      // Show error to user with reset callback
      CustomModals.showFailedModal(
        context: context,
        message: errorMessage,
        onPressed: () {
          Navigator.of(context).pop();
          // Reset only No. Catridge field since the error is related to catridge validation
          _resetCatridgeAndSealFields(catridgeIndex, resetNoCatridge: true, resetSealCatridge: false);
        },
      );
    }
  }
  
  // Step 2: Validate seal and update detail item using comprehensive validation
  Future<void> _validateSealAndUpdateDetail(int catridgeIndex, String sealCode) async {
    if (sealCode.isEmpty || !mounted) return;
    
    try {
      print('=== STEP 2: COMPREHENSIVE SEAL VALIDATION ===');
      print('Catridge Index: $catridgeIndex');
      print('Seal Code: $sealCode');
      
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });
      
      final response = await _apiService.validateSeal(sealCode);
      
      setState(() {
        _isLoading = false;
      });
      
      print('Seal validation response: ${response.success}');
      print('Seal validation message: ${response.message}');
      
      // Extract validation status from response data
      String validationStatus = '';
      String errorMessage = '';
      String validatedSealCode = '';
      
      if (response.data != null) {
        try {
          if (response.data is Map<String, dynamic>) {
            // Try to extract values directly from the data map
            Map<String, dynamic> dataMap = response.data as Map<String, dynamic>;
            
            // Normalize keys for consistent access
            Map<String, dynamic> normalizedData = {};
            dataMap.forEach((key, value) {
              normalizedData[key.toLowerCase()] = value;
            });
            
            // Extract status with fallbacks
            if (normalizedData.containsKey('validationstatus')) {
              validationStatus = normalizedData['validationstatus'].toString();
            } else if (normalizedData.containsKey('status')) {
              validationStatus = normalizedData['status'].toString();
            }
            
            // Extract error message with fallbacks
            if (normalizedData.containsKey('errormessage')) {
              errorMessage = normalizedData['errormessage'].toString();
            } else if (normalizedData.containsKey('message')) {
              errorMessage = normalizedData['message'].toString();
            }
            
            // Extract validated seal code with fallbacks
            if (normalizedData.containsKey('validatedsealcode')) {
              validatedSealCode = normalizedData['validatedsealcode'].toString();
            } else if (normalizedData.containsKey('sealcode')) {
              validatedSealCode = normalizedData['sealcode'].toString();
            } else if (normalizedData.containsKey('seal')) {
              validatedSealCode = normalizedData['seal'].toString();
            }
            
            // If validation is successful but no validated code, use input code
            if (validationStatus.toUpperCase() == 'SUCCESS' && validatedSealCode.isEmpty) {
              validatedSealCode = sealCode;
            }
          }
        } catch (e) {
          print('Error parsing validation data: $e');
        }
      }
      
      print('Extracted validation status: $validationStatus');
      print('Extracted error message: $errorMessage');
      print('Extracted validated seal code: $validatedSealCode');
      
      // If no status extracted, determine from overall response
      if (validationStatus.isEmpty) {
        validationStatus = response.success ? 'SUCCESS' : 'FAILED';
      }
      
      // If no error message extracted, use response message
      if (errorMessage.isEmpty && !response.success) {
        errorMessage = response.message;
      }
      
      // If still no validated code and validation successful, use input code
      if (validatedSealCode.isEmpty && validationStatus.toUpperCase() == 'SUCCESS') {
        validatedSealCode = sealCode;
      }
      
      if ((response.success && validationStatus.toUpperCase() == 'SUCCESS') && mounted) {
        // Validation successful - update with validated seal code
        setState(() {
          // Manual mode reset is now handled in scanner callback
          print('✅ SUCCESS: Seal validation completed for catridge $catridgeIndex');
          
          // Update seal controller with validated code
          if (_catridgeControllers.length > catridgeIndex && _catridgeControllers[catridgeIndex].length > 1) {
            _catridgeControllers[catridgeIndex][1].text = validatedSealCode;
          }
          
          int existingIndex = _detailCatridgeItems.indexWhere((item) => item.index == catridgeIndex + 1);
          if (existingIndex >= 0) {
            var existingItem = _detailCatridgeItems[existingIndex];
            _detailCatridgeItems[existingIndex] = DetailCatridgeItem(
              index: existingItem.index,
              noCatridge: existingItem.noCatridge,
              sealCatridge: validatedSealCode, // Use validated seal code
              value: existingItem.value,
              total: existingItem.total,
              denom: existingItem.denom,
              bagCode: existingItem.bagCode,
              sealCode: existingItem.sealCode,
              sealReturn: existingItem.sealReturn,
            );
            print('Updated seal for detail item at index $existingIndex with validated code: $validatedSealCode');
          } else {
            // Create new DetailCatridgeItem if not exists
            String noCatridge = catridgeIndex < _catridgeControllers.length ? _catridgeControllers[catridgeIndex][0].text.trim() : '';
            String bagCode = catridgeIndex < _catridgeControllers.length ? _catridgeControllers[catridgeIndex][2].text.trim() : '';
            String sealCode = catridgeIndex < _catridgeControllers.length ? _catridgeControllers[catridgeIndex][3].text.trim() : '';
            String sealReturn = catridgeIndex < _catridgeControllers.length ? _catridgeControllers[catridgeIndex][4].text.trim() : '';
            
            DetailCatridgeItem newItem = DetailCatridgeItem(
              index: catridgeIndex + 1,
              noCatridge: noCatridge,
              sealCatridge: validatedSealCode,
              value: 0,
              total: 'Rp 0',
              denom: _prepareData?.tipeDenom == 'A100' ? 'Rp 100.000' : 'Rp 50.000',
              bagCode: bagCode,
              sealCode: sealCode,
              sealReturn: sealReturn,
            );
            _detailCatridgeItems.add(newItem);
            print('Created new detail item for catridge index ${catridgeIndex + 1} with validated seal: $validatedSealCode');
          }
        });
        
        // Check if approval form should be hidden
        // REMOVED: _checkAndHideApprovalForm();
        
        CustomModals.showSuccessModal(
          context: context,
          message: 'Seal berhasil divalidasi',
        );
      } else {
        // Validation failed - update detail item with error from SP
        if (errorMessage.isEmpty) {
          errorMessage = 'Seal tidak valid';
        }
        
        setState(() {
          int existingIndex = _detailCatridgeItems.indexWhere((item) => item.index == catridgeIndex + 1);
          if (existingIndex >= 0) {
            var existingItem = _detailCatridgeItems[existingIndex];
            _detailCatridgeItems[existingIndex] = DetailCatridgeItem(
              index: existingItem.index,
              noCatridge: existingItem.noCatridge,
              sealCatridge: 'Error: $errorMessage', // Show error from SP
              value: existingItem.value,
              total: existingItem.total,
              denom: existingItem.denom,
              bagCode: existingItem.bagCode,
              sealCode: existingItem.sealCode,
              sealReturn: existingItem.sealReturn,
            );
          }
        });
        
        // Check if approval form should be hidden
        // REMOVED: _checkAndHideApprovalForm();
        
        CustomModals.showFailedModal(
          context: context,
          message: 'Validasi seal gagal: $errorMessage',
          onPressed: () {
            Navigator.of(context).pop();
            // Reset only Seal Catridge field since the error is related to seal validation
            _resetCatridgeAndSealFields(catridgeIndex, resetNoCatridge: false, resetSealCatridge: true);
          },
        );
      }
    } catch (e, stackTrace) {
      print('🔒 SEAL VALIDATION: Exception caught - $e');
      print('🔒 SEAL VALIDATION: Stack trace: $stackTrace');
      
      setState(() {
        _isLoading = false;
      });
      
      // Determine specific error message based on exception type
      String errorMessage;
      if (e.toString().contains('timeout') || e.toString().contains('connection')) {
        errorMessage = 'Koneksi timeout atau masalah jaringan';
      } else if (e.toString().contains('parsing') || e.toString().contains('format')) {
        errorMessage = 'Format respons validasi seal tidak valid';
      } else if (e.toString().contains('validation')) {
        errorMessage = 'Error dalam proses validasi seal';
      } else {
        errorMessage = 'Kesalahan sistem: ${e.toString()}';
      }
      
      print('🔒 SEAL VALIDATION: Final error message: $errorMessage');
      print('Error validating seal: $e');
      
      // Update detail item with network/system error
      setState(() {
        int existingIndex = _detailCatridgeItems.indexWhere((item) => item.index == catridgeIndex + 1);
        if (existingIndex >= 0) {
          var existingItem = _detailCatridgeItems[existingIndex];
          _detailCatridgeItems[existingIndex] = DetailCatridgeItem(
            index: existingItem.index,
            noCatridge: existingItem.noCatridge,
            sealCatridge: 'Error: $errorMessage', // Show specific error
            value: existingItem.value,
            total: existingItem.total,
            denom: existingItem.denom,
            bagCode: existingItem.bagCode,
            sealCode: existingItem.sealCode,
            sealReturn: existingItem.sealReturn,
          );
        }
      });
      
      // Check if approval form should be hidden
      // REMOVED: _checkAndHideApprovalForm();
      
      CustomModals.showFailedModal(
        context: context,
        message: errorMessage,
        onPressed: () {
          Navigator.of(context).pop();
          // Reset only Seal Catridge field since the error is related to seal validation
          _resetCatridgeAndSealFields(catridgeIndex, resetNoCatridge: false, resetSealCatridge: true);
        },
      );
    }
  }
  
  // Helper method to get appropriate title for detail item based on index
  String _getDetailItemTitle(int index) {
    if (index >= 200) {
      // Pocket section (index 200+)
      return 'Pocket';
    } else if (index >= 100) {
      // Divert sections (index 100-102)
      int divertNumber = index - 99; // 100->1, 101->2, 102->3
      return 'Divert $divertNumber';
    } else {
      // Main catridge sections (index 1-10)
      return '${index}. Catridge ${index}';
    }
  }

  // Helper method to reset specific fields for specific section
  void _resetCatridgeAndSealFields(int catridgeIndex, {bool resetNoCatridge = true, bool resetSealCatridge = true}) {
    if (catridgeIndex >= 0 && catridgeIndex < _catridgeControllers.length) {
      setState(() {
        if (resetNoCatridge) {
          // Reset No. Catridge field (index 0)
          _catridgeControllers[catridgeIndex][0].clear();
        }
        if (resetSealCatridge) {
          // Reset Seal Catridge field (index 1)
          _catridgeControllers[catridgeIndex][1].clear();
        }
        
        List<String> resetFields = [];
        if (resetNoCatridge) resetFields.add('No. Catridge');
        if (resetSealCatridge) resetFields.add('Seal Catridge');
        
        print('🔄 RESET FIELDS: Catridge section ${catridgeIndex + 1} - ${resetFields.join(' and ')} fields cleared');
      });
    }
  }

  // Reset fields selectively for Divert section
  void _resetDivertAndSealFields(int sectionIndex, {bool resetNoCatridge = true, bool resetSealCatridge = true}) {
    if (sectionIndex >= 0 && sectionIndex < _divertControllers.length && _divertControllers[sectionIndex].isNotEmpty) {
      setState(() {
        if (resetNoCatridge) {
          // Reset No. Catridge field (index 0)
          _divertControllers[sectionIndex][0].clear();
        }
        if (resetSealCatridge && _divertControllers[sectionIndex].length > 1) {
          // Reset Seal Catridge field (index 1)
          _divertControllers[sectionIndex][1].clear();
        }
        
        List<String> resetFields = [];
        if (resetNoCatridge) resetFields.add('No. Catridge');
        if (resetSealCatridge) resetFields.add('Seal Catridge');
        
        print('🔄 RESET FIELDS: Divert section ${sectionIndex + 1} - ${resetFields.join(' and ')} fields cleared');
      });
    }
  }

  // Reset fields selectively for Pocket section
  void _resetPocketAndSealFields({bool resetNoCatridge = true, bool resetSealCatridge = true}) {
    if (_pocketControllers.isNotEmpty) {
      setState(() {
        if (resetNoCatridge) {
          // Reset No. Catridge field (index 0)
          _pocketControllers[0].clear();
        }
        if (resetSealCatridge && _pocketControllers.length > 1) {
          // Reset Seal Catridge field (index 1)
          _pocketControllers[1].clear();
        }
        
        List<String> resetFields = [];
        if (resetNoCatridge) resetFields.add('No. Catridge');
        if (resetSealCatridge) resetFields.add('Seal Catridge');
        
        print('🔄 RESET FIELDS: Pocket section - ${resetFields.join(' and ')} fields cleared');
      });
    }
  }

  // Helper method to create error detail item
  void _createErrorDetailItem(int catridgeIndex, String catridgeCode, String errorMessage) {
    final detailItem = DetailCatridgeItem(
      index: catridgeIndex + 1,
      noCatridge: catridgeCode.isNotEmpty ? catridgeCode : 'Error',
      sealCatridge: '',
      value: 0,
      total: errorMessage, // Show error in total field
      denom: '',
      bagCode: '',
      sealCode: '',
      sealReturn: '',
    );
    
    setState(() {
      int existingIndex = _detailCatridgeItems.indexWhere((item) => item.index == catridgeIndex + 1);
      if (existingIndex >= 0) {
        _detailCatridgeItems[existingIndex] = detailItem;
      } else {
        _detailCatridgeItems.add(detailItem);
      }
      
      _detailCatridgeItems.sort((a, b) => a.index.compareTo(b.index));
      print('Created error detail item: $errorMessage');
    });
    
    // Check if approval form should be hidden
    // REMOVED: _checkAndHideApprovalForm();
  }
  
  // Remove detail catridge item and clear related fields
  void _removeDetailCatridgeItem(int index) {
    setState(() {
      // Find the item to be removed
      DetailCatridgeItem? itemToRemove = _detailCatridgeItems.firstWhere(
        (item) => item.index == index,
        orElse: () => DetailCatridgeItem(index: -1, noCatridge: '', sealCatridge: '', value: 0, total: '', denom: '', bagCode: '', sealCode: '', sealReturn: ''),
      );
      
      // Remove the detail item from main list
      _detailCatridgeItems.removeWhere((item) => item.index == index);
      
      // Check if this item belongs to divert or pocket by matching noCatridge
      bool isFromDivert = false;
      bool isFromPocket = false;
      
      // Check if it's from divert (check all divert sections)
      for (int i = 0; i < _divertDetailItems.length; i++) {
        if (_divertDetailItems[i] != null && _divertDetailItems[i]!.noCatridge == itemToRemove.noCatridge) {
          isFromDivert = true;
          print('Removing divert item from section $i: ${itemToRemove.noCatridge}');
          
          // Clear divert data and controllers for this specific section
          _divertCatridgeData[i] = null;
          _divertDetailItems[i] = null;
          
          // Clear controllers for this divert section
          for (var controller in _divertControllers[i]) {
            controller.clear();
          }
          
          // Reset divert manual mode state for this section
          if (i < _divertManualMode.length) {
            _divertManualMode[i] = false;
          }
          
          // Clear divert remark controllers for this section
          if (i < _divertAlasanControllers.length) {
            _divertAlasanControllers[i].clear();
          }
          if (i < _divertRemarkControllers.length) {
            _divertRemarkControllers[i].clear();
          }
          
          // Reset divert section active state for this section
          if (i < _divertSectionActive.length) {
            _divertSectionActive[i] = false;
          }
          
          break; // Exit loop once we find the matching item
        }
      }
      
      // Check if it's from pocket (check all pocket sections)
      // Check if item is from pocket section
      if (_pocketCatridgeData != null && _pocketCatridgeData!.code == itemToRemove.noCatridge) {
        isFromPocket = true;
        print('Removing pocket item: ${itemToRemove.noCatridge}');
        
        // Clear pocket data and controllers
        _pocketCatridgeData = null;
        
        // Clear pocket controllers
        for (var controller in _pocketControllers) {
          controller.clear();
        }
        
        // Clear pocket alasan and remark controllers
        _pocketAlasanController.clear();
        _pocketRemarkController.clear();
        _pocketNoAlasanController.clear();
        _pocketSealAlasanController.clear();
        _pocketNoRemarkController.clear();
        _pocketSealRemarkController.clear();
        
        // Reset pocket manual mode states
        _pocketManualMode = false;
        _pocketNoManualMode = false;
        _pocketSealManualMode = false;
      }
      
      // If it's not from divert or pocket, it's from main catridge sections
      if (!isFromDivert && !isFromPocket) {
        // Index 1-4 corresponds to Catridge sections (index - 1 = catridgeIndex)
        if (index >= 1 && index <= 10) { // Support up to 10 catridge sections
          int catridgeIndex = index - 1;
          
          print('Removing catridge item at index $catridgeIndex: ${itemToRemove.noCatridge}');
          
          // Clear catridge controllers if they exist
          if (catridgeIndex < _catridgeControllers.length) {
            for (var controller in _catridgeControllers[catridgeIndex]) {
              controller.clear();
            }
          }
          
          // Clear catridge data
          if (catridgeIndex < _catridgeData.length) {
            _catridgeData[catridgeIndex] = null;
          }
          
          // Reset manual mode states for this catridge
          if (catridgeIndex < _catridgeManualMode.length) {
            _catridgeManualMode[catridgeIndex] = false;
          }
          if (catridgeIndex < _catridgeNoManualMode.length) {
            _catridgeNoManualMode[catridgeIndex] = false;
          }
          if (catridgeIndex < _catridgeSealManualMode.length) {
            _catridgeSealManualMode[catridgeIndex] = false;
          }
          
          // Clear remark controllers
          if (catridgeIndex < _catridgeRemarkControllers.length) {
            _catridgeRemarkControllers[catridgeIndex].clear();
          }
          if (catridgeIndex < _catridgeAlasanControllers.length) {
            _catridgeAlasanControllers[catridgeIndex].clear();
          }
          if (catridgeIndex < _catridgeNoAlasanControllers.length) {
            _catridgeNoAlasanControllers[catridgeIndex].clear();
          }
          if (catridgeIndex < _catridgeNoRemarkControllers.length) {
            _catridgeNoRemarkControllers[catridgeIndex].clear();
          }
          if (catridgeIndex < _catridgeSealAlasanControllers.length) {
            _catridgeSealAlasanControllers[catridgeIndex].clear();
          }
          if (catridgeIndex < _catridgeSealRemarkControllers.length) {
            _catridgeSealRemarkControllers[catridgeIndex].clear();
          }
          
          // Reset remark filled states
          if (catridgeIndex < _catridgeRemarkFilled.length) {
            _catridgeRemarkFilled[catridgeIndex] = false;
          }
          if (catridgeIndex < _catridgeNoRemarkFilled.length) {
            _catridgeNoRemarkFilled[catridgeIndex] = false;
          }
          if (catridgeIndex < _catridgeSealRemarkFilled.length) {
            _catridgeSealRemarkFilled[catridgeIndex] = false;
          }
        }
      }
    });
    
    // Check if approval form should be hidden
    // REMOVED: _checkAndHideApprovalForm();
  }
  
  // Check if all detail catridge items are valid and complete
  bool _areAllCatridgeItemsValid() {
    print('🔍 VALIDATION: Checking ${_detailCatridgeItems.length} catridge items');
    if (_detailCatridgeItems.isEmpty) {
      print('🔍 VALIDATION: No catridge items found');
      return false;
    }
    
    for (int i = 0; i < _detailCatridgeItems.length; i++) {
      var item = _detailCatridgeItems[i];
      print('🔍 VALIDATION: Item $i - index: ${item.index}, noCatridge: "${item.noCatridge}", sealCatridge: "${item.sealCatridge}", value: ${item.value}');
      
      // Check if item has error
      if (item.total.contains('Error') || item.total.contains('tidak ditemukan') ||
          item.sealCatridge.contains('Error') || item.sealCatridge.contains('tidak valid')) {
        print('🔍 VALIDATION: Item has error: ${item.noCatridge}');
        return false;
      }
      
      // Check if all required fields are filled
      // For divert items (index >= 100), value can be 0 (empty divert is allowed)
      bool isMainCatridge = item.index < 100;
      bool valueValid = isMainCatridge ? item.value > 0 : item.value >= 0;
      
      if (item.noCatridge.isEmpty || item.sealCatridge.isEmpty || !valueValid) {
        print('🔍 VALIDATION: Item is incomplete - noCatridge empty: ${item.noCatridge.isEmpty}, sealCatridge empty: ${item.sealCatridge.isEmpty}, value invalid: ${!valueValid} (isMain: $isMainCatridge, value: ${item.value})');
        return false;
      }
    }
    
    print('🔍 VALIDATION: All catridge items are valid');
    return true;
  }

  // NEW: Get validation message in Indonesian for submit validation
  String? _getValidationMessage() {
    // Check if prepare data exists
    if (_prepareData == null) {
      return 'Data Prepare masih ada yang belum lengkap, silahkan cek semua datanya terlebih dahulu.';
    }

    // Check header fields
    if (_idCRFController.text.trim().isEmpty) {
      return 'ID CRF harus diisi.';
    }
    
    if (_jamMulaiController.text.trim().isEmpty) {
      return 'Jam Mulai harus diisi.';
    }

    // Check if catridge items exist
    if (_detailCatridgeItems.isEmpty) {
      return 'Belum ada data catridge yang ditambahkan. Silakan tambahkan minimal satu catridge.';
    }

    // Check each catridge item
    for (int i = 0; i < _detailCatridgeItems.length; i++) {
      var item = _detailCatridgeItems[i];
      
      // Check for errors in catridge data
      if (item.total.contains('Error') || item.total.contains('tidak ditemukan')) {
        return 'Catridge ${i + 1} (${item.noCatridge}): Data catridge tidak ditemukan atau terjadi error. Silakan periksa kembali nomor catridge.';
      }
      
      if (item.sealCatridge.contains('Error') || item.sealCatridge.contains('tidak valid')) {
        return 'Catridge ${i + 1} (${item.noCatridge}): Seal catridge tidak valid atau terjadi error. Silakan periksa kembali seal catridge.';
      }
      
      // Check required fields
      if (item.noCatridge.isEmpty) {
        return 'Catridge ${i + 1}: Nomor catridge harus diisi.';
      }
      
      if (item.sealCatridge.isEmpty) {
        return 'Catridge ${i + 1} (${item.noCatridge}): Seal catridge harus diisi.';
      }
      
      
      // NEW: Validate Seal Code Return for each catridge
      if (i < _catridgeControllers.length) {
        String sealReturn = _catridgeControllers[i][4].text.trim(); // Seal Code Return field
        if (sealReturn.isEmpty) {
          return 'Catridge ${i + 1} (${item.noCatridge}): Seal Code Return harus diisi.';
        }
      }
    }

    // Check manual mode remark requirements
    for (int i = 0; i < _catridgeControllers.length; i++) {
      // Check No. Catridge manual mode
      if (i < _catridgeNoManualMode.length && _catridgeNoManualMode[i]) {
        if (i >= _catridgeNoRemarkControllers.length || _catridgeNoRemarkControllers[i].text.trim().isEmpty) {
          return 'Catridge ${i + 1}: Remark wajib diisi untuk mode manual pada field No. Catridge.';
        }
        if (i >= _catridgeNoAlasanControllers.length || _catridgeNoAlasanControllers[i].text.trim().isEmpty) {
          return 'Catridge ${i + 1}: Alasan wajib dipilih untuk mode manual pada field No. Catridge.';
        }
      }
      
      // Check Seal Catridge manual mode
      if (i < _catridgeSealManualMode.length && _catridgeSealManualMode[i]) {
        if (i >= _catridgeSealRemarkControllers.length || _catridgeSealRemarkControllers[i].text.trim().isEmpty) {
          return 'Catridge ${i + 1}: Remark wajib diisi untuk mode manual pada field Seal Catridge.';
        }
        if (i >= _catridgeSealAlasanControllers.length || _catridgeSealAlasanControllers[i].text.trim().isEmpty) {
          return 'Catridge ${i + 1}: Alasan wajib dipilih untuk mode manual pada field Seal Catridge.';
        }
      }
    }

    // Check Divert manual mode requirements
    for (int i = 0; i < _divertNoManualMode.length; i++) {
      if (_divertNoManualMode[i]) {
        String? remark = i < _divertNoRemarkControllers.length ? _divertNoRemarkControllers[i].text.trim() : null;
        String? alasan = i < _divertNoAlasanControllers.length ? _divertNoAlasanControllers[i].text.trim() : null;
        
        if (remark == null || remark.isEmpty) {
          return 'Divert ${i + 1}: Remark wajib diisi untuk mode manual pada field No. Catridge.';
        }
        if (alasan == null || alasan.isEmpty) {
          return 'Divert ${i + 1}: Alasan wajib dipilih untuk mode manual pada field No. Catridge.';
        }
      }
    }
    
    for (int i = 0; i < _divertSealManualMode.length; i++) {
      if (_divertSealManualMode[i]) {
        String? remark = i < _divertSealRemarkControllers.length ? _divertSealRemarkControllers[i].text.trim() : null;
        String? alasan = i < _divertSealAlasanControllers.length ? _divertSealAlasanControllers[i].text.trim() : null;
        
        if (remark == null || remark.isEmpty) {
          return 'Divert ${i + 1}: Remark wajib diisi untuk mode manual pada field Seal Catridge.';
        }
        if (alasan == null || alasan.isEmpty) {
          return 'Divert ${i + 1}: Alasan wajib dipilih untuk mode manual pada field Seal Catridge.';
        }
      }
    }

    // Check Pocket manual mode requirements
    if (_pocketNoManualMode) {
      if (_pocketNoRemarkController.text.trim().isEmpty) {
        return 'Pocket: Remark wajib diisi untuk mode manual pada field No. Catridge.';
      }
      if (_pocketNoAlasanController.text.trim().isEmpty) {
        return 'Pocket: Alasan wajib dipilih untuk mode manual pada field No. Catridge.';
      }
    }
    
    if (_pocketSealManualMode) {
      if (_pocketSealRemarkController.text.trim().isEmpty) {
        return 'Pocket: Remark wajib diisi untuk mode manual pada field Seal Catridge.';
      }
      if (_pocketSealAlasanController.text.trim().isEmpty) {
        return 'Pocket: Alasan wajib dipilih untuk mode manual pada field Seal Catridge.';
      }
    }

    // NEW: Validate that all catridge sections are completely filled (5 columns each)
    for (int i = 0; i < _catridgeControllers.length; i++) {
      bool isCompletelyFilled = true;
      for (int j = 0; j < _catridgeControllers[i].length; j++) {
        if (_catridgeControllers[i][j].text.trim().isEmpty) {
          isCompletelyFilled = false;
          break;
        }
      }
      if (!isCompletelyFilled) {
        return 'Inputan Prepare masih ada yang belum lengkap!';
      }
    }
    
    // NEW: Validate that Divert 1 section is completely filled (5 columns)
    bool isDivert1Complete = true;
    
    // Check only Divert 1 section (first divert section with 5 controllers)
    if (_divertControllers.isNotEmpty && _divertControllers[0].length >= 5) {
      for (int j = 0; j < _divertControllers[0].length; j++) {
        String value = _divertControllers[0][j].text.trim();
        if (value.isEmpty) {
          isDivert1Complete = false;
          break;
        }
      }
    } else {
      isDivert1Complete = false;
    }
    
    if (!isDivert1Complete) {
      return 'Inputan Prepare masih ada yang belum lengkap!';
    }
    
    // Validate Seal Code Return for sections that have data
    for (int i = 0; i < _divertControllers.length; i++) {
      // Check if any controller in this divert section has data
      bool hasDivertSectionData = false;
      for (int j = 0; j < _divertControllers[i].length; j++) {
        if (_divertControllers[i][j].text.trim().isNotEmpty) {
          hasDivertSectionData = true;
          break;
        }
      }
      
      // If this divert section has data, validate Seal Code Return
      if (hasDivertSectionData) {
        String sealReturn = _divertControllers[i][4].text.trim(); // Seal Code Return field
        if (sealReturn.isEmpty) {
          return 'Divert ${i + 1}: Seal Code Return harus diisi.';
        }
      }
    }
    
    // NEW: Validate Pocket Seal Code Return if Pocket has data
    if (_pocketDetailItem != null) {
      String sealReturn = _pocketControllers[4].text.trim(); // Seal Code Return field
      if (sealReturn.isEmpty) {
        return 'Pocket: Seal Code Return harus diisi.';
      }
    }

    return null; // No validation errors
  }

  // NEW: Handle submit button press with validation
  void _handleSubmitButtonPressed() {
    // First check catridge validation
    bool catridgeValid = _areAllCatridgeItemsValid();
    
    if (!catridgeValid) {
      CustomModals.showFailedModal(
        context: context,
        message: 'Inputan Prepare masih ada yang belum lengkap!',
        buttonText: 'Mengerti',
      );
      return;
    }
    
    // Then check complete validation including divert
    String? validationMessage = _getValidationMessage();
    
    if (validationMessage != null) {
      // Show validation error modal
      CustomModals.showFailedModal(
        context: context,
        message: validationMessage,
        buttonText: 'Mengerti',
      );
    } else {
      // All validations passed, show approval form
      _showApprovalFormDialog();
    }
  }

  // NEW: Handle approve & submit button press with validation
  void _handleApproveSubmitButtonPressed() {
    if (_isSubmitting) return; // Prevent multiple submissions
    
    // Validate approval form fields
    if (_nikTLController.text.trim().isEmpty) {
      CustomModals.showFailedModal(
        context: context,
        message: 'NIK TL SPV harus diisi',
        buttonText: 'Mengerti',
      );
      return;
    }
    
    if (_passwordTLController.text.trim().isEmpty) {
      CustomModals.showFailedModal(
        context: context,
        message: 'Password harus diisi',
        buttonText: 'Mengerti',
      );
      return;
    }
    
    // Check for manual mode validations
    String? manualValidationMessage = _getManualModeValidationMessage();
    if (manualValidationMessage != null) {
      CustomModals.showFailedModal(
        context: context,
        message: manualValidationMessage,
        buttonText: 'Mengerti',
      );
      return;
    }
    
    // All validations passed, proceed with submission
    _submitDataWithApproval();
  }

  // NEW: Get manual mode validation message for approval form
  String? _getManualModeValidationMessage() {
    List<String> missingFields = [];
    
    // Check Catridge No. Catridge manual mode
    for (int i = 0; i < _catridgeNoManualMode.length; i++) {
      if (_catridgeNoManualMode[i]) {
        String? remark = i < _catridgeNoRemarkControllers.length ? _catridgeNoRemarkControllers[i].text.trim() : null;
        String? alasan = i < _catridgeNoAlasanControllers.length ? _catridgeNoAlasanControllers[i].text.trim() : null;
        
        if (remark == null || remark.isEmpty) {
          missingFields.add('Remark untuk No. Catridge ${i + 1}');
        }
        if (alasan == null || alasan.isEmpty) {
          missingFields.add('Alasan untuk No. Catridge ${i + 1}');
        }
      }
    }
    
    // Check Catridge Seal Catridge manual mode
    for (int i = 0; i < _catridgeSealManualMode.length; i++) {
      if (_catridgeSealManualMode[i]) {
        String? remark = i < _catridgeSealRemarkControllers.length ? _catridgeSealRemarkControllers[i].text.trim() : null;
        String? alasan = i < _catridgeSealAlasanControllers.length ? _catridgeSealAlasanControllers[i].text.trim() : null;
        
        if (remark == null || remark.isEmpty) {
          missingFields.add('Remark untuk Seal Catridge ${i + 1}');
        }
        if (alasan == null || alasan.isEmpty) {
          missingFields.add('Alasan untuk Seal Catridge ${i + 1}');
        }
      }
    }
    
    // Check Divert No. Catridge manual mode
    for (int i = 0; i < _divertNoManualMode.length; i++) {
      if (_divertNoManualMode[i]) {
        String? remark = i < _divertNoRemarkControllers.length ? _divertNoRemarkControllers[i].text.trim() : null;
        String? alasan = i < _divertNoAlasanControllers.length ? _divertNoAlasanControllers[i].text.trim() : null;
        
        if (remark == null || remark.isEmpty) {
          missingFields.add('Remark untuk No. Catridge Divert ${i + 1}');
        }
        if (alasan == null || alasan.isEmpty) {
          missingFields.add('Alasan untuk No. Catridge Divert ${i + 1}');
        }
      }
    }
    
    // Check Divert Seal Catridge manual mode
    for (int i = 0; i < _divertSealManualMode.length; i++) {
      if (_divertSealManualMode[i]) {
        String? remark = i < _divertSealRemarkControllers.length ? _divertSealRemarkControllers[i].text.trim() : null;
        String? alasan = i < _divertSealAlasanControllers.length ? _divertSealAlasanControllers[i].text.trim() : null;
        
        if (remark == null || remark.isEmpty) {
          missingFields.add('Remark untuk Seal Catridge Divert ${i + 1}');
        }
        if (alasan == null || alasan.isEmpty) {
          missingFields.add('Alasan untuk Seal Catridge Divert ${i + 1}');
        }
      }
    }
    
    // Check Pocket No. Catridge manual mode
    if (_pocketNoManualMode) {
      String? remark = _pocketNoRemarkController.text.trim();
      String? alasan = _pocketNoAlasanController.text.trim();
      
      if (remark.isEmpty) {
        missingFields.add('Remark untuk No. Catridge Pocket');
      }
      if (alasan.isEmpty) {
        missingFields.add('Alasan untuk No. Catridge Pocket');
      }
    }
    
    // Check Pocket Seal Catridge manual mode
    if (_pocketSealManualMode) {
      String? remark = _pocketSealRemarkController.text.trim();
      String? alasan = _pocketSealAlasanController.text.trim();
      
      if (remark.isEmpty) {
        missingFields.add('Remark untuk Seal Catridge Pocket');
      }
      if (alasan.isEmpty) {
        missingFields.add('Alasan untuk Seal Catridge Pocket');
      }
    }
    
    if (missingFields.isNotEmpty) {
      return 'Field berikut harus diisi untuk mode manual:\n\n${missingFields.join('\n')}';
    }
    
    return null;
  }
   
  // Sync form data to models before navigation
  void _syncFormDataToModels() {
    // Sync catridge data
    for (int i = 0; i < _catridgeControllers.length; i++) {
      if (_catridgeControllers[i].length >= 5) {
        String bagCode = _catridgeControllers[i][2].text.trim();
        String sealCode = _catridgeControllers[i][3].text.trim();
        String sealReturn = _catridgeControllers[i][4].text.trim();
        
        // Update existing item or create new one
        int existingIndex = _detailCatridgeItems.indexWhere((item) => item.index == i + 1);
        if (existingIndex >= 0) {
          DetailCatridgeItem currentItem = _detailCatridgeItems[existingIndex];
          _detailCatridgeItems[existingIndex] = DetailCatridgeItem(
            index: currentItem.index,
            noCatridge: currentItem.noCatridge,
            sealCatridge: currentItem.sealCatridge,
            value: currentItem.value,
            total: currentItem.total,
            denom: currentItem.denom,
            bagCode: bagCode.isNotEmpty ? bagCode : currentItem.bagCode,
            sealCode: sealCode.isNotEmpty ? sealCode : currentItem.sealCode,
            sealReturn: sealReturn.isNotEmpty ? sealReturn : currentItem.sealReturn,
          );
        }
      }
    }
    
    // Sync divert data - use DetailCatridgeItem with index offset
    for (int i = 0; i < _divertControllers.length; i++) {
      if (_divertControllers[i].length >= 5) {
        String bagCode = _divertControllers[i][2].text.trim();
        String sealCode = _divertControllers[i][3].text.trim();
        String sealReturn = _divertControllers[i][4].text.trim();
        
        if (_divertDetailItems[i] != null) {
          // Create a new DetailCatridgeItem for divert with index 100+
          int divertIndex = _detailCatridgeItems.indexWhere((item) => item.index == 100 + i);
          if (divertIndex >= 0) {
            DetailCatridgeItem currentItem = _detailCatridgeItems[divertIndex];
            _detailCatridgeItems[divertIndex] = DetailCatridgeItem(
              index: currentItem.index,
              noCatridge: currentItem.noCatridge,
              sealCatridge: currentItem.sealCatridge,
              value: currentItem.value,
              total: currentItem.total,
              denom: currentItem.denom,
              bagCode: bagCode.isNotEmpty ? bagCode : currentItem.bagCode,
              sealCode: sealCode.isNotEmpty ? sealCode : currentItem.sealCode,
              sealReturn: sealReturn.isNotEmpty ? sealReturn : currentItem.sealReturn,
            );
          }
        }
      }
    }
    
    // Sync pocket data - use DetailCatridgeItem with index 200
    if (_pocketControllers.length >= 5 && _pocketDetailItem != null) {
      String bagCode = _pocketControllers[2].text.trim();
      String sealCode = _pocketControllers[3].text.trim();
      String sealReturn = _pocketControllers[4].text.trim();
      
      int pocketIndex = _detailCatridgeItems.indexWhere((item) => item.index == 200);
      if (pocketIndex >= 0) {
        DetailCatridgeItem currentItem = _detailCatridgeItems[pocketIndex];
        _detailCatridgeItems[pocketIndex] = DetailCatridgeItem(
          index: currentItem.index,
          noCatridge: currentItem.noCatridge,
          sealCatridge: currentItem.sealCatridge,
          value: currentItem.value,
          total: currentItem.total,
          denom: currentItem.denom,
          bagCode: bagCode.isNotEmpty ? bagCode : currentItem.bagCode,
          sealCode: sealCode.isNotEmpty ? sealCode : currentItem.sealCode,
          sealReturn: sealReturn.isNotEmpty ? sealReturn : currentItem.sealReturn,
        );
      }
    }
  }

  // Show approval form
  void _showApprovalFormDialog() {
    // Sync form data to models before navigation
    _syncFormDataToModels();
    
    // Navigate to prepare summary page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrepareSummaryPage(
          prepareData: _prepareData!,
          catridgeData: _detailCatridgeItems.where((item) => item.index < 100).toList(), // Filter hanya catridge asli, bukan divert/pocket
          divertData: _divertDetailItems.where((item) => item != null).map((item) => item!.toJson()).toList(),
          pocketData: _pocketDetailItem?.toJson(),
        ),
      ),
    );
  }
  
  // Hide approval form
  void _hideApprovalForm() {
    setState(() {
      _showApprovalForm = false;
      _nikTLController.clear();
      _passwordTLController.clear();
    });
  }
  
  // Submit data with approval
  Future<void> _submitDataWithApproval() async {
    if (_nikTLController.text.isEmpty || _passwordTLController.text.isEmpty) {
      CustomModals.showFailedModal(
        context: context,
        message: 'NIK TL SPV dan Password harus diisi',
      );
      return;
    }
    
    // Validasi sudah dipindahkan ke _getValidationMessage yang dipanggil saat submit pertama
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Step 0: Validate TL Supervisor credentials and role
      print('=== STEP 0: VALIDATE TL SUPERVISOR ===');
      final tlValidationResponse = await _apiService.validateTLSupervisor(
        nik: _nikTLController.text.trim(),
        password: _passwordTLController.text.trim(),
      );
      
      if (!tlValidationResponse.success || 
          tlValidationResponse.data?.validationStatus != 'SUCCESS') {
        throw Exception('Validasi TL SPV gagal: ${tlValidationResponse.message}');
      }
      
      print('TL Supervisor validation success: ${tlValidationResponse.data?.userName} (${tlValidationResponse.data?.userRole})');
      
      // Step 1: Update Planning API
      print('=== STEP 1: UPDATE PLANNING ===');
      final planningResponse = await _apiService.updatePlanning(
        idTool: _prepareData!.id,
        cashierCode: 'CURRENT_USER', // TODO: Get from auth service
        spvTLCode: _nikTLController.text,
        tableCode: _prepareData!.tableCode,
      );
      
      if (!planningResponse.success) {
        throw Exception('Planning update failed: ${planningResponse.message}');
      }
      
      print('Planning update success: ${planningResponse.message}');
      
      // Step 2: Insert ATM Catridge for each detail item
      print('=== STEP 2: INSERT ATM CATRIDGE ===');
      List<String> successMessages = [];
      List<String> errorMessages = [];
      
      // Function to insert catridge with type
      Future<void> insertCatridge({
        required String noCatridge,
        required String sealCatridge,
        required String bagCode,
        required String sealCode,
        required String sealReturn,
        required String typeCatridgeTrx,
        required String section,
        String? scanCatStatus,
        String? scanCatStatusRemark,
        String? scanSealStatus,
        String? scanSealStatusRemark,
      }) async {
        try {
          // Get current user data for userInput
          String userInput = 'UNKNOWN';
          try {
            final userData = await _authService.getUserData();
            if (userData != null) {
              // Prioritas userId yang disimpan saat login
              userInput = userData['userId'] ?? userData['userID'] ?? userData['nik'] ?? userData['username'] ?? userData['userCode'] ?? 'UNKNOWN';
            }
          } catch (e) {
            print('Error getting user data: $e');
            userInput = 'UNKNOWN';
          }
          
          // Ensure denomination code is not empty
          String finalDenomCode = _prepareData!.denomCode;
          if (finalDenomCode.isEmpty) finalDenomCode = 'TEST';
          
          print('Inserting catridge with following data:');
          print('  ID Tool: ${_prepareData!.id}');
          print('  Bag Code: $bagCode');
          print('  Catridge Code: $noCatridge');
          print('  Seal Code: $sealCode');
          print('  Catridge Seal: $sealCatridge');
          print('  Denom Code: $finalDenomCode');
          print('  User Input: $userInput');
          print('  Seal Return: $sealReturn');
          print('  Type Catridge Trx: $typeCatridgeTrx');
          
          // Add retry logic for InsertedId errors
          int maxRetries = 2;
          for (int retry = 0; retry <= maxRetries; retry++) {
            try {
              final catridgeResponse = await _apiService.insertAtmCatridge(
                idTool: _prepareData!.id,
                bagCode: bagCode.isEmpty ? 'TEST' : bagCode,
                catridgeCode: noCatridge,
                sealCode: sealCode.isEmpty ? 'TEST' : sealCode,
                catridgeSeal: sealCatridge.isEmpty ? 'TEST' : sealCatridge,
                denomCode: finalDenomCode,
                qty: '1',
                userInput: userInput,
                sealReturn: sealReturn,
                typeCatridgeTrx: typeCatridgeTrx,
                scanCatStatus: scanCatStatus ?? 'TEST',
                scanCatStatusRemark: scanCatStatusRemark ?? 'TEST',
                scanSealStatus: scanSealStatus ?? 'TEST',
                scanSealStatusRemark: scanSealStatusRemark ?? 'TEST',
              );
              
              if (catridgeResponse.success) {
                successMessages.add('$section: ${catridgeResponse.message}');
                print('$section success: ${catridgeResponse.message}');
                break; // Exit retry loop on success
              } else {
                if (retry < maxRetries && 
                    catridgeResponse.message.contains('InsertedId') && 
                    catridgeResponse.message.contains('not belong to table')) {
                  // This is the specific error we're trying to handle with retries
                  print('$section got InsertedId error, retrying (${retry + 1}/$maxRetries)...');
                  await Future.delayed(const Duration(milliseconds: 2000)); // Small delay before retry
                  continue; // Try again
                }
                
                // If we've exhausted retries or it's a different error, add to errors
                errorMessages.add('$section: ${catridgeResponse.message}');
                print('$section error: ${catridgeResponse.message} (Status: ${catridgeResponse.status})');
                
                // Add the catridge to the failed list so we can show it to the user
                setState(() {
                  _failedCatridges.add(noCatridge);
                });
                break; // Exit retry loop on non-retryable error
              }
            } catch (e) {
              if (retry < maxRetries && e.toString().contains('InsertedId') && e.toString().contains('not belong to table')) {
                // Handle exception containing the specific error
                print('$section got InsertedId exception, retrying (${retry + 1}/$maxRetries)...');
                await Future.delayed(const Duration(milliseconds: 2000)); // Small delay before retry
                continue; // Try again
              }
              
              // If we've exhausted retries or it's a different error, add to errors
              errorMessages.add('$section: ${e.toString()}');
              print('$section exception: $e');
              
              // Add the catridge to the failed list so we can show it to the user
              setState(() {
                _failedCatridges.add(noCatridge);
              });
              break; // Exit retry loop on non-retryable exception
            }
          }
        } catch (e) {
          errorMessages.add('$section: ${e.toString()}');
          print('$section outer exception: $e');
          
          // Add the catridge to the failed list so we can show it to the user
          setState(() {
            _failedCatridges.add(noCatridge);
          });
        }
      }
      
      // Reset failed catridges list
      setState(() {
        _failedCatridges = [];
      });
      
      // Process each catridge (validation already done in _getValidationMessage)
      for (int i = 0; i < _detailCatridgeItems.length; i++) {
        var item = _detailCatridgeItems[i];
        print('Processing catridge ${i + 1}: ${item.noCatridge}');
        
        // Get data from form fields for this catridge
        String bagCode = '';
        String sealCode = '';
        String sealReturn = '';
        
        // Get data from controllers if available
        if (i < _catridgeControllers.length) {
          bagCode = _catridgeControllers[i][2].text.trim(); // Bag Code field
          sealCode = _catridgeControllers[i][3].text.trim(); // Seal Code field
          sealReturn = _catridgeControllers[i][4].text.trim(); // Seal Code Return field
        }
        
        // Fallback to prepare data if form fields are empty
        if (bagCode.isEmpty) bagCode = _prepareData!.bagCode;
        if (sealCode.isEmpty) sealCode = _prepareData!.sealCode;
        // sealReturn MUST come from form field only - no fallback to TEST
        
        // Final validation - ensure no empty critical fields
        if (bagCode.isEmpty) bagCode = 'TEST';
        if (sealCode.isEmpty) sealCode = 'TEST';
        // sealReturn validation already done in _getValidationMessage
        
        // Insert main catridge with type C
        // Get No. Catridge manual mode data
        bool isNoManualMode = i < _catridgeNoManualMode.length && _catridgeNoManualMode[i];
        String? noAlasan = isNoManualMode && i < _catridgeNoAlasanControllers.length 
            ? _catridgeNoAlasanControllers[i].text.trim() 
            : null;
        String? noRemark = isNoManualMode && i < _catridgeNoRemarkControllers.length 
            ? _catridgeNoRemarkControllers[i].text.trim() 
            : null;
        
        // Get Seal Catridge manual mode data
        bool isSealManualMode = i < _catridgeSealManualMode.length && _catridgeSealManualMode[i];
        String? sealAlasan = isSealManualMode && i < _catridgeSealAlasanControllers.length 
            ? _catridgeSealAlasanControllers[i].text.trim() 
            : null;
        String? sealRemark = isSealManualMode && i < _catridgeSealRemarkControllers.length 
            ? _catridgeSealRemarkControllers[i].text.trim() 
            : null;
        
        await insertCatridge(
          noCatridge: item.noCatridge,
          sealCatridge: item.sealCatridge,
          bagCode: bagCode,
          sealCode: sealCode,
          sealReturn: sealReturn,
          typeCatridgeTrx: 'C',
          section: 'Catridge ${i + 1}',
          scanCatStatus: noAlasan?.isNotEmpty == true ? noAlasan : null,
          scanCatStatusRemark: noRemark?.isNotEmpty == true ? noRemark : null,
          scanSealStatus: sealAlasan?.isNotEmpty == true ? sealAlasan : null,
          scanSealStatusRemark: sealRemark?.isNotEmpty == true ? sealRemark : null,
        );
      }
      
      // Insert Divert catridges if exists (check all 3 sections)
      for (int i = 0; i < 3; i++) {
        // Check if this divert section has data
        bool hasData = _divertControllers[i].any((controller) => controller.text.trim().isNotEmpty);
        if (hasData) {
          String sealReturn = _divertControllers[i][4].text.trim();
          // sealReturn validation already done in _getValidationMessage
          bool isManualMode = _divertManualMode[i];
          String? alasan = isManualMode 
              ? _divertAlasanControllers[i].text.trim() 
              : null;
          String? remark = isManualMode 
              ? _divertRemarkControllers[i].text.trim() 
              : null;
          
          await insertCatridge(
              noCatridge: _divertControllers[i][0].text.trim(),
              sealCatridge: _divertControllers[i][1].text.trim(),
              bagCode: _divertControllers[i][2].text.trim(),
              sealCode: _divertControllers[i][3].text.trim(),
            sealReturn: sealReturn,
            typeCatridgeTrx: 'D',
            section: 'Divert ${i + 1}',
            scanCatStatus: alasan?.isNotEmpty == true ? alasan : null,
            scanCatStatusRemark: remark?.isNotEmpty == true ? remark : null,
            scanSealStatus: null,
            scanSealStatusRemark: null,
          );
        }
      }

      // Insert Pocket catridge if exists
      if (_pocketDetailItem != null) {
        String sealReturn = _pocketControllers[4].text.trim();
        // sealReturn validation already done in _getValidationMessage
        bool isManualMode = _pocketManualMode;
        String? alasan = isManualMode 
            ? _pocketAlasanController.text.trim() 
            : null;
        String? remark = isManualMode 
            ? _pocketRemarkController.text.trim() 
            : null;
        
        await insertCatridge(
          noCatridge: _pocketDetailItem!.noCatridge,
          sealCatridge: _pocketDetailItem!.sealCatridge,
          bagCode: _pocketControllers[2].text.trim(),
          sealCode: _pocketControllers[3].text.trim(),
          sealReturn: sealReturn,
          typeCatridgeTrx: 'P',
          section: 'Pocket',
          scanCatStatus: alasan?.isNotEmpty == true ? alasan : null,
          scanCatStatusRemark: remark?.isNotEmpty == true ? remark : null,
          scanSealStatus: null,
          scanSealStatusRemark: null,
        );
      }

      // Show results
      if (errorMessages.isEmpty) {
        // All success
        CustomModals.showSuccessModal(
          context: context,
          message: 'Semua data berhasil disimpan!\n${successMessages.join('\n')}',
        );
        
        // Hide approval form and potentially navigate back or reset form
        _hideApprovalForm();
        
        // Navigate back
        Navigator.of(context).pop();
        
      } else if (successMessages.isEmpty) {
        // All failed
        throw Exception('Semua catridge gagal disimpan:\n${errorMessages.join('\n')}');
      } else {
        // Mixed results
        _showMixedResultsDialog(successMessages, errorMessages);
      }
      
    } catch (e) {
      print('Submit error: $e');
      CustomModals.showFailedModal(
        context: context,
        message: 'Gagal menyimpan data: ${e.toString()}',
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }
  
  // List to track failed catridges
  List<String> _failedCatridges = [];
  
  // Show dialog for mixed results using CustomModals
  void _showMixedResultsDialog(List<String> successMessages, List<String> errorMessages) {
    String message = 'Beberapa data berhasil disimpan, tetapi beberapa gagal.\n\n';
    
    if (successMessages.isNotEmpty) {
      message += 'Berhasil disimpan (${successMessages.length}):\n';
      for (String msg in successMessages) {
        message += '✓ $msg\n';
      }
      message += '\n';
    }
    
    if (errorMessages.isNotEmpty) {
      message += 'Gagal disimpan (${errorMessages.length}):\n';
      for (String msg in errorMessages) {
        message += '✗ $msg\n';
      }
    }
    
    message += '\nCatatan: Data yang berhasil sudah tersimpan di server.';
    
    CustomModals.showFailedModal(
      context: context,
      message: message.trim(),
      buttonText: 'OK',
              onPressed: () {
                Navigator.of(context).pop();
                _hideApprovalForm();
      },
    );
  }
  
  // Fetch data from API based on ID CRF
  Future<void> _fetchPrepareData() async {
    // DEBUG: Print current token to verify it's correctly stored
    try {
      final token = await _authService.getToken();
      debugPrint('🔴 DEBUG: Current token before fetch: ${token != null ? "Found (${token.length} chars)" : "NULL"}');
      
      // If token is null, try to log the user out and redirect to login page
      if (token == null || token.isEmpty) {
        debugPrint('🔴 DEBUG: Token is null or empty, forcing logout');
        
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sesi telah berakhir. Silakan login kembali.';
        });
        
        // Show dialog with CustomModals
        CustomModals.showFailedModal(
          context: context,
          message: 'Sesi anda telah berakhir. Silakan login kembali.',
          buttonText: 'OK',
                  onPressed: () {
                    Navigator.of(context).pop();
                    _authService.logout().then((_) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    });
          },
        );
        return;
      }
      
      // Validate token before proceeding
      debugPrint('🔴 DEBUG: Validating token before fetch...');
      final isTokenValid = await _apiService.checkTokenValidity();
      if (!isTokenValid) {
        debugPrint('🔴 DEBUG: Token validation failed, forcing logout');
        
        setState(() {
          _isLoading = false;
          _errorMessage = 'Sesi telah berakhir. Silakan login kembali.';
        });
        
        // Show dialog with CustomModals
        CustomModals.showFailedModal(
          context: context,
          message: 'Sesi anda telah berakhir. Silakan login kembali.',
          buttonText: 'OK',
                  onPressed: () {
                    Navigator.of(context).pop();
                    _authService.logout().then((_) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    });
          },
        );
        return;
      }
      
      debugPrint('🔴 DEBUG: Token validation successful, proceeding with fetch');
    } catch (e) {
      debugPrint('🔴 DEBUG: Error getting token: $e');
    }
    
    final idText = _idCRFController.text.trim();
    if (idText.isEmpty) {
      _showErrorDialog('ID CRF tidak boleh kosong');
      return;
    }
    
    // Try to parse ID as integer
    int? id;
    try {
      id = int.parse(idText);
    } catch (e) {
      _showErrorDialog('ID CRF harus berupa angka');
      return;
    }
    
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }
    
    try {
      final response = await _apiService.getATMPrepareReplenish(id);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (response.success && response.data != null) {
            _prepareData = response.data;
            
            // Initialize controllers based on jmlKaset
            int kasetCount = _prepareData!.jmlKaset;
            if (kasetCount <= 0) kasetCount = 1; // Ensure at least 1 catridge
            
            _initializeCatridgeControllers(kasetCount);
            
            // Set jam mulai to current time
            _setCurrentTime();
            
            // Populate catridge fields if data is available
            if (_catridgeControllers.isNotEmpty && _prepareData!.catridgeCode.isNotEmpty) {
              _catridgeControllers[0][0].text = _prepareData!.catridgeCode;
              _catridgeControllers[0][1].text = _prepareData!.catridgeSeal;
              _catridgeControllers[0][2].text = _prepareData!.bagCode;
              _catridgeControllers[0][3].text = _prepareData!.sealCode;
            }
            
            // Note: standValue is now taken directly from _prepareData.standValue
            // No need to store in _denomValues array
            
            // Check if approval form should be hidden
            // REMOVED: _checkAndHideApprovalForm();
          } else {
            // Show error using CustomModals instead of setting _errorMessage
           
            
            // Show error modal after setState
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await CustomModals.showFailedModal(
                context: context,
                message: response.message,
              );
            });
            
            // Check if approval form should be hidden
            // REMOVED: _checkAndHideApprovalForm();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          
          if (e.toString().contains('Session expired') || 
              e.toString().contains('Unauthorized')) {
            _handleSessionExpired();
          } else {
            // Provide more user-friendly error messages
            String errorMessage = e.toString();
            if (errorMessage.contains('Connection timeout') || errorMessage.contains('timeout')) {
              _errorMessage = 'Koneksi timeout. Silakan periksa jaringan dan coba lagi.';
            } else if (errorMessage.contains('Network error') || errorMessage.contains('Connection failed')) {
              _errorMessage = 'Tidak dapat terhubung ke server. Periksa koneksi internet dan coba lagi.';
            } else if (errorMessage.contains('Invalid data format')) {
              _errorMessage = 'Format data dari server tidak valid. Hubungi administrator sistem.';
            } else {
              // For other errors, show generic message
              _errorMessage = 'Terjadi kesalahan. Silakan coba lagi atau hubungi support jika masalah berlanjut.';
            }
          }
        });
        
        // If unauthorized, navigate back to login
        if (e.toString().contains('Unauthorized') || e.toString().contains('Session expired')) {
          CustomModals.showFailedModal(
            context: context,
            message: 'Sesi telah berakhir. Silakan login ulang.',
          );
          
          // Clear token and navigate back
          await _authService.logout();
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
    }
  }

  // Add error handling for session expired
  void _handleSessionExpired() async {
    if (mounted) {
      // Try to refresh token first
      final success = await _authService.refreshToken();
      if (!success) {
        CustomModals.showFailedModal(
          context: context,
          message: 'Sesi telah berakhir. Silakan login kembali.',
        );
        await _authService.logout();
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive layout
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    
    return Scaffold(
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header section with back button, title, and user info
            _buildHeader(context, isSmallScreen),
            
            // Error message if any
            if (_errorMessage.isNotEmpty)
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
                color: Colors.red.shade100,
                width: double.infinity,
                child: Text(
                  _errorMessage,
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
              ),
            
            // Loading indicator
            if (_isLoading)
              const LinearProgressIndicator(),
            
            // Main content - Changes layout based on screen size
            Expanded(
              child: Container(
                color: Colors.white,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Use Row for wide screens, Column for narrow screens (same as return_page)
                    final useRow = constraints.maxWidth >= 600;
                    
                    // ID CRF, Jam Mulai, and Tanggal Replenish fields
                    Widget idCrfAndTimeFields = Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ID CRF field - increased width
                          SizedBox(
                            width: 280,
                            child: _buildFormField(
                              label: 'ID CRF :',
                              controller: _idCRFController,
                              enableScan: false,
                              isSmallScreen: isSmallScreen,
                              hintText: 'Masukkan ID CRF',
                              focusNode: _idCRFFocusNode,
                            ),
                          ),
                          
                          const SizedBox(width: 20),
                          
                          // Jam Mulai field - increased width
                          SizedBox(
                            width: 200,
                            child: _buildFormField(
                              label: 'Jam Mulai :',
                              controller: _jamMulaiController,
                              readOnly: true,
                              hasIcon: true,
                              iconData: Icons.access_time,
                              isSmallScreen: isSmallScreen,
                              hintText: '--:--',
                            ),
                          ),
                          
                          // TANPA BAG label - show when isNoBag is true
                          if (_prepareData?.isNoBag == true) ...[
                            const SizedBox(width: 15),
                            Padding(
                              padding: const EdgeInsets.only(top: 25), // Align with form field
                              child: const Text(
                                'TANPA BAG',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900, // Extra bold
                                ),
                              ),
                            ),
                          ],
                          
                          const Spacer(), // Space between left fields and right field
                          
                          // Tanggal Replenish field - positioned to the right with increased width
                          SizedBox(
                            width: 240,
                            child: _buildFormField(
                              label: 'Tanggal Replenish:',
                              controller: _tanggalReplenishController,
                              readOnly: true,
                              hasIcon: true,
                              iconData: Icons.calendar_today,
                              isSmallScreen: isSmallScreen,
                              hintText: 'dd/mm/yyyy',
                            ),
                          ),
                        ],
                      ),
                    );
                    
                    // Wrap in SingleChildScrollView for proper scrolling
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: useRow
                          ? Column(
                              children: [
                                idCrfAndTimeFields,
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left side - Catridge forms
                                    Expanded(
                                      flex: 7,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Dynamic catridge sections
                                            for (int i = 0; i < _catridgeControllers.length; i++)
                                              _buildCatridgeSection(i + 1, _catridgeControllers[i], _denomValues[i], isSmallScreen),

                                            // Divert sections (3 sections)
                                            for (int i = 0; i < 3; i++)
                                              _buildDivertSection(i, isSmallScreen),

                                            // Pocket section (single)
                                            _buildPocketSection(isSmallScreen),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    // Right side - Details (same level as left)
                                    Expanded(
                                      flex: 5, // Increased from 4 to 5 to make right section even wider
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                          // Detail WSID section
                                          _buildDetailWSIDSection(isSmallScreen),
                                          
                                          // Divider between Detail WSID and Detail Catridge
                                          Container(
                                            margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 15),
                                            height: 1,
                                            color: Colors.grey.withOpacity(0.3),
                                          ),
                                          
                                          // Detail Catridge section
                                          _buildDetailCatridgeSection(isSmallScreen),
                                          
                                          // Grand Total section (simplified)
                                          const SizedBox(height: 20),
                                          _buildGrandTotalInlineSection(isSmallScreen),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                idCrfAndTimeFields,
                                // Left side - Catridge forms
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Dynamic catridge sections
                                    for (int i = 0; i < _catridgeControllers.length; i++)
                                      _buildCatridgeSection(i + 1, _catridgeControllers[i], _denomValues[i], isSmallScreen),

                                    // Divert sections (3 sections)
                                    for (int i = 0; i < 3; i++)
                                      _buildDivertSection(i, isSmallScreen),

                                    // Pocket section (single)
                                    _buildPocketSection(isSmallScreen),
                                  ],
                                ),
                                
                                // Horizontal divider
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 10),
                                  height: 1,
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                                
                                // Right side - Details
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Detail WSID section
                                    _buildDetailWSIDSection(isSmallScreen),
                                    
                                    // Divider between Detail WSID and Detail Catridge
                                    Container(
                                      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 15),
                                      height: 1,
                                      color: Colors.grey.withOpacity(0.3),
                                    ),
                                    
                                    // Detail Catridge section
                                    _buildDetailCatridgeSection(isSmallScreen),
                                    
                                    // Grand Total section (simplified)
                                    const SizedBox(height: 20),
                                    _buildGrandTotalInlineSection(isSmallScreen),
                                  ],
                                ),
                              ],
                            ),
                    );
                  }
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isSmallScreen) {
    final isTabletOrLandscapeMobile = MediaQuery.of(context).size.width >= 768;
    final isTablet = MediaQuery.of(context).size.width >= 768;
    
    return Container(
      height: isTabletOrLandscapeMobile ? 80 : 70,
      padding: EdgeInsets.symmetric(
        horizontal: isTabletOrLandscapeMobile ? 32.0 : 24.0,
        vertical: isTabletOrLandscapeMobile ? 16.0 : 12.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Menu button - Green hamburger icon
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: isTabletOrLandscapeMobile ? 48 : 40,
              height: isTabletOrLandscapeMobile ? 48 : 40,
              child: Image.asset(
                'assets/images/back.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  );
                },
              ),
            ),
          ),
          SizedBox(width: isTabletOrLandscapeMobile ? 20 : 16),
          
          // Title
          Text(
            'Prepare Mode',
            style: TextStyle(
              fontSize: isTabletOrLandscapeMobile ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          
          const Spacer(),
          
          // Location info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _branchName,
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              SizedBox(
                width: isTablet ? 100 : 80,
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _authService.getUserData(),
                  builder: (context, snapshot) {
                    String meja = '';
                    if (snapshot.hasData && snapshot.data != null) {
                      meja = snapshot.data!['noMeja'] ?? 
                            snapshot.data!['NoMeja'] ?? 
                            '010101';
                    } else {
                      meja = '010101';
                    }
                    return Text(
                      'Meja: $meja',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF6B7280),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    );
                  },
                ),
              ),
            ],
          ),
          
          SizedBox(width: isTablet ? 24 : 20),
          
          // CRF_KONSOL button
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 12 : 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              _userData?['role'] ?? 'CRF_KONSOL', // Get role from user data, fallback to default
              style: TextStyle(
                color: Colors.white,
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          SizedBox(width: isTablet ? 16 : 12),
          
          // Refresh button
          GestureDetector(
            onTap: () {
              // Refresh data when clicked
              _fetchPrepareData();
            },
            child: Container(
              width: isTablet ? 44 : 40,
              height: isTablet ? 44 : 40,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.refresh,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          
          SizedBox(width: isTablet ? 24 : 20),
          
          // User info
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: isTablet ? 150 : 120),
                    child: Text(
                      _userName,
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _authService.getUserData(),
                    builder: (context, snapshot) {
                      String nik = '';
                      if (snapshot.hasData && snapshot.data != null) {
                        nik = snapshot.data!['userId'] ?? 
                              snapshot.data!['userID'] ?? 
                              '';
                      } else {
                        nik = _userData != null && _userData!.containsKey('userId') ? _userData!['userId'] : '';
                      }
                      return Text(
                        nik,
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF6B7280),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SizedBox(width: isTablet ? 12 : 10),
              GestureDetector(
                onTap: () async {
                  final confirmed = await CustomModals.showConfirmationModal(
                    context: context,
                    message: "Apakah kamu yakin ingin pergi ke halaman profile?",
                    confirmText: "Ya",
                    cancelText: "Tidak",
                  );
                  if (confirmed) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ProfileMenuScreen(),
                      ),
                    );
                  }
                },
                child: Container(
                  width: isTablet ? 48 : 44,
                  height: isTablet ? 48 : 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: FutureBuilder<ImageProvider>(
                      future: _profileService.getProfilePhoto(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done && 
                            snapshot.hasData) {
                          return Image(
                            image: snapshot.data!,
                            width: isTablet ? 48 : 44,
                            height: isTablet ? 48 : 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF10B981),
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              );
                            },
                          );
                        } else {
                          return Container(
                            color: const Color(0xFF10B981),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormHeaderFields(bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 8.0 : 16.0),
      child: isSmallScreen
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ID CRF field - removed search button
                _buildFormField(
                  label: 'ID CRF :',
                  controller: _idCRFController,
                  hasIcon: false,
                  isSmallScreen: isSmallScreen,
                  enableScan: true,
                  focusNode: _idCRFFocusNode,
                ),
                
                const SizedBox(height: 8),
                
                // Jam Mulai field with time icon
                _buildFormField(
                  label: 'Jam Mulai :',
                  controller: _jamMulaiController,
                  hasIcon: true,
                  iconData: Icons.access_time,
                  isSmallScreen: isSmallScreen,
                ),
                
                const SizedBox(height: 8),
                
                // Tanggal Replenish field (auto-filled with current date)
                _buildFormField(
                  label: 'Tanggal Replenish :',
                  controller: _tanggalReplenishController,
                  readOnly: true,
                  isSmallScreen: isSmallScreen,
                ),
              ],
            )
          : Row(
              children: [
                // ID CRF field - removed search button
                Expanded(
                  child: _buildFormField(
                    label: 'ID CRF :',
                    controller: _idCRFController,
                    hasIcon: false,
                    isSmallScreen: isSmallScreen,
                    enableScan: true,
                    focusNode: _idCRFFocusNode,
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // Jam Mulai field with time icon
                Expanded(
                  child: _buildFormField(
                    label: 'Jam Mulai :',
                    controller: _jamMulaiController,
                    hasIcon: true,
                    iconData: Icons.access_time,
                    isSmallScreen: isSmallScreen,
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // Tanggal Replenish field (auto-filled with current date)
                Expanded(
                  child: _buildFormField(
                    label: 'Tanggal Replenish :',
                    controller: _tanggalReplenishController,
                    readOnly: true,
                    isSmallScreen: isSmallScreen,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCatridgeSection(
    int index, 
    List<TextEditingController> controllers, 
    int denomValue,
    bool isSmallScreen
  ) {
    // Get tipeDenom from API data if available
    String? tipeDenom = _prepareData?.tipeDenom;
    int standValue = _prepareData?.standValue ?? 0;
    
    // Convert tipeDenom to rupiah value
    String denomText = '';
    int denomAmount = 0;
    
    // Only show denom values if _prepareData is available
    if (_prepareData != null && tipeDenom != null) {
      if (tipeDenom == 'A50') {
        denomText = 'Rp 50.000';
        denomAmount = 50000;
      } else if (tipeDenom == 'A100') {
        denomText = 'Rp 100.000';
        denomAmount = 100000;
      } else {
        // Default fallback
        denomText = 'Rp 50.000';
        denomAmount = 50000;
      }
    } else {
      // Empty state when no data is available
      denomText = '—';
    }
    
    // Calculate total nominal using standValue from prepare data
    String formattedTotal = '—';
    int actualValue = _prepareData?.standValue ?? 0;
    
    if (denomAmount > 0 && actualValue > 0) {
      int totalNominal = denomAmount * actualValue;
      formattedTotal = _formatCurrency(totalNominal);
    }
    
    // Determine image path based on tipeDenom
    String? imagePath;
    if (_prepareData != null && tipeDenom != null) {
      imagePath = 'assets/images/$tipeDenom.png';
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Catridge title with Manual Mode icon and Denom indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 2,
                child: Row(
                  children: [
                    Text(
                  'Catridge $index',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 18,
                    fontWeight: FontWeight.bold,
                        color: (index - 1 < _catridgeSectionActive.length && _catridgeSectionActive[index - 1]) 
                            ? const Color(0xFF4CAF50) // Green when active
                            : Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Flexible(
                flex: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Denom',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 4 : 8),
                    Flexible(
                      child: Text(
                        denomText,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          SizedBox(height: isSmallScreen ? 6 : 15),
          
          // Fields with denom section on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - All 5 fields in single column (vertical) - made narrower
              Expanded(
                flex: isSmallScreen ? 2 : 2, // Reduced from 3 to 2 to make form fields narrower
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // No. Catridge field
                    _buildCompactField(
                      label: 'No. Catridge', 
                      controller: controllers[0],
                      focusNode: (index - 1 < _catridgeFocusNodes.length) ? _catridgeFocusNodes[index - 1][0] : null,
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid(), // Read-only if ID CRF is not valid
                      catridgeIndex: 100 + (index - 1), // Pass catridge index with offset 100
                      onChanged: (value) {
                        // Only trigger manual mode when user actually types
                        if (value.isNotEmpty) {
                          _onCatridgeFieldChanged(index - 1, 0);
                        }
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Catridge field
                    _buildCompactField(
                      label: 'Seal Catridge', 
                      controller: controllers[1],
                      focusNode: (index - 1 < _catridgeFocusNodes.length) ? _catridgeFocusNodes[index - 1][1] : null,
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid(), // Read-only if ID CRF is not valid
                      catridgeIndex: 100 + (index - 1), // Pass catridge index with offset 100
                      onChanged: (value) {
                        // Only trigger manual mode when user actually types
                        if (value.isNotEmpty) {
                          _onCatridgeFieldChanged(index - 1, 1);
                        }
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Bag Code field - NEW: Always editable (not dependent on manual mode)
                    _buildCompactField(
                      label: 'Bag Code', 
                      controller: controllers[2],
                      focusNode: (index - 1 < _catridgeFocusNodes.length) ? _catridgeFocusNodes[index - 1][2] : null,
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid() || (_prepareData?.isNoBag ?? false), // Disabled if isNoBag is true
                      onChanged: (value) {
                        _updateDetailCatridgeItemField(index - 1, 'bagCode', value);
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Code field - NEW: Always editable (not dependent on manual mode)
                    _buildCompactField(
                      label: 'Seal Code', 
                      controller: controllers[3],
                      focusNode: (index - 1 < _catridgeFocusNodes.length) ? _catridgeFocusNodes[index - 1][3] : null,
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid() || (_prepareData?.isNoBag ?? false), // Disabled if isNoBag is true
                      onChanged: (value) {
                        _updateDetailCatridgeItemField(index - 1, 'sealCode', value);
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Code Return field - NEW: Always editable (not dependent on manual mode)
                    if (controllers.length >= 5)
                      _buildCompactField(
                        label: 'Seal Code Return', 
                        controller: controllers[4],
                        focusNode: (index - 1 < _catridgeFocusNodes.length) ? _catridgeFocusNodes[index - 1][4] : null,
                        isSmallScreen: isSmallScreen,
                        isReadOnly: !_isIdCRFValid() || (_prepareData?.isNoBag ?? false), // Disabled if isNoBag is true
                        onChanged: (value) {
                          _updateDetailCatridgeItemField(index - 1, 'sealReturn', value);
                        },
                      ),
                    


                  ],
                ),
              ),
              
              SizedBox(width: isSmallScreen ? 12 : 16),
              
              // Right side - Denom details with image and total - balanced width
              Expanded(
                flex: isSmallScreen ? 1 : 1, // Reduced from 2 to 1 to make middle section narrower // Reduced from 2:3 to 3:2
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Money image - adjusted size
                    Container(
                      height: isSmallScreen ? 110 : 135,
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _prepareData == null || imagePath == null
                        ? Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: isSmallScreen ? 45 : 60,
                              color: Colors.grey.shade400,
                            ),
                          )
                        : Image.asset(
                            imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.currency_exchange,
                                    size: isSmallScreen ? 45 : 60,
                                    color: Colors.blue,
                                  ),
                                  SizedBox(height: isSmallScreen ? 5 : 8),
                                  Text(
                                    denomText,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 13 : 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              );
                            },
                          ),
                    ),
                    
                    // Value and Lembar info
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 9 : 11),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Value',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _prepareData?.standValue != null && _prepareData!.standValue > 0
                              ? _prepareData!.standValue.toString()
                              : '—',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                            ),
                          ),
                          Text(
                            'Lembar',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Total Nominal box
                    Container(
                      margin: EdgeInsets.only(top: isSmallScreen ? 11 : 16),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 11 : 13, 
                        horizontal: isSmallScreen ? 9 : 11
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,  // Changed from light green to white
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade400,  // Gray border
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,  // Gray shadow
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Nominal',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallScreen ? 5 : 8),
                          Text(
                            formattedTotal,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 17,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Divider at the bottom
          Padding(
            padding: EdgeInsets.only(top: isSmallScreen ? 15 : 25),
            child: Container(
              height: 1,
              color: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to format currency
  String _formatCurrency(int amount) {
    String value = amount.toString();
    String result = '';
    int count = 0;
    
    for (int i = value.length - 1; i >= 0; i--) {
      count++;
      result = value[i] + result;
      if (count % 3 == 0 && i > 0) {
        result = '.$result';
      }
    }
    
    return 'Rp $result';
  }

  // Helper method to calculate dynamic font size based on value length
  double _calculateDynamicFontSize(String formattedValue, bool isSmallScreen) {
    // Remove 'Rp ' and count characters
    String cleanValue = formattedValue.replaceAll('Rp ', '').replaceAll('—', '');
    int length = cleanValue.length;
    
    // Base font sizes
    double baseFontSize = isSmallScreen ? 12 : 16;
    double minFontSize = isSmallScreen ? 10 : 12;
    
    // Adjust font size based on length
    if (length <= 8) {
      // Short values (up to 99.999): normal size
      return baseFontSize;
    } else if (length <= 12) {
      // Medium values (up to 999.999.999): slightly smaller
      return baseFontSize - (isSmallScreen ? 1 : 2);
    } else {
      // Long values (1.000.000.000+): minimum size
      return minFontSize;
    }
  }

  // Helper method to build compact field (for inline layout with underline)
  Widget _buildCompactField({
    required String label,
    required TextEditingController controller,
    required bool isSmallScreen,
    FocusNode? focusNode,
    bool isReadOnly = false,
    VoidCallback? onEditingComplete,
    Function(String)? onChanged,
    int? catridgeIndex, // Add catridge index for manual mode tracking
  }) {
    // Check if this is a manual mode field (No. Catridge or Seal Catridge)
    bool isManualModeField = (label == 'No. Catridge' || label == 'Seal Catridge');
    
    return SizedBox(
      height: isSmallScreen ? 40 : 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Label section - fixed width
          SizedBox(
            width: isSmallScreen ? 90 : 110,
            child: Padding(
              padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
              child: Text(
                '$label :',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Input field section with underline - expandable
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        readOnly: isReadOnly,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 12,
                          color: isReadOnly ? Colors.grey.shade600 : null,
                        ),
                        decoration: InputDecoration(
                          contentPadding: EdgeInsets.only(
                            left: isSmallScreen ? 4 : 6,
                            right: isSmallScreen ? 4 : 6,
                            bottom: isSmallScreen ? 4 : 6,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          fillColor: isReadOnly ? Colors.grey.shade100 : null,
                          filled: isReadOnly,
                        ),
                        onChanged: onChanged,
                        onEditingComplete: onEditingComplete,
                    ),
                  ),
                  // Scan barcode icon button - positioned on the underline
                  Container(
                    width: isSmallScreen ? 28 : 32,
                    height: isSmallScreen ? 28 : 32,
                    margin: EdgeInsets.only(
                      left: isSmallScreen ? 4 : 6,
                      bottom: isSmallScreen ? 2 : 3,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.qr_code_scanner,
                        size: isSmallScreen ? 20 : 24,
                        color: Colors.blue.shade600,
                      ),
                      onPressed: () => _openBarcodeScanner(label, controller),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  // Manual mode icon - only show when field has content and is manual mode field
                  if (isManualModeField && catridgeIndex != null && _shouldShowManualIcon(catridgeIndex, label))
                    Container(
                      width: isSmallScreen ? 28 : 32,
                      height: isSmallScreen ? 28 : 32,
                      margin: EdgeInsets.only(
                        left: isSmallScreen ? 2 : 4,
                        bottom: isSmallScreen ? 2 : 3,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          _showManualModePopup(catridgeIndex, label);
                        },
                        child: _buildFieldSpecificManualIcon(catridgeIndex, label, isSmallScreen),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailWSIDSection(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 15 : 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '| Detail WSID',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 15),
          
          _buildDetailRow('WSID', _prepareData?.atmCode ?? '-', isSmallScreen),
          _buildDetailRow('Bank', _prepareData?.codeBank ?? '-', isSmallScreen),
          _buildDetailRow('Lokasi', _prepareData?.lokasi ?? '-', isSmallScreen),
          _buildDetailRow('ATM Type', _prepareData?.idTypeATM ?? '-', isSmallScreen),
          _buildDetailRow('Jumlah Kaset', '${_prepareData?.jmlKaset ?? 0}', isSmallScreen),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 4 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSmallScreen ? 80 : 100,
            child: Text(
              '$label :',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailCatridgeSection(bool isSmallScreen) {
    // Debug logging to check what's in _detailCatridgeItems
    print('🐛 DEBUG: _detailCatridgeItems count: ${_detailCatridgeItems.length}');
    for (var item in _detailCatridgeItems) {
      print('🐛 DEBUG: Item index ${item.index}, noCatridge: ${item.noCatridge}, type: ${item.index >= 200 ? "Pocket" : item.index >= 100 ? "Divert" : "Main"}');
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 15 : 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Catridge Details
          Text(
            '| Detail Catridge',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 15),
          
          // Scrollable container for detail catridge items
          Container(
            height: _detailCatridgeItems.length > 2 ? 400 : null, // Dynamic height based on item count
            constraints: _detailCatridgeItems.length <= 2 ? null : BoxConstraints(maxHeight: 400),
            child: _detailCatridgeItems.isNotEmpty
                ? _detailCatridgeItems.length > 2
                    ? SingleChildScrollView(
                        child: Column(
                          children: _detailCatridgeItems.map((item) => _buildDetailCatridgeItem(item, isSmallScreen)).toList(),
                        ),
                      )
                    : Column(
                        children: _detailCatridgeItems.map((item) => _buildDetailCatridgeItem(item, isSmallScreen)).toList(),
                      )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'No catridge data available',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailCatridgeItem(DetailCatridgeItem item, bool isSmallScreen) {
    // Check if this is an error item
    bool isError = item.total.contains('Error') || item.total.contains('tidak ditemukan') || 
                   item.sealCatridge.contains('Error') || item.sealCatridge.contains('tidak valid');
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      decoration: BoxDecoration(
        border: Border.all(color: isError ? Colors.red.shade300 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Catridge number, Denom and trash icon
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 8 : 12,
              vertical: isSmallScreen ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: isError ? Colors.red.shade50 : Colors.grey.shade50,
              border: Border(
                bottom: BorderSide(color: isError ? Colors.red.shade300 : Colors.grey.shade300),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        _getDetailItemTitle(item.index),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.bold,
                          color: isError ? Colors.red.shade700 : null,
                        ),
                      ),
                      const SizedBox(width: 20),
                      if (!isError)
                        Flexible(
                          child: Text(
                            'Denom : ${item.denom}',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: isSmallScreen ? 16 : 18,
                        ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: isSmallScreen ? 20 : 24,
                    ),
                    onPressed: () => _removeDetailCatridgeItem(item.index),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Detail fields
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
            child: Column(
              children: [
                _buildDetailItemRow('No. Catridge', item.noCatridge, isSmallScreen, isError),
                SizedBox(height: isSmallScreen ? 6 : 8),
                _buildDetailItemRow('Seal Catridge', item.sealCatridge, isSmallScreen, isError),
                SizedBox(height: isSmallScreen ? 6 : 8),
                _buildDetailItemRow('Bag Code', item.bagCode, isSmallScreen, isError),
                SizedBox(height: isSmallScreen ? 6 : 8),
                _buildDetailItemRow('Seal Code', item.sealCode, isSmallScreen, isError),
                SizedBox(height: isSmallScreen ? 6 : 8),
                _buildDetailItemRow('Seal Code Return', item.sealReturn, isSmallScreen, isError),
                SizedBox(height: isSmallScreen ? 6 : 8),
                _buildDetailItemRow('Value', item.value.toString(), isSmallScreen, isError),
                SizedBox(height: isSmallScreen ? 6 : 8),
                _buildDetailItemRow('Total', item.total, isSmallScreen, isError),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailItemRow(String label, String value, bool isSmallScreen, [bool isError = false]) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isSmallScreen ? 100 : 120,
          child: Text(
            '$label :',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.w500,
              color: isError ? Colors.red.shade700 : null,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              color: isError && (value.contains('Error') || value.contains('tidak')) 
                     ? Colors.red.shade700 : null,
              fontWeight: isError && (value.contains('Error') || value.contains('tidak'))
                        ? FontWeight.w500 : null,
            ),
          ),
        ),
      ],
    );
  }
  
  // Build Approval TL Supervisor form sesuai design baru
  Widget _buildApprovalForm(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 15 : 25, top: isSmallScreen ? 10 : 15),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - sesuai design baru
          Row(
            children: [
              Text(
                'Approval TL Supervisor',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 12 : 16),
          
          // NIK TL SPV Field
          _buildApprovalField(
            label: 'NIK TL SPV',
            controller: _nikTLController,
            isSmallScreen: isSmallScreen,
            icon: Icons.person,
          ),
          
          SizedBox(height: isSmallScreen ? 12 : 16),
          
          // Password Field
          _buildApprovalField(
            label: 'Password',
            controller: _passwordTLController,
            isSmallScreen: isSmallScreen,
            icon: Icons.lock,
            isPassword: true,
          ),
          
          SizedBox(height: isSmallScreen ? 16 : 20),
          
          // OR Divider - sesuai design baru
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey.shade400)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'ATAU',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey.shade400)),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 12 : 16),
          
          // QR Code Generator Section - pindah ke bawah form
          SizedBox(height: isSmallScreen ? 16 : 20),
          Center(
            child: QRCodeGeneratorWidget(
              action: 'PREPARE',
              idTool: _prepareData?.id.toString() ?? _idCRFController.text,
              catridgeData: _prepareCatridgeQRData(),
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 16 : 20),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Cancel button
              TextButton(
                onPressed: _isSubmitting ? null : _hideApprovalForm,
                child: Text(
                  'Batal',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Submit button
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5AE25A), Color(0xFF29CC29)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: ElevatedButton.icon(
                  onPressed: _handleApproveSubmitButtonPressed,
                  icon: _isSubmitting 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(Icons.check, size: isSmallScreen ? 16 : 18),
                  label: Text(
                    _isSubmitting ? 'Processing...' : 'Approve & Submit',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 8 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Helper method to build approval form fields - sesuai design baru
  Widget _buildApprovalField({
    required String label,
    required TextEditingController controller,
    required bool isSmallScreen,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            enabled: !_isSubmitting,
            style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              suffixIcon: isPassword 
                ? const Icon(Icons.visibility, color: Colors.grey) 
                : const Icon(Icons.person_outline, color: Colors.grey),
              hintText: isPassword ? '••••••••••' : '',
              hintStyle: TextStyle(
                color: Colors.grey.shade400,
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  
  Widget _buildGrandTotalInlineSection(bool isSmallScreen) {
    final totalAmount = _calculateGrandTotal();
    final formattedTotal = totalAmount > 0 ? _formatCurrency(totalAmount) : '—';
    final isDataReady = _prepareData != null;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20, 
        vertical: isSmallScreen ? 14 : 18
      ),
      decoration: _buildGrandTotalDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildGrandTotalText(formattedTotal, isSmallScreen),
          _buildSubmitButton(isSmallScreen, isDataReady),
        ],
      ),
    );
  }
  
  // Simplified calculation method
  int _calculateGrandTotal() {
    if (_prepareData == null || _detailCatridgeItems.isEmpty) return 0;
    
    int totalAmount = 0;
    final denomAmount = _getDenomAmount();
    
    for (var item in _detailCatridgeItems) {
      String cleanTotal = item.total.replaceAll('Rp ', '').replaceAll('.', '').trim();
      if (cleanTotal.isNotEmpty && cleanTotal != '0') {
        try {
          totalAmount += int.parse(cleanTotal);
        } catch (e) {
          totalAmount += denomAmount * item.value;
        }
      }
    }
    return totalAmount;
  }
  
  // Get denomination amount
  int _getDenomAmount() {
    String tipeDenom = _prepareData?.tipeDenom ?? 'A50';
    return tipeDenom == 'A100' ? 100000 : 50000;
  }
  
  // Build decoration for grand total container
  BoxDecoration _buildGrandTotalDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade300, width: 1.5),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    );
  }
  
  // Build grand total text widget
  Widget _buildGrandTotalText(String formattedTotal, bool isSmallScreen) {
    return Expanded(
      child: Row(
        children: [
          Text(
            'Grand Total : ',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Flexible(
            child: Text(
              formattedTotal,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  // Build submit button widget
  Widget _buildSubmitButton(bool isSmallScreen, bool isDataReady) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: const LinearGradient(
          colors: [Color(0xFF5AE25A), Color(0xFF29CC29)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: ElevatedButton.icon(
        onPressed: isDataReady 
            ? _handleSubmitButtonPressed 
            : null,
        icon: Icon(Icons.arrow_forward, size: isSmallScreen ? 18 : 20),
        label: Text(
          'Submit Data',
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14, // Reduced from 14:16 to 12:14
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12 : 16, // Reduced from 16:20 to 12:16 to make button narrower
            vertical: isSmallScreen ? 10 : 12
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          minimumSize: Size(0, 0),
        ),
      ),
    );
  }
  
  Widget _buildTotalAndSubmitSection(bool isSmallScreen) {
    // Add debugging for submit button validation
    print('=== SUBMIT BUTTON CHECK ===');
    print('_prepareData is null: ${_prepareData == null}');
    print('_detailCatridgeItems.length: ${_detailCatridgeItems.length}');
    if (_detailCatridgeItems.isNotEmpty) {
      for (int i = 0; i < _detailCatridgeItems.length; i++) {
        var item = _detailCatridgeItems[i];
        print('Item $i: ${item.noCatridge} - ${item.sealCatridge} - ${item.value} - ${item.total}');
      }
    }
    bool isValid = _areAllCatridgeItemsValid();
    print('_areAllCatridgeItemsValid(): $isValid');
    
    // Jika belum ada data, tampilkan format inline dengan ukuran lebih besar
    if (_prepareData == null) {
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 16 : 20, 
          vertical: isSmallScreen ? 14 : 18
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Grand Total : — ',
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const LinearGradient(
                  colors: [Color(0xFF5AE25A), Color(0xFF29CC29)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: _areAllCatridgeItemsValid() ? _showApprovalFormDialog : null,
                icon: Icon(Icons.arrow_forward, size: isSmallScreen ? 18 : 20),
                label: Text(
                  'Submit Data',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 16 : 20, 
                    vertical: isSmallScreen ? 10 : 12
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  minimumSize: Size(0, 0),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Get tipeDenom from API data if available
    String tipeDenom = _prepareData?.tipeDenom ?? 'A50';
    int standValue = _prepareData?.standValue ?? 0;
    
    // Convert tipeDenom to rupiah value
    int denomAmount = 0;
    if (tipeDenom == 'A50') {
      denomAmount = 50000;
    } else if (tipeDenom == 'A100') {
      denomAmount = 100000;
    } else {
      // Default fallback
      denomAmount = 50000;
    }
    
    // Calculate total from detail catridge items
    int totalAmount = 0;
    for (var item in _detailCatridgeItems) {
      // Parse total back to int (remove currency formatting)
      String cleanTotal = item.total.replaceAll('Rp ', '').replaceAll('.', '').trim();
      if (cleanTotal.isNotEmpty && cleanTotal != '0') {
        try {
          totalAmount += int.parse(cleanTotal);
        } catch (e) {
          // If parsing fails, calculate from value and denom
          String tipeDenom = _prepareData?.tipeDenom ?? 'A50';
          int denomAmount = tipeDenom == 'A100' ? 100000 : 50000;
          totalAmount += denomAmount * item.value;
        }
      }
    }
    
    String formattedTotal = totalAmount > 0 ? _formatCurrency(totalAmount) : '—';
    double dynamicFontSize = _calculateDynamicFontSize(formattedTotal, isSmallScreen);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 20, 
        vertical: isSmallScreen ? 14 : 18
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  'Grand Total : ',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Flexible(
                  child: Text(
                    formattedTotal,
                    style: TextStyle(
                      fontSize: (dynamicFontSize * 0.8).clamp(12.0, 18.0), // Mengecilkan font nominal dengan batas minimum
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                colors: [Color(0xFF5AE25A), Color(0xFF29CC29)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: _areAllCatridgeItemsValid() ? _showApprovalFormDialog : null,
              icon: Icon(Icons.arrow_forward, size: isSmallScreen ? 18 : 20),
              label: Text(
                'Submit Data',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 20, 
                  vertical: isSmallScreen ? 10 : 12
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                minimumSize: Size(0, 0),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to check if ID CRF is valid
  bool _isIdCRFValid() {
    return _idCRFController.text.trim().isNotEmpty && _prepareData != null;
  }

  Widget _buildFormField({
    required String label,
    TextEditingController? controller,
    bool readOnly = false,
    String? hintText,
    bool hasIcon = false,
    IconData iconData = Icons.search,
    VoidCallback? onIconPressed,
    required bool isSmallScreen,
    bool enableScan = false,
    Function(bool)? onFocusChange,
    FocusNode? focusNode,
  }) {
    // Make all fields except ID CRF read-only if ID CRF is not valid
    bool shouldBeReadOnly = readOnly || (label != 'ID CRF :' && !_isIdCRFValid());
    return SizedBox(
      height: isSmallScreen ? 40 : 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Label section - fixed width
          SizedBox(
            width: isSmallScreen ? 90 : 110,
            child: Padding(
              padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Input field section with underline - expandable
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      readOnly: shouldBeReadOnly,
                      style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                      decoration: InputDecoration(
                        hintText: hintText,
                        contentPadding: EdgeInsets.only(
                          left: isSmallScreen ? 4 : 6,
                          right: isSmallScreen ? 4 : 6,
                          bottom: isSmallScreen ? 6 : 8,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (value) {
                         // Keep onChanged for other potential uses but remove auto-fetch
                         // Auto-fetch is now handled by onFocusChange for better UX
                       },
                    ),
                  ),
                  
                  // Icons positioned on the underline
                  if (enableScan && controller != null)
                    Container(
                      width: isSmallScreen ? 20 : 24,
                      height: isSmallScreen ? 20 : 24,
                      margin: EdgeInsets.only(
                        left: isSmallScreen ? 4 : 6,
                        bottom: isSmallScreen ? 3 : 4,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.qr_code_scanner,
                          size: isSmallScreen ? 14 : 18,
                          color: Colors.blue.shade600,
                        ),
                        onPressed: () => _openBarcodeScanner(label, controller),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    
                  if (hasIcon)
                    Container(
                      width: isSmallScreen ? 20 : 24,
                      height: isSmallScreen ? 20 : 24,
                      margin: EdgeInsets.only(
                        left: isSmallScreen ? 4 : 6,
                        bottom: isSmallScreen ? 3 : 4,
                      ),
                      child: IconButton(
                        icon: Icon(
                          iconData,
                          size: isSmallScreen ? 14 : 18,
                          color: Colors.grey.shade700,
                        ),
                        onPressed: onIconPressed,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  // Open barcode scanner for field input
  Future<void> _openBarcodeScanner(String fieldLabel, TextEditingController controller) async {
    try {
      print('Opening barcode scanner for field: $fieldLabel');
      
      // Clean field label for display
      String cleanLabel = fieldLabel.replaceAll(' :', '').trim();
      
      // Navigate to barcode scanner
      final result = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (context) => BarcodeScannerWidget(
            title: 'Scan $cleanLabel',
            onBarcodeDetected: (String barcode) {
              print('Barcode detected for $cleanLabel: $barcode');
              
              // Fill the field with scanned barcode
              setState(() {
                controller.text = barcode;
              });
              
              // Reset manual mode immediately after successful scan
              if (cleanLabel == 'No. Catridge') {
                // Find catridge index for this controller and reset manual mode
                for (int i = 0; i < _catridgeControllers.length; i++) {
                  if (_catridgeControllers[i].isNotEmpty && _catridgeControllers[i][0] == controller) {
                    setState(() {
                      _catridgeNoManualMode[i] = false;
                      _catridgeNoAlasanControllers[i].clear();
                      _catridgeNoRemarkControllers[i].clear();
                      _catridgeRemarkFilled[i] = false;
                      print('🔄 RESET: Manual mode reset for catridge $i after scan');
                    });
                    break;
                  }
                }
                
                // Check if this is a Divert No. Catridge field
                for (int i = 0; i < _divertControllers.length; i++) {
                  if (_divertControllers[i].isNotEmpty && _divertControllers[i][0] == controller) {
                    setState(() {
                      _divertManualMode[i] = false;
                      _divertNoManualMode[i] = false;
                      _divertAlasanControllers[i].clear();
                      _divertRemarkControllers[i].clear();
                      if (i < _divertNoAlasanControllers.length) _divertNoAlasanControllers[i].clear();
                      if (i < _divertNoRemarkControllers.length) _divertNoRemarkControllers[i].clear();
                      print('🔄 RESET: Divert manual mode reset for section $i after scan');
                    });
                    break;
                  }
                }
                
                // Check if this is a Pocket No. Catridge field
                if (_pocketControllers.isNotEmpty && _pocketControllers[0] == controller) {
                  setState(() {
                    _pocketManualMode = false;
                    _pocketNoManualMode = false;
                    _pocketAlasanController.clear();
                    _pocketNoAlasanController.clear();
                    _pocketNoRemarkController.clear();
                    print('🔄 RESET: Pocket manual mode reset after scan');
                  });
                }
              } else if (cleanLabel == 'Seal Catridge') {
                // Find catridge index for this controller and reset seal manual mode
                for (int i = 0; i < _catridgeControllers.length; i++) {
                  if (_catridgeControllers[i].length > 1 && _catridgeControllers[i][1] == controller) {
                    setState(() {
                      _catridgeSealManualMode[i] = false;
                      _catridgeSealAlasanControllers[i].clear();
                      _catridgeSealRemarkControllers[i].clear();
                      _catridgeSealRemarkFilled[i] = false;
                      print('🔄 RESET: Seal manual mode reset for catridge $i after scan');
                    });
                    break;
                  }
                }
                
                // Check if this is a Divert Seal Catridge field
                for (int i = 0; i < _divertControllers.length; i++) {
                  if (_divertControllers[i].length > 1 && _divertControllers[i][1] == controller) {
                    setState(() {
                      _divertManualMode[i] = false;
                      _divertSealManualMode[i] = false;
                      _divertAlasanControllers[i].clear();
                      _divertRemarkControllers[i].clear();
                      if (i < _divertSealAlasanControllers.length) _divertSealAlasanControllers[i].clear();
                      if (i < _divertSealRemarkControllers.length) _divertSealRemarkControllers[i].clear();
                      print('🔄 RESET: Divert manual mode reset for section $i after scan');
                    });
                    break;
                  }
                }
                
                // Check if this is a Pocket Seal Catridge field
                if (_pocketControllers.length > 1 && _pocketControllers[1] == controller) {
                  setState(() {
                    _pocketManualMode = false;
                    _pocketSealManualMode = false;
                    _pocketAlasanController.clear();
                    _pocketSealAlasanController.clear();
                    _pocketSealRemarkController.clear();
                    print('🔄 RESET: Pocket manual mode reset after scan');
                  });
                }
              } else if (cleanLabel == 'Bag Code' || cleanLabel == 'Seal Code' || cleanLabel == 'Seal Code Return') {
                 // Check if this is a Divert field (Bag Code, Seal Code, or Seal Code Return)
                 for (int i = 0; i < _divertControllers.length; i++) {
                   for (int j = 2; j < _divertControllers[i].length; j++) {
                     if (_divertControllers[i][j] == controller) {
                       setState(() {
                         _divertManualMode[i] = false;
                         _divertAlasanControllers[i].clear();
                         _divertRemarkControllers[i].clear();
                         print('🔄 RESET: Divert manual mode reset for section $i after scan');
                       });
                       break;
                     }
                   }
                 }
                 
                 // Check if this is a Pocket field (Bag Code, Seal Code, or Seal Code Return)
                 for (int j = 2; j < _pocketControllers.length; j++) {
                   if (_pocketControllers[j] == controller) {
                     setState(() {
                       _pocketManualMode = false;
                       _pocketAlasanController.clear();
                       print('🔄 RESET: Pocket manual mode reset after scan');
                     });
                     break;
                   }
                 }
               }
            },
          ),
        ),
      );
      
      // Handle result after scanner closes
      if (result != null && result.isNotEmpty) {
        // Show success message after scanner closes
        CustomModals.showSuccessModal(
          context: context,
          message: '$cleanLabel berhasil diisi: $result',
        );
        
        // Trigger the same logic as manual input
        if (cleanLabel == 'ID CRF') {
          // Trigger API call to fetch prepare data
          Future.delayed(const Duration(milliseconds: 2000), () {
            _fetchPrepareData();
          });
        } else if (cleanLabel == 'No. Catridge') {
          // Find catridge index for this controller
          for (int i = 0; i < _catridgeControllers.length; i++) {
            if (_catridgeControllers[i].isNotEmpty && _catridgeControllers[i][0] == controller) {
              Future.delayed(const Duration(milliseconds: 2000), () {
                _lookupCatridgeAndCreateDetail(i, result);
              });
              break;
            }
          }
          
          // Check if this is a Divert No. Catridge field
          for (int i = 0; i < _divertControllers.length; i++) {
            if (_divertControllers[i].isNotEmpty && _divertControllers[i][0] == controller) {
              // Check for duplicates before API call
              String fieldKey = 'divert_${i}_no';
              String fieldName = 'No. Catridge (Divert ${i + 1})';
              String apiKey = 'divert_${i}_${result}';
              
              // Skip if API call is already in progress for this field and value
              if (_divertApiCallInProgress[apiKey] == true) {
                print('🔍 DIVERT LOOKUP: Skipping duplicate API call for $apiKey');
                return;
              }
              
              // Skip duplicate validation if modal is already showing to prevent double modals
              if (!_isDuplicateModalShowing && _validateFieldForDuplicates(result, fieldKey, fieldName)) {
                Future.delayed(const Duration(milliseconds: 2000), () {
                  _lookupDivertCatridge(i, result);
                });
              } else if (_isDuplicateValue(result, fieldKey)) {
                // Clear the field if duplicate found, but don't show modal again
                controller.clear();
              }
              break;
            }
          }
          
          // Check if this is a Pocket No. Catridge field
          if (_pocketControllers.isNotEmpty && _pocketControllers[0] == controller) {
            // Create unique key for API call tracking
            String apiKey = 'pocket_0_$result';
            
            // Check if API call is already in progress for this field and value
            if (_pocketApiCallInProgress[apiKey] == true) {
              print('API call already in progress for Pocket field from barcode scanner with value: $result');
              return;
            }
            
            Future.delayed(const Duration(milliseconds: 2000), () {
              _lookupPocketCatridge(result);
            });
          }
        } else if (cleanLabel == 'Seal Catridge') {
          // Find catridge index for this controller
          for (int i = 0; i < _catridgeControllers.length; i++) {
            if (_catridgeControllers[i].length > 1 && _catridgeControllers[i][1] == controller) {
              Future.delayed(const Duration(milliseconds: 2000), () {
                _validateSealAndUpdateDetail(i, result);
              });
              break;
            }
          }
          
          // Check if this is a Divert Seal Catridge field
          for (int i = 0; i < _divertControllers.length; i++) {
            if (_divertControllers[i].length > 1 && _divertControllers[i][1] == controller) {
              // Check for duplicates before API call
              String fieldKey = 'divert_${i}_seal';
              String fieldName = 'Seal Catridge (Divert ${i + 1})';
              
              // Create unique key for seal validation tracking
              String validationKey = 'divert_${i}_seal_$result';
              
              // Check if seal validation is already in progress for this field and value
              if (_divertSealValidationInProgress[validationKey] == true) {
                print('Seal validation already in progress for Divert field from barcode scanner with value: $result');
                return;
              }
              
              // Skip duplicate validation if modal is already showing to prevent double modals
              if (!_isDuplicateModalShowing && _validateFieldForDuplicates(result, fieldKey, fieldName)) {
                Future.delayed(const Duration(milliseconds: 2000), () {
                  _validateDivertSeal(i, result);
                });
              } else if (_isDuplicateValue(result, fieldKey)) {
                // Clear the field if duplicate found, but don't show modal again
                controller.clear();
              }
              break;
            }
          }
          
          // Check if this is a Pocket Seal Catridge field
          if (_pocketControllers.length > 1 && _pocketControllers[1] == controller) {
            // Create unique key for seal validation tracking
            String validationKey = 'pocket_0_seal_$result';
            
            // Check if seal validation is already in progress for this field and value
            if (_pocketSealValidationInProgress[validationKey] == true) {
              print('Seal validation already in progress for Pocket field from barcode scanner with value: $result');
              return;
            }
            
            Future.delayed(const Duration(milliseconds: 2000), () {
              _validatePocketSeal(result);
            });
          }
        }
      }
    } catch (e) {
      print('Error opening barcode scanner: $e');
      CustomModals.showFailedModal(
        context: context,
        message: 'Gagal membuka scanner: ${e.toString()}',
      );
    }
  }

  // Build Divert section with index support (0, 1, 2)
  Widget _buildDivertSection(int sectionIndex, bool isSmallScreen) {
    // Get tipeDenom from API data if available (same logic as catridge)
    String? tipeDenom = _prepareData?.tipeDenom;
    
    // Convert tipeDenom to rupiah value and determine image
    String denomText = '';
    String? imagePath;
    
    // Only show denom values if _prepareData is available
    if (_prepareData != null && tipeDenom != null) {
      if (tipeDenom == 'A50') {
        denomText = 'Rp 50.000';
        imagePath = 'assets/images/A50.png';
      } else if (tipeDenom == 'A100') {
        denomText = 'Rp 100.000';
        imagePath = 'assets/images/A100.png';
      } else if (tipeDenom == 'CDM' || tipeDenom == 'CRM') {
        // CDM/CRM always shows A50.png
        denomText = 'Rp 50.000';
        imagePath = 'assets/images/A50.png';
      } else {
        // Default fallback
        denomText = 'Rp 50.000';
        imagePath = 'assets/images/A50.png';
      }
    } else {
      // Empty state when no data is available
      denomText = '—';
      imagePath = null;
    }
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divert title with green highlighting when active
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 2,
                child: Text(
                  'Divert ${sectionIndex + 1}',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 18,
                    fontWeight: FontWeight.bold,
                    color: _divertSectionActive[sectionIndex] 
                        ? const Color(0xFF4CAF50) // Green when active
                        : Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 6 : 15),
          
          // Fields
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - All 5 fields in single column
              Expanded(
                flex: isSmallScreen ? 2 : 2, // Reduced from 3 to 2 to make form fields narrower
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // No. Catridge field
                    _buildCompactField(
                      label: 'No. Catridge', 
                      controller: _divertControllers[sectionIndex][0],
                      focusNode: _divertFocusNodes[sectionIndex][0],
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid(),
                      catridgeIndex: sectionIndex,
                      onChanged: (value) {
                        // Trigger manual mode when user types
                        if (value.isNotEmpty) {
                          _onDivertFieldChanged(sectionIndex, 'catridge', value);
                        }
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Catridge field
                    _buildCompactField(
                      label: 'Seal Catridge', 
                      controller: _divertControllers[sectionIndex][1],
                      focusNode: _divertFocusNodes[sectionIndex][1],
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid(),
                      catridgeIndex: sectionIndex,
                      onChanged: (value) {
                        // Trigger manual mode when user types
                        if (value.isNotEmpty) {
                          _onDivertFieldChanged(sectionIndex, 'seal', value);
                        }
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Bag Code field - Always editable
                    _buildCompactField(
                      label: 'Bag Code', 
                      controller: _divertControllers[sectionIndex][2],
                      focusNode: _divertFocusNodes[sectionIndex][2],
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid() || (_prepareData?.isNoBag ?? false), // Disabled if isNoBag is true
                      onChanged: (value) {
                        _updateDetailDivertItemField(sectionIndex, 'bagCode', value);
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Code field - Always editable
                    _buildCompactField(
                      label: 'Seal Code', 
                      controller: _divertControllers[sectionIndex][3],
                      focusNode: _divertFocusNodes[sectionIndex][3],
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid() || (_prepareData?.isNoBag ?? false), // Disabled if isNoBag is true
                      onChanged: (value) {
                        _updateDetailDivertItemField(sectionIndex, 'sealCode', value);
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Code Return field - Always editable
                    _buildCompactField(
                      label: 'Seal Code Return', 
                      controller: _divertControllers[sectionIndex][4],
                      focusNode: _divertFocusNodes[sectionIndex][4],
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid() || (_prepareData?.isNoBag ?? false), // Disabled if isNoBag is true
                      onChanged: (value) {
                        _updateDetailDivertItemField(sectionIndex, 'sealReturn', value);
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),


                  ],
                ),
              ),
              
              SizedBox(width: isSmallScreen ? 12 : 16),
              
              // Right side - Denom details
              Expanded(
                flex: isSmallScreen ? 1 : 1, // Reduced from 2 to 1 to make middle section narrower
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Money image with denomination logic
                    Container(
                      height: isSmallScreen ? 110 : 135,
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _prepareData == null || imagePath == null
                        ? Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: isSmallScreen ? 45 : 60,
                              color: Colors.grey.shade400,
                            ),
                          )
                        : Image.asset(
                            imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.currency_exchange,
                            size: isSmallScreen ? 45 : 60,
                                    color: Colors.blue,
                          ),
                          SizedBox(height: isSmallScreen ? 5 : 8),
                          Text(
                                    denomText,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 17,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                              );
                            },
                      ),
                    ),
                    
                    // Value and Lembar info (combined from all divert sections)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 9 : 11),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Value',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            () {
                              int totalValue = 0;
                              for (int i = 0; i < 3; i++) {
                                if (_divertDetailItems[i]?.value != null) {
                                  totalValue += _divertDetailItems[i]!.value;
                                }
                              }
                              return totalValue > 0 ? totalValue.toString() : '—';
                            }(),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                            ),
                          ),
                          Text(
                            'Lembar',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Total Nominal box (combined from all divert sections)
                    Container(
                      margin: EdgeInsets.only(top: isSmallScreen ? 11 : 16),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 11 : 13, 
                        horizontal: isSmallScreen ? 9 : 11
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,  // Changed from light green to white
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade400,  // Gray border
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,  // Gray shadow
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Nominal',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallScreen ? 5 : 8),
                          Text(
                            () {
                              int totalNominal = 0;
                              int totalValue = 0;
                              bool hasValidData = false;
                              
                              for (int i = 0; i < 3; i++) {
                                if (_divertDetailItems[i]?.total != null && 
                                    _divertDetailItems[i]!.total.isNotEmpty && 
                                    _divertDetailItems[i]!.total != '—') {
                                  
                                  // Extract numeric value from total string
                                  String totalStr = _divertDetailItems[i]!.total;
                                  RegExp regExp = RegExp(r'Rp ([0-9,]+)');
                                  Match? match = regExp.firstMatch(totalStr);
                                  
                                  if (match != null) {
                                    String numericStr = match.group(1)!.replaceAll(',', '');
                                    int value = int.tryParse(numericStr) ?? 0;
                                    if (value > 0) {
                                      totalNominal += value;
                                      hasValidData = true;
                                    }
                                  }
                                  
                                  // Also add the value count
                                  if (_divertDetailItems[i]?.value != null) {
                                    totalValue += _divertDetailItems[i]!.value;
                                  }
                                }
                              }
                              
                              if (hasValidData && totalNominal > 0) {
                                // Format the total with thousand separators
                                String formattedTotal = totalNominal.toString().replaceAllMapped(
                                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                  (Match m) => '${m[1]},'
                                );
                                return 'Rp 0';
                              } else {
                                return 'Rp 0';
                              }
                            }(),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 17,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
          
          // Divider
          Padding(
            padding: EdgeInsets.only(top: isSmallScreen ? 15 : 25),
            child: Container(
              height: 1,
              color: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  // Build Pocket section
  Widget _buildPocketSection(bool isSmallScreen) {
    // Get tipeDenom from API data if available (same logic as catridge)
    String? tipeDenom = _prepareData?.tipeDenom;
    
    // Convert tipeDenom to rupiah value and determine image
    String denomText = '';
    String? imagePath;
    
    // Only show denom values if _prepareData is available
    if (_prepareData != null && tipeDenom != null) {
      if (tipeDenom == 'A50') {
        denomText = 'Rp 50.000';
        imagePath = 'assets/images/A50.png';
      } else if (tipeDenom == 'A100') {
        denomText = 'Rp 100.000';
        imagePath = 'assets/images/A100.png';
      } else if (tipeDenom == 'CDM' || tipeDenom == 'CRM') {
        // CDM/CRM always shows A50.png
        denomText = 'Rp 50.000';
        imagePath = 'assets/images/A50.png';
      } else {
        // Default fallback
        denomText = 'Rp 50.000';
        imagePath = 'assets/images/A50.png';
      }
    } else {
      // Empty state when no data is available
      denomText = '—';
      imagePath = null;
    }
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pocket title with green highlighting
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 2,
                child: Text(
                  'Pocket',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 18,
                    fontWeight: FontWeight.bold,
                    color: _pocketSectionActive 
                        ? const Color(0xFF4CAF50) // Green when active
                        : Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 6 : 15),
          
          // Fields
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - All 5 fields in single column
              Expanded(
                flex: isSmallScreen ? 2 : 2, // Reduced from 3 to 2 to make form fields narrower
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // No. Catridge field
                    _buildCompactField(
                      label: 'No. Catridge', 
                      controller: _pocketControllers[0],
                      focusNode: _pocketFocusNodes[0],
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid(),
                      catridgeIndex: 50, // Use 50 for pocket section
                      onChanged: (value) {
                        // Only trigger manual mode when user actually types
                        if (value.isNotEmpty) {
                          _onPocketFieldChanged('catridge', value);
                        }
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Catridge field
                    _buildCompactField(
                      label: 'Seal Catridge', 
                      controller: _pocketControllers[1],
                      focusNode: _pocketFocusNodes[1],
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid(),
                      catridgeIndex: 50, // Use 50 for pocket section
                      onChanged: (value) {
                        // Only trigger manual mode when user actually types
                        if (value.isNotEmpty) {
                          _onPocketFieldChanged('seal', value);
                        }
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Bag Code field
                    _buildCompactField(
                      label: 'Bag Code', 
                      controller: _pocketControllers[2],
                      focusNode: _pocketFocusNodes[2],
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid() || (_prepareData?.isNoBag ?? false), // Disabled if isNoBag is true
                      onChanged: (value) {
                        _updateDetailPocketItemField('bagCode', value);
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Code field
                    _buildCompactField(
                      label: 'Seal Code', 
                      controller: _pocketControllers[3],
                      focusNode: _pocketFocusNodes[3],
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid() || (_prepareData?.isNoBag ?? false), // Disabled if isNoBag is true
                      onChanged: (value) {
                        _updateDetailPocketItemField('sealCode', value);
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 6 : 10),
                    
                    // Seal Code Return field
                    _buildCompactField(
                      label: 'Seal Code Return', 
                      controller: _pocketControllers[4],
                      focusNode: _pocketFocusNodes[4],
                      isSmallScreen: isSmallScreen,
                      isReadOnly: !_isIdCRFValid() || (_prepareData?.isNoBag ?? false), // Disabled if isNoBag is true
                      onChanged: (value) {
                        _updateDetailPocketItemField('sealReturn', value);
                      },
                    ),
                    


                  ],
                ),
              ),
              
              SizedBox(width: isSmallScreen ? 12 : 16),
              
              // Right side - Denom details
              Expanded(
                flex: isSmallScreen ? 1 : 1, // Reduced from 2 to 1 to make middle section narrower
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Money image with denomination logic
                    Container(
                      height: isSmallScreen ? 110 : 135,
                      width: double.infinity,
                      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _prepareData == null || imagePath == null
                        ? Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: isSmallScreen ? 45 : 60,
                              color: Colors.grey.shade400,
                            ),
                          )
                        : Image.asset(
                            imagePath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.currency_exchange,
                            size: isSmallScreen ? 45 : 60,
                                    color: Colors.blue,
                          ),
                          SizedBox(height: isSmallScreen ? 5 : 8),
                          Text(
                                    denomText,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 17,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                              );
                            },
                      ),
                    ),
                    
                    // Value and Lembar info
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 9 : 11),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Value',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _pocketDetailItem?.value.toString() ?? '—',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                            ),
                          ),
                          Text(
                            'Lembar',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Total Nominal box
                    Container(
                      margin: EdgeInsets.only(top: isSmallScreen ? 11 : 16),
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 11 : 13, 
                        horizontal: isSmallScreen ? 9 : 11
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,  // Changed from light green to white
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade400,  // Gray border
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,  // Gray shadow
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Total Nominal',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 15,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isSmallScreen ? 5 : 8),
                          Text(
                            _pocketDetailItem?.total ?? '—',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 17,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Divider
          Padding(
            padding: EdgeInsets.only(top: isSmallScreen ? 15 : 25),
            child: Container(
              height: 1,
              color: Colors.grey.shade300,
            ),
          ),
        ],
      ),
    );
  }

  // Lookup Divert catridge with enhanced error handling and logging
  Future<void> _lookupDivertCatridge(int sectionIndex, String catridgeCode) async {
    if (catridgeCode.isEmpty || !mounted) {
      print('🔍 DIVERT LOOKUP: Skipped - catridgeCode empty or widget not mounted');
      return;
    }
    
    String apiKey = 'divert_${sectionIndex}_${catridgeCode}';
    
    // Check if API call is already in progress for this field and value
    if (_divertApiCallInProgress[apiKey] == true) {
      print('🔍 DIVERT LOOKUP: API call already in progress for $apiKey');
      return;
    }
    
    // Set flag to indicate API call is in progress
    _divertApiCallInProgress[apiKey] = true;
    
    print('🔍 DIVERT LOOKUP: Starting lookup for catridge: $catridgeCode, sectionIndex: $sectionIndex');
    
    try {
      // Get branch code with enhanced logging
      String branchCode = "1";
      if (_prepareData != null && _prepareData!.branchCode.isNotEmpty) {
        branchCode = _prepareData!.branchCode;
      }
      print('🔍 DIVERT LOOKUP: Using branchCode: $branchCode');
      
      // Get list of existing catridge codes with enhanced logging
      List<String> existingCatridges = [];
      for (var item in _detailCatridgeItems) {
        if (item.noCatridge.isNotEmpty) {
          existingCatridges.add(item.noCatridge);
        }
      }
      if (_pocketDetailItem?.noCatridge.isNotEmpty == true) {
        existingCatridges.add(_pocketDetailItem!.noCatridge);
      }
      print('🔍 DIVERT LOOKUP: Existing catridges: $existingCatridges');
      
      print('🔍 DIVERT LOOKUP: Calling API getCatridgeDetails...');
      final response = await _apiService.getCatridgeDetails(
        branchCode, 
        catridgeCode,
        requiredType: 'D', // Must be type D for divert
        existingCatridges: existingCatridges,
        idTool: _idCRFController.text.trim(), // Pass ID CRF as IdTool parameter
      );
      
      print('🔍 DIVERT LOOKUP: API Response - success: ${response.success}, message: ${response.message}');
      print('🔍 DIVERT LOOKUP: Response data type: ${response.data?.runtimeType}, length: ${response.data is List ? (response.data as List).length : 'N/A'}');
      
      // Enhanced validation with detailed logging
      if (response.success && response.data != null && response.data is List && (response.data as List).isNotEmpty && mounted) {
        final dataList = response.data as List;
        print('🔍 DIVERT LOOKUP: Processing first item from ${dataList.length} items');
        
        // Enhanced data validation
        final firstItem = dataList[0];
        if (firstItem == null) {
          throw Exception('First item in response data is null');
        }
        
        if (firstItem is! Map<String, dynamic>) {
          throw Exception('First item is not a Map<String, dynamic>, got: ${firstItem.runtimeType}');
        }
        
        print('🔍 DIVERT LOOKUP: First item keys: ${firstItem.keys.toList()}');
        
        // Safe parsing with enhanced error handling
        final catridgeData = CatridgeData.fromJson(firstItem);
        print('🔍 DIVERT LOOKUP: Parsed CatridgeData - code: ${catridgeData.code}, standValue: ${catridgeData.standValue}, type: ${catridgeData.typeCatridge}');
        
        // Validate that this is actually a Divert type
        if (catridgeData.typeCatridge.toUpperCase() != 'D') {
          throw Exception('Catridge type mismatch: expected D (Divert), got ${catridgeData.typeCatridge}');
        }
        
        // Calculate total with enhanced logging
        int denomAmount = _prepareData?.tipeDenom == 'A100' ? 100000 : 50000;
        print('🔍 DIVERT LOOKUP: Using denomAmount: $denomAmount (tipeDenom: ${_prepareData?.tipeDenom})');
        
        // Safe standValue handling
        if (catridgeData.standValue.isNaN || catridgeData.standValue.isInfinite) {
          throw Exception('Invalid standValue: ${catridgeData.standValue}');
        }
        
        int standValueInt = catridgeData.standValue.round();
        int totalNominal = denomAmount * standValueInt;
        String formattedTotal = _formatCurrency(totalNominal);
        
        print('🔍 DIVERT LOOKUP: Calculated - standValueInt: $standValueInt, totalNominal: $totalNominal, formatted: $formattedTotal');
        
        setState(() {
          // Store data for specific section
          _divertCatridgeData[sectionIndex] = catridgeData;
          _divertDetailItems[sectionIndex] = DetailCatridgeItem(
            index: sectionIndex + 1,
            noCatridge: catridgeCode,
            sealCatridge: '',
            value: standValueInt,
            total: formattedTotal,
            denom: denomAmount == 100000 ? 'Rp 100.000' : 'Rp 50.000',
            bagCode: '',
            sealCode: '',
            sealReturn: '',
          );
          
          // Add Divert data to main detail catridge items list
          // Use specific index for each divert section (100 + sectionIndex)
          int divertIndex = 100 + sectionIndex;
          
          // Remove existing divert data for this section if any
          _detailCatridgeItems.removeWhere((item) => item.index == divertIndex);
          
          DetailCatridgeItem divertDetailForList = DetailCatridgeItem(
            index: divertIndex,
            noCatridge: catridgeCode,
            sealCatridge: '',
            value: standValueInt,
            total: formattedTotal,
            denom: denomAmount == 100000 ? 'Rp 100.000' : 'Rp 50.000',
            bagCode: '',
            sealCode: '',
            sealReturn: '',
          );
          _detailCatridgeItems.add(divertDetailForList);
          print('🔍 DIVERT LOOKUP: Added divert data to _detailCatridgeItems with index $divertIndex for section $sectionIndex');
          

          
          // REMOVED: Reset manual mode after API call
          // Manual mode should only be reset after successful scan, not after API call
        });
        
        print('🔍 DIVERT LOOKUP: Success - showing success modal');
        CustomModals.showSuccessModal(
          context: context,
          message: 'Divert catridge berhasil ditemukan: ${catridgeData.code}',
        );
      } else {
        print('🔍 DIVERT LOOKUP: Failed - clearing data and showing error');
        setState(() {
          _divertCatridgeData[sectionIndex] = null;
          
          // Remove existing divert data from _detailCatridgeItems if any
          if (_divertDetailItems[sectionIndex] != null) {
            int divertIndex = 100 + sectionIndex;
            _detailCatridgeItems.removeWhere((item) => item.index == divertIndex);
            print('🔍 DIVERT LOOKUP: Removed divert data from _detailCatridgeItems for section $sectionIndex');
          }
          
          _divertDetailItems[sectionIndex] = null;
        });
        
        String errorMessage = response.message.isNotEmpty ? response.message : 'Divert catridge tidak ditemukan atau tidak valid';
        CustomModals.showFailedModal(
          context: context,
          message: errorMessage,
          onPressed: () {
            Navigator.of(context).pop();
            // Reset only No. Catridge field for Divert section (error from catridge lookup)
            _resetDivertAndSealFields(sectionIndex, resetNoCatridge: true, resetSealCatridge: false);
          },
        );
      }
    } catch (e, stackTrace) {
      print('🔍 DIVERT LOOKUP: Exception caught: $e');
      print('🔍 DIVERT LOOKUP: Stack trace: $stackTrace');
      
      setState(() {
        _divertCatridgeData[sectionIndex] = null;
        
        // Remove existing divert data from _detailCatridgeItems if any
        if (_divertDetailItems[sectionIndex] != null) {
          int divertIndex = 100 + sectionIndex;
          _detailCatridgeItems.removeWhere((item) => item.index == divertIndex);
          print('🔍 DIVERT LOOKUP: Removed divert data from _detailCatridgeItems due to exception for section $sectionIndex');
        }
        
        _divertDetailItems[sectionIndex] = null;
      });
      
      CustomModals.showFailedModal(
        context: context,
        message: 'Error lookup divert catridge: ${e.toString()}',
        onPressed: () {
          Navigator.of(context).pop();
          // Reset only No. Catridge field for Divert section (error from catridge lookup)
          _resetDivertAndSealFields(sectionIndex, resetNoCatridge: true, resetSealCatridge: false);
        },
      );
    } finally {
      // Always reset the API call flag when the method completes
      String apiKey = 'divert_${sectionIndex}_${catridgeCode}';
      _divertApiCallInProgress[apiKey] = false;
      print('🔍 DIVERT LOOKUP: API call completed for $apiKey');
    }
  }

  // Validate Divert seal
  Future<void> _validateDivertSeal(int sectionIndex, String sealCode) async {
    if (sealCode.isEmpty || !mounted) {
      print('🔒 DIVERT SEAL: Skipped - sealCode empty or widget not mounted (section: $sectionIndex)');
      return;
    }
    
    // Create unique key for seal validation tracking
    String validationKey = 'divert_${sectionIndex}_seal_$sealCode';
    
    // Check if seal validation is already in progress for this field and value
    if (_divertSealValidationInProgress[validationKey] == true) {
      print('🔒 DIVERT SEAL: Validation already in progress for section $sectionIndex with seal: $sealCode');
      return;
    }
    
    // Set flag to indicate validation is in progress
    _divertSealValidationInProgress[validationKey] = true;
    
    print('🔒 DIVERT SEAL: Starting validation for seal: $sealCode (section: $sectionIndex)');
    
    try {
      print('🔒 DIVERT SEAL: Calling API validateSeal...');
      final response = await _apiService.validateSeal(sealCode);
      
      print('🔒 DIVERT SEAL: API Response - success: ${response.success}, message: ${response.message}');
      print('🔒 DIVERT SEAL: Response data: ${response.data}');
      
      // Extract validation status from response data (consistent with Catridge implementation)
      String validationStatus = '';
      String validatedSealCode = '';
      
      if (response.data != null) {
        try {
          if (response.data is Map<String, dynamic>) {
            Map<String, dynamic> dataMap = response.data as Map<String, dynamic>;
            
            // Normalize keys for consistent access
            Map<String, dynamic> normalizedData = {};
            dataMap.forEach((key, value) {
              normalizedData[key.toLowerCase()] = value;
            });
            
            // Extract status with fallbacks
            if (normalizedData.containsKey('validationstatus')) {
              validationStatus = normalizedData['validationstatus'].toString();
            } else if (normalizedData.containsKey('status')) {
              validationStatus = normalizedData['status'].toString();
            }
            
            // Extract validated seal code with fallbacks
            if (normalizedData.containsKey('validatedsealcode')) {
              validatedSealCode = normalizedData['validatedsealcode'].toString();
            } else if (normalizedData.containsKey('sealcode')) {
              validatedSealCode = normalizedData['sealcode'].toString();
            } else if (normalizedData.containsKey('seal')) {
              validatedSealCode = normalizedData['seal'].toString();
            }
            
            // If validation is successful but no validated code, use input code
            if (validationStatus.toUpperCase() == 'SUCCESS' && validatedSealCode.isEmpty) {
              validatedSealCode = sealCode;
            }
          }
        } catch (e) {
          print('🔒 DIVERT SEAL: Error parsing validation data: $e');
        }
      }
      
      // If no status extracted, determine from overall response
      if (validationStatus.isEmpty) {
        validationStatus = response.success ? 'SUCCESS' : 'FAILED';
      }
      
      // If still no validated code and validation successful, use input code
      if (validatedSealCode.isEmpty && validationStatus.toUpperCase() == 'SUCCESS') {
        validatedSealCode = sealCode;
      }
      
      if (response.success && validationStatus.toUpperCase() == 'SUCCESS' && mounted) {
        print('🔒 DIVERT SEAL: Validation successful - updating state');
        
        setState(() {
          if (_divertDetailItems[sectionIndex] != null) {
            _divertDetailItems[sectionIndex] = DetailCatridgeItem(
              index: _divertDetailItems[sectionIndex]!.index,
              noCatridge: _divertDetailItems[sectionIndex]!.noCatridge,
              sealCatridge: validatedSealCode,
              value: _divertDetailItems[sectionIndex]!.value,
              total: _divertDetailItems[sectionIndex]!.total,
              denom: _divertDetailItems[sectionIndex]!.denom,
              bagCode: _divertDetailItems[sectionIndex]!.bagCode,
              sealCode: _divertDetailItems[sectionIndex]!.sealCode,
              sealReturn: _divertDetailItems[sectionIndex]!.sealReturn,
            );
            print('🔒 DIVERT SEAL: Updated divert item for section $sectionIndex with validated seal: $validatedSealCode');
          } else {
            // Create new DetailCatridgeItem if not exists
            String noCatridge = sectionIndex < _divertControllers.length ? _divertControllers[sectionIndex][0].text.trim() : '';
            String bagCode = sectionIndex < _divertControllers.length ? _divertControllers[sectionIndex][2].text.trim() : '';
            String sealCode = sectionIndex < _divertControllers.length ? _divertControllers[sectionIndex][3].text.trim() : '';
            String sealReturn = sectionIndex < _divertControllers.length ? _divertControllers[sectionIndex][4].text.trim() : '';
            
            _divertDetailItems[sectionIndex] = DetailCatridgeItem(
              index: 100 + sectionIndex,
              noCatridge: noCatridge,
              sealCatridge: validatedSealCode,
              value: 0,
              total: 'Rp 0',
              denom: _prepareData?.tipeDenom == 'A100' ? 'Rp 100.000' : 'Rp 50.000',
              bagCode: bagCode,
              sealCode: sealCode,
              sealReturn: sealReturn,
            );
            print('🔒 DIVERT SEAL: Created new divert item for section $sectionIndex with validated seal: $validatedSealCode');
          }
            
            // Also update the corresponding item in _detailCatridgeItems
            int divertIndex = 100 + sectionIndex;
            bool foundInDetailCatridge = false;
            for (int i = 0; i < _detailCatridgeItems.length; i++) {
              if (_detailCatridgeItems[i].index == divertIndex) {
                _detailCatridgeItems[i] = DetailCatridgeItem(
                  index: _detailCatridgeItems[i].index,
                  noCatridge: _detailCatridgeItems[i].noCatridge,
                  sealCatridge: validatedSealCode,
                  value: _detailCatridgeItems[i].value,
                  total: _detailCatridgeItems[i].total,
                  denom: _detailCatridgeItems[i].denom,
                  bagCode: _detailCatridgeItems[i].bagCode,
                  sealCode: _detailCatridgeItems[i].sealCode,
                  sealReturn: _detailCatridgeItems[i].sealReturn,
                );
                print('🔒 DIVERT SEAL: Updated corresponding item in _detailCatridgeItems with validated seal for section $sectionIndex');
                foundInDetailCatridge = true;
                break;
              }
            }
            
            // If not found in _detailCatridgeItems, create new one
            if (!foundInDetailCatridge) {
              String noCatridge = sectionIndex < _divertControllers.length ? _divertControllers[sectionIndex][0].text.trim() : '';
              String bagCode = sectionIndex < _divertControllers.length ? _divertControllers[sectionIndex][2].text.trim() : '';
              String sealCode = sectionIndex < _divertControllers.length ? _divertControllers[sectionIndex][3].text.trim() : '';
              String sealReturn = sectionIndex < _divertControllers.length ? _divertControllers[sectionIndex][4].text.trim() : '';
              
              DetailCatridgeItem newDetailItem = DetailCatridgeItem(
                index: divertIndex,
                noCatridge: noCatridge,
                sealCatridge: validatedSealCode,
                value: 0,
                total: 'Rp 0',
                denom: _prepareData?.tipeDenom == 'A100' ? 'Rp 100.000' : 'Rp 50.000',
                bagCode: bagCode,
                sealCode: sealCode,
                sealReturn: sealReturn,
              );
              _detailCatridgeItems.add(newDetailItem);
              print('🔒 DIVERT SEAL: Created new item in _detailCatridgeItems for divert section $sectionIndex with validated seal: $validatedSealCode');
            }
          
          // Tidak reset manual mode setelah validasi berhasil
          // Manual mode hanya direset setelah berhasil scan, bukan setelah berhasil validasi
          print('🔒 DIVERT SEAL: Manual mode tetap dipertahankan setelah validasi berhasil');
          // Catatan: Reset manual mode akan dilakukan di _onScanSuccess
        });
        
        print('🔒 DIVERT SEAL: Success - showing success modal');
        CustomModals.showSuccessModal(
          context: context,
          message: 'Seal berhasil divalidasi',
        );
      } else {
        print('🔒 DIVERT SEAL: Validation failed - showing error modal');
        print('🔒 DIVERT SEAL: Failure details - validationStatus: $validationStatus');
        
        CustomModals.showFailedModal(
          context: context,
          message: response.message,
          onPressed: () {
            Navigator.of(context).pop();
            // Reset only Seal Catridge field for Divert section (error from seal validation)
            _resetDivertAndSealFields(sectionIndex, resetNoCatridge: false, resetSealCatridge: true);
          },
        );
      }
    } catch (e, stackTrace) {
      print('🔒 DIVERT SEAL: Exception occurred - $e');
      print('🔒 DIVERT SEAL: Stack trace: $stackTrace');
      
      CustomModals.showFailedModal(
        context: context,
        message: 'Error: ${e.toString()}',
        onPressed: () {
          Navigator.of(context).pop();
          // Reset only Seal Catridge field for Divert section (error from seal validation)
          _resetDivertAndSealFields(sectionIndex, resetNoCatridge: false, resetSealCatridge: true);
        },
      );
    } finally {
      // Reset the validation flag
      String validationKey = 'divert_${sectionIndex}_seal_$sealCode';
      _divertSealValidationInProgress[validationKey] = false;
      print('🔒 DIVERT SEAL: Validation completed for section $sectionIndex with seal: $sealCode');
    }
  }

  // Lookup Pocket catridge with enhanced error handling and logging
  Future<void> _lookupPocketCatridge(String catridgeCode) async {
    if (catridgeCode.isEmpty || !mounted) {
      print('🔍 POCKET LOOKUP: Skipped - catridgeCode empty or widget not mounted');
      return;
    }
    
    // Create unique key for API call tracking
    String apiKey = 'pocket_0_$catridgeCode';
    
    // Check if API call is already in progress for this field and value
    if (_pocketApiCallInProgress[apiKey] == true) {
      print('🔍 POCKET LOOKUP: API call already in progress for catridge: $catridgeCode');
      return;
    }
    
    // Set flag to indicate API call is in progress
    _pocketApiCallInProgress[apiKey] = true;
    
    print('🔍 POCKET LOOKUP: Starting lookup for catridge: $catridgeCode');
    
    try {
      // Get branch code with enhanced logging
      String branchCode = "1";
      if (_prepareData != null && _prepareData!.branchCode.isNotEmpty) {
        branchCode = _prepareData!.branchCode;
      }
      print('🔍 POCKET LOOKUP: Using branchCode: $branchCode');
      
      // Get list of existing catridge codes with enhanced logging
      List<String> existingCatridges = [];
      for (var item in _detailCatridgeItems) {
        if (item.noCatridge.isNotEmpty) {
          existingCatridges.add(item.noCatridge);
        }
      }
      // Add divert catridges from all sections
      for (int i = 0; i < _divertDetailItems.length; i++) {
        if (_divertDetailItems[i]?.noCatridge.isNotEmpty == true) {
          existingCatridges.add(_divertDetailItems[i]!.noCatridge);
        }
      }
      print('🔍 POCKET LOOKUP: Existing catridges: $existingCatridges');
      
      print('🔍 POCKET LOOKUP: Calling API getCatridgeDetails...');
      final response = await _apiService.getCatridgeDetails(
        branchCode, 
        catridgeCode,
        requiredType: 'P', // Must be type P for pocket
        existingCatridges: existingCatridges,
        idTool: _idCRFController.text.trim(), // Pass ID CRF as IdTool parameter
      );
      
      print('🔍 POCKET LOOKUP: API Response - success: ${response.success}, message: ${response.message}');
      print('🔍 POCKET LOOKUP: Response data type: ${response.data?.runtimeType}, length: ${response.data is List ? (response.data as List).length : 'N/A'}');
      
      // Enhanced validation with detailed logging
      if (response.success && response.data != null && response.data is List && (response.data as List).isNotEmpty && mounted) {
        final dataList = response.data as List;
        print('🔍 POCKET LOOKUP: Processing first item from ${dataList.length} items');
        
        // Enhanced data validation
        final firstItem = dataList[0];
        if (firstItem == null) {
          throw Exception('First item in response data is null');
        }
        
        if (firstItem is! Map<String, dynamic>) {
          throw Exception('First item is not a Map<String, dynamic>, got: ${firstItem.runtimeType}');
        }
        
        print('🔍 POCKET LOOKUP: First item keys: ${firstItem.keys.toList()}');
        
        // Safe parsing with enhanced error handling
        final catridgeData = CatridgeData.fromJson(firstItem);
        print('🔍 POCKET LOOKUP: Parsed CatridgeData - code: ${catridgeData.code}, standValue: ${catridgeData.standValue}, type: ${catridgeData.typeCatridge}');
        
        // Validate that this is actually a Pocket type
        if (catridgeData.typeCatridge.toUpperCase() != 'P') {
          throw Exception('Catridge type mismatch: expected P (Pocket), got ${catridgeData.typeCatridge}');
        }
        
        // Calculate total with enhanced logging
        int denomAmount = _prepareData?.tipeDenom == 'A100' ? 100000 : 50000;
        print('🔍 POCKET LOOKUP: Using denomAmount: $denomAmount (tipeDenom: ${_prepareData?.tipeDenom})');
        
        // Safe standValue handling
        if (catridgeData.standValue.isNaN || catridgeData.standValue.isInfinite) {
          throw Exception('Invalid standValue: ${catridgeData.standValue}');
        }
        
        int standValueInt = catridgeData.standValue.round();
        int totalNominal = denomAmount * standValueInt;
        String formattedTotal = _formatCurrency(totalNominal);
        
        print('🔍 POCKET LOOKUP: Calculated - standValueInt: $standValueInt, totalNominal: $totalNominal, formatted: $formattedTotal');
        
        setState(() {
          _pocketCatridgeData = catridgeData;
          _pocketDetailItem = DetailCatridgeItem(
            index: 1,
            noCatridge: catridgeCode,
            sealCatridge: '',
            value: standValueInt,
            total: formattedTotal,
            denom: denomAmount == 100000 ? 'Rp 100.000' : 'Rp 50.000',
            bagCode: '',
            sealCode: '',
            sealReturn: '',
          );
          
          // Add Pocket data to main detail catridge items list
          // Find next available index for detail catridge items (avoid conflict with main catridge indices 1-10 and Divert 100+)
          int nextIndex = 200; // Start from 200 for Pocket items
          while (_detailCatridgeItems.any((item) => item.index == nextIndex)) {
            nextIndex++;
          }
          DetailCatridgeItem pocketDetailForList = DetailCatridgeItem(
            index: nextIndex,
            noCatridge: catridgeCode,
            sealCatridge: '',
            value: standValueInt,
            total: formattedTotal,
            denom: denomAmount == 100000 ? 'Rp 100.000' : 'Rp 50.000',
            bagCode: '',
            sealCode: '',
            sealReturn: '',
          );
          _detailCatridgeItems.add(pocketDetailForList);
          print('🔍 POCKET LOOKUP: Added pocket data to _detailCatridgeItems with index $nextIndex');
          
          // REMOVED: Reset manual mode after API call
          // Manual mode should only be reset after successful scan, not after API call
        });
        
        print('🔍 POCKET LOOKUP: Success - showing success modal');
        CustomModals.showSuccessModal(
          context: context,
          message: 'Pocket catridge berhasil ditemukan: ${catridgeData.code}',
        );
      } else {
        print('🔍 POCKET LOOKUP: Failed - clearing data and showing error');
        print('🔍 POCKET LOOKUP: Failure details - success: ${response.success}, data: ${response.data}, message: ${response.message}');
        
        setState(() {
          _pocketCatridgeData = null;
          
          // Remove existing pocket data from _detailCatridgeItems if any
          if (_pocketDetailItem != null) {
            _detailCatridgeItems.removeWhere((item) => 
              item.noCatridge == _pocketDetailItem!.noCatridge);
            print('🔍 POCKET LOOKUP: Removed pocket data from _detailCatridgeItems');
          }
          
          _pocketDetailItem = null;
        });
        
        String errorMessage = 'Pocket catridge tidak ditemukan';
        if (response.message.isNotEmpty) {
          errorMessage = response.message;
        }
        
        CustomModals.showFailedModal(
          context: context,
          message: errorMessage,
          onPressed: () {
            Navigator.of(context).pop();
            // Reset only No. Catridge field for Pocket section
            _resetPocketAndSealFields(resetNoCatridge: true, resetSealCatridge: false);
          },
        );
      }
    } catch (e, stackTrace) {
      print('🔍 POCKET LOOKUP: Exception occurred - $e');
      print('🔍 POCKET LOOKUP: Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _pocketCatridgeData = null;
          
          // Remove existing pocket data from _detailCatridgeItems if any
          if (_pocketDetailItem != null) {
            _detailCatridgeItems.removeWhere((item) => 
              item.noCatridge == _pocketDetailItem!.noCatridge);
            print('🔍 POCKET LOOKUP: Removed pocket data from _detailCatridgeItems due to exception');
          }
          
          _pocketDetailItem = null;
        });
        
        String errorMessage = 'Error saat mencari pocket catridge';
        if (e.toString().contains('standValue')) {
          errorMessage = 'Error: Data standValue tidak valid pada pocket catridge';
        } else if (e.toString().contains('type mismatch')) {
          errorMessage = 'Error: Tipe catridge tidak sesuai (harus Pocket)';
        } else if (e.toString().contains('Map<String, dynamic>')) {
          errorMessage = 'Error: Format data response tidak valid';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Error: Koneksi timeout';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Error: Masalah koneksi jaringan';
        }
        
        CustomModals.showFailedModal(
          context: context,
          message: errorMessage,
        );
      }
    } finally {
      // Always reset the API call flag, regardless of success or error
      String apiKey = 'pocket_0_$catridgeCode';
      _pocketApiCallInProgress[apiKey] = false;
      print('🔍 POCKET LOOKUP: API call completed for catridge: $catridgeCode');
    }
  }

  Future<void> _validatePocketSeal(String sealCode) async {
    if (sealCode.isEmpty || !mounted) {
      print('🔒 POCKET SEAL: Skipped - sealCode empty or widget not mounted');
      return;
    }
    
    // Create unique key for seal validation tracking
    String validationKey = 'pocket_0_seal_$sealCode';
    
    // Check if seal validation is already in progress for this field and value
    if (_pocketSealValidationInProgress[validationKey] == true) {
      print('🔒 POCKET SEAL: Validation already in progress for seal: $sealCode');
      return;
    }
    
    // Set flag to indicate seal validation is in progress
    _pocketSealValidationInProgress[validationKey] = true;
    
    print('🔒 POCKET SEAL: Starting validation for seal: $sealCode');
    
    try {
      print('🔒 POCKET SEAL: Calling API validateSeal...');
      final response = await _apiService.validateSeal(sealCode);
      
      print('🔒 POCKET SEAL: API Response - success: ${response.success}, message: ${response.message}');
      print('🔒 POCKET SEAL: Response data: ${response.data}');
      
      // Extract validation status from response data (consistent with Catridge implementation)
      String validationStatus = '';
      String validatedSealCode = '';
      
      if (response.data != null) {
        try {
          if (response.data is Map<String, dynamic>) {
            Map<String, dynamic> dataMap = response.data as Map<String, dynamic>;
            
            // Normalize keys for consistent access
            Map<String, dynamic> normalizedData = {};
            dataMap.forEach((key, value) {
              normalizedData[key.toLowerCase()] = value;
            });
            
            // Extract status with fallbacks
            if (normalizedData.containsKey('validationstatus')) {
              validationStatus = normalizedData['validationstatus'].toString();
            } else if (normalizedData.containsKey('status')) {
              validationStatus = normalizedData['status'].toString();
            }
            
            // Extract validated seal code with fallbacks
            if (normalizedData.containsKey('validatedsealcode')) {
              validatedSealCode = normalizedData['validatedsealcode'].toString();
            } else if (normalizedData.containsKey('sealcode')) {
              validatedSealCode = normalizedData['sealcode'].toString();
            } else if (normalizedData.containsKey('seal')) {
              validatedSealCode = normalizedData['seal'].toString();
            }
            
            // If validation is successful but no validated code, use input code
            if (validationStatus.toUpperCase() == 'SUCCESS' && validatedSealCode.isEmpty) {
              validatedSealCode = sealCode;
            }
          }
        } catch (e) {
          print('🔒 POCKET SEAL: Error parsing validation data: $e');
        }
      }
      
      // If no status extracted, determine from overall response
      if (validationStatus.isEmpty) {
        validationStatus = response.success ? 'SUCCESS' : 'FAILED';
      }
      
      // If still no validated code and validation successful, use input code
      if (validatedSealCode.isEmpty && validationStatus.toUpperCase() == 'SUCCESS') {
        validatedSealCode = sealCode;
      }
      
      if (response.success && validationStatus.toUpperCase() == 'SUCCESS' && mounted) {
        print('🔒 POCKET SEAL: Validation successful - updating state');
        
        setState(() {
          if (_pocketDetailItem != null) {
            _pocketDetailItem = DetailCatridgeItem(
              index: _pocketDetailItem!.index,
              noCatridge: _pocketDetailItem!.noCatridge,
              sealCatridge: validatedSealCode,
              value: _pocketDetailItem!.value,
              total: _pocketDetailItem!.total,
              denom: _pocketDetailItem!.denom,
              bagCode: _pocketDetailItem!.bagCode,
              sealCode: _pocketDetailItem!.sealCode,
              sealReturn: _pocketDetailItem!.sealReturn,
            );
            print('🔒 POCKET SEAL: Updated pocket item with validated seal: $validatedSealCode');
          } else {
            // Create new DetailCatridgeItem if not exists
            String noCatridge = _pocketControllers.isNotEmpty ? _pocketControllers[0].text.trim() : '';
            String bagCode = _pocketControllers.length > 2 ? _pocketControllers[2].text.trim() : '';
            String sealCode = _pocketControllers.length > 3 ? _pocketControllers[3].text.trim() : '';
            String sealReturn = _pocketControllers.length > 4 ? _pocketControllers[4].text.trim() : '';
            
            _pocketDetailItem = DetailCatridgeItem(
              index: 200, // Pocket index
              noCatridge: noCatridge,
              sealCatridge: validatedSealCode,
              value: 0,
              total: 'Rp 0',
              denom: _prepareData?.tipeDenom == 'A100' ? 'Rp 100.000' : 'Rp 50.000',
              bagCode: bagCode,
              sealCode: sealCode,
              sealReturn: sealReturn,
            );
            print('🔒 POCKET SEAL: Created new pocket item with validated seal: $validatedSealCode');
          }
            
            // Also update the corresponding item in _detailCatridgeItems
            bool foundInDetailCatridge = false;
            for (int i = 0; i < _detailCatridgeItems.length; i++) {
              if (_detailCatridgeItems[i].noCatridge == _pocketDetailItem!.noCatridge) {
                _detailCatridgeItems[i] = DetailCatridgeItem(
                  index: _detailCatridgeItems[i].index,
                  noCatridge: _detailCatridgeItems[i].noCatridge,
                  sealCatridge: validatedSealCode,
                  value: _detailCatridgeItems[i].value,
                  total: _detailCatridgeItems[i].total,
                  denom: _detailCatridgeItems[i].denom,
                  bagCode: _detailCatridgeItems[i].bagCode,
                  sealCode: _detailCatridgeItems[i].sealCode,
                  sealReturn: _detailCatridgeItems[i].sealReturn,
                );
                print('🔒 POCKET SEAL: Updated corresponding item in _detailCatridgeItems with validated seal');
                foundInDetailCatridge = true;
                break;
              }
            }
            
            // If not found in _detailCatridgeItems, create new one
            if (!foundInDetailCatridge) {
              String noCatridge = _pocketControllers.isNotEmpty ? _pocketControllers[0].text.trim() : '';
              String bagCode = _pocketControllers.length > 2 ? _pocketControllers[2].text.trim() : '';
              String sealCode = _pocketControllers.length > 3 ? _pocketControllers[3].text.trim() : '';
              String sealReturn = _pocketControllers.length > 4 ? _pocketControllers[4].text.trim() : '';
              
              DetailCatridgeItem newDetailItem = DetailCatridgeItem(
                index: 200, // Pocket index
                noCatridge: noCatridge,
                sealCatridge: validatedSealCode,
                value: 0,
                total: 'Rp 0',
                denom: _prepareData?.tipeDenom == 'A100' ? 'Rp 100.000' : 'Rp 50.000',
                bagCode: bagCode,
                sealCode: sealCode,
                sealReturn: sealReturn,
              );
              _detailCatridgeItems.add(newDetailItem);
              print('🔒 POCKET SEAL: Created new item in _detailCatridgeItems for pocket with validated seal: $validatedSealCode');
            }
          
          // Tidak reset manual mode setelah validasi berhasil
          // Manual mode hanya direset setelah berhasil scan, bukan setelah berhasil validasi
          print('🔒 POCKET SEAL: Manual mode tetap dipertahankan setelah validasi berhasil');
          // Catatan: Reset manual mode akan dilakukan di _onScanSuccess
        });
        
        print('🔒 POCKET SEAL: Success - showing success modal');
        CustomModals.showSuccessModal(
          context: context,
          message: 'Seal berhasil divalidasi',
        );
      } else {
        print('🔒 POCKET SEAL: Validation failed - showing error modal');
        print('🔒 POCKET SEAL: Failure details - validationStatus: $validationStatus');
        
        CustomModals.showFailedModal(
          context: context,
          message: response.message,
        );
      }
    } catch (e, stackTrace) {
      print('🔒 POCKET SEAL: Exception occurred - $e');
      print('🔒 POCKET SEAL: Stack trace: $stackTrace');
      
      CustomModals.showFailedModal(
        context: context,
        message: 'Error: ${e.toString()}',
      );
    } finally {
      // Always reset the seal validation flag, regardless of success or error
      String validationKey = 'pocket_0_seal_$sealCode';
      _pocketSealValidationInProgress[validationKey] = false;
      print('🔒 POCKET SEAL: Validation completed for seal: $sealCode');
    }
  }

  // Show error dialog using CustomModals
  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    CustomModals.showFailedModal(
      context: context,
      message: message,
    );
  }

  // Konversi detail catridge items ke CatridgeQRData untuk QR code
  List<CatridgeQRData> _prepareCatridgeQRData() {
    if (_detailCatridgeItems.isEmpty) {
      return [];
    }
    
    // Get current user data
    String userInput = 'UNKNOWN';
    try {
      final userData = _authService.getUserDataSync();
      if (userData != null) {
        userInput = userData['userId'] ?? userData['userID'] ?? userData['nik'] ?? userData['userCode'] ?? 'UNKNOWN';
      }
    } catch (e) {
      print('Error getting user data for QR code: $e');
    }
    
    // Ensure denomCode is not empty
    String finalDenomCode = _prepareData?.denomCode ?? '';
    if (finalDenomCode.isEmpty) finalDenomCode = 'A50';
    
    // Get tableCode and warehouseCode
    String tableCode = _prepareData?.tableCode ?? 'DEFAULT';
    String warehouseCode = 'Cideng'; // Default value
    
    // Get operator name
    String operatorName = '';
    try {
      final userData = _authService.getUserDataSync();
      if (userData != null) {
        operatorName = userData['userName'] ?? userData['name'] ?? '';
      }
    } catch (e) {
      print('Error getting operator name for QR code: $e');
    }
    
    // Convert each detail item to CatridgeQRData
    List<CatridgeQRData> result = [];
    for (var item in _detailCatridgeItems) {
      // Skip items with errors or incomplete data
      if (item.noCatridge.isEmpty || item.sealCatridge.isEmpty || item.value <= 0) {
        continue;
      }
      
      if (item.total.contains('Error') || item.total.contains('tidak ditemukan') ||
          item.sealCatridge.contains('Error') || item.sealCatridge.contains('tidak valid')) {
        continue;
      }
      
      // Create CatridgeQRData
      try {
        final catridgeData = CatridgeQRData(
          idTool: _prepareData?.id?.toString() ?? _idCRFController.text,
          bagCode: 'TEST', // Default value
          catridgeCode: item.noCatridge,
          sealCode: 'TEST', // Default value
          catridgeSeal: item.sealCatridge,
          denomCode: finalDenomCode,
          qty: '1', // Default value
          userInput: userInput,
          sealReturn: '', // Default value
          typeCatridgeTrx: 'C', // Default value for Catridge
          tableCode: tableCode,
          warehouseCode: warehouseCode,
          operatorId: userInput,
          operatorName: operatorName,
        );
        
        result.add(catridgeData);
      } catch (e) {
        print('Error creating CatridgeQRData: $e');
      }
    }
    
    // Add divert items if available (check all 3 sections)
    for (int i = 0; i < 3; i++) {
      // Check if this divert section has data
      bool hasData = _divertControllers[i].any((controller) => controller.text.trim().isNotEmpty);
      if (hasData) {
      try {
        final catridgeData = CatridgeQRData(
          idTool: _prepareData?.id?.toString() ?? _idCRFController.text,
            bagCode: _divertControllers[i][2].text.isNotEmpty ? _divertControllers[i][2].text : 'TEST',
            catridgeCode: _divertControllers[i][0].text.trim(),
            sealCode: _divertControllers[i][3].text.isNotEmpty ? _divertControllers[i][3].text : 'TEST',
            catridgeSeal: _divertControllers[i][1].text.trim(),
          denomCode: finalDenomCode,
          qty: '1', // Default value
          userInput: userInput,
            sealReturn: _divertControllers[i][4].text.isNotEmpty ? _divertControllers[i][4].text : '',
          typeCatridgeTrx: 'D', // 'D' for Divert
          tableCode: tableCode,
          warehouseCode: warehouseCode,
          operatorId: userInput,
          operatorName: operatorName,
        );
        
        result.add(catridgeData);
      } catch (e) {
          print('Error creating Divert ${i + 1} CatridgeQRData: $e');
        }
      }
    }
    
    if (_pocketDetailItem != null) {
      try {
        final catridgeData = CatridgeQRData(
          idTool: _prepareData?.id?.toString() ?? _idCRFController.text,
          bagCode: _pocketControllers[2].text.isNotEmpty ? _pocketControllers[2].text : 'TEST',
          catridgeCode: _pocketDetailItem!.noCatridge,
          sealCode: _pocketControllers[3].text.isNotEmpty ? _pocketControllers[3].text : 'TEST',
          catridgeSeal: _pocketDetailItem!.sealCatridge,
          denomCode: finalDenomCode,
          qty: '1', // Default value
          userInput: userInput,
          sealReturn: _pocketControllers[4].text.isNotEmpty ? _pocketControllers[4].text : '',
          typeCatridgeTrx: 'P', // 'P' for Pocket
          tableCode: tableCode,
          warehouseCode: warehouseCode,
          operatorId: userInput,
          operatorName: operatorName,
        );
        
        result.add(catridgeData);
      } catch (e) {
        print('Error creating Pocket CatridgeQRData: $e');
      }
    }
    
    print('Prepared ${result.length} catridge items for QR code');
    return result;
  }
}







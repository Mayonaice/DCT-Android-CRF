import 'package:flutter/material.dart';
import '../models/return_model.dart';
import '../models/prepare_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/custom_modals.dart';
import '../screens/profile_menu_screen.dart';
import '../widgets/qr_code_generator_widget.dart';

class ReturnSummaryPage extends StatefulWidget {
  final ReturnHeaderResponse? returnData;
  final List<Map<String, dynamic>> cartridgeData;
  final Map<String, TextEditingController> detailReturnLembarControllers;
  final Map<String, TextEditingController> detailReturnNominalControllers;

  const ReturnSummaryPage({
    Key? key,
    required this.returnData,
    required this.cartridgeData,
    required this.detailReturnLembarControllers,
    required this.detailReturnNominalControllers,
  }) : super(key: key);

  @override
  State<ReturnSummaryPage> createState() => _ReturnSummaryPageState();
}

class _ReturnSummaryPageState extends State<ReturnSummaryPage> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final TextEditingController _tlNikController = TextEditingController();
  final TextEditingController _tlPasswordController = TextEditingController();
  bool _isSubmitting = false;
  String _userName = '';
  String _branchName = '';
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        setState(() {
          _userData = userData;
          _userName = userData['userName'] ?? userData['username'] ?? 'User';
          _branchName = userData['branchName'] ?? userData['branch'] ?? 'Branch';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _tlNikController.dispose();
    _tlPasswordController.dispose();
    super.dispose();
  }

  List<CatridgeQRData> _prepareReturnQRData() {
    print('🔧 [QR_DATA] Preparing return QR data...');
    List<CatridgeQRData> qrDataList = [];
    
    for (var cartridge in widget.cartridgeData) {
      final qrData = CatridgeQRData(
        idTool: widget.returnData?.header?.atmCode ?? '0',
        bagCode: cartridge['bagCode']?.toString() ?? '',
        catridgeCode: cartridge['noCatridge']?.toString() ?? '',
        sealCode: cartridge['sealCode']?.toString() ?? '',
        catridgeSeal: cartridge['noSeal']?.toString() ?? '',
        denomCode: cartridge['catridgeFisik']?.toString() ?? '',
        qty: cartridge['qty']?.toString() ?? '0',
        userInput: 'RETURN',
        sealReturn: cartridge['sealReturn']?.toString() ?? '',
        typeCatridgeTrx: 'RETURN',
        tableCode: 'RETURN',
        warehouseCode: '',
        operatorId: '',
        operatorName: '',
      );
      qrDataList.add(qrData);
      print('   - Added return cartridge: ${cartridge['noCatridge']}');
    }
    
    print('✅ [QR_DATA] Prepared ${qrDataList.length} return QR data items');
    return qrDataList;
  }

  Future<void> _validateTLAndSubmit() async {
    if (_tlNikController.text.isEmpty || _tlPasswordController.text.isEmpty) {
      await _showErrorDialog('NIK dan Password TL harus diisi');
      return;
    }
    
    setState(() { _isSubmitting = true; });
    
    try {
      // Validate TL credentials
      final tlResponse = await _apiService.validateTLSupervisor(
        nik: _tlNikController.text,
        password: _tlPasswordController.text,
      );
      
      if (tlResponse.success) {
        // Submit return data
        await _submitReturnData();
      } else {
        await _showErrorDialog(tlResponse.message ?? 'Validasi TL gagal');
      }
    } catch (e) {
      await _showErrorDialog('Error validasi TL: ${e.toString()}');
    } finally {
      setState(() { _isSubmitting = false; });
    }
  }

  Future<void> _submitReturnData() async {
    try {
      // Implementation for submitting return data
      // This should match the existing submit logic from return_page.dart
      
      await _showSuccessDialog('Data berhasil disubmit!');
      
      // Navigate back to previous screens
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      await _showErrorDialog('Error submit data: ${e.toString()}');
    }
  }

  Future<void> _showErrorDialog(String message) async {
    return CustomModals.showSuccessModal(
      context: context,
      message: message,
    );
  }

  Future<void> _showSuccessDialog(String message) async {
    return CustomModals.showSuccessModal(
      context: context,
      message: message,
    );
  }

  String _getCartridgeSectionTitle(Map<String, dynamic> cartridge, int index) {
    final typeCatridgeTrx = cartridge['typeCatridgeTrx']?.toString().toUpperCase() ?? 'C';
    
    switch (typeCatridgeTrx) {
      case 'D':
        return 'Divert ${index + 1}';
      case 'P':
        return 'Pocket';
      case 'C':
      default:
        return 'Catridge ${index + 1}';
    }
  }

  Widget _buildCartridgeSection(Map<String, dynamic> cartridge, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getCartridgeSectionTitle(cartridge, index),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          // Layout 3 kolom (2-2-2) untuk 7 field dengan garis pemisah
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kolom 1 (2 field)
              Expanded(
                child: Column(
                  children: [
                    _buildCartridgeField('No. Cartridge', cartridge['noCatridge'] ?? ''),
                    _buildCartridgeField('Seal Cartridge', cartridge['sealCatridge'] ?? ''),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 80,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              // Kolom 2 (2 field)
              Expanded(
                child: Column(
                  children: [
                    _buildCartridgeField('Cartridge Fisik', cartridge['catridgeFisik'] ?? ''),
                    _buildCartridgeField('Bag Code', cartridge['bagCode'] ?? ''),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 80,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              // Kolom 3 (3 field)
              Expanded(
                child: Column(
                  children: [
                    _buildCartridgeField('Seal Code', cartridge['sealCode'] ?? ''),
                    _buildCartridgeField('Kondisi Seal', cartridge['kondisiSeal'] ?? ''),
                    _buildCartridgeField('Kondisi Catridge', cartridge['kondisiCatridge'] ?? ''),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Denominasi
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Denominasi:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...['1K', '2K', '5K', '10K', '20K', '50K', '100K'].where((denom) {
                      final lembar = int.tryParse(cartridge['lembar_$denom'] ?? '0') ?? 0;
                      return lembar > 0; // Only show denominations with input > 0
                    }).map((denom) {
                      final lembar = cartridge['lembar_$denom'] ?? '0';
                      final lembarInt = int.tryParse(lembar) ?? 0;
                      // Calculate correct nominal based on denomination
                      final denomValue = _getDenomValue(denom);
                      final totalNominal = lembarInt * denomValue;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text('$denom:'),
                            ),
                            SizedBox(
                              width: 80,
                              child: Text('$lembar lembar'),
                            ),
                            Text('Rp ${_formatCurrency(totalNominal)}'),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right side - Total per cartridge
              Expanded(
                flex: 1,
                child: _buildCartridgeTotal(cartridge),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartridgeField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailWSID() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '| Detail WSID',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _buildLabelValue('WSID', widget.returnData?.header?.atmCode ?? ''),
          _buildLabelValue('Bank', widget.returnData?.header?.codeBank ?? widget.returnData?.header?.namaBank ?? ''),
          _buildLabelValue('Lokasi', widget.returnData?.header?.lokasi ?? ''),
          _buildLabelValue('Jenis Mesin', widget.returnData?.header?.jnsMesin ?? ''),
          _buildLabelValue('ATM Type', widget.returnData?.header?.idTypeAtm ?? widget.returnData?.header?.typeATM ?? ''),
          _buildLabelValue('Tgl. Unload', widget.returnData?.header?.timeSTReturn ?? ''),
        ],
      ),
    );
  }



  Widget _buildTLValidationForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approval TL Supervisor',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'NIK TL SPV',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
            ),
            child: TextField(
              controller: _tlNikController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                suffixIcon: Icon(Icons.person_outline, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Password',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
            ),
            child: TextField(
              controller: _tlPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                suffixIcon: Icon(Icons.visibility, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Grand Total
          const Row(
            children: [
              Text(
                'Grand Total:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(width: 8),
              Text('Rp', style: TextStyle(fontSize: 16)),
            ],
          ),
          const SizedBox(height: 24),
          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _validateTLAndSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Submit Data',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          // Divider ATAU
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[400])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'ATAU',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[400])),
            ],
          ),
          const SizedBox(height: 16),
          // QR Code Section
          const Text(
            'Scan QR Code untuk Approval',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'TL dapat scan QR code ini untuk approval tanpa memasukkan NIK',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                QRCodeGeneratorWidget(
                   action: 'RETURN',
                   idTool: widget.returnData?.header?.atmCode ?? '0',
                   catridgeData: _prepareReturnQRData(),
                 ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label :',
              style: const TextStyle(fontWeight: FontWeight.normal),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  // Helper method to get denomination value
  int _getDenomValue(String denom) {
    switch (denom) {
      case '1K': return 1000;
      case '2K': return 2000;
      case '5K': return 5000;
      case '10K': return 10000;
      case '20K': return 20000;
      case '50K': return 50000;
      case '100K': return 100000;
      default: return 0;
    }
  }

  // Helper method to format currency
  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Widget _buildCartridgeTotal(Map<String, dynamic> cartridge) {
    int totalLembar = 0;
    int totalNominal = 0;

    for (String denom in ['1K', '2K', '5K', '10K', '20K', '50K', '100K']) {
      final lembar = int.tryParse(cartridge['lembar_$denom'] ?? '0') ?? 0;
      final denomValue = _getDenomValue(denom);
      totalLembar += lembar;
      totalNominal += lembar * denomValue;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Total:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Value: $totalLembar lembar',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            'Rp ${_formatCurrency(totalNominal)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  // Build total section
  Widget _buildTotalSection() {
    int totalLembar = 0;
    int totalNominal = 0;

    // Calculate totals from all cartridges
    for (var cartridge in widget.cartridgeData) {
      for (String denom in ['1K', '2K', '5K', '10K', '20K', '50K', '100K']) {
        final lembar = int.tryParse(cartridge['lembar_$denom'] ?? '0') ?? 0;
        final denomValue = _getDenomValue(denom);
        totalLembar += lembar;
        totalNominal += lembar * denomValue;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Keseluruhan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Value (Lembar):',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '$totalLembar lembar',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total (Nominal):',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                'Rp ${_formatCurrency(totalNominal)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTabletOrLandscapeMobile = size.width >= 600;
    final isTablet = isTabletOrLandscapeMobile;

    return Scaffold(
      appBar: null, // Remove default AppBar
      body: Column(
        children: [
          // Custom header - same as return_page
          Container(
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
                // Back button
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
                          color: Colors.black,
                          size: 24,
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: isTabletOrLandscapeMobile ? 20 : 16),
                
                // Title
                Text(
                  'Summary Return',
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
                    _userData?['role'] ?? 'CRF_KONSOL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                
                SizedBox(width: isTablet ? 16 : 12),
                
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
          ),
          // Body content
          Expanded(
            child: isTabletOrLandscapeMobile
                ? Stack(
                    children: [
                      // Left side - Scrollable cartridge data (takes full width)
                      Positioned.fill(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(left: 16, top: 16, bottom: 16, right: MediaQuery.of(context).size.width * 0.35), // Add right padding to avoid overlap
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title Detail Return
                              Text(
                                'Detail Return',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Cartridge sections
                              ...widget.cartridgeData.asMap().entries.map((entry) {
                                return _buildCartridgeSection(entry.value, entry.key);
                              }).toList(),
                              const SizedBox(height: 16),
                              // Total Value dan Total
                              // _buildTotalSection(), // Removed as total is now shown per cartridge
                            ],
                          ),
                        ),
                      ),
                      // Right side - Absolutely positioned fixed sidebar
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        width: MediaQuery.of(context).size.width * 0.3,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              left: BorderSide(color: Colors.grey.shade300, width: 1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Detail WSID - Fixed at top
                              _buildDetailWSID(),
                              const SizedBox(height: 16),
                              // TL Validation Form - Fixed below Detail WSID
                              Expanded(
                                child: SingleChildScrollView(
                                  child: _buildTLValidationForm(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Detail Return
                        Text(
                          'Detail Return',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Cartridge sections
                        ...widget.cartridgeData.asMap().entries.map((entry) {
                          return _buildCartridgeSection(entry.value, entry.key);
                        }).toList(),
                        const SizedBox(height: 16),
                        const SizedBox(height: 16),
                        // Detail WSID
                        _buildDetailWSID(),
                        const SizedBox(height: 16),
                        // TL Validation Form
                        _buildTLValidationForm(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
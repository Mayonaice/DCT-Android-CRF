import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/konsol_api_service.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../models/closing_android_request.dart';
import '../models/bank_model.dart';
import '../widgets/custom_modals.dart';
import '../mixins/auto_logout_mixin.dart';
import 'profile_menu_screen.dart';

class KonsolDataClosingFormScreen extends StatefulWidget {
  const KonsolDataClosingFormScreen({super.key});

  @override
  State<KonsolDataClosingFormScreen> createState() => _KonsolDataClosingFormScreenState();
}

class _KonsolDataClosingFormScreenState extends State<KonsolDataClosingFormScreen> with AutoLogoutMixin {
  final KonsolApiService _apiService = KonsolApiService();
  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  DateTime selectedDate = DateTime.now();
  String? selectedBank;
  String? selectedMesinType;
  List<Bank> bankList = [];
  List<String> mesinTypes = ['ATM', 'CRM', 'CDM'];
  
  // Data for the form
  List<ClosingPreviewItem> closingPreviewItems = [];
  bool isLoading = false;
  bool hasAppliedFilter = false;
  String errorMessage = '';
  
  // Totals for denominations
  int totalA1 = 0;
  int totalA2 = 0;
  int totalA5 = 0;
  int totalA10 = 0;
  int totalA20 = 0;
  int totalA50 = 0;
  int totalA75 = 0;
  int totalA100 = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _loadBanks();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  Future<void> _loadBanks() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      final banks = await _apiService.getBankList();
      
      setState(() {
        bankList = banks;
        if (banks.isNotEmpty) {
          selectedBank = banks[0].code;
        }
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load banks: $e';
        isLoading = false;
      });
      
      await CustomModals.showFailedModal(
        context: context,
        message: 'Gagal memuat daftar bank: $e',
      );
    }
  }

  Future<void> _applyFilter() async {
    if (selectedBank == null || selectedMesinType == null) {
      setState(() {
        errorMessage = 'Please select Bank and Machine Type';
      });
      
      await CustomModals.showFailedModal(
        context: context,
        message: 'Mohon pilih Bank dan Tipe Mesin',
      );
      return;
    }

    // Check token expiry sebelum API call
    final isTokenValid = await checkTokenBeforeApiCall();
    if (!isTokenValid) return;

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final dateStr = DateFormat('dd-MM-yyyy').format(selectedDate);
      final items = await safeApiCall(() => _apiService.getClosingPreview(
        selectedBank!,
        selectedMesinType!,
        dateStr
      ));

      if (items != null) {
        // Calculate totals
        int a1Sum = 0;
        int a2Sum = 0;
        int a5Sum = 0;
        int a10Sum = 0;
        int a20Sum = 0;
        int a50Sum = 0;
        int a75Sum = 0;
        int a100Sum = 0;

        for (var item in items) {
          a1Sum += item.a1Edit;
          a2Sum += item.a2Edit;
          a5Sum += item.a5Edit;
          a10Sum += item.a10Edit;
          a20Sum += item.a20Edit;
          a50Sum += item.a50Edit;
          a75Sum += item.a75Edit;
          a100Sum += item.a100Edit;
        }

        setState(() {
          closingPreviewItems = items;
          hasAppliedFilter = true;
          totalA1 = a1Sum;
          totalA2 = a2Sum;
          totalA5 = a5Sum;
          totalA10 = a10Sum;
          totalA20 = a20Sum;
          totalA50 = a50Sum;
          totalA75 = a75Sum;
          totalA100 = a100Sum;
          isLoading = false;
        });
        
        if (items.isEmpty) {
          await CustomModals.showFailedModal(
            context: context,
            message: 'Belum ada Data Yang Dipilih',
          );
        }
      } else {
        setState(() {
          errorMessage = 'Session expired. Please login again.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to load preview data: $e';
        isLoading = false;
      });
      
      await CustomModals.showFailedModal(
        context: context,
        message: 'Gagal memuat data: $e',
      );
    }
  }

  Future<void> _submitClosing() async {
    if (selectedBank == null || selectedMesinType == null) {
      setState(() {
        errorMessage = 'Please select Bank and Machine Type';
      });
      
      // Show error modal
      await CustomModals.showFailedModal(
        context: context,
        message: 'Mohon pilih Bank dan Tipe Mesin',
      );
      return;
    }

    // Show confirmation modal first
    final confirmed = await CustomModals.showConfirmationModal(
      context: context,
      message: 'Apakah anda sudah Yakin untuk Closing Konsolidasi?',
    );
    
    if (!confirmed) {
      return; // User canceled the operation
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Use the same parameters from the filter
      final dateStr = DateFormat('dd-MM-yyyy').format(selectedDate);
      
      // Call the API with the selected filter values
      final response = await _apiService.insertClosingData(
        selectedBank!,
        selectedMesinType!,
        dateStr
      );

      setState(() {
        isLoading = false;
      });

      if (response.success) {
        // Show success modal
        await CustomModals.showSuccessModal(
          context: context,
          message: 'Closing Konsolidasi sudah berhasil disimpan!',
          onPressed: () {
            Navigator.pop(context); // Close modal
            Navigator.pop(context, true); // Return to previous screen with success flag
          },
        );
      } else {
        setState(() {
          errorMessage = response.message;
        });
        
        // Show error modal
        await CustomModals.showFailedModal(
          context: context,
          message: 'Gagal: ${response.message}',
        );
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to submit closing data: $e';
        isLoading = false;
      });
      
      // Show error modal
      await CustomModals.showFailedModal(
        context: context,
        message: 'Gagal menyimpan data: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth >= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isTablet),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 16.0 : 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFilterSection(isTablet),
                      SizedBox(height: isTablet ? 16 : 12),
                      if (isLoading)
                        const Center(child: CircularProgressIndicator()),
                      if (errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(bottom: 16),
                          color: Colors.red.shade100,
                          child: Text(
                            errorMessage,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                      if (hasAppliedFilter && closingPreviewItems.isNotEmpty)
                        _buildClosingForm(isTablet),
                      if (hasAppliedFilter && closingPreviewItems.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              'No data available for the selected filters',
                              style: TextStyle(
                                fontSize: isTablet ? 16 : 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            _buildFooter(isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    return Container(
      height: isTablet ? 80 : 70,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32.0 : 24.0,
        vertical: isTablet ? 16.0 : 12.0,
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
              width: isTablet ? 48 : 40,
              height: isTablet ? 48 : 40,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          SizedBox(width: isTablet ? 20 : 16),
          
          // Title
          Text(
            'Data Closing',
            style: TextStyle(
              fontSize: isTablet ? 28 : 24,
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
              FutureBuilder<Map<String, dynamic>?>(
                future: _authService.getUserData(),
                builder: (context, snapshot) {
                  String branchName = '';
                  if (snapshot.hasData && snapshot.data != null) {
                    branchName = snapshot.data!['branchName'] ?? 
                                snapshot.data!['branch'] ?? 
                                '';
                  }
                  return Text(
                    branchName,
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  );
                },
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
            child: FutureBuilder<Map<String, dynamic>?>(
              future: _authService.getUserData(),
              builder: (context, snapshot) {
                String role = '';
                if (snapshot.hasData && snapshot.data != null) {
                  role = snapshot.data!['roleID'] ?? 
                         snapshot.data!['role'] ?? 
                         'CRF_KONSOL';
                } else {
                  role = 'CRF_KONSOL';
                }
                return Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                );
              },
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
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _authService.getUserData(),
                    builder: (context, snapshot) {
                      String userName = '';
                      if (snapshot.hasData && snapshot.data != null) {
                        userName = snapshot.data!['userName'] ?? 
                                  snapshot.data!['name'] ?? 
                                  '';
                      }
                      return Container(
                        constraints: BoxConstraints(maxWidth: isTablet ? 150 : 120),
                        child: Text(
                          userName,
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      );
                    },
                  ),
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _authService.getUserData(),
                    builder: (context, snapshot) {
                      String nik = '';
                      if (snapshot.hasData && snapshot.data != null) {
                        nik = snapshot.data!['userId'] ?? 
                              snapshot.data!['userID'] ?? 
                              '';
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
                  final shouldNavigate = await CustomModals.showConfirmationModal(
                    context: context,
                    message: 'Apakah Anda ingin membuka halaman Profile Menu?',
                    confirmText: 'Ya',
                    cancelText: 'Tidak',
                  );
                  if (shouldNavigate == true) {
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
                          return Container(
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                image: snapshot.data!,
                                fit: BoxFit.cover,
                              ),
                            ),
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

  Widget _buildFilterSection(bool isTablet) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Tanggal Replenish
          Row(
            children: [
              Text(
                'Tanggal Replenish',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                ':',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                      _applyFilter(); // Auto-apply filter when date changes
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade400),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy').format(selectedDate),
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.calendar_today,
                        size: isTablet ? 18 : 16,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Bank
          Row(
            children: [
              Text(
                'Bank',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                ':',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: isTablet ? 200 : 150,
                padding: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
                child: DropdownButton<String>(
                  value: selectedBank,
                  hint: const Text('Select Bank'),
                  underline: const SizedBox(),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: bankList.map((bank) {
                    return DropdownMenuItem<String>(
                      value: bank.code,
                      child: Text(bank.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedBank = value;
                      _applyFilter(); // Auto-apply filter when bank changes
                    });
                  },
                ),
              ),
            ],
          ),
          
          // Jenis Mesin
          Row(
            children: [
              Text(
                'Jenis Mesin',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                ':',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: isTablet ? 150 : 120,
                padding: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
                child: DropdownButton<String>(
                  value: selectedMesinType,
                  hint: const Text('Select Type'),
                  underline: const SizedBox(),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: mesinTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedMesinType = value;
                      _applyFilter(); // Auto-apply filter when mesin type changes
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClosingForm(bool isTablet) {
    return Column(
      children: [
        // ATM data items
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // List of ATM data items
              ...closingPreviewItems.map((item) => _buildAtmDataItem(item, isTablet)).toList(),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Bottom section with Closing button and totals (separate container)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Closing button
              Container(
                margin: const EdgeInsets.only(top: 24),
                child: ElevatedButton(
                  onPressed: _submitClosing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32 : 24,
                      vertical: isTablet ? 16 : 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        'Closing',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Totals section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTotalRow('Total Proses', isTablet),
                  const SizedBox(height: 8),
                  _buildTotalRow('Pengurangan Untuk Prepare, Stock Uang, Delivery', isTablet),
                  const SizedBox(height: 8),
                  _buildTotalRow('Sisa Uang Proses (Closing Konsol)', isTablet),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildAtmDataItem(ClosingPreviewItem item, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Horizontal divider
        Container(
          height: 1,
          color: Colors.grey.shade300,
        ),
        
        // ATM Code header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            item.atmCode,
            style: TextStyle(
              fontSize: isTablet ? 22 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Horizontal divider
        Container(
          height: 1,
          color: Colors.grey.shade300,
        ),
        
        const SizedBox(height: 16),
        
        // Details section
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - ATM details
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('ID Tool', item.id, isTablet),
                  const SizedBox(height: 12),
                  _buildDetailRow('Lokasi', item.name, isTablet),
                  const SizedBox(height: 12),
                  _buildDetailRow('Nama Bank', item.codeBank, isTablet),
                ],
              ),
            ),
            
            // Vertical divider
            Container(
              width: 1,
              height: 120,
              color: Colors.grey.shade300,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            
            // Middle section - Date and time
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    'Tanggal Proses', 
                    DateFormat('dd MMM yyyy').format(
                      DateTime.tryParse(item.timeFinish) ?? DateTime.now()
                    ), 
                    isTablet
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Jam Mulai', 
                    DateFormat('HH:mm').format(
                      DateTime.tryParse(item.timeStart) ?? DateTime.now()
                    ), 
                    isTablet
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    'Jam Selesai', 
                    DateFormat('HH:mm').format(
                      DateTime.tryParse(item.timeFinish) ?? DateTime.now()
                    ), 
                    isTablet
                  ),
                ],
              ),
            ),
            
            // Vertical divider
            Container(
              width: 1,
              height: 120,
              color: Colors.grey.shade300,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            
            // Right side - Denomination counts
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jumlah Denom',
                    style: TextStyle(
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDenomGrid(item, isTablet),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, bool isTablet) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isTablet ? 140 : 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          ':',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDenomGrid(ClosingPreviewItem item, bool isTablet) {
    return Column(
      children: [
        Row(
          children: [
            _buildDenomItem('A100', item.a100Edit.toString(), isTablet),
            const SizedBox(width: 8),
            _buildDenomItem('A20', item.a20Edit.toString(), isTablet),
            const SizedBox(width: 8),
            _buildDenomItem('A2', item.a2Edit.toString(), isTablet),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDenomItem('A75', item.a75Edit.toString(), isTablet),
            const SizedBox(width: 8),
            _buildDenomItem('A10', item.a10Edit.toString(), isTablet),
            const SizedBox(width: 8),
            _buildDenomItem('A1', item.a1Edit.toString(), isTablet),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDenomItem('A50', item.a50Edit.toString(), isTablet),
            const SizedBox(width: 8),
            _buildDenomItem('A5', item.a5Edit.toString(), isTablet),
            const SizedBox(width: 8),
            Container(width: 50), // Empty space for balance
          ],
        ),
      ],
    );
  }
  
  Widget _buildDenomItem(String label, String value, bool isTablet) {
    return Container(
      width: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(3),
                topRight: Radius.circular(3),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: isTablet ? 14 : 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              value,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTotalRow(String label, bool isTablet) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Container(
          width: 300,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        // Denomination boxes
        Row(
          children: [
            _buildTotalBox(label == 'Total Proses' ? totalA1.toString() : '', isTablet),
            _buildTotalBox(label == 'Total Proses' ? totalA2.toString() : '', isTablet),
            _buildTotalBox(label == 'Total Proses' ? totalA5.toString() : '', isTablet),
            _buildTotalBox(label == 'Total Proses' ? totalA10.toString() : '', isTablet),
            _buildTotalBox(label == 'Total Proses' ? totalA20.toString() : '', isTablet),
            _buildTotalBox(label == 'Total Proses' ? totalA50.toString() : '', isTablet),
            _buildTotalBox(label == 'Total Proses' ? totalA75.toString() : '', isTablet),
            _buildTotalBox(
              label == 'Total Proses' ? totalA100.toString() : 
              label == 'Sisa Uang Proses (Closing Konsol)' ? '100' : '', 
              isTablet
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTotalBox(String value, bool isTablet) {
    return Container(
      width: 50,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }







  Widget _buildFooter(bool isTablet) {
    return Container(
      height: isTablet ? 40 : 35,
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 32 : 24),
      color: Colors.white,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'CASH REPLENISH FORM  ver. 0.0.1',
          style: TextStyle(
            fontSize: isTablet ? 12 : 10,
            fontWeight: FontWeight.w400,
            color: const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}
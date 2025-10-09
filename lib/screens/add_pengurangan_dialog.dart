import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/pengurangan_insert_request.dart';
import '../models/bank_model.dart';
import '../services/konsol_api_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_modals.dart';

class AddPenguranganDialog extends StatefulWidget {
  const AddPenguranganDialog({super.key});

  @override
  State<AddPenguranganDialog> createState() => _AddPenguranganDialogState();
}

class _AddPenguranganDialogState extends State<AddPenguranganDialog> {
  final _formKey = GlobalKey<FormState>();
  final KonsolApiService _apiService = KonsolApiService();
  final AuthService _authService = AuthService();
  
  // Controllers
  final TextEditingController _bankController = TextEditingController();
  final TextEditingController _jenisMesinController = TextEditingController();
  final TextEditingController _jenisDataController = TextEditingController();
  final TextEditingController _tglPrepareController = TextEditingController();
  final TextEditingController _keteranganController = TextEditingController();
  final TextEditingController _a100Controller = TextEditingController();
  final TextEditingController _a75Controller = TextEditingController();
  final TextEditingController _a50Controller = TextEditingController();
  final TextEditingController _a20Controller = TextEditingController();
  final TextEditingController _a10Controller = TextEditingController();
  final TextEditingController _a5Controller = TextEditingController();
  final TextEditingController _a2Controller = TextEditingController();
  final TextEditingController _a1Controller = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  String _errorMessage = '';
  String _userNik = '';
  String _branchCode = '';
  
  // Bank data
  List<Bank> _bankList = [];
  
  // Jenis Mesin options
  final List<String> _jenisMesinOptions = ['ATM', 'CRM', 'CDM'];
  
  // Jenis Data options
  final List<String> _jenisDataOptions = ['PENGURANGAN', 'PENAMBAHAN'];

  @override
  void initState() {
    super.initState();
    _tglPrepareController.text = DateFormat('dd MMM yyyy').format(_selectedDate);
    _loadUserData();
    _loadBankData();
  }
  
  // Load bank data from API
  Future<void> _loadBankData() async {
    try {
      final banks = await _apiService.getBankList();
      setState(() {
        _bankList = banks;
      });
      debugPrint('🔍 Loaded ${banks.length} banks');
    } catch (e) {
      debugPrint('Error loading bank data: $e');
    }
  }

  @override
  void dispose() {
    _bankController.dispose();
    _jenisMesinController.dispose();
    _jenisDataController.dispose();
    _tglPrepareController.dispose();
    _keteranganController.dispose();
    _a100Controller.dispose();
    _a75Controller.dispose();
    _a50Controller.dispose();
    _a20Controller.dispose();
    _a10Controller.dispose();
    _a5Controller.dispose();
    _a2Controller.dispose();
    _a1Controller.dispose();
    super.dispose();
  }

  // Load user data from login
  Future<void> _loadUserData() async {
    try {
      final userData = await _authService.getUserData();
      if (userData != null) {
        // Try multiple possible keys for NIK
        final possibleNikKeys = ['nik', 'NIK', 'userID', 'UserID', 'userId', 'UserNIK', 'userNIK'];
        String nikValue = '';
        
        for (var key in possibleNikKeys) {
          if (userData.containsKey(key) && userData[key] != null && userData[key].toString().isNotEmpty) {
            nikValue = userData[key].toString();
            break;
          }
        }
        
        setState(() {
          _userNik = nikValue;
          _branchCode = userData['groupId'] ?? userData['branchCode'] ?? '';
        });
        
        debugPrint('🔍 User NIK: $_userNik, Branch Code: $_branchCode');
        
        if (_userNik.isEmpty) {
          debugPrint('⚠️ WARNING: User NIK is empty! Available keys: ${userData.keys.join(', ')}');
          debugPrint('⚠️ User data: $userData');
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  // Show date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _tglPrepareController.text = DateFormat('dd MMM yyyy').format(_selectedDate);
      });
    }
  }

  // Validate form manually
  String? _validateForm() {
    if (_bankController.text.isEmpty) {
      return 'Bank harus diisi';
    }
    if (_jenisMesinController.text.isEmpty) {
      return 'Jenis Mesin harus diisi';
    }
    if (_jenisDataController.text.isEmpty) {
      return 'Jenis Data harus diisi';
    }
    if (_tglPrepareController.text.isEmpty) {
      return 'Tanggal Prepare harus diisi';
    }
    return null;
  }

  // Submit form
  Future<void> _submitForm() async {
    // Manual validation
    final validationError = _validateForm();
    if (validationError != null) {
      await CustomModals.showFailedModal(
        context: context,
        message: validationError,
      );
      return;
    }
    
    // Show confirmation modal first
    final confirmed = await CustomModals.showConfirmationModal(
      context: context,
      message: 'Apakah anda yakin ingin menyimpan data ini?',
      confirmText: 'Simpan',
    );
    
    if (!confirmed) {
      return; // User canceled the operation
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Convert jenis value to T or K based on selection
      String jenisValue;
      if (_jenisDataController.text == 'PENAMBAHAN') {
        jenisValue = 'T';
      } else if (_jenisDataController.text == 'PENGURANGAN') {
        jenisValue = 'K';
      } else {
        jenisValue = _jenisDataController.text;
      }
      
      debugPrint('🔍 Converting jenis from "${_jenisDataController.text}" to "$jenisValue"');
      
      if (_userNik.isEmpty) {
        debugPrint('⚠️ WARNING: userInput is empty! This may cause issues.');
      }
      
      final request = PenguranganInsertRequest(
        codeBank: _bankController.text,
        jnsMesin: _jenisMesinController.text,
        jenis: jenisValue, // Use the converted value
        tglPrepare: _selectedDate,
        a100: int.tryParse(_a100Controller.text),
        a75: int.tryParse(_a75Controller.text),
        a50: int.tryParse(_a50Controller.text),
        a20: int.tryParse(_a20Controller.text),
        a10: int.tryParse(_a10Controller.text),
        a5: int.tryParse(_a5Controller.text),
        a2: int.tryParse(_a2Controller.text),
        a1: int.tryParse(_a1Controller.text),
        userInput: _userNik,
        tlCode: "", // Explicitly set to empty string
        keterangan: _keteranganController.text,
        branchCode: _branchCode,
      );

      final response = await _apiService.insertPenguranganData(request);

      setState(() {
        _isLoading = false;
      });

      if (response.success) {
        if (!mounted) return;
        
        await CustomModals.showSuccessModal(
          context: context,
          message: 'Data berhasil disimpan!',
          onPressed: () {
            Navigator.pop(context); // Close modal
            Navigator.of(context).pop(true); // Return true to indicate success
          },
        );
      } else {
        setState(() {
          _errorMessage = response.message;
        });
        
        await CustomModals.showFailedModal(
          context: context,
          message: 'Gagal: ${response.message}',
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      
      await CustomModals.showFailedModal(
        context: context,
        message: 'Gagal menyimpan data: ${e.toString()}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth >= 768;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: isTablet ? screenWidth * 0.8 : screenWidth * 0.9,
        height: isTablet ? screenHeight * 0.8 : screenHeight * 0.9,
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Form Pengurangan/Penambahan Data',
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.grey,
                  ),
                  tooltip: 'Tutup',
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Main content with two columns
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left column - Main fields
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _bankList.isEmpty
                                ? _buildDropdownField(
                                    label: 'Bank',
                                    controller: _bankController,
                                    options: ['Loading...'],
                                    isTablet: isTablet,
                                  )
                                : _buildBankDropdownField(
                                    label: 'Bank',
                                    controller: _bankController,
                                    banks: _bankList,
                                    isTablet: isTablet,
                                  ),
                                const SizedBox(height: 16),
                                _buildDropdownField(
                                  label: 'Jenis Mesin',
                                  controller: _jenisMesinController,
                                  options: _jenisMesinOptions,
                                  isTablet: isTablet,
                                ),
                                const SizedBox(height: 16),
                                _buildDropdownField(
                                  label: 'Jenis Data',
                                  controller: _jenisDataController,
                                  options: _jenisDataOptions,
                                  isTablet: isTablet,
                                ),
                                const SizedBox(height: 16),
                                _buildDateField(
                                  label: 'Tanggal Prepare',
                                  controller: _tglPrepareController,
                                  onTap: () => _selectDate(context),
                                  isTablet: isTablet,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Keterangan :',
                                  style: TextStyle(
                                    fontSize: isTablet ? 16 : 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: TextFormField(
                                    controller: _keteranganController,
                                    maxLines: 4,
                                    decoration: const InputDecoration(
                                      contentPadding: EdgeInsets.all(12),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(width: 24),
                          
                          // Right column - Denomination fields
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jumlah (Lembar)',
                                  style: TextStyle(
                                    fontSize: isTablet ? 18 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildDenomField(
                                  label: 'A100',
                                  controller: _a100Controller,
                                  isTablet: isTablet,
                                ),
                                const SizedBox(height: 12),
                                _buildDenomField(
                                  label: 'A75',
                                  controller: _a75Controller,
                                  isTablet: isTablet,
                                ),
                                const SizedBox(height: 12),
                                _buildDenomField(
                                  label: 'A50',
                                  controller: _a50Controller,
                                  isTablet: isTablet,
                                ),
                                const SizedBox(height: 12),
                                _buildDenomField(
                                  label: 'A20',
                                  controller: _a20Controller,
                                  isTablet: isTablet,
                                ),
                                const SizedBox(height: 12),
                                _buildDenomField(
                                  label: 'A10',
                                  controller: _a10Controller,
                                  isTablet: isTablet,
                                ),
                                const SizedBox(height: 12),
                                _buildDenomField(
                                  label: 'A5',
                                  controller: _a5Controller,
                                  isTablet: isTablet,
                                ),
                                const SizedBox(height: 12),
                                _buildDenomField(
                                  label: 'A2',
                                  controller: _a2Controller,
                                  isTablet: isTablet,
                                ),
                                const SizedBox(height: 12),
                                _buildDenomField(
                                  label: 'A1',
                                  controller: _a1Controller,
                                  isTablet: isTablet,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Error message
                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Submit button
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 16,
                    vertical: isTablet ? 16 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                icon: _isLoading
                    ? Container(
                        width: 24,
                        height: 24,
                        padding: const EdgeInsets.all(2.0),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : const Icon(Icons.check, color: Colors.white),
                label: Text(
                  'Submit',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build dropdown field with underline style
  Widget _buildDropdownField({
    required String label,
    required TextEditingController controller,
    required List<String> options,
    required bool isTablet,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ':',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade400,
                  width: 1,
                ),
              ),
            ),
            child: DropdownButtonFormField<String>(
              value: controller.text.isNotEmpty ? controller.text : null,
              hint: Text('Pilih $label'),
              isExpanded: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
              ),
              items: options.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  controller.text = newValue;
                }
              },
              // Validator removed - using custom modal validation
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildBankDropdownField({
    required String label,
    required TextEditingController controller,
    required List<Bank> banks,
    required bool isTablet,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ':',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade400,
                  width: 1,
                ),
              ),
            ),
            child: DropdownButtonFormField<String>(
              value: controller.text.isNotEmpty ? controller.text : null,
              hint: Text('Pilih $label'),
              isExpanded: true,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
              ),
              items: banks.map((Bank bank) {
                return DropdownMenuItem<String>(
                  value: bank.code,
                  child: Text(
                    bank.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  controller.text = newValue;
                }
              },
              // Validator removed - using custom modal validation
            ),
          ),
        ),
      ],
    );
  }

  // Build date field with underline style
  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required Function() onTap,
    required bool isTablet,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ':',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: AbsorbPointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.shade400,
                      width: 1,
                    ),
                  ),
                ),
                child: TextFormField(
                  controller: controller,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    suffixIcon: Icon(
                      Icons.calendar_today,
                      size: isTablet ? 20 : 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  // Validator removed - using custom modal validation
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Build denomination field
  Widget _buildDenomField({
    required String label,
    required TextEditingController controller,
    required bool isTablet,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            height: isTablet ? 40 : 36,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 60,
          child: Text(
            'Lembar',
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}
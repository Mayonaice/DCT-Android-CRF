import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../widgets/error_dialogs.dart';
import '../widgets/custom_modals.dart';
import '../mixins/auto_logout_mixin.dart';

class ReturnValidationScreen extends StatefulWidget {
  const ReturnValidationScreen({Key? key}) : super(key: key);

  @override
  _ReturnValidationScreenState createState() => _ReturnValidationScreenState();
}

class _ReturnValidationScreenState extends State<ReturnValidationScreen> with AutoLogoutMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _idToolController = TextEditingController();
  final TextEditingController _catridgeCodeController = TextEditingController();
  final TextEditingController _branchCodeController = TextEditingController();
  
  bool _isLoading = false;
  String _validationMessage = '';
  bool _validationSuccess = false;
  Map<String, dynamic> _headerData = {};
  List<dynamic> _catridgeData = [];

  @override
  void initState() {
    super.initState();
    // Pre-fill branch code from user data if available
    AuthService().getUserData().then((userData) {
      if (userData != null && userData['branchCode'] != null) {
        setState(() {
          _branchCodeController.text = userData['branchCode'];
        });
      }
    });
  }

  @override
  void dispose() {
    _idToolController.dispose();
    _catridgeCodeController.dispose();
    _branchCodeController.dispose();
    super.dispose();
  }

  Future<void> _validateAndGetReplenish() async {
    if (_idToolController.text.isEmpty) {
      ErrorDialogs.showErrorDialog(context, title: 'Error', message: 'ID Tool tidak boleh kosong');
      return;
    }

    if (_branchCodeController.text.isEmpty) {
      ErrorDialogs.showErrorDialog(context, title: 'Error', message: 'Branch Code tidak boleh kosong');
      return;
    }

    setState(() {
      _isLoading = true;
      _validationMessage = '';
      _validationSuccess = false;
      _headerData = {};
      _catridgeData = [];
    });

    // Check token expiry sebelum API call
    final isTokenValid = await checkTokenBeforeApiCall();
    if (!isTokenValid) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final result = await safeApiCall(() => _apiService.validateAndGetReplenishRaw(
        _idToolController.text,
        _branchCodeController.text,
        catridgeCode: _catridgeCodeController.text,
      ));

      setState(() {
        _isLoading = false;
        _validationSuccess = result != null && (result['success'] ?? false);
        _validationMessage = result?['message'] ?? 'No message returned';
        
        if (_validationSuccess && result!['data'] != null) {
          _headerData = result['data']['header'] != null && result['data']['header'] is List && (result['data']['header'] as List).isNotEmpty 
              ? (result['data']['header'] as List).first 
              : {};
          
          _catridgeData = result['data']['catridges'] != null && result['data']['catridges'] is List 
              ? result['data']['catridges'] as List 
              : [];
        } else if (!_validationSuccess && _validationMessage.contains('404')) {
          // Show more detailed error dialog for 404 errors
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ErrorDialogs.showErrorDialog(
              context,
              title: 'Endpoint Tidak Ditemukan (404)',
              message: 'API endpoint tidak dapat diakses. Mohon periksa konfigurasi server dan parameter yang digunakan.',
              buttonText: 'Lihat Detail',
              onPressed: () {
                Navigator.pop(context);
                _showDetailedErrorDialog(_validationMessage);
              },
            );
          });
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _validationSuccess = false;
        _validationMessage = 'Error: ${e.toString()}';
      });
      
      // Show error dialog for unexpected errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ErrorDialogs.showErrorDialog(
          context,
          title: 'Terjadi Kesalahan',
          message: 'Terjadi kesalahan saat berkomunikasi dengan server.',
          buttonText: 'Lihat Detail',
          onPressed: () {
            Navigator.pop(context);
            _showDetailedErrorDialog(_validationMessage);
          },
        );
      });
    }
  }
  
  void _showDetailedErrorDialog(String errorMessage) async {
    final confirmed = await CustomModals.showConfirmationModal(
      context: context,
      message: 'Detail Kesalahan:\n\n$errorMessage',
      confirmText: 'Coba Lagi',
      cancelText: 'Tutup',
    );
    
    if (confirmed) {
      _validateAndGetReplenish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Validation'),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _idToolController,
              decoration: const InputDecoration(
                labelText: 'ID Tool',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _branchCodeController,
              decoration: const InputDecoration(
                labelText: 'Branch Code',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _catridgeCodeController,
              decoration: const InputDecoration(
                labelText: 'Catridge Code (Opsional)',
                border: OutlineInputBorder(),
                hintText: 'Kosongkan untuk melihat semua catridge',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _validateAndGetReplenish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Validate and Get Replenish Data'),
            ),
            const SizedBox(height: 24),
            if (_validationMessage.isNotEmpty && !(_validationMessage.contains('404') && !_validationSuccess))
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _validationSuccess ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _validationSuccess ? 'Validasi Berhasil' : 'Validasi Gagal',
                      style: TextStyle(
                        color: _validationSuccess ? Colors.green.shade800 : Colors.red.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getFormattedErrorMessage(_validationMessage),
                      style: TextStyle(
                        color: _validationSuccess ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                    if (!_validationSuccess) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _showDetailedErrorDialog(_validationMessage),
                            child: Text(
                              'Lihat Detail',
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _validateAndGetReplenish,
                            child: Text(
                              'Coba Lagi',
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            if (_validationSuccess && _headerData.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Header Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('ATM Code', _headerData['AtmCode'] ?? 'N/A'),
                      _buildInfoRow('ID Tool Prepare', _headerData['IdToolPrepare'] ?? 'N/A'),
                      _buildInfoRow('Current ID Tool', _headerData['CurrentIdTool'] ?? 'N/A'),
                    ],
                  ),
                ),
              ),
            ],
            if (_validationSuccess && _catridgeData.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Catridge Data (${_catridgeData.length})',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_catridgeCodeController.text.isEmpty && _catridgeData.length > 1)
                    Text(
                      'Showing all catridges',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _catridgeData.length,
                  itemBuilder: (context, index) {
                    final catridge = _catridgeData[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text('Catridge: ${catridge['catridgeCode'] ?? catridge['CatridgeCode'] ?? 'N/A'}'),
                            ),
                            if (_catridgeCodeController.text.isNotEmpty && 
                                _catridgeCodeController.text.toUpperCase() == 
                                (catridge['catridgeCode'] ?? catridge['CatridgeCode'] ?? '').toString().toUpperCase())
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'MATCH',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Seal: ${catridge['catridgeSeal'] ?? catridge['CatridgeSeal'] ?? 'N/A'}'),
                            if (catridge['bagCode'] != null) 
                              Text('Bag Code: ${catridge['bagCode']}'),
                            if (catridge['sealCode'] != null) 
                              Text('Seal Code: ${catridge['sealCode']}'),
                            if (catridge['sealCodeReturn'] != null) 
                              Text('Return Seal: ${catridge['sealCodeReturn']}'),
                            if (catridge['typeCatridgeTrx'] != null) 
                              Text('Type: ${catridge['typeCatridgeTrx']}'),
                            if (catridge['Description'] != null)
                              Text('Description: ${catridge['Description']}'),
                            if (catridge['TripType'] != null || catridge['tripType'] != null)
                              Text('Trip Type: ${catridge['tripType'] ?? catridge['TripType'] ?? 'N/A'}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFormattedErrorMessage(String message) {
    // Format the error message to be more readable in the UI
    if (message.contains('\n')) {
      // If message contains newlines, keep only the first paragraph
      return message.split('\n').first;
    }
    
    // For long messages without newlines, truncate
    if (message.length > 100) {
      return '${message.substring(0, 100)}...';
    }
    
    return message;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
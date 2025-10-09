import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/closing_android_request.dart';
import '../services/konsol_api_service.dart';
import '../models/bank_model.dart';
import '../widgets/custom_modals.dart';

class AddClosingDialog extends StatefulWidget {
  const AddClosingDialog({super.key});

  @override
  State<AddClosingDialog> createState() => _AddClosingDialogState();
}

class _AddClosingDialogState extends State<AddClosingDialog> {
  final KonsolApiService _apiService = KonsolApiService();
  
  // Selected values
  DateTime selectedDate = DateTime.now();
  String? selectedBank;
  String? selectedJenisMesin;
  
  // Lists for dropdown options
  List<Bank> banks = [];
  List<String> jenisMesin = ['ATM', 'CRM'];
  
  // Preview data
  List<ClosingPreviewItem> previewData = [];
  
  // Loading states
  bool isLoadingBanks = true;
  bool isLoadingPreview = false;
  
  // Totals
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
    _loadBanks();
  }
  
  Future<void> _loadBanks() async {
    setState(() {
      isLoadingBanks = true;
    });
    
    try {
      final bankList = await _apiService.getBankList();
      setState(() {
        banks = bankList;
        isLoadingBanks = false;
      });
    } catch (e) {
      debugPrint('Error loading banks: $e');
      setState(() {
        isLoadingBanks = false;
      });
    }
  }
  
  Future<void> _loadPreviewData() async {
    if (selectedBank == null || selectedJenisMesin == null) {
      return;
    }
    
    setState(() {
      isLoadingPreview = true;
      previewData = [];
    });
    
    try {
      final dateString = DateFormat('dd-MM-yyyy').format(selectedDate);
      final data = await _apiService.getClosingPreview(
        selectedBank!,
        selectedJenisMesin!,
        dateString
      );
      
      setState(() {
        previewData = data;
        isLoadingPreview = false;
        _calculateTotals();
      });
    } catch (e) {
      debugPrint('Error loading preview data: $e');
      setState(() {
        isLoadingPreview = false;
      });
    }
  }
  
  void _calculateTotals() {
    totalA1 = 0;
    totalA2 = 0;
    totalA5 = 0;
    totalA10 = 0;
    totalA20 = 0;
    totalA50 = 0;
    totalA75 = 0;
    totalA100 = 0;
    
    for (var item in previewData) {
      totalA1 += item.a1Edit;
      totalA2 += item.a2Edit;
      totalA5 += item.a5Edit;
      totalA10 += item.a10Edit;
      totalA20 += item.a20Edit;
      totalA50 += item.a50Edit;
      totalA75 += item.a75Edit;
      totalA100 += item.a100Edit;
    }
  }
  
  Future<void> _submitClosingData() async {
    if (selectedBank == null || selectedJenisMesin == null) {
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
    
    try {
      final dateString = DateFormat('dd-MM-yyyy').format(selectedDate);
      final response = await _apiService.insertClosingData(
        selectedBank!,
        selectedJenisMesin!,
        dateString
      );
      
      if (response.success) {
        await CustomModals.showSuccessModal(
          context: context,
          message: 'Closing Konsolidasi sudah berhasil disimpan!',
          onPressed: () {
            Navigator.pop(context); // Close modal
            Navigator.of(context).pop(true); // Return success
          },
        );
      } else {
        await CustomModals.showFailedModal(
          context: context,
          message: 'Gagal: ${response.message}',
        );
      }
    } catch (e) {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenWidth * 0.9,
        height: screenHeight * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Data Closing',
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const Divider(thickness: 2, color: Colors.orange),
            const SizedBox(height: 16),
            
            // Filter section
            Row(
              children: [
                // Date picker
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tanggal Replenish', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
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
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                              const SizedBox(width: 8),
                              const Icon(Icons.calendar_today, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Bank dropdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bank', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      isLoadingBanks
                          ? const CircularProgressIndicator()
                          : DropdownButtonFormField<String>(
                              value: selectedBank,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: banks.map((bank) {
                                return DropdownMenuItem<String>(
                                  value: bank.code,
                                  child: Text(bank.name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedBank = value;
                                });
                              },
                              hint: const Text('Select Bank'),
                            ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                
                // Jenis Mesin dropdown
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Jenis Mesin', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedJenisMesin,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: jenisMesin.map((jenis) {
                          return DropdownMenuItem<String>(
                            value: jenis,
                            child: Text(jenis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedJenisMesin = value;
                          });
                        },
                        hint: const Text('Select Jenis Mesin'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Apply filter button
            Center(
              child: ElevatedButton(
                onPressed: _loadPreviewData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Apply Filter', style: TextStyle(color: Colors.white)),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Data display section
            Expanded(
              child: isLoadingPreview
                  ? const Center(child: CircularProgressIndicator())
                  : previewData.isEmpty
                      ? const Center(child: Text('No data available'))
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // First item details
                              if (previewData.isNotEmpty) ...[
                                _buildDetailSection(previewData[0], isTablet),
                                const SizedBox(height: 24),
                              ],
                              
                              // Totals table
                              _buildTotalsTable(isTablet),
                            ],
                          ),
                        ),
            ),
            
            // Bottom buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: previewData.isEmpty ? null : _submitClosingData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Closing', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDetailSection(ClosingPreviewItem item, bool isTablet) {
    // Parse dates for formatting
    DateTime? timeFinish;
    try {
      timeFinish = DateTime.parse(item.timeFinish);
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }
    
    // Extract hours from timestamps
    String startHour = item.timeStart.isNotEmpty ? item.timeStart.split(' ').last.split(':').first : '--:--';
    String finishHour = item.timeFinish.isNotEmpty ? item.timeFinish.split(' ').last.split(':').first : '--:--';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ATM Code as title
        Text(
          item.atmCode,
          style: TextStyle(
            fontSize: isTablet ? 22 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Details in two columns
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('ID Tool', item.id),
                  const SizedBox(height: 8),
                  _buildDetailRow('Lokasi', item.name),
                  const SizedBox(height: 8),
                  _buildDetailRow('Nama Bank', item.codeBank),
                ],
              ),
            ),
            
            // Right column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Tanggal Proses', timeFinish != null 
                      ? DateFormat('dd MMM yyyy').format(timeFinish)
                      : '--'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Jam Mulai', '$startHour:00'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Jam Selesai', '$finishHour:00'),
                ],
              ),
            ),
            
            // Denomination column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Jumlah Denom', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDenomBox('A100', item.a100Edit),
                      const SizedBox(width: 8),
                      _buildDenomBox('A20', item.a20Edit),
                      const SizedBox(width: 8),
                      _buildDenomBox('A2', item.a2Edit),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDenomBox('A75', item.a75Edit),
                      const SizedBox(width: 8),
                      _buildDenomBox('A10', item.a10Edit),
                      const SizedBox(width: 8),
                      _buildDenomBox('A1', item.a1Edit),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDenomBox('A50', item.a50Edit),
                      const SizedBox(width: 8),
                      _buildDenomBox('A5', item.a5Edit),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const Text(': '),
        Expanded(child: Text(value)),
      ],
    );
  }
  
  Widget _buildDenomBox(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value.toString(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
  
  Widget _buildTotalsTable(bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table header
        Row(
          children: [
            _buildTableHeaderCell('A1', isTablet),
            _buildTableHeaderCell('A2', isTablet),
            _buildTableHeaderCell('A5', isTablet),
            _buildTableHeaderCell('A10', isTablet),
            _buildTableHeaderCell('A20', isTablet),
            _buildTableHeaderCell('A50', isTablet),
            _buildTableHeaderCell('A75', isTablet),
            _buildTableHeaderCell('A100', isTablet),
          ],
        ),
        
        // Total Proses row
        Row(
          children: [
            _buildTableCell(totalA1.toString(), isTablet),
            _buildTableCell(totalA2.toString(), isTablet),
            _buildTableCell(totalA5.toString(), isTablet),
            _buildTableCell(totalA10.toString(), isTablet),
            _buildTableCell(totalA20.toString(), isTablet),
            _buildTableCell(totalA50.toString(), isTablet),
            _buildTableCell(totalA75.toString(), isTablet),
            _buildTableCell(totalA100.toString(), isTablet),
          ],
        ),
        
        const SizedBox(height: 16),
        const Text('Total Proses', style: TextStyle(fontWeight: FontWeight.bold)),
        
        const SizedBox(height: 16),
        const Text('Pengurangan Untuk Prepare, Stock Uang, Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
        
        // Empty row for pengurangan
        Row(
          children: [
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
          ],
        ),
        
        const SizedBox(height: 16),
        const Text('Sisa Uang Proses (Closing Konsol)', style: TextStyle(fontWeight: FontWeight.bold)),
        
        // Total row for closing
        Row(
          children: [
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
            _buildTableCell('', isTablet),
            _buildTableCell(totalA100.toString(), isTablet),
          ],
        ),
      ],
    );
  }
  
  Widget _buildTableHeaderCell(String text, bool isTablet) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 8 : 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          color: Colors.grey.shade200,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 14 : 12,
          ),
        ),
      ),
    );
  }
  
  Widget _buildTableCell(String text, bool isTablet) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isTablet ? 8 : 6),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(fontSize: isTablet ? 14 : 12),
        ),
      ),
    );
  }
}
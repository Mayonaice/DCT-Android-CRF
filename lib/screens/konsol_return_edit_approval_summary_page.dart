import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/return_data_model.dart';
import '../services/konsol_api_service.dart';
import '../services/return_api_service.dart';
import '../widgets/custom_modals.dart';
import '../widgets/qr_code_generator_widget.dart';

class KonsolReturnEditApprovalSummaryPage extends StatefulWidget {
  final ReturnData returnData;
  final Map<String, int> editedDenoms;
  final String cashierCode;
  final String tableCode;

  const KonsolReturnEditApprovalSummaryPage({
    super.key,
    required this.returnData,
    required this.editedDenoms,
    required this.cashierCode,
    required this.tableCode,
  });

  @override
  State<KonsolReturnEditApprovalSummaryPage> createState() =>
      _KonsolReturnEditApprovalSummaryPageState();
}

class _KonsolReturnEditApprovalSummaryPageState
    extends State<KonsolReturnEditApprovalSummaryPage> {
  final KonsolApiService _konsolApiService = KonsolApiService();
  final ReturnApiService _returnApiService = ReturnApiService();
  late final String _approvalDateStart = DateTime.now().toIso8601String();
  bool _checking = false;
  String _resolvedBankName = '';

  static const Map<String, int> _denomValues = {
    'A100': 100000,
    'A75': 75000,
    'A50': 50000,
    'A20': 20000,
    'A10': 10000,
    'A5': 5000,
    'A2': 2000,
    'A1': 1000,
  };

  Map<String, int> get _originalDenoms => {
        'A100': widget.returnData.a100 ?? 0,
        'A75': widget.returnData.a75 ?? 0,
        'A50': widget.returnData.a50 ?? 0,
        'A20': widget.returnData.a20 ?? 0,
        'A10': widget.returnData.a10 ?? 0,
        'A5': widget.returnData.a5 ?? 0,
        'A2': widget.returnData.a2 ?? 0,
        'A1': widget.returnData.a1 ?? 0,
      };

  String get _displayBankName => _resolvedBankName.isNotEmpty
      ? _resolvedBankName
      : widget.returnData.codeBank;

  @override
  void initState() {
    super.initState();
    _loadBankName();
  }

  Future<void> _loadBankName() async {
    try {
      final banks = await _konsolApiService.getBankList();
      for (final bank in banks) {
        if (bank.code == widget.returnData.codeBank) {
          if (!mounted) return;
          setState(() => _resolvedBankName = _cleanBankName(bank.name));
          return;
        }
      }
    } catch (_) {
      // Barcode tetap membawa code bank jika nama bank gagal di-resolve.
    }
  }

  String _cleanBankName(String value) {
    final name = value.trim();
    final match = RegExp(r'\(([^)]+)\)').firstMatch(name);
    if (match != null) return match.group(1) ?? name;
    return name;
  }

  int _totalLembar(Map<String, int> denoms) =>
      denoms.values.fold<int>(0, (sum, value) => sum + value);

  int _totalNominal(Map<String, int> denoms) {
    return denoms.entries.fold<int>(
      0,
      (sum, entry) => sum + entry.value * (_denomValues[entry.key] ?? 0),
    );
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.trim().isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(rawDate.trim()));
    } catch (_) {
      return rawDate;
    }
  }

  bool _isApprovedKonsolRow(KonsolData item) {
    final isClosing = (item.isClosing ?? '').trim().toUpperCase() == 'Y';
    final validate = (item.validate ?? '').trim().toUpperCase() == 'Y';
    final tlCode = (item.tlCode ?? '').trim();
    final timeFinish = (item.timeFinish ?? '').trim();
    return isClosing ||
        (validate &&
            tlCode.isNotEmpty &&
            tlCode.toLowerCase() != 'null' &&
            timeFinish.isNotEmpty &&
            timeFinish.toLowerCase() != 'null');
  }

  Future<void> _checkApprovalStatus() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final konsolList = await _konsolApiService.getKonsolAndroidList(
        branchCode: widget.returnData.branchCode,
      );
      final approvalId = widget.returnData.id.trim();
      final approved = approvalId.isNotEmpty &&
          konsolList.any(
            (item) =>
                (item.consoleIdTool ?? '').trim() == approvalId &&
                _isApprovedKonsolRow(item),
          );

      if (!mounted) return;
      if (approved) {
        await CustomModals.showSuccessModal(
          context: context,
          message: 'Approval TL berhasil, data return sudah diperbarui',
        );
        if (mounted) Navigator.of(context).pop(true);
      } else {
        await CustomModals.showConfirmationModal(
          context: context,
          message:
              'Masih menunggu approval TL. Jika TL sudah approve, coba refresh lagi.',
          confirmText: 'OK',
          cancelText: 'Tutup',
        );
      }
    } catch (e) {
      if (!mounted) return;
      await CustomModals.showConfirmationModal(
        context: context,
        message:
            'Gagal cek status approval TL. Silakan coba refresh lagi.',
        confirmText: 'OK',
        cancelText: 'Tutup',
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Map<String, dynamic> _qrExtraData() {
    final originalDenoms = _originalDenoms;
    return {
      'approvalType': 'KONSOL_RETURN_EDIT',
      'codeBank': widget.returnData.codeBank,
      'bankName': _displayBankName,
      'atmCode': widget.returnData.atmCode,
      'jnsMesin': widget.returnData.jnsMesin,
      'lokasi': widget.returnData.name,
      'branchCode': widget.returnData.branchCode,
      'dateStart': _approvalDateStart,
      'DateStart': _approvalDateStart,
      'dateStartReturn': _approvalDateStart,
      'DateStartReturn': _approvalDateStart,
      'dateReturn': widget.returnData.dateSTReturn,
      'cashierCode': widget.cashierCode,
      'tableCode': widget.tableCode,
      'originalDenoms': originalDenoms,
      'editedDenoms': widget.editedDenoms,
      'totalLembarAwal': _totalLembar(originalDenoms),
      'totalNominalAwal': _totalNominal(originalDenoms),
      'totalLembarEdit': _totalLembar(widget.editedDenoms),
      'totalNominalEdit': _totalNominal(widget.editedDenoms),
    };
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.red),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'Approval Edit Return TLSPV',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE0E0E0)),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'assets/images/bg-deviceinfo.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDataCard(currency),
                const SizedBox(height: 16),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        QRCodeGeneratorWidget(
                          key: ValueKey(
                            'return-edit-qr-${widget.returnData.id}-$_displayBankName',
                          ),
                          action: 'KONSOL_RETURN_EDIT',
                          source: 'KonsolReturnEdit',
                          idTool: widget.returnData.id,
                          totalLembar: _totalLembar(widget.editedDenoms),
                          totalNominal: _totalNominal(widget.editedDenoms),
                          dateStart: _approvalDateStart,
                          extraData: _qrExtraData(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : _checkApprovalStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    icon: _checking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: const Text(
                      'Refresh Status',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(NumberFormat currency) {
    final originalDenoms = _originalDenoms;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: Border.all(color: const Color(0xFF555555), width: 1.4),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 26, color: Colors.black),
              const SizedBox(width: 8),
              const Text(
                'EDIT RETURN',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  widget.returnData.atmCode,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildLabelValue('Bank', _displayBankName),
          _buildLabelValue(
            'Tanggal Return',
            _formatDate(widget.returnData.dateSTReturn),
          ),
          _buildLabelValue('Lokasi', widget.returnData.name),
          const SizedBox(height: 18),
          _buildDenomComparison(originalDenoms, widget.editedDenoms),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTotalBox(
                  'Total Awal',
                  _totalLembar(originalDenoms),
                  currency.format(_totalNominal(originalDenoms)),
                  const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTotalBox(
                  'Total Edit',
                  _totalLembar(widget.editedDenoms),
                  currency.format(_totalNominal(widget.editedDenoms)),
                  const Color(0xFFFFA95C),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabelValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDenomComparison(
    Map<String, int> originalDenoms,
    Map<String, int> editedDenoms,
  ) {
    const order = ['A100', 'A75', 'A50', 'A20', 'A10', 'A5', 'A2', 'A1'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildDenomColumn(
            'Denom Awal (Lembar)',
            const Color(0xFF22C55E),
            order,
            originalDenoms,
          ),
        ),
        Container(
          width: 1,
          height: 142,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: const Color(0xFFD4D4D4),
        ),
        Expanded(
          child: _buildDenomColumn(
            'Denom Edit (Lembar)',
            const Color(0xFFFFA95C),
            order,
            editedDenoms,
          ),
        ),
      ],
    );
  }

  Widget _buildDenomColumn(
    String title,
    Color color,
    List<String> order,
    Map<String, int> values,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          runSpacing: 6,
          spacing: 10,
          children: order.map((denom) {
            return SizedBox(
              width: 72,
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      denom,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.white,
                      ),
                      child: Text(
                        '${values[denom] ?? 0}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTotalBox(
    String title,
    int totalLembar,
    String totalNominal,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text('Total Lembar : $totalLembar'),
          Text('Total Nominal : $totalNominal'),
        ],
      ),
    );
  }
}

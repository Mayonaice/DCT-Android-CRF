import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/closing_android_request.dart';
import '../services/konsol_api_service.dart';
import '../widgets/custom_modals.dart';
import '../widgets/qr_code_generator_widget.dart';

class KonsolClosingApprovalSummaryPage extends StatefulWidget {
  final String codeBank;
  final String bankName;
  final String jnsMesin;
  final String dateReplenish;
  final List<ClosingPreviewItem> previewItems;

  const KonsolClosingApprovalSummaryPage({
    super.key,
    required this.codeBank,
    required this.bankName,
    required this.jnsMesin,
    required this.dateReplenish,
    required this.previewItems,
  });

  @override
  State<KonsolClosingApprovalSummaryPage> createState() =>
      _KonsolClosingApprovalSummaryPageState();
}

class _KonsolClosingApprovalSummaryPageState
    extends State<KonsolClosingApprovalSummaryPage> {
  final KonsolApiService _apiService = KonsolApiService();
  late final String _approvalDateStart = DateTime.now().toIso8601String();
  bool _checking = false;

  int get _totalLembar => widget.previewItems.fold<int>(
        0,
        (sum, item) =>
            sum +
            item.a1Edit +
            item.a2Edit +
            item.a5Edit +
            item.a10Edit +
            item.a20Edit +
            item.a50Edit +
            item.a75Edit +
            item.a100Edit,
      );

  int get _totalNominal => widget.previewItems.fold<int>(
        0,
        (sum, item) =>
            sum +
            item.a1Edit * 1000 +
            item.a2Edit * 2000 +
            item.a5Edit * 5000 +
            item.a10Edit * 10000 +
            item.a20Edit * 20000 +
            item.a50Edit * 50000 +
            item.a75Edit * 75000 +
            item.a100Edit * 100000,
      );

  String get _cleanBankName {
    final name = widget.bankName.trim();
    final match = RegExp(r'\(([^)]+)\)').firstMatch(name);
    if (match != null) return match.group(1) ?? name;
    return name.isEmpty ? widget.codeBank : name;
  }

  String get _displayAtmCode {
    final codes = widget.previewItems
        .map((item) => item.atmCode.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (codes.length == 1) return codes.first;
    return '${widget.codeBank}-${widget.jnsMesin}';
  }

  String get _displayLokasi {
    final locations = widget.previewItems
        .map((item) => item.name.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (locations.length == 1) return locations.first;
    return '${locations.length} lokasi';
  }

  String get _branchCode {
    for (final item in widget.previewItems) {
      if (item.branchCode.trim().isNotEmpty) return item.branchCode.trim();
    }
    return '';
  }

  String get _idTools => widget.previewItems.map((item) => item.id).join(',');

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
      final approvalIds = widget.previewItems
          .map((item) => item.id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      final konsolList = await _apiService.getKonsolAndroidList(
        branchCode: _branchCode.isEmpty ? null : _branchCode,
      );
      final approved = approvalIds.isNotEmpty &&
          approvalIds.every(
            (approvalId) => konsolList.any(
              (item) =>
                  (item.consoleIdTool ?? '').trim() == approvalId &&
                  _isApprovedKonsolRow(item),
            ),
          );

      if (!mounted) return;
      if (approved) {
        await CustomModals.showSuccessModal(
          context: context,
          message: 'Approval TL berhasil, data closing sudah diproses',
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
    return {
      'codeBank': widget.codeBank,
      'bankName': _cleanBankName,
      'jnsMesin': widget.jnsMesin,
      'dateReplenish': widget.dateReplenish,
      'atmCode': _displayAtmCode,
      'lokasi': _displayLokasi,
      'branchCode': _branchCode,
      'dateStart': _approvalDateStart,
      'DateStart': _approvalDateStart,
      'rowCount': widget.previewItems.length,
      'idTools': _idTools,
      'totalLembar': _totalLembar,
      'totalNominal': _totalNominal,
      'approvalType': 'KONSOL_CLOSING',
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
          'Approval Closing TLSPV',
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
                          action: 'KONSOL_CLOSING',
                          source: 'KonsolClosing',
                          idTool: _displayAtmCode,
                          totalLembar: _totalLembar,
                          totalNominal: _totalNominal,
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
                'DATA CLOSING',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  _displayAtmCode,
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
          _buildLabelValue('Bank', _cleanBankName),
          _buildLabelValue('Tgl Replenish', widget.dateReplenish),
          _buildLabelValue('Lokasi', _displayLokasi),
          _buildLabelValue('Jenis Mesin', widget.jnsMesin),
          const SizedBox(height: 10),
          _buildLabelValue('Total Lembar', _totalLembar.toString()),
          _buildLabelValue('Total Nominal', currency.format(_totalNominal)),
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
            width: 118,
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
}

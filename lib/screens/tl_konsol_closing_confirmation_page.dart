import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/konsol_api_service.dart';
import '../widgets/custom_modals.dart';
import '../widgets/face_recognition_widget.dart';

class TLKonsolClosingConfirmationPage extends StatefulWidget {
  final Map<String, dynamic> payload;

  const TLKonsolClosingConfirmationPage({
    super.key,
    required this.payload,
  });

  @override
  State<TLKonsolClosingConfirmationPage> createState() =>
      _TLKonsolClosingConfirmationPageState();
}

class _TLKonsolClosingConfirmationPageState
    extends State<TLKonsolClosingConfirmationPage> {
  final AuthService _auth = AuthService();
  final KonsolApiService _api = KonsolApiService();
  bool _submitting = false;

  String _value(String key) => widget.payload[key]?.toString().trim() ?? '';

  String get _codeBank => _value('codeBank');
  String get _bankName => _cleanBankName(_value('bankName'));
  String get _jnsMesin => _value('jnsMesin');
  String get _dateReplenish => _value('dateReplenish');
  String get _atmCode =>
      _value('atmCode').isNotEmpty ? _value('atmCode') : _codeBank;
  String get _lokasi => _value('lokasi');
  int get _totalLembar => _intValue('totalLembar');
  int get _totalNominal => _intValue('totalNominal');

  int _intValue(String key) {
    final raw = widget.payload[key];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '0') ?? 0;
  }

  String _cleanBankName(String value) {
    final name = value.trim();
    final match = RegExp(r'\(([^)]+)\)').firstMatch(name);
    if (match != null) return match.group(1) ?? name;
    return name.isEmpty ? _codeBank : name;
  }

  Future<void> _approve() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final response = await _api.approveClosingData(
        codeBank: _codeBank,
        jnsMesin: _jnsMesin,
        dateReplenish: _dateReplenish,
        cashierCode: _value('cashierCode'),
        tableCode: _value('tableCode'),
      );

      if (!mounted) return;
      if (response.success) {
        await CustomModals.showSuccessModal(
          context: context,
          message: response.message.isEmpty
              ? 'Approve closing berhasil'
              : response.message,
        );
        if (mounted) Navigator.of(context).pop(true);
      } else {
        await CustomModals.showFailedModal(
          context: context,
          message: response.message.isEmpty
              ? 'Approve closing gagal'
              : response.message,
        );
      }
    } catch (e) {
      if (!mounted) return;
      await CustomModals.showFailedModal(context: context, message: '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _verifyFaceAndApprove() async {
    if (_submitting) return;
    final user = await _auth.getUserData();
    final personId = user != null
        ? (user['userId']?.toString() ??
            user['userID']?.toString() ??
            user['nik']?.toString() ??
            '')
        : '';
    if (personId.isEmpty) {
      await CustomModals.showFailedModal(
        context: context,
        message: 'Validasi wajah TL gagal, wajah tidak dikenali',
      );
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FaceRecognitionWidget(
          personId: personId,
          onRecognitionComplete: (success, message) {
            Navigator.of(context).pop(success);
          },
        ),
      ),
    );
    if (result == true) {
      await _approve();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Konfirmasi Approve TLSPV',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w800,
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
                opacity: 0.10,
                child: Image.asset(
                  'assets/images/bg-deviceinfo.png',
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: _buildDataCard(),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _verifyFaceAndApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3EF763),
                        foregroundColor: Colors.black,
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_submitting)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            const SizedBox.shrink(),
                          if (_submitting) const SizedBox(width: 8),
                          const Text(
                            'Approve Data',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, size: 20),
                        ],
                      ),
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

  Widget _buildDataCard() {
    final currency = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
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
                  _atmCode,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildLabelValue('Bank', _bankName),
          _buildLabelValue('Tgl Replenish', _dateReplenish),
          _buildLabelValue('Lokasi', _lokasi),
          _buildLabelValue('Jenis Mesin', _jnsMesin),
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

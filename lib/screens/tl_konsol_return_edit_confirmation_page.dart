import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/konsol_api_service.dart';
import '../services/return_api_service.dart';
import '../widgets/custom_modals.dart';
import '../widgets/face_recognition_widget.dart';

class TLKonsolReturnEditConfirmationPage extends StatefulWidget {
  final Map<String, dynamic> payload;

  const TLKonsolReturnEditConfirmationPage({
    super.key,
    required this.payload,
  });

  @override
  State<TLKonsolReturnEditConfirmationPage> createState() =>
      _TLKonsolReturnEditConfirmationPageState();
}

class _TLKonsolReturnEditConfirmationPageState
    extends State<TLKonsolReturnEditConfirmationPage> {
  final AuthService _auth = AuthService();
  final ReturnApiService _returnApi = ReturnApiService();
  final KonsolApiService _konsolApi = KonsolApiService();

  bool _submitting = false;
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

  @override
  void initState() {
    super.initState();
    _loadBankName();
  }

  String _value(String key) => widget.payload[key]?.toString().trim() ?? '';

  String get _idTool => _value('idTool');
  String get _codeBank => _value('codeBank');
  String get _atmCode => _value('atmCode');
  String get _lokasi => _value('lokasi');
  String get _dateReturn => _formatDate(_value('dateReturn'));
  String get _cashierCode => _value('cashierCode');
  String get _tableCode => _value('tableCode');
  String get _payloadBankName => _cleanBankName(_value('bankName'));
  String get _displayBankName {
    if (_payloadBankName.isNotEmpty && _payloadBankName != _codeBank) {
      return _payloadBankName;
    }
    return _resolvedBankName;
  }

  Map<String, int> get _originalDenoms => _readDenomMap('originalDenoms');
  Map<String, int> get _editedDenoms => _readDenomMap('editedDenoms');

  Future<void> _loadBankName() async {
    if (_payloadBankName.isNotEmpty && _payloadBankName != _codeBank) return;
    try {
      final banks = await _konsolApi.getBankList();
      for (final bank in banks) {
        if (bank.code == _codeBank) {
          if (!mounted) return;
          setState(() {
            _resolvedBankName = _cleanBankName(bank.name);
          });
          return;
        }
      }
    } catch (_) {
      // Bank code is still enough for approval if lookup fails.
    }
  }

  String _cleanBankName(String value) {
    final name = value.trim();
    final match = RegExp(r'\(([^)]+)\)').firstMatch(name);
    if (match != null) return match.group(1) ?? name;
    return name;
  }

  String _formatDate(String rawDate) {
    if (rawDate.isEmpty || rawDate.toLowerCase() == 'null') return '-';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(rawDate));
    } catch (_) {
      return rawDate;
    }
  }

  Map<String, int> _readDenomMap(String key) {
    final raw = widget.payload[key];
    final result = <String, int>{};
    for (final denom in _denomValues.keys) {
      result[denom] = 0;
    }

    if (raw is Map) {
      for (final entry in raw.entries) {
        final denom = entry.key.toString().toUpperCase();
        if (!result.containsKey(denom)) continue;
        final value = entry.value;
        result[denom] =
            value is int ? value : int.tryParse(value?.toString() ?? '0') ?? 0;
      }
    }
    return result;
  }

  int _totalLembar(Map<String, int> denoms) =>
      denoms.values.fold<int>(0, (sum, value) => sum + value);

  int _totalNominal(Map<String, int> denoms) {
    return denoms.entries.fold<int>(
      0,
      (sum, entry) => sum + entry.value * (_denomValues[entry.key] ?? 0),
    );
  }

  Future<void> _approve() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final edited = _editedDenoms;
      final response = await _returnApi.approveKonsolReturnEdit(
        idTool: _idTool,
        a1: edited['A1'] ?? 0,
        a2: edited['A2'] ?? 0,
        a5: edited['A5'] ?? 0,
        a10: edited['A10'] ?? 0,
        a20: edited['A20'] ?? 0,
        a50: edited['A50'] ?? 0,
        a75: edited['A75'] ?? 0,
        a100: edited['A100'] ?? 0,
        user: _cashierCode,
        tableCode: _tableCode,
      );

      if (!mounted) return;
      if (response['success'] == true) {
        await CustomModals.showSuccessModal(
          context: context,
          message:
              response['message']?.toString() ?? 'Approve edit return berhasil',
        );
        if (mounted) Navigator.of(context).pop(true);
      } else {
        await CustomModals.showFailedModal(
          context: context,
          message:
              response['message']?.toString() ?? 'Approve edit return gagal',
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
                            ),
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
    final original = _originalDenoms;
    final edited = _editedDenoms;
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
              Container(width: 3, height: 28, color: Colors.black),
              const SizedBox(width: 8),
              const Text(
                'EDIT RETURN',
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
          _buildLabelValue(
            'Bank',
            _displayBankName.isNotEmpty ? _displayBankName : _codeBank,
          ),
          _buildLabelValue('Tanggal Return', _dateReturn),
          _buildLabelValue('Lokasi', _lokasi),
          const SizedBox(height: 18),
          _buildDenomComparison(original, edited),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildTotalBox(
                  'Total Awal',
                  _totalLembar(original),
                  currency.format(_totalNominal(original)),
                  const Color(0xFF22C55E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTotalBox(
                  'Total Edit',
                  _totalLembar(edited),
                  currency.format(_totalNominal(edited)),
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
      padding: const EdgeInsets.only(bottom: 10),
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
    Map<String, int> original,
    Map<String, int> edited,
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
            original,
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
            edited,
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

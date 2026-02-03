import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/prepare_model.dart';
import '../models/return_model.dart';
import '../widgets/custom_modals.dart';
import '../widgets/face_recognition_widget.dart';

class TLReturnConfirmationPage extends StatefulWidget {
  final String idTool;
  final String cashierCode;
  final String tableCode;
  final int? totalNominal;
  final int? totalLembar;
  final int? jumlahKasetCatridge;
  const TLReturnConfirmationPage({
    Key? key,
    required this.idTool,
    required this.cashierCode,
    required this.tableCode,
    this.totalNominal,
    this.totalLembar,
    this.jumlahKasetCatridge,
  }) : super(key: key);
  @override
  State<TLReturnConfirmationPage> createState() => _TLReturnConfirmationPageState();
}

class _TLReturnConfirmationPageState extends State<TLReturnConfirmationPage> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  PrepareConfirmationData? _data;
  ReturnHeaderResponse? _return;
  int? _jumlahKaset;
  num _total = 0;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _denomValue(String codeRaw) {
    final code = codeRaw.trim().toUpperCase();
    if (code.isEmpty) return 0;
    switch (code) {
      case 'A1':
      case '1K':
        return 1000;
      case 'A2':
      case '2K':
        return 2000;
      case 'A5':
      case '5K':
        return 5000;
      case 'A10':
      case '10K':
        return 10000;
      case 'A20':
      case '20K':
        return 20000;
      case 'A50':
      case '50K':
        return 50000;
      case 'A75':
      case '75K':
        return 75000;
      case 'A100':
      case '100K':
        return 100000;
    }
    final numeric = int.tryParse(code.replaceAll(RegExp(r'[^0-9]'), ''));
    if (numeric != null && numeric > 0) return numeric;
    return 0;
  }

  num _calculateReturnTotal(ReturnHeaderResponse response) {
    num total = 0;
    for (final item in response.data) {
      final qty = int.tryParse(item.qty?.toString() ?? '0') ?? 0;
      final denomValue = _denomValue(item.denomCode);
      if (denomValue > 0) {
        total += qty * denomValue;
      } else {
        total += qty;
      }
    }
    return total;
  }

  Future<String> _resolveBranchCode() async {
    final userData = await _auth.getUserData();
    final value = (userData?['groupId'] ??
            userData?['GroupId'] ??
            userData?['GroupID'] ??
            userData?['groupid'] ??
            userData?['groupID'] ??
            userData?['branchCode'] ??
            userData?['BranchCode'])
        ?.toString()
        .trim();
    if (value != null && value.isNotEmpty && value != '0' && RegExp(r'^\d+$').hasMatch(value)) {
      return value;
    }
    return '1';
  }

  Future<void> _load() async {
    try {
      int? jumlahKaset;
      ReturnHeaderResponse? rtn;
      try {
        final branchCode = await _resolveBranchCode();
        rtn = await _api.getReturnHeaderAndCatridge(widget.idTool, branchCode: branchCode);
        if (rtn.success) {
          jumlahKaset = rtn.data.where((e) => (e.typeCatridgeTrx?.toString().toUpperCase() ?? 'C') == 'C').length;
        }
      } catch (_) {}
      PrepareConfirmationData? data;
      try {
        final idToolInt = int.tryParse(widget.idTool) ?? 0;
        final resp = await _api.getPrepareConfirmation(idToolInt);
        data = resp.data;
      } catch (_) {}
      setState(() {
        _data = data;
        _return = rtn;
        _jumlahKaset = (widget.jumlahKasetCatridge != null && widget.jumlahKasetCatridge! > 0) ? widget.jumlahKasetCatridge : jumlahKaset;
        _total = (widget.totalNominal != null && widget.totalNominal! > 0)
            ? widget.totalNominal!
            : (rtn != null && rtn.success)
                ? _calculateReturnTotal(rtn)
                : (data?.total ?? 0);
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _approve() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
    });
    try {
      final user = await _auth.getUserData();
      final spv = user != null ? (user['nik']?.toString() ?? user['userId']?.toString() ?? user['userID']?.toString() ?? '') : '';
      final params = {
        "idTool": widget.idTool,
        "CashierReturnCode": widget.cashierCode,
        "TableReturnCode": widget.tableCode,
        "DateStartReturn": DateTime.now().toIso8601String(),
        "WarehouseCode": user?['warehouseCode']?.toString() ?? 'Cideng',
        "UserATMReturn": spv,
        "SPVBARusak": spv,
        "IsManual": "N"
      };
      final upd = await _api.updatePlanningRTN(params);
      if (upd.success) {
        final idToolInt = int.tryParse(widget.idTool) ?? 0;
        final exec = await _api.executeReturnAtmCatridgeByIdTool(
          idTool: idToolInt,
          userApproveReturn: spv,
        );
        if (exec.success) {
          await CustomModals.showSuccessModal(context: context, message: 'Approve Return berhasil');
          if (mounted) Navigator.of(context).pop();
        } else {
          await CustomModals.showFailedModal(context: context, message: exec.message);
        }
      } else {
        await CustomModals.showFailedModal(context: context, message: upd.message);
      }
    } catch (e) {
      await CustomModals.showFailedModal(context: context, message: e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<void> _verifyFaceAndApprove() async {
    if (_submitting) return;
    final user = await _auth.getUserData();
    final personId = user != null ? (user['userId']?.toString() ?? user['userID']?.toString() ?? user['nik']?.toString() ?? '') : '';
    if (personId.isEmpty) {
      await CustomModals.showFailedModal(context: context, message: 'Validasi wajah TL gagal, wajah tidak dikenali');
      return;
    }
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FaceRecognitionWidget(
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
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.red), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Konfirmasi Return', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700)),
        centerTitle: false,
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: Color(0xFFE0E0E0))),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loading
                    ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Text('ID CRF : ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(widget.idTool, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                          const SizedBox(height: 8),
                          if (_return?.header != null || _data != null) ...[
                            Row(children: [
                              const Text('ATM : ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(_return?.header?.atmCode ?? _data?.wsid ?? '')),
                            ]),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Text('Bank : ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(_return?.header?.namaBank ?? _return?.header?.codeBank ?? _data?.bank ?? '')),
                            ]),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Text('Lokasi : ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(_return?.header?.lokasi ?? _data?.lokasi ?? '')),
                            ]),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Text('ATM Type : ', style: TextStyle(fontWeight: FontWeight.bold)),
                              Expanded(child: Text(_return?.header?.idTypeAtm ?? _return?.header?.typeATM ?? _data?.atmType ?? '')),
                            ]),
                          ],
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Row(children: const [
                            Icon(Icons.inventory_2_outlined, size: 18, color: Colors.green),
                            SizedBox(width: 6),
                            Text('Detail', style: TextStyle(fontWeight: FontWeight.w600)),
                          ]),
                          const SizedBox(height: 8),
                          if (_data == null && (_return == null || _return?.header == null))
                            const Text('Data tidak tersedia')
                          else
                            Column(
                              children: [
                                Row(children: [
                                  const Expanded(child: Text('Jumlah Kaset :', style: TextStyle(fontWeight: FontWeight.w500))),
                                  Text('${_jumlahKaset ?? 0}'),
                                ]),
                                const SizedBox(height: 6),
                                Row(children: [
                                  const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w500))),
                                  Text(_formatRupiah(_total)),
                                ]),
                              ],
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.35,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _verifyFaceAndApprove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF29CC29),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Approve Data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRupiah(num value) {
  final s = value.toString();
  try {
    final n = value.toInt();
    final str = n.toString();
    final b = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      b.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) b.write('.');
    }
    final rev = b.toString().split('').reversed.join();
    return 'Rp  $rev';
  } catch (_) {
    return 'Rp  $s';
  }
}

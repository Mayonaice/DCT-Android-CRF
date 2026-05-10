import 'package:flutter/material.dart'
    show
        Alignment,
        AlwaysStoppedAnimation,
        Border,
        BorderRadius,
        BoxDecoration,
        BuildContext,
        Card,
        Center,
        CircularProgressIndicator,
        Colors,
        Column,
        Container,
        Divider,
        EdgeInsets,
        ElevatedButton,
        ElevatedButtonIcon,
        Expanded,
        Icon,
        Icons,
        MainAxisAlignment,
        MaterialPageRoute,
        Navigator,
        Padding,
        Row,
        RoundedRectangleBorder,
        Scaffold,
        ShapeDecoration,
        SizedBox,
        StatelessWidget,
        State,
        StatefulWidget,
        Text,
        TextAlign,
        TextStyle,
        Widget;
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/prepare_model.dart';
import '../widgets/custom_modals.dart';
import '../widgets/face_recognition_widget.dart';

class TLPrepareConfirmationPage extends StatefulWidget {
  final String idTool;
  final String cashierCode;
  final String tableCode;
  final int? totalNominal;
  final String? wsidFromQr;
  final String? bankFromQr;
  final String? lokasiFromQr;
  final String? atmTypeFromQr;
  final int? jumlahKasetFromQr;
  final String? dateStartFromQr;
  const TLPrepareConfirmationPage({
    Key? key,
    required this.idTool,
    required this.cashierCode,
    required this.tableCode,
    this.totalNominal,
    this.wsidFromQr,
    this.bankFromQr,
    this.lokasiFromQr,
    this.atmTypeFromQr,
    this.jumlahKasetFromQr,
    this.dateStartFromQr,
  }) : super(key: key);
  @override
  State<TLPrepareConfirmationPage> createState() => _TLPrepareConfirmationPageState();
}

class _TLPrepareConfirmationPageState extends State<TLPrepareConfirmationPage> {
  final ApiService _api = ApiService();
  final AuthService _auth = AuthService();
  PrepareConfirmationData? _data;
  int? _jumlahKaset;
  String? _dateStartFromData;
  bool _loading = true;
  bool _submitting = false;

  String _pickNonEmpty(String? primary, String? fallback) {
    final p = primary?.trim() ?? '';
    if (p.isNotEmpty) return p;
    return fallback?.trim() ?? '';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final idTool = int.tryParse(widget.idTool) ?? 0;
      final resp = await _api.getPrepareConfirmation(idTool);
      int? jumlahKaset;
      try {
        final prepareResp = await _api.getATMPrepareReplenish(idTool);
        if (prepareResp.success && prepareResp.data != null) {
          jumlahKaset = prepareResp.data!.jmlKaset;
          _dateStartFromData = prepareResp.data!.dateStart?.toIso8601String();
        }
      } catch (_) {}
      setState(() {
        _data = resp.data;
        _jumlahKaset = widget.jumlahKasetFromQr ?? jumlahKaset;
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
      final resolvedDateStart = _pickNonEmpty(widget.dateStartFromQr, _dateStartFromData);
      if (resolvedDateStart.isEmpty) {
        await CustomModals.showFailedModal(
          context: context,
          message: 'DateStart dari QR tidak ditemukan. Silakan scan ulang QR Prepare.',
        );
        return;
      }
      final upd = await _api.updatePlanning(
        idTool: int.tryParse(widget.idTool) ?? 0,
        cashierCode: widget.cashierCode,
        spvTLCode: spv,
        tableCode: widget.tableCode,
        dateStart: resolvedDateStart,
      );
      if (upd.success) {
        final exec = await _api.insertAtmCatridgeByIdTool(idTool: int.tryParse(widget.idTool) ?? 0);
        if (exec.success) {
          await CustomModals.showSuccessModal(context: context, message: 'Approve berhasil');
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
        title: const Text('Konfirmasi Prepare', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w700)),
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
                          const SizedBox(height: 12),
                          Row(children: [
                            const Text('WSID  : '),
                            Expanded(child: Text(_pickNonEmpty(widget.wsidFromQr, _data?.wsid))),
                            const SizedBox(width: 12),
                            const Text('Bank  : '),
                            Expanded(child: Text(_pickNonEmpty(widget.bankFromQr, _data?.bank))),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            const Text('Lokasi : '),
                            Expanded(child: Text(_pickNonEmpty(widget.lokasiFromQr, _data?.lokasi))),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            const Text('ATM Type : '),
                            Expanded(child: Text(_pickNonEmpty(widget.atmTypeFromQr, _data?.atmType))),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            const Text('Jumlah Kaset : '),
                            Expanded(child: Text('${_jumlahKaset ?? 0}')),
                          ]),
                          const SizedBox(height: 12),
                          Row(children: [
                            const Text('Total : '),
                            Expanded(child: Text(_formatRupiah(widget.totalNominal ?? (_data?.total ?? 0)))),
                          ]),
                        ],
                      ),
              ),
            ),
            const Spacer(),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _submitting ? 'Processing...' : 'Approve Data',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
}

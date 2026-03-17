// ============================================================
// NTG App - Phiếu Phép / Công Tác Mobile
// File: lib/screens/hanhchinh/phieu_nghi_screen.dart
//
// Tính năng:
// 1. Tạo đơn xin nghỉ phép / công tác nhanh
// 2. Chọn loại, ngày, lý do
// 3. Upload file đính kèm (giấy tờ)
// 4. Xem trạng thái duyệt
// ============================================================

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ─── MODELS ──────────────────────────────────────────────────

enum LoaiPhieu { nghiPhep, congTac, nghiOm, nghiKhac }

extension LoaiPhieuExt on LoaiPhieu {
  String get label {
    switch (this) {
      case LoaiPhieu.nghiPhep: return 'Nghỉ phép năm';
      case LoaiPhieu.congTac:  return 'Công tác';
      case LoaiPhieu.nghiOm:   return 'Nghỉ ốm';
      case LoaiPhieu.nghiKhac: return 'Nghỉ khác';
    }
  }
  String get icon {
    switch (this) {
      case LoaiPhieu.nghiPhep: return '✈️';
      case LoaiPhieu.congTac:  return '💼';
      case LoaiPhieu.nghiOm:   return '🏥';
      case LoaiPhieu.nghiKhac: return '📋';
    }
  }
  String get apiCode {
    switch (this) {
      case LoaiPhieu.nghiPhep: return 'nghi_phep';
      case LoaiPhieu.congTac:  return 'cong_tac';
      case LoaiPhieu.nghiOm:   return 'nghi_om';
      case LoaiPhieu.nghiKhac: return 'nghi_khac';
    }
  }
  Color get color {
    switch (this) {
      case LoaiPhieu.nghiPhep: return const Color(0xFF0891B2);
      case LoaiPhieu.congTac:  return const Color(0xFFF59E0B);
      case LoaiPhieu.nghiOm:   return const Color(0xFFDC2626);
      case LoaiPhieu.nghiKhac: return const Color(0xFF7C3AED);
    }
  }
}

class PhieuItem {
  final int id;
  final String loai;
  final DateTime tuNgay;
  final DateTime denNgay;
  final String lyDo;
  final String trangThai;
  final String nguoiDuyet;
  final String ghiChuDuyet;

  const PhieuItem({
    required this.id,
    required this.loai,
    required this.tuNgay,
    required this.denNgay,
    required this.lyDo,
    required this.trangThai,
    this.nguoiDuyet = '',
    this.ghiChuDuyet = '',
  });

  factory PhieuItem.fromJson(Map<String, dynamic> j) => PhieuItem(
    id: j['id'] ?? 0,
    loai: j['loai'] ?? '',
    tuNgay: DateTime.tryParse(j['tu_ngay'] ?? '') ?? DateTime.now(),
    denNgay: DateTime.tryParse(j['den_ngay'] ?? '') ?? DateTime.now(),
    lyDo: j['ly_do'] ?? '',
    trangThai: j['trang_thai'] ?? 'cho_duyet',
    nguoiDuyet: j['nguoi_duyet'] ?? '',
    ghiChuDuyet: j['ghi_chu_duyet'] ?? '',
  );

  int get soNgay => denNgay.difference(tuNgay).inDays + 1;
}

// ─── MAIN SCREEN ─────────────────────────────────────────────

class PhieuNghiScreen extends StatefulWidget {
  final String token;
  final int userId;

  const PhieuNghiScreen({Key? key, required this.token, required this.userId}) : super(key: key);

  @override
  State<PhieuNghiScreen> createState() => _PhieuNghiScreenState();
}

class _PhieuNghiScreenState extends State<PhieuNghiScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<PhieuItem> _phieuList = [];
  bool _loading = true;
  int _soPhepConLai = 0;

  final _baseUrl = 'https://erp.namthinh.com.vn/api';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/phieu_nghi_list.php?idnhanvien=${widget.userId}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == 1) {
          setState(() {
            _phieuList = (data['list'] as List? ?? [])
                .map((e) => PhieuItem.fromJson(e))
                .toList();
            _soPhepConLai = data['so_phep_con_lai'] ?? 12;
          });
        }
      }
    } catch (_) {
      // Demo data
      setState(() {
        _soPhepConLai = 10;
        _phieuList = [
          PhieuItem(
            id: 1, loai: 'nghi_phep',
            tuNgay: DateTime.now().add(const Duration(days: 5)),
            denNgay: DateTime.now().add(const Duration(days: 7)),
            lyDo: 'Đi du lịch gia đình',
            trangThai: 'cho_duyet',
          ),
          PhieuItem(
            id: 2, loai: 'cong_tac',
            tuNgay: DateTime.now().subtract(const Duration(days: 3)),
            denNgay: DateTime.now().subtract(const Duration(days: 1)),
            lyDo: 'Khảo sát dự án HCM-01',
            trangThai: 'da_duyet',
            nguoiDuyet: 'Nguyễn Văn A',
          ),
        ];
      });
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('Phiếu Phép & Công Tác',
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFF59E0B)),
            onPressed: () => _showCreateSheet(),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: const Color(0xFFF59E0B),
          labelColor: const Color(0xFFF59E0B),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Của tôi'),
            Tab(text: 'Cần duyệt'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildMyPhieu(),
          _buildChuaDuyet(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(),
        backgroundColor: const Color(0xFF0891B2),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tạo phiếu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildMyPhieu() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF0891B2),
      child: CustomScrollView(
        slivers: [
          // Số ngày phép còn lại
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildPhepSummary(),
            ),
          ),

          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Color(0xFF0891B2))),
            )
          else if (_phieuList.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('Chưa có phiếu nào', style: TextStyle(color: Colors.white54)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _buildPhieuCard(_phieuList[i]),
                childCount: _phieuList.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildPhepSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0891B2), Color(0xFF0E7490)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ngày phép còn lại', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_soPhepConLai',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6, left: 4),
                      child: Text('ngày', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              _MiniStat('Chờ duyệt', _phieuList.where((e) => e.trangThai == 'cho_duyet').length.toString()),
              const SizedBox(height: 8),
              _MiniStat('Đã duyệt', _phieuList.where((e) => e.trangThai == 'da_duyet').length.toString(), approved: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhieuCard(PhieuItem phieu) {
    final loai = LoaiPhieu.values.firstWhere(
      (e) => e.apiCode == phieu.loai,
      orElse: () => LoaiPhieu.nghiKhac,
    );
    final fmt = DateFormat('dd/MM');
    final statusInfo = _statusInfo(phieu.trangThai);

    return GestureDetector(
      onTap: () => _showPhieuDetail(phieu),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            // Loại icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: loai.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(loai.icon, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(loai.label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(
                    '${fmt.format(phieu.tuNgay)} - ${fmt.format(phieu.denNgay)} · ${phieu.soNgay} ngày',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    phieu.lyDo,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusInfo.$1.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusInfo.$2,
                style: TextStyle(
                  color: statusInfo.$1,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChuaDuyet() {
    // TODO: List phiếu cần duyệt (cho manager)
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt, color: Color(0xFF22C55E), size: 48),
          SizedBox(height: 12),
          Text('Không có phiếu cần duyệt', style: TextStyle(color: Colors.white60, fontSize: 14)),
        ],
      ),
    );
  }

  // ─── CREATE SHEET ─────────────────────────────────────────

  void _showCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePhieuSheet(
        token: widget.token,
        userId: widget.userId,
        onCreated: () {
          Navigator.pop(context);
          _loadData();
        },
      ),
    );
  }

  void _showPhieuDetail(PhieuItem phieu) {
    final loai = LoaiPhieu.values.firstWhere(
      (e) => e.apiCode == phieu.loai,
      orElse: () => LoaiPhieu.nghiKhac,
    );
    final statusInfo = _statusInfo(phieu.trangThai);
    final fmt = DateFormat('dd/MM/yyyy');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(loai.icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loai.label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusInfo.$1.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(statusInfo.$2, style: TextStyle(color: statusInfo.$1, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DetailRow('Từ ngày', fmt.format(phieu.tuNgay)),
            _DetailRow('Đến ngày', fmt.format(phieu.denNgay)),
            _DetailRow('Số ngày', '${phieu.soNgay} ngày'),
            _DetailRow('Lý do', phieu.lyDo),
            if (phieu.nguoiDuyet.isNotEmpty)
              _DetailRow('Người duyệt', phieu.nguoiDuyet),
            if (phieu.ghiChuDuyet.isNotEmpty)
              _DetailRow('Ghi chú duyệt', phieu.ghiChuDuyet),
            const SizedBox(height: 16),
            if (phieu.trangThai == 'cho_duyet')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 18),
                  label: const Text('Hủy phiếu', style: TextStyle(color: Color(0xFFEF4444))),
                  onPressed: () {
                    // TODO: cancel phieu
                    Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  (Color, String) _statusInfo(String status) {
    switch (status) {
      case 'da_duyet':   return (const Color(0xFF22C55E), '✓ Đã duyệt');
      case 'tu_choi':    return (const Color(0xFFEF4444), '✗ Từ chối');
      case 'cho_duyet':  return (const Color(0xFFF59E0B), '⏳ Chờ duyệt');
      default:           return (Colors.white54, status);
    }
  }
}

// ─── CREATE PHIEU BOTTOM SHEET ───────────────────────────────

class _CreatePhieuSheet extends StatefulWidget {
  final String token;
  final int userId;
  final VoidCallback onCreated;

  const _CreatePhieuSheet({required this.token, required this.userId, required this.onCreated});

  @override
  State<_CreatePhieuSheet> createState() => _CreatePhieuSheetState();
}

class _CreatePhieuSheetState extends State<_CreatePhieuSheet> {
  LoaiPhieu _loai = LoaiPhieu.nghiPhep;
  DateTime _tuNgay = DateTime.now();
  DateTime _denNgay = DateTime.now();
  final _lyDoCtrl = TextEditingController();
  final _diaChiCtrl = TextEditingController(); // cho công tác
  File? _attachFile;
  bool _submitting = false;

  final _baseUrl = 'https://erp.namthinh.com.vn/api';
  final _fmt = DateFormat('dd/MM/yyyy');

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final soNgay = _denNgay.difference(_tuNgay).inDays + 1;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text('Tạo phiếu mới', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),

            // Loại phiếu
            const Text('Loại phiếu', style: TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: LoaiPhieu.values.map((l) => GestureDetector(
                onTap: () => setState(() => _loai = l),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _loai == l ? l.color.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _loai == l ? l.color : const Color(0xFF334155),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(l.label, style: TextStyle(
                        color: _loai == l ? l.color : Colors.white60,
                        fontSize: 13,
                        fontWeight: _loai == l ? FontWeight.w700 : FontWeight.w400,
                      )),
                    ],
                  ),
                ),
              )).toList(),
            ),

            const SizedBox(height: 20),

            // Ngày
            Row(
              children: [
                Expanded(
                  child: _DatePicker(
                    label: 'Từ ngày',
                    value: _tuNgay,
                    onChanged: (d) => setState(() {
                      _tuNgay = d;
                      if (_denNgay.isBefore(d)) _denNgay = d;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePicker(
                    label: 'Đến ngày',
                    value: _denNgay,
                    firstDate: _tuNgay,
                    onChanged: (d) => setState(() => _denNgay = d),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Center(
              child: Text(
                '$soNgay ngày',
                style: TextStyle(
                  color: _loai.color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Lý do
            _buildTextField(_lyDoCtrl, 'Lý do *', maxLines: 3),

            // Địa chỉ (chỉ khi công tác)
            if (_loai == LoaiPhieu.congTac) ...[
              const SizedBox(height: 12),
              _buildTextField(_diaChiCtrl, 'Địa điểm công tác'),
            ],

            const SizedBox(height: 16),

            // Attach file
            GestureDetector(
              onTap: _pickAttach,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _attachFile != null
                        ? const Color(0xFF22C55E).withOpacity(0.5)
                        : const Color(0xFF334155),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _attachFile != null ? Icons.attach_file : Icons.upload_file,
                      color: _attachFile != null ? const Color(0xFF22C55E) : Colors.white38,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _attachFile != null
                            ? _attachFile!.path.split('/').last
                            : 'Đính kèm giấy tờ (nếu có)',
                        style: TextStyle(
                          color: _attachFile != null ? Colors.white70 : Colors.white38,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_attachFile != null)
                      GestureDetector(
                        onTap: () => setState(() => _attachFile = null),
                        child: const Icon(Icons.close, color: Colors.white38, size: 16),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _loai.color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Gửi phiếu', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0891B2)),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }

  Future<void> _pickAttach() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null) setState(() => _attachFile = File(img.path));
  }

  Future<void> _submit() async {
    if (_lyDoCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập lý do')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/tao_phieu_nghi.php'),
      );
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.fields['idnhanvien'] = widget.userId.toString();
      request.fields['loai'] = _loai.apiCode;
      request.fields['tu_ngay'] = _tuNgay.toIso8601String().split('T').first;
      request.fields['den_ngay'] = _denNgay.toIso8601String().split('T').first;
      request.fields['ly_do'] = _lyDoCtrl.text.trim();
      if (_diaChiCtrl.text.trim().isNotEmpty) {
        request.fields['dia_chi'] = _diaChiCtrl.text.trim();
      }
      if (_attachFile != null) {
        request.files.add(await http.MultipartFile.fromPath('attach', _attachFile!.path));
      }

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == 1) {
          widget.onCreated();
          return;
        }
        throw Exception(data['message'] ?? 'Lỗi tạo phiếu');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }

    if (mounted) setState(() => _submitting = false);
  }
}

// ─── HELPER WIDGETS ──────────────────────────────────────────

class _DatePicker extends StatelessWidget {
  final String label;
  final DateTime value;
  final DateTime? firstDate;
  final Function(DateTime) onChanged;

  const _DatePicker({required this.label, required this.value, this.firstDate, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (_, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(primary: Color(0xFF0891B2)),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF0891B2), size: 14),
                const SizedBox(width: 6),
                Text(
                  DateFormat('dd/MM/yyyy').format(value),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool approved;
  const _MiniStat(this.label, this.value, {this.approved = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(
            color: approved ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
            fontSize: 20, fontWeight: FontWeight.w900,
          )),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

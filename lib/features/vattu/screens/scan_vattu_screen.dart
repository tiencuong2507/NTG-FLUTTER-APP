// ============================================================
// NTG App - OCR Scan Phiếu Vật Tư
// File: lib/screens/vattu/scan_vattu_screen.dart
//
// Tính năng:
// 1. Chụp hình phiếu giao nhận / phiếu xuất kho
// 2. Gửi lên API OCR (Claude Vision hoặc Google Vision)
// 3. Tự động điền danh sách vật tư vào form
// 4. User kiểm tra, chỉnh sửa, rồi xác nhận nhập hệ thống
//
// Packages:
//   image_picker: ^1.0.7
//   http: ^1.1.0
//   image: ^4.0.0  (optional: crop)
// ============================================================

import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// ─── MODEL ───────────────────────────────────────────────────

class VatTuItem {
  String ten;
  String maVatTu;
  double soLuong;
  String donVi;
  double donGia;
  String ghiChu;
  bool selected;

  VatTuItem({
    this.ten = '',
    this.maVatTu = '',
    this.soLuong = 0,
    this.donVi = '',
    this.donGia = 0,
    this.ghiChu = '',
    this.selected = true,
  });

  factory VatTuItem.fromJson(Map<String, dynamic> j) => VatTuItem(
    ten: j['ten'] ?? '',
    maVatTu: j['ma_vat_tu'] ?? '',
    soLuong: double.tryParse(j['so_luong']?.toString() ?? '0') ?? 0,
    donVi: j['don_vi'] ?? '',
    donGia: double.tryParse(j['don_gia']?.toString() ?? '0') ?? 0,
    ghiChu: j['ghi_chu'] ?? '',
    selected: true,
  );

  Map<String, dynamic> toJson() => {
    'ten': ten,
    'ma_vat_tu': maVatTu,
    'so_luong': soLuong,
    'don_vi': donVi,
    'don_gia': donGia,
    'ghi_chu': ghiChu,
  };
}

// ─── SCREEN ──────────────────────────────────────────────────

class ScanVatTuScreen extends StatefulWidget {
  final String token;
  final String loai; // 'nhap' hoặc 'xuat'

  const ScanVatTuScreen({
    Key? key,
    required this.token,
    this.loai = 'nhap',
  }) : super(key: key);

  @override
  State<ScanVatTuScreen> createState() => _ScanVatTuScreenState();
}

class _ScanVatTuScreenState extends State<ScanVatTuScreen> {
  final _baseUrl = 'https://erp.namthinh.com.vn/api';
  final _picker = ImagePicker();

  _ScanStatus _status = _ScanStatus.idle;
  File? _image;
  List<VatTuItem> _items = [];
  String _ocrRawText = '';
  String _errorMsg = '';
  String _nhaCC = '';
  String _soPhieu = '';
  String _ngayPhieu = '';

  // Kho
  List<Map<String, dynamic>> _khoList = [];
  int? _selectedKhoId;
  String _selectedKhoTen = '';
  bool _loadingKho = true;

  @override
  void initState() {
    super.initState();
    _loadKhoList();
  }

  Future<void> _loadKhoList() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/ds_kho.php'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == 1) {
          setState(() {
            _khoList = List<Map<String, dynamic>>.from(data['khos'] ?? []);
            _loadingKho = false;
          });
          return;
        }
      }
    } catch (_) {}
    setState(() => _loadingKho = false);
  }

  // ─── IMAGE PICK ───────────────────────────────────────────

  Future<void> _pickImage(ImageSource source) async {
    final XFile? img = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 2200,
    );
    if (img == null) return;

    setState(() {
      _image = File(img.path);
      _status = _ScanStatus.scanning;
      _items = [];
      _errorMsg = '';
    });

    await _scanImage(File(img.path));
  }

  // ─── OCR via Claude Vision API ────────────────────────────

  Future<void> _scanImage(File img) async {
    try {
      final bytes = await img.readAsBytes();
      final base64Img = base64Encode(bytes);

      final res = await http.post(
        Uri.parse('$_baseUrl/ocr_vattu.php'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'image_base64': base64Img,
          'loai': widget.loai,
        }),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == 1) {
          setState(() {
            _status = _ScanStatus.review;
            _items = (data['items'] as List? ?? [])
                .map((e) => VatTuItem.fromJson(e))
                .toList();
            _ocrRawText = data['raw_text'] ?? '';
            _nhaCC = data['nha_cung_cap'] ?? '';
            _soPhieu = data['so_phieu'] ?? '';
            _ngayPhieu = data['ngay_phieu'] ?? '';
          });
          return;
        }
        setState(() {
          _errorMsg = data['message'] ?? 'Không nhận diện được văn bản';
          _status = _ScanStatus.error;
        });
      } else {
        setState(() {
          _errorMsg = 'Lỗi server (${res.statusCode})';
          _status = _ScanStatus.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Lỗi kết nối: $e';
        _status = _ScanStatus.error;
      });
    }
  }

  // ─── SUBMIT ───────────────────────────────────────────────

  Future<void> _submitPhieu() async {
    final selected = _items.where((e) => e.selected).toList();
    if (selected.isEmpty) {
      _showSnack('Chưa chọn vật tư nào');
      return;
    }
    if (_selectedKhoId == null) {
      _showSnack('Vui lòng chọn kho ${widget.loai == "nhap" ? "nhập" : "xuất"}');
      return;
    }

    setState(() => _status = _ScanStatus.submitting);

    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/nhap_vattu_tu_scan.php'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'loai': widget.loai,
          'id_kho': _selectedKhoId,
          'ten_kho': _selectedKhoTen,
          'nha_cung_cap': _nhaCC,
          'so_phieu': _soPhieu,
          'ngay_phieu': _ngayPhieu,
          'items': selected.map((e) => e.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == 1) {
          setState(() => _status = _ScanStatus.success);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pop(context, true);
          return;
        }
        _showSnack(data['message'] ?? 'Lỗi nhập kho');
      }
    } catch (e) {
      _showSnack('Lỗi: $e');
    }

    setState(() => _status = _ScanStatus.review);
  }

  // ─── KHO PICKER ─────────────────────────────────────────
  void _showKhoPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          minChildSize: 0.3,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.warehouse, color: Color(0xFFF59E0B), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      widget.loai == 'nhap' ? 'Chọn kho nhập' : 'Chọn kho xuất',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text('${_khoList.length} kho', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Color(0xFF334155), height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: _khoList.length,
                  itemBuilder: (_, i) {
                    final kho = _khoList[i];
                    final isSelected = _selectedKhoId == kho['id'];
                    return ListTile(
                      leading: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF3B82F6) : Colors.white38,
                            width: 2,
                          ),
                          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 14)
                            : null,
                      ),
                      title: Text(
                        kho['ten'] ?? '',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: kho['vitri'] != null && kho['vitri'].toString().isNotEmpty
                          ? Text(kho['vitri'], style: const TextStyle(color: Colors.white38, fontSize: 11))
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedKhoId = kho['id'];
                          _selectedKhoTen = kho['ten'] ?? '';
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── BUILD ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Text(
          widget.loai == 'nhap' ? '📦 Scan Phiếu Nhập Kho' : '📤 Scan Phiếu Xuất Kho',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    return switch (_status) {
      _ScanStatus.idle     => _buildIdleView(),
      _ScanStatus.scanning => _buildScanningView(),
      _ScanStatus.error    => _buildErrorView(),
      _ScanStatus.review   => _buildReviewView(),
      _ScanStatus.submitting => _buildLoadingView('Đang nhập kho...'),
      _ScanStatus.success  => _buildSuccessView(),
    };
  }

  // ── Idle: chọn nguồn ảnh ──────────────────────────────────

  Widget _buildIdleView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0891B2), Color(0xFF0E7490)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.document_scanner, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Scan Phiếu Vật Tư',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Chụp hình phiếu giao nhận, phiếu xuất kho\n'
                  'AI sẽ tự động nhận diện vật tư và số lượng',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Camera button
          _SourceButton(
            icon: Icons.camera_alt,
            label: 'Chụp ảnh trực tiếp',
            subtitle: 'Dùng camera để chụp phiếu',
            color: const Color(0xFF0891B2),
            onTap: () => _pickImage(ImageSource.camera),
          ),

          const SizedBox(height: 12),

          // Gallery button
          _SourceButton(
            icon: Icons.photo_library,
            label: 'Chọn từ thư viện',
            subtitle: 'Chọn ảnh đã chụp sẵn',
            color: const Color(0xFF7C3AED),
            onTap: () => _pickImage(ImageSource.gallery),
          ),

          const SizedBox(height: 24),

          const Row(
            children: [
              Expanded(child: Divider(color: Color(0xFF334155))),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Hỗ trợ nhận diện', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ),
              Expanded(child: Divider(color: Color(0xFF334155))),
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag('Phiếu giao hàng'),
              _Tag('Phiếu xuất kho'),
              _Tag('Phiếu nhập kho'),
              _Tag('Bảng kê vật tư'),
              _Tag('Hóa đơn NCC'),
            ],
          ),
        ],
      ),
    );
  }

  // ── Scanning ─────────────────────────────────────────────

  Widget _buildScanningView() {
    return Column(
      children: [
        if (_image != null)
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(_image!, fit: BoxFit.cover),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        const Color(0xFF0F172A).withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
                // Scanning animation
                const _ScanLineAnimation(),
              ],
            ),
          ),
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF0891B2),
                strokeWidth: 2.5,
              ),
              const SizedBox(height: 16),
              const Text(
                'AI đang phân tích phiếu...',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nhận diện vật tư, số lượng, đơn vị',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Review: kiểm tra kết quả OCR ─────────────────────────

  Widget _buildReviewView() {
    final selectedCount = _items.where((e) => e.selected).length;

    return CustomScrollView(
      slivers: [
        // Ảnh thumbnail + thông tin phiếu
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: Color(0xFF22C55E), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Nhận diện thành công ${_items.length} vật tư',
                            style: const TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (_image != null)
                            GestureDetector(
                              onTap: () => _showImagePreview(),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(_image!, width: 44, height: 44, fit: BoxFit.cover),
                              ),
                            ),
                        ],
                      ),
                      if (_nhaCC.isNotEmpty || _soPhieu.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Divider(color: Color(0xFF334155), height: 1),
                        const SizedBox(height: 10),
                        if (_nhaCC.isNotEmpty)
                          _InfoChip('NCC', _nhaCC),
                        if (_soPhieu.isNotEmpty)
                          _InfoChip('Số phiếu', _soPhieu),
                        if (_ngayPhieu.isNotEmpty)
                          _InfoChip('Ngày', _ngayPhieu),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Chọn kho ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedKhoId != null
                          ? const Color(0xFF3B82F6).withOpacity(0.5)
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warehouse, color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            widget.loai == 'nhap' ? 'Nhập vào kho' : 'Xuất từ kho',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const Text(' *', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _loadingKho
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)))
                          : GestureDetector(
                              onTap: () => _showKhoPicker(),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF475569)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedKhoId != null ? _selectedKhoTen : 'Chọn kho...',
                                        style: TextStyle(
                                          color: _selectedKhoId != null ? Colors.white : Colors.white38,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const Icon(Icons.arrow_drop_down, color: Colors.white38),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  children: [
                    const Text(
                      'Danh sách vật tư',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0891B2).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$selectedCount/${_items.length} đã chọn',
                        style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        for (final e in _items) e.selected = true;
                      }),
                      child: const Text('Chọn tất cả', style: TextStyle(fontSize: 12, color: Color(0xFFF59E0B))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // List items
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) => _VatTuItemCard(
              item: _items[i],
              index: i,
              onChanged: () => setState(() {}),
            ),
            childCount: _items.length,
          ),
        ),

        // Thêm mới
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF334155)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add, color: Color(0xFFF59E0B), size: 18),
              label: const Text('Thêm vật tư thủ công', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13)),
              onPressed: _addManualItem,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 64),
            const SizedBox(height: 16),
            const Text('Không nhận diện được', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(_errorMsg, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 24),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF334155))),
                  onPressed: () => setState(() => _status = _ScanStatus.idle),
                  child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0891B2)),
                  onPressed: _addManualItem,
                  child: const Text('Nhập thủ công', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF0891B2)),
          const SizedBox(height: 16),
          Text(msg, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF16A34A).withOpacity(0.2),
              border: Border.all(color: const Color(0xFF16A34A), width: 2),
            ),
            child: const Icon(Icons.check, color: Color(0xFF22C55E), size: 44),
          ),
          const SizedBox(height: 20),
          const Text('Nhập kho thành công!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Đã nhập ${_items.where((e) => e.selected).length} loại vật tư',
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar() {
    if (_status != _ScanStatus.review) return null;

    final selected = _items.where((e) => e.selected).length;
    if (selected == 0) return null;

    double total = _items
        .where((e) => e.selected && e.donGia > 0)
        .fold(0, (s, e) => s + e.soLuong * e.donGia);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text('$selected vật tư đã chọn', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const Spacer(),
                if (total > 0)
                  Text(
                    'Tổng: ${_formatMoney(total)}đ',
                    style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 14, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check, color: Colors.white, size: 18),
                label: Text(
                  widget.loai == 'nhap' ? 'Xác nhận nhập kho' : 'Xác nhận xuất kho',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                onPressed: _submitPhieu,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────

  void _addManualItem() {
    setState(() {
      _items.add(VatTuItem(ten: '', soLuong: 1, donVi: 'cái'));
      if (_status != _ScanStatus.review) _status = _ScanStatus.review;
    });
  }

  void _showImagePreview() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(_image!),
        ),
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatMoney(double v) {
    return v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

// ─── VAT TU ITEM CARD ─────────────────────────────────────────

class _VatTuItemCard extends StatefulWidget {
  final VatTuItem item;
  final int index;
  final VoidCallback onChanged;

  const _VatTuItemCard({required this.item, required this.index, required this.onChanged});

  @override
  State<_VatTuItemCard> createState() => _VatTuItemCardState();
}

class _VatTuItemCardState extends State<_VatTuItemCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: item.selected ? const Color(0xFF1E293B) : const Color(0xFF1E293B).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.selected
              ? const Color(0xFF334155)
              : const Color(0xFF334155).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Checkbox
                  GestureDetector(
                    onTap: () {
                      item.selected = !item.selected;
                      widget.onChanged();
                    },
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: item.selected
                            ? const Color(0xFF0891B2)
                            : Colors.transparent,
                        border: Border.all(
                          color: item.selected
                              ? const Color(0xFF0891B2)
                              : const Color(0xFF475569),
                          width: 2,
                        ),
                      ),
                      child: item.selected
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name & quantity
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        item.ten.isEmpty
                            ? const Text(
                                'Chưa có tên',
                                style: TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
                              )
                            : Text(
                                item.ten,
                                style: TextStyle(
                                  color: item.selected ? Colors.white : Colors.white38,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                        if (item.maVatTu.isNotEmpty)
                          Text(
                            item.maVatTu,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                      ],
                    ),
                  ),

                  // Quantity
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0891B2).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.soLuong % 1 == 0 ? item.soLuong.toInt() : item.soLuong} ${item.donVi}',
                      style: const TextStyle(
                        color: Color(0xFF60A5FA),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white38,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          // Expanded edit form
          if (_expanded) ...[
            const Divider(color: Color(0xFF334155), height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _EditRow('Tên vật tư', item.ten, (v) => setState(() => item.ten = v)),
                  _EditRow('Mã vật tư', item.maVatTu, (v) => setState(() => item.maVatTu = v)),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _EditRow('Số lượng', item.soLuong.toString(), (v) {
                          setState(() => item.soLuong = double.tryParse(v) ?? item.soLuong);
                        }, isNumber: true),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _EditRow('Đơn vị', item.donVi, (v) => setState(() => item.donVi = v)),
                      ),
                    ],
                  ),
                  _EditRow('Đơn giá', item.donGia > 0 ? item.donGia.toString() : '', (v) {
                    setState(() => item.donGia = double.tryParse(v) ?? 0);
                  }, isNumber: true),
                  _EditRow('Ghi chú', item.ghiChu, (v) => setState(() => item.ghiChu = v)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _EditRow(String label, String value, Function(String) onChanged, {bool isNumber = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ),
        Expanded(
          child: TextFormField(
            initialValue: value,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    ),
  );
}

// ─── SMALL WIDGETS ───────────────────────────────────────────

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 14),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(color: Colors.white38, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ScanLineAnimation extends StatefulWidget {
  const _ScanLineAnimation();

  @override
  State<_ScanLineAnimation> createState() => _ScanLineAnimationState();
}

class _ScanLineAnimationState extends State<_ScanLineAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _anim = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Positioned(
        top: MediaQuery.of(context).size.height * 0.4 * _anim.value,
        left: 0, right: 0,
        child: Container(
          height: 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                const Color(0xFF0891B2).withOpacity(0.8),
                const Color(0xFF0891B2),
                const Color(0xFF0891B2).withOpacity(0.8),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ScanStatus { idle, scanning, review, submitting, success, error }

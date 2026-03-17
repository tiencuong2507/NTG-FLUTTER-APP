// ============================================================
// NTG App - Chấm Công GPS + Camera
// File: lib/screens/chamcong/chamcong_screen.dart
//
// Tính năng:
// 1. Lấy GPS hiện tại
// 2. So sánh với tọa độ dự án đã khai báo
// 3. Chụp hình selfie để xác thực
// 4. Gửi lên server kèm ảnh + tọa độ + thời gian
//
// Packages cần thêm vào pubspec.yaml:
//   geolocator: ^11.0.0
//   camera: ^0.11.0
//   image_picker: ^1.0.7
//   http: ^1.1.0
//   intl: ^0.19.0
//   permission_handler: ^11.0.0
// ============================================================

import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── MODEL ───────────────────────────────────────────────────

class DuAnLocation {
  final int id;
  final String ten;
  final double lat;
  final double lng;
  final double banhKinh; // mét, bán kính cho phép chấm công

  const DuAnLocation({
    required this.id,
    required this.ten,
    required this.lat,
    required this.lng,
    this.banhKinh = 200.0,
  });

  factory DuAnLocation.fromJson(Map<String, dynamic> json) {
    return DuAnLocation(
      id: json['id'] ?? 0,
      ten: json['ten'] ?? '',
      lat: double.tryParse(json['lat'].toString()) ?? 0,
      lng: double.tryParse(json['lng'].toString()) ?? 0,
      banhKinh: double.tryParse(json['banh_kinh']?.toString() ?? '200') ?? 200,
    );
  }
}

class ChamCongResult {
  final bool success;
  final String message;
  final String? imageUrl;
  final double? distance;

  ChamCongResult({
    required this.success,
    required this.message,
    this.imageUrl,
    this.distance,
  });
}

// ─── SCREEN ──────────────────────────────────────────────────

class ChamCongScreen extends StatefulWidget {
  final String token;
  final int userId;
  final String userName;

  const ChamCongScreen({
    Key? key,
    required this.token,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<ChamCongScreen> createState() => _ChamCongScreenState();
}

class _ChamCongScreenState extends State<ChamCongScreen>
    with TickerProviderStateMixin {
  // State
  _Status _status = _Status.idle;
  String _statusMessage = 'Nhấn để bắt đầu chấm công';
  Position? _currentPosition;
  DuAnLocation? _nearestDuAn;
  DuAnLocation? _selectedDuAn; // User chọn thủ công
  double? _distance;
  File? _photo;
  bool _isInRange = false;
  String _loaiChamCong = 'vao'; // 'vao' hoặc 'ra'
  List<DuAnLocation> _duAnList = [];
  bool _loadingDuAn = true;

  // Controllers
  late AnimationController _pulseController;
  late AnimationController _checkController;
  late Animation<double> _pulseAnim;
  late Animation<double> _checkAnim;

  final _baseUrl = 'https://erp.namthinh.com.vn/api';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkAnim = CurvedAnimation(parent: _checkController, curve: Curves.elasticOut);

    _loadDuAnList();
    _checkExistingChamCong();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _checkController.dispose();
    super.dispose();
  }

  // ─── DATA LOADING ─────────────────────────────────────────

  Future<void> _loadDuAnList() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/chamcong_locations.php'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == 1) {
          setState(() {
            _duAnList = (data['locations'] as List)
                .map((e) => DuAnLocation.fromJson(e))
                .toList();
            _loadingDuAn = false;
          });
          return;
        }
      }
    } catch (_) {}

    // Fallback dữ liệu mẫu nếu API chưa có
    setState(() {
      _duAnList = [
        const DuAnLocation(id: 1, ten: 'Văn phòng Nam Thịnh', lat: 10.7769, lng: 106.7009, banhKinh: 100),
        const DuAnLocation(id: 2, ten: 'Dự án HCM-01', lat: 10.7500, lng: 106.6800, banhKinh: 200),
        const DuAnLocation(id: 3, ten: 'Dự án HN-2026-03', lat: 21.0285, lng: 105.8542, banhKinh: 200),
      ];
      _loadingDuAn = false;
    });
  }

  Future<void> _checkExistingChamCong() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/chamcong_status.php?idnhanvien=${widget.userId}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == 1 && data['da_vao'] == true) {
          setState(() => _loaiChamCong = 'ra');
        }
      }
    } catch (_) {}
  }

  // ─── GPS LOGIC ────────────────────────────────────────────

  Future<void> _startChamCong() async {
    // 1. Xin quyền
    final locPerm = await Permission.location.request();
    final camPerm = await Permission.camera.request();

    if (!locPerm.isGranted || !camPerm.isGranted) {
      _showError('Cần cấp quyền vị trí và camera để chấm công');
      return;
    }

    setState(() {
      _status = _Status.gettingLocation;
      _statusMessage = 'Đang lấy vị trí GPS...';
    });

    try {
      // 2. Lấy GPS
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      setState(() => _currentPosition = pos);

      // 3. Tìm dự án gần nhất
      _findNearestDuAn(pos);

      if (_selectedDuAn == null) {
        _showError('Vui lòng chọn dự án / văn phòng để chấm công');
        setState(() => _status = _Status.idle);
        return;
      }

      setState(() {
        _status = _Status.takingPhoto;
        _statusMessage = _isInRange
            ? 'Vị trí hợp lệ! Chụp ảnh xác thực...'
            : 'Ngoài phạm vi ${_distance?.toStringAsFixed(0)}m. Vẫn tiếp tục?';
      });

      // 4. Chụp ảnh nếu trong phạm vi (hoặc xác nhận ngoài phạm vi)
      if (!_isInRange) {
        final confirm = await _confirmOutOfRange();
        if (!confirm) {
          setState(() {
            _status = _Status.idle;
            _statusMessage = 'Đã hủy chấm công';
          });
          return;
        }
      }

      await _takePhoto();
    } on LocationServiceDisabledException {
      _showError('Vui lòng bật GPS và thử lại');
      setState(() => _status = _Status.idle);
    } catch (e) {
      _showError('Lỗi lấy vị trí: ${e.toString()}');
      setState(() => _status = _Status.idle);
    }
  }

  void _findNearestDuAn(Position pos) {
    if (_duAnList.isEmpty) return;

    double minDist = double.infinity;
    DuAnLocation? nearest;

    for (final da in _duAnList) {
      final d = Geolocator.distanceBetween(pos.latitude, pos.longitude, da.lat, da.lng);
      if (d < minDist) {
        minDist = d;
        nearest = da;
      }
    }

    setState(() {
      _nearestDuAn = nearest;
      // Chỉ auto-select nếu user chưa chọn thủ công
      if (_selectedDuAn == null) {
        _selectedDuAn = nearest;
        _distance = minDist;
        _isInRange = nearest != null && minDist <= nearest.banhKinh;
      }
    });
  }

  // Chọn dự án thủ công
  void _selectDuAn(DuAnLocation da) {
    double? dist;
    if (_currentPosition != null) {
      dist = Geolocator.distanceBetween(
        _currentPosition!.latitude, _currentPosition!.longitude,
        da.lat, da.lng,
      );
    }
    setState(() {
      _selectedDuAn = da;
      _distance = dist;
      _isInRange = dist != null && dist <= da.banhKinh;
    });
  }

  // ─── CAMERA ───────────────────────────────────────────────

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front, // camera trước (selfie)
      imageQuality: 70,
      maxWidth: 800,
      maxHeight: 800,
    );

    if (img == null) {
      setState(() {
        _status = _Status.idle;
        _statusMessage = 'Đã hủy chụp ảnh';
      });
      return;
    }

    setState(() {
      _photo = File(img.path);
      _status = _Status.uploading;
      _statusMessage = 'Đang gửi dữ liệu...';
    });

    await _submitChamCong();
  }

  // ─── SUBMIT ───────────────────────────────────────────────

  Future<void> _submitChamCong() async {
    if (_currentPosition == null || _photo == null) return;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/chamcong_gps.php'),
      );

      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.fields['idnhanvien'] = widget.userId.toString();
      request.fields['loai'] = _loaiChamCong;
      request.fields['lat'] = _currentPosition!.latitude.toString();
      request.fields['lng'] = _currentPosition!.longitude.toString();
      request.fields['accuracy'] = _currentPosition!.accuracy.toString();
      request.fields['iddu_an'] = (_selectedDuAn?.id ?? 0).toString();
      request.fields['distance'] = (_distance ?? 0).toStringAsFixed(1);
      request.fields['is_in_range'] = _isInRange ? '1' : '0';
      request.fields['timestamp'] = DateTime.now().toIso8601String();

      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        _photo!.path,
        filename: 'chamcong_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == 1) {
          setState(() {
            _status = _Status.success;
            _statusMessage = _loaiChamCong == 'vao'
                ? 'Chấm công VÀO thành công!'
                : 'Chấm công RA thành công!';
          });
          _checkController.forward();
          // Toggle loại chấm công cho lần sau
          setState(() => _loaiChamCong = _loaiChamCong == 'vao' ? 'ra' : 'vao');
          return;
        }
        _showError(data['message'] ?? 'Lỗi không xác định');
      } else {
        _showError('Lỗi kết nối server (${res.statusCode})');
      }
    } catch (e) {
      _showError('Lỗi gửi dữ liệu: ${e.toString()}');
    }

    setState(() => _status = _Status.idle);
  }

  // ─── HELPERS ──────────────────────────────────────────────

  Future<bool> _confirmOutOfRange() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Ngoài phạm vi'),
          ],
        ),
        content: Text(
          'Bạn đang cách ${_selectedDuAn?.ten ?? "dự án"} khoảng '
          '${_distance?.toStringAsFixed(0) ?? "?"}m (giới hạn: '
          '${_selectedDuAn?.banhKinh.toStringAsFixed(0) ?? "?"}m).\n\n'
          'Vẫn tiếp tục chấm công? Sẽ bị ghi nhận là ngoài phạm vi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tiếp tục', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    setState(() {
      _status = _Status.idle;
      _statusMessage = msg;
    });
  }

  // ─── BUILD ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final now = DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Chấm Công', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.history, color: Color(0xFFF59E0B), size: 18),
            label: const Text('Lịch sử', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 13)),
            onPressed: () => _showHistory(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ── Thời gian hiện tại ──
              _buildTimeCard(now),
              const SizedBox(height: 20),

              // ── Nút chấm công chính ──
              _buildMainButton(),
              const SizedBox(height: 20),

              // ── Thông tin vị trí ──
              if (_currentPosition != null || _status != _Status.idle)
                _buildLocationCard(),

              // ── Ảnh preview ──
              if (_photo != null) ...[
                const SizedBox(height: 16),
                _buildPhotoPreview(),
              ],

              // ── Danh sách dự án ──
              const SizedBox(height: 20),
              _buildDuAnList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCard(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A5F), Color(0xFF1a2744)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D4A7A), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Xin chào, ${widget.userName.split(' ').last}!',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _loaiChamCong == 'vao'
                  ? const Color(0xFF16A34A).withOpacity(0.2)
                  : const Color(0xFFDC2626).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _loaiChamCong == 'vao'
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFDC2626),
              ),
            ),
            child: Text(
              _loaiChamCong == 'vao' ? '● CHƯA VÀO' : '● ĐÃ VÀO',
              style: TextStyle(
                color: _loaiChamCong == 'vao'
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFEF4444),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton() {
    final isLoading = _status == _Status.gettingLocation ||
        _status == _Status.takingPhoto ||
        _status == _Status.uploading;
    final isSuccess = _status == _Status.success;

    Color btnColor = _loaiChamCong == 'vao'
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    if (isSuccess) btnColor = const Color(0xFF0891B2);

    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: isLoading ? 1.0 : _pulseAnim.value,
            child: child,
          ),
          child: GestureDetector(
            onTap: (isLoading || _status == _Status.success) ? null : _startChamCong,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    btnColor.withOpacity(0.3),
                    btnColor.withOpacity(0.1),
                  ],
                ),
                border: Border.all(color: btnColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: btnColor.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: btnColor,
                        strokeWidth: 3,
                      ),
                    )
                  : isSuccess
                      ? ScaleTransition(
                          scale: _checkAnim,
                          child: const Icon(
                            Icons.check_circle,
                            color: Color(0xFF22C55E),
                            size: 70,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _loaiChamCong == 'vao'
                                  ? Icons.login
                                  : Icons.logout,
                              color: btnColor,
                              size: 48,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _loaiChamCong == 'vao' ? 'CHẤM VÀO' : 'CHẤM RA',
                              style: TextStyle(
                                color: btnColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSuccess
                ? const Color(0xFF22C55E)
                : _status == _Status.idle
                    ? Colors.white60
                    : const Color(0xFFF59E0B),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (!isLoading && _status == _Status.idle) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() {
              _loaiChamCong = _loaiChamCong == 'vao' ? 'ra' : 'vao';
            }),
            child: Text(
              'Chuyển sang chấm ${_loaiChamCong == 'vao' ? 'RA' : 'VÀO'}',
              style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 12,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isInRange
              ? const Color(0xFF16A34A).withOpacity(0.5)
              : const Color(0xFFDC2626).withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isInRange ? Icons.location_on : Icons.location_off,
                color: _isInRange ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isInRange ? 'Trong phạm vi' : 'Ngoài phạm vi',
                style: TextStyle(
                  color: _isInRange ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (_currentPosition != null)
                Text(
                  '±${_currentPosition!.accuracy.toStringAsFixed(0)}m',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
            ],
          ),
          if (_selectedDuAn != null) ...[
            const SizedBox(height: 10),
            _infoRow('Nơi chấm công', _selectedDuAn!.ten),
            _infoRow(
              'Khoảng cách',
              '${_distance?.toStringAsFixed(0) ?? "?"}m / giới hạn ${_selectedDuAn!.banhKinh.toStringAsFixed(0)}m',
            ),
          ],
          if (_currentPosition != null) ...[
            const SizedBox(height: 4),
            _infoRow(
              'Tọa độ',
              '${_currentPosition!.latitude.toStringAsFixed(6)}, '
              '${_currentPosition!.longitude.toStringAsFixed(6)}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Image.file(
            _photo!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Ảnh xác thực',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuAnList() {
    if (_loadingDuAn) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Chọn nơi chấm công',
              style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              '${_duAnList.length} địa điểm',
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._duAnList.map((da) => _DuAnCard(
          duAn: da,
          currentPosition: _currentPosition,
          isSelected: _selectedDuAn?.id == da.id,
          isNearest: _nearestDuAn?.id == da.id,
          onTap: () => _selectDuAn(da),
        )),
      ],
    );
  }

  void _showHistory() {
    // TODO: Navigate to history screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lịch sử chấm công - Coming soon')),
    );
  }
}

// ─── DU AN CARD ──────────────────────────────────────────────

class _DuAnCard extends StatelessWidget {
  final DuAnLocation duAn;
  final Position? currentPosition;
  final bool isSelected;
  final bool isNearest;
  final VoidCallback? onTap;

  const _DuAnCard({
    required this.duAn,
    this.currentPosition,
    this.isSelected = false,
    this.isNearest = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    double? dist;
    if (currentPosition != null) {
      dist = Geolocator.distanceBetween(
        currentPosition!.latitude,
        currentPosition!.longitude,
        duAn.lat,
        duAn.lng,
      );
    }
    final inRange = dist != null && dist <= duAn.banhKinh;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1E3A5F)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF3B82F6).withOpacity(0.7)
                : const Color(0xFF334155),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
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
            const SizedBox(width: 10),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: inRange
                    ? const Color(0xFF16A34A).withOpacity(0.2)
                    : const Color(0xFF334155),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.place,
                color: inRange ? const Color(0xFF22C55E) : Colors.white38,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          duAn.ten,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (isNearest && !isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Gần nhất',
                              style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      if (isSelected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Đã chọn',
                              style: TextStyle(color: Color(0xFF60A5FA), fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dist != null
                        ? '${dist.toStringAsFixed(0)}m · bán kính ${duAn.banhKinh.toStringAsFixed(0)}m'
                        : 'Bán kính: ${duAn.banhKinh.toStringAsFixed(0)}m',
                    style: TextStyle(
                      color: inRange ? const Color(0xFF22C55E) : Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (inRange)
              const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── ENUMS ────────────────────────────────────────────────────

enum _Status { idle, gettingLocation, takingPhoto, uploading, success, error }

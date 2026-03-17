// lib/features/profile/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = '';
  String _avatar = '';
  int _userId = 0;
  String _username = '';
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = info.version;
    });
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString(AppConstants.keyUserName) ?? '';
      _avatar = prefs.getString(AppConstants.keyAvatar) ?? '';
      _userId = prefs.getInt(AppConstants.keyUserId) ?? 0;
      _username = prefs.getString('user_username') ?? '';
    });
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đăng xuất', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      ApiService().clearSession();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Get.offAllNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatar.isNotEmpty
        ? '${AppConstants.baseUrl}/uploads/$_avatar'
        : null;

    return Scaffold(
      backgroundColor: const Color(AppColors.bgSecondary),
      body: Column(children: [
        // Header
        Container(
          color: const Color(AppColors.primary),
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16, right: 16, bottom: 8,
          ),
          child: const Row(children: [
            Text('Tôi', style: TextStyle(color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.bold)),
          ]),
        ),
        // Profile card
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: const Color(AppColors.primary).withOpacity(0.1),
              child: avatarUrl != null
                  ? ClipOval(child: CachedNetworkImage(
                      imageUrl: avatarUrl, width: 64, height: 64, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _avatarFallback(),
                    ))
                  : _avatarFallback(),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('ID: $_userId',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              ],
            )),
          ]),
        ),
        const SizedBox(height: 12),
        // Menu items
        _buildSection([
          _menuItem(Icons.person_outline, 'Thông tin cá nhân', () => _showUserInfo()),
          _menuItem(Icons.qr_code, 'Mã QR của tôi', () {
            Get.snackbar('', 'Tính năng sẽ có sớm', snackPosition: SnackPosition.BOTTOM);
          }),
        ]),
        const SizedBox(height: 12),
        _buildSection([
          _menuItem(Icons.notifications_outlined, 'Cài đặt thông báo', () {
            Get.snackbar('', 'Tính năng sẽ có sớm', snackPosition: SnackPosition.BOTTOM);
          }),
          _menuItem(Icons.storage_outlined, 'Dung lượng & dữ liệu', () {
            Get.snackbar('', 'Tính năng sẽ có sớm', snackPosition: SnackPosition.BOTTOM);
          }),
          _menuItem(Icons.color_lens_outlined, 'Giao diện', () {
            Get.snackbar('', 'Tính năng sẽ có sớm', snackPosition: SnackPosition.BOTTOM);
          }),
        ]),
        const SizedBox(height: 12),
        _buildSection([
          _menuItem(Icons.info_outline, 'Về ứng dụng', () => _showAbout()),
          _menuItem(Icons.bug_report_outlined, 'Báo lỗi', () {
            Get.snackbar('', 'Liên hệ Phòng IT để báo lỗi', snackPosition: SnackPosition.BOTTOM);
          }),
        ]),
        const SizedBox(height: 12),
        // Logout button
        Container(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Đăng xuất', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
            onTap: _logout,
          ),
        ),
        const SizedBox(height: 20),
        Text('Chat Nội Bộ v$_appVersion', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        Text('© ${DateTime.now().year} Nam Thinh Group',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      ]),
    );
  }

  Widget _avatarFallback() {
    return Text(_name.isNotEmpty ? _name[0].toUpperCase() : '?',
        style: const TextStyle(color: Color(AppColors.primary),
            fontWeight: FontWeight.bold, fontSize: 24));
  }

  Widget _buildSection(List<Widget> items) {
    return Container(
      color: Colors.white,
      child: Column(children: items),
    );
  }

  Widget _menuItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(AppColors.textPrimary), size: 22),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
      onTap: onTap,
      dense: true,
    );
  }

  void _showUserInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.8, minChildSize: 0.3, expand: false,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Thông tin cá nhân', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _infoRow(Icons.person, 'Họ tên', _name),
            _infoRow(Icons.badge, 'User ID', '$_userId'),
            const SizedBox(height: 20),
            const Text('Để thay đổi thông tin, vui lòng liên hệ Phòng HCNS.',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
          ]),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, size: 20, color: Colors.grey.shade500),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Image.asset('assets/images/logo.png', width: 40, height: 40),
          const SizedBox(width: 12),
          const Text('Chat Nội Bộ'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Phiên bản: $_appVersion'),
          const SizedBox(height: 8),
          const Text('Ứng dụng chat nội bộ dành cho nhân viên Nam Thinh Group.'),
          const SizedBox(height: 8),
          const Text('Phát triển bởi: Phòng IT - NTG'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
        ],
      ),
    );
  }
}

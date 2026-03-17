// lib/features/contacts/screens/contacts_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../chat/screens/chat_room_screen.dart';
import '../../chat/models/room_model.dart';
import '../../chat/controllers/chat_controller.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});
  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _search = TextEditingController();
  final _api = ApiService();
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getEmployees();
      if (res['ok'] == 1 && res['data'] != null) {
        _employees = List<Map<String, dynamic>>.from(res['data']);
        _applyFilter();
      }
    } catch (e) {
      debugPrint('Load employees error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_employees);
    } else {
      final q = _searchQuery.toLowerCase();
      _filtered = _employees.where((e) {
        final name = (e['hoten'] ?? '').toString().toLowerCase();
        final dept = (e['phongban'] ?? '').toString().toLowerCase();
        final phone = (e['didong'] ?? '').toString().toLowerCase();
        final pos = (e['chucvu'] ?? '').toString().toLowerCase();
        return name.contains(q) || dept.contains(q) || phone.contains(q) || pos.contains(q);
      }).toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Group by department
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var emp in _filtered) {
      final dept = emp['phongban'] ?? 'Khác';
      grouped.putIfAbsent(dept, () => []);
      grouped[dept]!.add(emp);
    }
    final depts = grouped.keys.toList()..sort();

    return Scaffold(
      backgroundColor: const Color(AppColors.bgSecondary),
      body: Column(children: [
        _buildHeader(),
        _buildSearchBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? Center(child: Text(
                      _searchQuery.isEmpty ? 'Không có nhân viên' : 'Không tìm thấy "$_searchQuery"',
                      style: TextStyle(color: Colors.grey.shade500)))
                  : RefreshIndicator(
                      onRefresh: _loadEmployees,
                      child: ListView.builder(
                        itemCount: depts.length,
                        itemBuilder: (ctx, i) => _buildDepartment(depts[i], grouped[depts[i]]!),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(AppColors.primary),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16, right: 16, bottom: 8,
      ),
      child: Row(children: [
        const Text('Danh bạ',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('${_employees.length} NV',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: const Color(AppColors.primary),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _search,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Tìm tên, phòng ban, SĐT...',
            hintStyle: TextStyle(color: Colors.white70),
            prefixIcon: Icon(Icons.search, color: Colors.white70, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
            isDense: true,
          ),
          onChanged: (v) {
            _searchQuery = v;
            _applyFilter();
          },
        ),
      ),
    );
  }

  Widget _buildDepartment(String deptName, List<Map<String, dynamic>> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(deptName,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700)),
        ),
        ...members.map((emp) => _buildEmployeeItem(emp)),
      ],
    );
  }

  Widget _buildEmployeeItem(Map<String, dynamic> emp) {
    final name = emp['hoten'] ?? '';
    final position = emp['chucvu'] ?? '';
    final phone = emp['didong'] ?? '';
    final avatar = emp['avatar'];
    final nguoidungId = emp['nguoidung_id'];

    final avatarUrl = avatar != null && avatar.toString().isNotEmpty
        ? '${AppConstants.baseUrl}/uploads/$avatar'
        : null;

    return InkWell(
      onTap: () => _openDirectChat(emp),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 1),
        child: Row(children: [
          // Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(AppColors.primary).withOpacity(0.1),
            child: avatarUrl != null
                ? ClipOval(child: CachedNetworkImage(
                    imageUrl: avatarUrl, width: 44, height: 44, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Color(AppColors.primary),
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ))
                : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(AppColors.primary),
                        fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              if (position.isNotEmpty)
                Text(position,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis),
            ],
          )),
          // Phone icon
          if (phone.isNotEmpty)
            IconButton(
              icon: Icon(Icons.phone_outlined, color: Colors.grey.shade400, size: 20),
              onPressed: () {
                // TODO: launch phone call
                Get.snackbar('SĐT', phone,
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2));
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.chat_bubble_outline, color: Colors.grey.shade400, size: 20),
            onPressed: () => _openDirectChat(emp),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
      ),
    );
  }

  Future<void> _openDirectChat(Map<String, dynamic> emp) async {
    final nguoidungId = emp['nguoidung_id'];
    final name = emp['hoten'] ?? '';
    if (nguoidungId == null) {
      Get.snackbar('Lỗi', 'Nhân viên chưa có tài khoản',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    Get.snackbar('', 'Đang mở chat với $name...',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 1));

    try {
      final res = await _api.directChat(int.parse(nguoidungId.toString()));
      if (res['ok'] == 1 && res['room_id'] != null) {
        final roomId = int.parse(res['room_id'].toString());
        final room = RoomModel(
          id: roomId,
          name: name,
          type: 2,
          otherAvatar: emp['avatar'],
        );
        final chatCtrl = Get.find<ChatController>();
        chatCtrl.openRoom(roomId, name);
        Get.to(() => ChatRoomScreen(key: UniqueKey(), room: room));
      } else {
        Get.snackbar('Lỗi', res['msg'] ?? 'Không mở được chat',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không kết nối được server',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

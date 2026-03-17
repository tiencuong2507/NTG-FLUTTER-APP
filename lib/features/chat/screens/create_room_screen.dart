// lib/features/chat/screens/create_room_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../controllers/chat_controller.dart';
import '../models/room_model.dart';
import 'chat_room_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});
  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _api = ApiService();
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filtered = [];
  final Set<int> _selectedIds = {};
  final Map<int, String> _selectedNames = {};
  bool _loading = true;
  bool _creating = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getEmployees();
      if (res['ok'] == 1 && res['data'] != null) {
        _allUsers = List<Map<String, dynamic>>.from(res['data']);
        // Remove duplicates by nguoidung_id
        final seen = <String>{};
        _allUsers = _allUsers.where((e) {
          final id = e['nguoidung_id']?.toString() ?? '';
          if (id.isEmpty || seen.contains(id)) return false;
          seen.add(id);
          return true;
        }).toList();
        _applyFilter();
      }
    } catch (e) {
      debugPrint('Load users error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filtered = List.from(_allUsers);
    } else {
      final q = _searchQuery.toLowerCase();
      _filtered = _allUsers.where((e) {
        final name = (e['hoten'] ?? '').toString().toLowerCase();
        final dept = (e['phongban'] ?? '').toString().toLowerCase();
        return name.contains(q) || dept.contains(q);
      }).toList();
    }
    setState(() {});
  }

  void _toggleSelect(Map<String, dynamic> user) {
    final id = int.tryParse(user['nguoidung_id']?.toString() ?? '');
    if (id == null) return;
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _selectedNames.remove(id);
      } else {
        _selectedIds.add(id);
        _selectedNames[id] = user['hoten'] ?? '';
      }
    });
  }

  Future<void> _createRoom() async {
    if (_selectedIds.isEmpty) {
      Get.snackbar('Lỗi', 'Chọn ít nhất 1 thành viên',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // Nếu chỉ 1 người → chat 1-1
    if (_selectedIds.length == 1) {
      setState(() => _creating = true);
      try {
        final res = await _api.directChat(_selectedIds.first);
        if (res['ok'] == 1 && res['room_id'] != null) {
          final roomId = int.parse(res['room_id'].toString());
          final name = _selectedNames[_selectedIds.first] ?? '';
          final room = RoomModel(id: roomId, name: name, type: 2);
          final chatCtrl = Get.find<ChatController>();
          chatCtrl.openRoom(roomId, name);
          Get.off(() => ChatRoomScreen(key: UniqueKey(), room: room));
        }
      } catch (e) {
        Get.snackbar('Lỗi', 'Không tạo được chat',
            snackPosition: SnackPosition.BOTTOM);
      } finally {
        setState(() => _creating = false);
      }
      return;
    }

    // Nhiều người → tạo nhóm
    final groupName = _nameController.text.trim();
    if (groupName.isEmpty) {
      Get.snackbar('Lỗi', 'Nhập tên nhóm',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    setState(() => _creating = true);
    try {
      final res = await _api.createRoom(
        name: groupName,
        memberIds: _selectedIds.toList(),
      );
      if (res['ok'] == 1 && res['room_id'] != null) {
        final roomId = int.parse(res['room_id'].toString());
        final room = RoomModel(
          id: roomId, name: groupName, type: 1,
          memberCount: _selectedIds.length + 1,
        );
        final chatCtrl = Get.find<ChatController>();
        chatCtrl.openRoom(roomId, groupName);
        chatCtrl.loadRooms(); // Refresh room list
        Get.off(() => ChatRoomScreen(key: UniqueKey(), room: room));
      } else {
        Get.snackbar('Lỗi', res['msg'] ?? 'Không tạo được nhóm',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không kết nối được server',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo nhóm chat'),
        actions: [
          TextButton(
            onPressed: _creating ? null : _createRoom,
            child: _creating
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    _selectedIds.length <= 1 ? 'Chat' : 'Tạo nhóm',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(children: [
        // Selected members chips
        if (_selectedIds.isNotEmpty) _buildSelectedChips(),
        // Group name (only if >1 selected)
        if (_selectedIds.length > 1) _buildGroupNameInput(),
        // Search
        _buildSearchBar(),
        // User list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _filtered.length,
                  itemBuilder: (ctx, i) => _buildUserItem(_filtered[i]),
                ),
        ),
      ]),
    );
  }

  Widget _buildSelectedChips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.blue.shade50,
      child: Wrap(
        spacing: 6, runSpacing: 6,
        children: _selectedIds.map((id) {
          final name = _selectedNames[id] ?? '';
          return Chip(
            label: Text(name, style: const TextStyle(fontSize: 12)),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => setState(() {
              _selectedIds.remove(id);
              _selectedNames.remove(id);
            }),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGroupNameInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: TextField(
        controller: _nameController,
        decoration: InputDecoration(
          hintText: 'Tên nhóm (bắt buộc)',
          prefixIcon: const Icon(Icons.group, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm tên, phòng ban...',
          prefixIcon: const Icon(Icons.search, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        onChanged: (v) {
          _searchQuery = v;
          _applyFilter();
        },
      ),
    );
  }

  Widget _buildUserItem(Map<String, dynamic> user) {
    final id = int.tryParse(user['nguoidung_id']?.toString() ?? '');
    final name = user['hoten'] ?? '';
    final dept = user['phongban'] ?? '';
    final avatar = user['avatar'];
    final isSelected = id != null && _selectedIds.contains(id);

    final avatarUrl = avatar != null && avatar.toString().isNotEmpty
        ? '${AppConstants.baseUrl}/uploads/$avatar'
        : null;

    return InkWell(
      onTap: () => _toggleSelect(user),
      child: Container(
        color: isSelected ? Colors.blue.shade50 : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 1),
        child: Row(children: [
          // Checkbox
          Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            color: isSelected ? const Color(AppColors.primary) : Colors.grey.shade400,
            size: 24,
          ),
          const SizedBox(width: 10),
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(AppColors.primary).withOpacity(0.1),
            child: avatarUrl != null
                ? ClipOval(child: CachedNetworkImage(
                    imageUrl: avatarUrl, width: 40, height: 40, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Color(AppColors.primary),
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ))
                : Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(AppColors.primary),
                        fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis),
              if (dept.isNotEmpty)
                Text(dept, style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis),
            ],
          )),
        ]),
      ),
    );
  }
}

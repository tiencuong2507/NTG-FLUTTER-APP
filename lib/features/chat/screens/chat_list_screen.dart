// lib/features/chat/screens/chat_list_screen.dart
// ========================================================
// FIX: Long-press menu hoạt động đầy đủ
// - Ghim / Bỏ ghim
// - Tắt / Bật thông báo
// - Đánh dấu chưa đọc
// - Xóa hội thoại (có confirm dialog)
// ========================================================
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../controllers/chat_controller.dart';
import '../models/room_model.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import 'chat_room_screen.dart';
import '../../chatbot/screens/chatbot_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _search = TextEditingController();
  final _ctrl = Get.find<ChatController>();
  final _api = ApiService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('vi', timeago.ViMessages());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.bgSecondary),
      body: Column(children: [
        _buildHeader(),
        _buildSearchBar(),
        Expanded(child: _buildRoomList()),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.toNamed('/chat/new'),
        backgroundColor: const Color(AppColors.primary),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
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
        const Text('Tin nhắn',
            style: TextStyle(color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.bold)),
        const Spacer(),
        Obx(() => _ctrl.totalUnread > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${_ctrl.totalUnread}',
                    style: const TextStyle(color: Colors.white, fontSize: 12)),
              )
            : const SizedBox()),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.group_add, color: Colors.white),
          onPressed: () => Get.toNamed('/chat/new'),
          tooltip: 'Tao nhom',
        ),
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
            hintText: 'Tim kiem',
            hintStyle: TextStyle(color: Colors.white70),
            prefixIcon: Icon(Icons.search, color: Colors.white70, size: 20),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
      ),
    );
  }

  Widget _buildRoomList() {
    return Obx(() {
      if (_ctrl.isLoadingRooms.value) {
        return _buildShimmer();
      }
      var filtered = _ctrl.rooms.where((r) =>
          _searchQuery.isEmpty ||
          r.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

      if (filtered.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chat_bubble_outline, size: 64,
                color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(_searchQuery.isEmpty ? 'Chua co cuoc hoi thoai nao'
                : 'Khong tim thay "$_searchQuery"',
                style: TextStyle(color: Colors.grey.shade500)),
          ]),
        );
      }
      return RefreshIndicator(
        onRefresh: _ctrl.loadRooms,
        color: const Color(AppColors.primary),
        child: ListView.builder(
          itemCount: filtered.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) return _buildAIAssistantItem();
            return _buildRoomItem(filtered[i - 1]);
          },
        ),
      );
    });
  }

  Widget _buildAIAssistantItem() {
    return InkWell(
      onTap: () => Get.to(() => const ChatbotScreen()),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 1),
        child: Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.purple.shade50,
            child: const Text('🤖', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('NTG Assistant',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15,
                        color: Color(AppColors.textPrimary))),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('AI', style: TextStyle(fontSize: 10,
                      color: Colors.purple, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 3),
              Text('Hoi dap thong minh, tra cuu ERP...',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
            ],
          )),
          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
        ]),
      ),
    );
  }

  Widget _buildRoomItem(RoomModel room) {
    return InkWell(
      onTap: () {
        _ctrl.openRoom(room.id, room.name);
        Get.to(() => ChatRoomScreen(room: room));
      },
      onLongPress: () => _showRoomMenu(room),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 1),
        child: Row(children: [
          _buildAvatar(room),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Row(children: [
                  Flexible(child: Text(room.name,
                      style: TextStyle(
                        fontWeight: room.unread > 0
                            ? FontWeight.bold : FontWeight.w500,
                        fontSize: 15, color: const Color(AppColors.textPrimary),
                      ),
                      overflow: TextOverflow.ellipsis)),
                  if (room.pinned) const Text(' 📌', style: TextStyle(fontSize: 12)),
                  if (room.isMuted) const Text(' 🔕', style: TextStyle(fontSize: 12)),
                ])),
                const SizedBox(width: 4),
                Text(_formatTime(room.lastTime),
                    style: TextStyle(
                      fontSize: 11,
                      color: room.unread > 0
                          ? const Color(AppColors.primary)
                          : const Color(AppColors.textHint),
                    )),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Expanded(child: Text(room.lastMsg ?? 'Chua co tin nhan',
                    style: TextStyle(
                      fontSize: 13,
                      color: room.unread > 0
                          ? const Color(AppColors.textPrimary)
                          : const Color(AppColors.textSecondary),
                      fontWeight: room.unread > 0
                          ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
                if (room.unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(AppColors.unread),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${room.unread}',
                        style: const TextStyle(color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ]),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _buildAvatar(RoomModel room) {
    final imgUrl = room.type == 2 && room.otherAvatar != null
        ? '${AppConstants.baseUrl}/uploads/${room.otherAvatar}'
        : room.avatar != null
            ? '${AppConstants.baseUrl}/uploads/${room.avatar}'
            : null;

    return Stack(children: [
      CircleAvatar(
        radius: 26,
        backgroundColor: const Color(AppColors.primary).withOpacity(0.1),
        child: imgUrl != null
            ? ClipOval(child: CachedNetworkImage(
                imageUrl: imgUrl, width: 52, height: 52, fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _avatarFallback(room),
              ))
            : _avatarFallback(room),
      ),
      Positioned(bottom: 0, right: 0,
        child: Container(width: 12, height: 12,
          decoration: BoxDecoration(
            color: const Color(AppColors.online),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ))),
    ]);
  }

  Widget _avatarFallback(RoomModel room) {
    if (room.type == 2) {
      final initials = room.name.isNotEmpty ? room.name[0].toUpperCase() : '?';
      return Text(initials, style: const TextStyle(
          color: Color(AppColors.primary), fontWeight: FontWeight.bold, fontSize: 18));
    }
    return Icon(room.projectId != null ? Icons.construction : Icons.group,
        color: const Color(AppColors.primary), size: 22);
  }

  // ==========================================
  // FIX: Menu long-press hoạt động đầy đủ
  // ==========================================
  void _showRoomMenu(RoomModel room) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          // Room name header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(room.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center),
          ),
          const Divider(height: 1),

          // Ghim / Bo ghim
          ListTile(
            leading: Icon(room.pinned ? Icons.push_pin_outlined : Icons.push_pin,
                color: const Color(AppColors.textPrimary)),
            title: Text(room.pinned ? 'Bo ghim' : 'Ghim len dau'),
            onTap: () {
              Get.back();
              _togglePin(room);
            },
            dense: true,
          ),

          // Tat / Bat thong bao
          ListTile(
            leading: Icon(room.isMuted ? Icons.notifications_active : Icons.notifications_off,
                color: const Color(AppColors.textPrimary)),
            title: Text(room.isMuted ? 'Bat thong bao' : 'Tat thong bao'),
            onTap: () {
              Get.back();
              _toggleMute(room);
            },
            dense: true,
          ),

          // Danh dau chua doc
          ListTile(
            leading: const Icon(Icons.mark_chat_unread,
                color: Color(AppColors.textPrimary)),
            title: const Text('Danh dau chua doc'),
            onTap: () {
              Get.back();
              _markUnread(room);
            },
            dense: true,
          ),

          // Xoa hoi thoai
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Xoa hoi thoai', style: TextStyle(color: Colors.red)),
            onTap: () {
              Get.back();
              _confirmDeleteRoom(room);
            },
            dense: true,
          ),
          const SizedBox(height: 8),
        ],
      )),
    );
  }

  // FIX: Ghim / Bo ghim
  Future<void> _togglePin(RoomModel room) async {
    try {
      final res = room.pinned
          ? await _api.unpinRoom(room.id)
          : await _api.pinRoom(room.id);
      if (res['ok'] == 1) {
        final idx = _ctrl.rooms.indexWhere((r) => r.id == room.id);
        if (idx >= 0) {
          _ctrl.rooms[idx] = _ctrl.rooms[idx].copyWith(pinned: !room.pinned);
        }
        Get.snackbar('', room.pinned ? 'Da bo ghim' : 'Da ghim len dau',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 1));
      }
    } catch (e) {
      Get.snackbar('Loi', 'Khong the thuc hien',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // FIX: Tat / Bat thong bao
  Future<void> _toggleMute(RoomModel room) async {
    try {
      final res = await _api.muteRoom(room.id);
      if (res['ok'] == 1) {
        final idx = _ctrl.rooms.indexWhere((r) => r.id == room.id);
        if (idx >= 0) {
          _ctrl.rooms[idx] = _ctrl.rooms[idx].copyWith(isMuted: !room.isMuted);
        }
        Get.snackbar('', room.isMuted ? 'Da bat thong bao' : 'Da tat thong bao',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 1));
      }
    } catch (e) {
      Get.snackbar('Loi', 'Khong the thuc hien',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // FIX: Danh dau chua doc
  Future<void> _markUnread(RoomModel room) async {
    try {
      final res = await _api.markUnread(room.id);
      if (res['ok'] == 1) {
        final idx = _ctrl.rooms.indexWhere((r) => r.id == room.id);
        if (idx >= 0) {
          _ctrl.rooms[idx] = _ctrl.rooms[idx].copyWith(unread: 1);
        }
        Get.snackbar('', 'Da danh dau chua doc',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 1));
      }
    } catch (e) {
      Get.snackbar('Loi', 'Khong the thuc hien',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  // FIX: Xoa hoi thoai - co confirm dialog
  void _confirmDeleteRoom(RoomModel room) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Xoa hoi thoai?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
            'Ban co chac muon xoa hoi thoai voi "${room.name}"?\n\nHoi thoai se bi an khoi danh sach cua ban.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Huy', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _deleteRoom(room);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Xoa'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRoom(RoomModel room) async {
    try {
      final res = await _api.hideRoom(room.id);
      if (res['ok'] == 1) {
        _ctrl.rooms.removeWhere((r) => r.id == room.id);
        Get.snackbar('', 'Da xoa hoi thoai',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2));
      } else {
        Get.snackbar('Loi', res['msg'] ?? 'Khong the xoa',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Loi', 'Khong ket noi duoc server',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    try {
      final dt = DateTime.parse(time);
      return timeago.format(dt, locale: 'vi');
    } catch (_) { return time; }
  }

  Widget _buildShimmer() {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, __) => Container(
        color: Colors.white,
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(width: 52, height: 52,
              decoration: BoxDecoration(
                  color: Colors.grey.shade200, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 120, height: 14, color: Colors.grey.shade200,
                  margin: const EdgeInsets.only(bottom: 6)),
              Container(width: double.infinity, height: 12,
                  color: Colors.grey.shade100),
            ],
          )),
        ]),
      ),
    );
  }
}

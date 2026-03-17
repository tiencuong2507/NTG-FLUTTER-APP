// lib/features/notifications/screens/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../chat/models/room_model.dart';
import '../../chat/screens/chat_room_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  bool _showUnreadOnly = false;

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('vi', timeago.ViMessages());
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getNotifications();
      if (res['ok'] == 1 && res['data'] != null) {
        _notifications = List<Map<String, dynamic>>.from(res['data']);
        // Filter out call signals
        _notifications = _notifications.where((n) =>
            !(n['noidung'] ?? '').toString().contains('__CALL__')).toList();
      }
    } catch (e) {
      debugPrint('Load notifications error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.markNotificationRead(0); // 0 = mark all
      setState(() {
        for (var n in _notifications) { n['daxem'] = '1'; }
      });
      Get.snackbar('', 'Đã đọc tất cả', snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 1));
    } catch (_) {}
  }

  void _openRoom(Map<String, dynamic> notif) async {
    // Mark as read
    final id = int.tryParse(notif['id']?.toString() ?? '0') ?? 0;
    if (notif['daxem'] == '0') {
      _api.markNotificationRead(id);
      setState(() => notif['daxem'] = '1');
    }

    final roomId = int.tryParse(notif['idroom']?.toString() ?? '0') ?? 0;
    final roomName = notif['room_ten'] ?? '';
    final roomType = int.tryParse(notif['room_loai']?.toString() ?? '1') ?? 1;

    if (roomId > 0) {
      final room = RoomModel(id: roomId, name: roomName, type: roomType);
      final chatCtrl = Get.find<ChatController>();
      chatCtrl.openRoom(roomId, roomName);
      Get.to(() => ChatRoomScreen(key: UniqueKey(), room: room));
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _showUnreadOnly
        ? _notifications.where((n) => n['daxem'] == '0').toList()
        : _notifications;
    final unreadCount = _notifications.where((n) => n['daxem'] == '0').length;

    return Scaffold(
      backgroundColor: const Color(AppColors.bgSecondary),
      body: Column(children: [
        _buildHeader(unreadCount),
        _buildFilterBar(unreadCount),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : displayed.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(_showUnreadOnly ? 'Không có thông báo chưa đọc' : 'Chưa có thông báo nào',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        itemCount: displayed.length,
                        itemBuilder: (ctx, i) => _buildNotifItem(displayed[i]),
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _buildHeader(int unreadCount) {
    return Container(
      color: const Color(AppColors.primary),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16, right: 8, bottom: 8,
      ),
      child: Row(children: [
        const Text('Thông báo',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        if (unreadCount > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
            child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
        const Spacer(),
        if (unreadCount > 0)
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Đọc tất cả', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
      ]),
    );
  }

  Widget _buildFilterBar(int unreadCount) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        _filterChip('Tất cả (${_notifications.length})', !_showUnreadOnly,
            () => setState(() => _showUnreadOnly = false)),
        const SizedBox(width: 8),
        _filterChip('Chưa đọc ($unreadCount)', _showUnreadOnly,
            () => setState(() => _showUnreadOnly = true)),
      ]),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(AppColors.primary) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade600)),
      ),
    );
  }

  Widget _buildNotifItem(Map<String, dynamic> notif) {
    final content = notif['noidung'] ?? '';
    final isUnread = notif['daxem'] == '0';
    final roomName = notif['room_ten'] ?? '';
    final roomType = int.tryParse(notif['room_loai']?.toString() ?? '1') ?? 1;
    final time = notif['ngay'] ?? '';

    // Parse sender name and message
    String sender = '';
    String message = content;
    if (content.contains(': ')) {
      final idx = content.indexOf(': ');
      sender = content.substring(0, idx);
      message = content.substring(idx + 2);
    }

    return InkWell(
      onTap: () => _openRoom(notif),
      child: Container(
        color: isUnread ? Colors.blue.shade50 : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 1),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon
          CircleAvatar(
            radius: 20,
            backgroundColor: isUnread
                ? const Color(AppColors.primary).withOpacity(0.15)
                : Colors.grey.shade200,
            child: Icon(
              roomType == 2 ? Icons.person : Icons.group,
              color: isUnread ? const Color(AppColors.primary) : Colors.grey,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(roomName,
                    style: TextStyle(fontSize: 13, fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                        color: const Color(AppColors.textPrimary)),
                    overflow: TextOverflow.ellipsis)),
                Text(_formatTime(time),
                    style: TextStyle(fontSize: 11,
                        color: isUnread ? const Color(AppColors.primary) : Colors.grey.shade400)),
              ]),
              const SizedBox(height: 3),
              if (sender.isNotEmpty)
                Text(sender, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700)),
              Text(message,
                  style: TextStyle(fontSize: 13,
                      color: isUnread ? const Color(AppColors.textPrimary) : Colors.grey.shade600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          )),
          // Unread dot
          if (isUnread)
            Container(width: 8, height: 8, margin: const EdgeInsets.only(left: 8, top: 6),
                decoration: const BoxDecoration(color: Color(AppColors.primary), shape: BoxShape.circle)),
        ]),
      ),
    );
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '';
    try {
      return timeago.format(DateTime.parse(time), locale: 'vi');
    } catch (_) { return time ?? ''; }
  }
}

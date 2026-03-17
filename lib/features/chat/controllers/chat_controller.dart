// lib/features/chat/controllers/chat_controller.dart
import 'dart:async';
import 'package:get/get.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/polling_service.dart';
import '../models/room_model.dart';


class ChatController extends GetxController {
  final rooms = <RoomModel>[].obs;
  final messages = <MessageModel>[].obs;
  final currentRoomId = RxnInt();
  final currentRoomName = ''.obs;
  final isLoadingRooms = true.obs;
  final isLoadingMessages = false.obs;
  final isSending = false.obs;
  final typingUsers = <String>[].obs;
  final searchResults = <MessageModel>[].obs;
  final isSearching = false.obs;

  int _lastMsgId = 0;
  final _api = ApiService();
  final _polling = PollingService();

  @override
  void onInit() {
    super.onInit();
    loadRooms();
    _polling.init(_onPollTick);
  }

  Future<void> loadRooms() async {
    isLoadingRooms.value = true;
    try {
      final res = await _api.getRooms();
      print('=== LOAD ROOMS RESPONSE: $res ===');
      if (res['ok'] == 1 && res['data'] != null) {
        final list = (res['data'] as List)
            .map((r) => RoomModel.fromJson(r))
            .toList();
        // Pinned rooms lên đầu
        list.sort((a, b) {
          if (a.pinned && !b.pinned) return -1;
          if (!a.pinned && b.pinned) return 1;
          return (b.lastTime ?? '').compareTo(a.lastTime ?? '');
        });
        rooms.value = list;
      }
    } catch (e) {
      // Silently fail - sẽ retry ở poll tiếp theo
    } finally {
      isLoadingRooms.value = false;
    }
  }

  Future<void> openRoom(int roomId, String roomName) async {
    currentRoomId.value = roomId;
    currentRoomName.value = roomName;
    _lastMsgId = 0;
    messages.clear();
    isLoadingMessages.value = true;

    try {
      final res = await _api.getMessages(roomId);
      if (res['ok'] == 1 && res['data'] != null) {
        final list = (res['data'] as List)
            .map((m) => MessageModel.fromJson(m))
            .where((m) => !m.isCallSignal) // Ẩn WebRTC signals
            .toList();
        messages.value = list;
        if (list.isNotEmpty) {
          _lastMsgId = list.last.id;
        }
        // Mark as read
        _markRoomRead(roomId);
      }
    } catch (e) {
      // handle error
    } finally {
      isLoadingMessages.value = false;
    }
  }

  Future<void> sendMessage(String text, {int? replyId}) async {
    if (text.trim().isEmpty || currentRoomId.value == null) return;
    isSending.value = true;

    // Optimistic UI - thêm vào list ngay
    final tempMsg = MessageModel.temp(text);
    messages.add(tempMsg);

    try {
      final res = await _api.sendMessage(
        roomId: currentRoomId.value!,
        content: text.trim(),
        replyId: replyId,
      );
      if (res['ok'] == 1) {
        // Cập nhật room last message
        _updateRoomLastMsg(currentRoomId.value!, text);
        // Remove temp, sẽ được load lại từ poll
        messages.remove(tempMsg);
      } else {
        messages.remove(tempMsg);
        Get.snackbar('Lỗi', 'Không gửi được tin nhắn');
      }
    } catch (e) {
      messages.remove(tempMsg);
      Get.snackbar('Lỗi', 'Không có kết nối mạng');
    } finally {
      isSending.value = false;
    }
  }

  Future<void> recallMessage(int msgId) async {
    final res = await _api.recallMessage(msgId);
    if (res['ok'] == 1) {
      final idx = messages.indexWhere((m) => m.id == msgId);
      if (idx >= 0) {
        messages[idx] = messages[idx].copyWith(recalled: true);
      }
    }
  }

  Future<void> reactToMessage(int msgId, String emoji) async {
    await _api.reactMessage(msgId, emoji);
    // Reload reactions for this message
    final res = await _api.getReactions(msgId);
    if (res['ok'] == 1) {
      final idx = messages.indexWhere((m) => m.id == msgId);
      if (idx >= 0) {
        messages[idx] = messages[idx].copyWith(
          reactions: res['data'] as List<dynamic>?,
        );
      }
    }
  }

  Future<void> searchMessages(String keyword) async {
    if (currentRoomId.value == null || keyword.isEmpty) return;
    isSearching.value = true;
    final res = await _api.searchMessages(currentRoomId.value!, keyword);
    if (res['ok'] == 1 && res['data'] != null) {
      searchResults.value = (res['data'] as List)
          .map((m) => MessageModel.fromJson(m))
          .toList();
    }
    isSearching.value = false;
  }

  /// Public method để refresh messages (gọi sau khi send voice, file, etc.)
  Future<void> refreshMessages() async {
    if (currentRoomId.value == null) return;
    try {
      final res = await _api.getMessages(
        currentRoomId.value!,
        lastId: _lastMsgId,
      );
      if (res['ok'] == 1 && res['data'] != null) {
        final newMsgs = (res['data'] as List)
            .map((m) => MessageModel.fromJson(m))
            .where((m) => !m.isCallSignal)
            .toList();
        if (newMsgs.isNotEmpty) {
          messages.addAll(newMsgs);
          _lastMsgId = newMsgs.last.id;
        }
      }
    } catch (_) {}
  }

  // Smart polling callback
  void _onPollTick() async {
    // Luôn cập nhật rooms list (unread counts)
    _pollRooms();
    // Cập nhật messages nếu đang mở room
    if (currentRoomId.value != null) {
      _pollMessages();
      _pollTyping();
    }
  }

  Future<void> _pollRooms() async {
    try {
      final res = await _api.getRooms();
      if (res['ok'] == 1 && res['data'] != null) {
        final newRooms = (res['data'] as List)
            .map((r) => RoomModel.fromJson(r))
            .toList();
        // Chỉ update nếu có thay đổi (giảm rebuild)
        bool changed = false;
        for (var newRoom in newRooms) {
          final idx = rooms.indexWhere((r) => r.id == newRoom.id);
          if (idx < 0 || rooms[idx] != newRoom) {
            changed = true;
            break;
          }
        }
        if (changed || newRooms.length != rooms.length) {
          newRooms.sort((a, b) {
            if (a.pinned && !b.pinned) return -1;
            if (!a.pinned && b.pinned) return 1;
            return (b.lastTime ?? '').compareTo(a.lastTime ?? '');
          });
          rooms.value = newRooms;
        }
      }
    } catch (_) {}
  }

  Future<void> _pollMessages() async {
    if (currentRoomId.value == null) return;
    try {
      final res = await _api.getMessages(
        currentRoomId.value!,
        lastId: _lastMsgId,
      );
      if (res['ok'] == 1 && res['data'] != null) {
        final newMsgs = (res['data'] as List)
            .map((m) => MessageModel.fromJson(m))
            .where((m) => !m.isCallSignal)
            .toList();
        if (newMsgs.isNotEmpty) {
          messages.addAll(newMsgs);
          _lastMsgId = newMsgs.last.id;
          _polling.onUserInteraction(); // Reset idle timer khi có tin mới
        }
      }
    } catch (_) {}
  }

  Future<void> _pollTyping() async {
    if (currentRoomId.value == null) return;
    try {
      final res = await _api.getTyping(currentRoomId.value!);
      if (res['ok'] == 1) {
        final typing = res['typing'];
        if (typing is List) {
          typingUsers.value = typing.cast<String>();
        } else {
          typingUsers.clear();
        }
      }
    } catch (_) {}
  }

  void _markRoomRead(int roomId) {
    final idx = rooms.indexWhere((r) => r.id == roomId);
    if (idx >= 0) {
      rooms[idx] = rooms[idx].copyWith(unread: 0);
    }
  }

  void _updateRoomLastMsg(int roomId, String msg) {
    final idx = rooms.indexWhere((r) => r.id == roomId);
    if (idx >= 0) {
      rooms[idx] = rooms[idx].copyWith(lastMsg: msg);
    }
  }

  int get totalUnread {
    return rooms.fold(0, (sum, r) => sum + r.unread);
  }

  @override
  void onClose() {
    _polling.dispose();
    super.onClose();
  }
}

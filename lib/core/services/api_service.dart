// lib/core/services/api_service.dart
// ========================================================
// FIX:
// 1. sendFile() - bỏ override Content-Type cho multipart (gây conflict)
// 2. Thêm getRoomContact() để lấy SĐT cho call
// 3. sendMessage() thêm param type cho system messages
// ========================================================
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late Dio _dio;
  String? _token;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      // FIX: KHÔNG set Content-Type mặc định ở đây
      // Để Dio tự xử lý theo từng request type
      responseType: ResponseType.plain, // Nhận raw string, tự parse
    ));

    // Interceptor tự động gắn Bearer token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (_token != null && _token!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        // FIX: Chỉ set Content-Type nếu chưa được set (tránh override multipart)
        if (!options.headers.containsKey('Content-Type') &&
            options.data is! FormData) {
          options.headers['Content-Type'] = 'application/x-www-form-urlencoded';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ));
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.keyToken);
  }

  void clearSession() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyToken);
    await prefs.remove(AppConstants.keyUserId);
    await prefs.remove(AppConstants.keyUserName);
    await prefs.remove(AppConstants.keyAvatar);
  }

  // ====== AUTH ======
  Future<Map<String, dynamic>> login(String user, String pass) async {
    final res = await _dio.post(
      '/api/mobile_login.php',
      data: jsonEncode({'username': user, 'password': pass}),
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = _parse(res.data);

    // Nếu login thành công, lưu token + user info
    if (data['success'] == true && data['data'] != null) {
      final info = data['data'] as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();
      _token = info['token'] ?? '';
      await prefs.setString(AppConstants.keyToken, _token!);
      await prefs.setInt(AppConstants.keyUserId, info['user_id'] ?? 0);
      await prefs.setString(AppConstants.keyUserName, info['hoten'] ?? '');
      await prefs.setInt('user_group', _parseGroup(info['idnhom']));
      if (info['avatar'] != null) {
        await prefs.setString(AppConstants.keyAvatar, info['avatar']);
      }
    }
    return data;
  }

  // ====== CHAT ======
  Future<Map<String, dynamic>> getRooms() async {
    final res = await _dio.get('/modules/chat/nt/api.php?act=rooms');
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> getMessages(int roomId,
      {int lastId = 0}) async {
    final res = await _dio.get(
      '/modules/chat/nt/api.php?act=messages&room=$roomId&last_id=$lastId',
    );
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> sendMessage({
    required int roomId,
    required String content,
    int? replyId,
    int type = 1, // FIX: thêm param type (1=text, 4=system, 6=call)
  }) async {
    final res = await _dio.post('/modules/chat/nt/api.php?act=send', data: {
      'room': roomId,
      'msg': content,
      if (replyId != null) 'reply_id': replyId,
      if (type != 1) 'type': type,
    });
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> sendFile({
    required int roomId,
    required String filePath,
    required String fileName,
    required int fileType, // 2=image, 3=file
  }) async {
    // FIX: Tạo FormData riêng, KHÔNG set Content-Type header
    // Dio sẽ tự set multipart/form-data + boundary đúng cách
    final formData = FormData.fromMap({
      'room': roomId.toString(),
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final res = await _dio.post(
      '/modules/chat/nt/api.php?act=upload',
      data: formData,
      // FIX: KHÔNG set options Content-Type - để Dio tự handle
      options: Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> recallMessage(int msgId) async {
    final res = await _dio.post('/modules/chat/nt/api.php?act=recall',
        data: {'msg_id': msgId});
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> reactMessage(int msgId, String emoji) async {
    final res = await _dio.post('/modules/chat/nt/api.php?act=react',
        data: {'msg_id': msgId, 'emoji': emoji});
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> pinRoom(int roomId) async {
    final res = await _dio.post('/modules/chat/nt/api.php?act=pin_room',
        data: {'room': roomId});
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> muteRoom(int roomId) async {
    final res = await _dio.post('/modules/chat/nt/api.php?act=mute_room',
        data: {'room': roomId});
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> unpinRoom(int roomId) async {
    final res = await _dio.post('/modules/chat/nt/api.php?act=unpin_room&room=$roomId',
        data: {'room': roomId});
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> markUnread(int roomId) async {
    final res = await _dio.post('/modules/chat/nt/api.php?act=mark_unread&room=$roomId',
        data: {'room': roomId});
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> hideRoom(int roomId) async {
    final res = await _dio.post('/modules/chat/nt/api.php?act=hide_room&room=$roomId',
        data: {'room': roomId});
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> sendTyping(int roomId) async {
    final res = await _dio.post('/modules/chat/nt/api.php?act=typing',
        data: {'room': roomId, 'typing': 1});
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> getTyping(int roomId) async {
    final res = await _dio
        .get('/modules/chat/nt/api.php?act=who_typing&room=$roomId');
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> searchMessages(
      int roomId, String keyword) async {
    final res = await _dio.post('/modules/chat/nt/api.php?act=search_msg',
        data: {'idroom': roomId, 'keyword': keyword});
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> getReactions(int msgId) async {
    final res = await _dio
        .get('/modules/chat/nt/api.php?act=get_reactions&idmsg=$msgId');
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> createRoom({
    required String name,
    required List<int> memberIds,
    int? projectId,
  }) async {
    // FIX: PHP cần members[] là array, không phải string join
    // Dùng FormData để gửi members[] đúng format cho $_POST
    final formData = FormData.fromMap({
      'ten': name,
      if (projectId != null) 'idduan': projectId,
    });
    for (final mid in memberIds) {
      formData.fields.add(MapEntry('members[]', mid.toString()));
    }
    final res = await _dio.post(
      '/modules/chat/nt/api.php?act=create_room',
      data: formData,
    );
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> directChat(int targetUserId) async {
    final res = await _dio.post('/modules/chat/nt/api.php?act=direct',
        data: {'target_user': targetUserId});
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> getRoomMembers(int roomId) async {
    final res = await _dio
        .get('/modules/chat/nt/api.php?act=room_members&room=$roomId');
    return _parse(res.data);
  }

  // ====== NEW: Lấy thông tin contact cho call ======
  Future<Map<String, dynamic>> getRoomContact(int roomId) async {
    final res = await _dio
        .get('/modules/chat/nt/api.php?act=room_contact&room=$roomId');
    return _parse(res.data);
  }

  // ====== TASKS ======
  Future<Map<String, dynamic>> getTasks({String? status}) async {
    final query = status != null ? '&filter=$status' : '';
    final res = await _dio.get('/api/tasks.php?act=list$query');
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> getTaskDetail(int taskId) async {
    final res = await _dio.get('/api/tasks.php?act=detail&id=$taskId');
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> updateTaskStatus(
      int taskId, String status) async {
    final res = await _dio.post('/api/tasks.php?act=update_status',
        data: {'id': taskId, 'trangthai': status});
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> createTask({
    required String name,
    required String description,
    required List<int> assigneeIds,
    required int priority,
    required String deadline,
    int? roomId,
  }) async {
    final formData = FormData.fromMap({
      'ten': name,
      'mota': description,
      'nguoithuchien': assigneeIds.join(','),
      'mucuutien': priority.toString(),
      'ketthuc': deadline,
      if (roomId != null) 'idroom': roomId.toString(),
    });
    final res = await _dio.post('/api/tasks.php?act=create', data: formData);
    return _parse(res.data);
  }

  // ====== EMPLOYEES ======
  Future<Map<String, dynamic>> getEmployees({String? search}) async {
    final query = search != null ? '&q=$search' : '';
    final res = await _dio.get('/api/employees.php?act=list$query');
    return _parse(res.data);
  }

  // ====== NOTIFICATIONS ======
  Future<Map<String, dynamic>> getNotifications() async {
    final res = await _dio.get('/api/notifications.php?act=list');
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> markNotificationRead(int id) async {
    final res = await _dio.post('/api/notifications.php?act=mark_read',
        data: {'id': id});
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> getUnreadCount() async {
    final res = await _dio.get('/api/notifications.php?act=count');
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> registerFcmToken(String token) async {
    final res = await _dio.post('/api/fcm.php?act=register',
        data: {'token': token, 'platform': 'android'});
    return _parse(res.data);
  }

  // ====== AI CHATBOT (Multi-Provider: Gemini + Claude + GPT) ======
  Future<Map<String, dynamic>> getDashboard() async {
    final res = await _dio.get('/api/dashboard.php?act=summary');
    return _parse(res.data);
  }

  Future<Map<String, dynamic>> askChatbot(String question,
      {List<Map<String, String>>? history}) async {
    final res = await _dio.post(
      '/api/aibot.php',
      data: jsonEncode({
        'message': question,
        if (history != null) 'history': history,
      }),
      options: Options(
        contentType: Headers.jsonContentType,
        receiveTimeout: const Duration(seconds: 90), // AI can thoi gian dai
      ),
    );
    return _parse(res.data);
  }

  // Helper - parse nhóm user (có thể là "240" hoặc "240,267,299")
  int _parseGroup(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    final s = val.toString().trim();
    if (s.isEmpty) return 0;
    // Lấy nhóm đầu tiên nếu có nhiều nhóm
    final first = s.split(',').first.trim();
    return int.tryParse(first) ?? 0;
  }

  // Helper - parse response: có thể là Map hoặc JSON string
  Map<String, dynamic> _parse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      try {
        // Tìm vị trí JSON bắt đầu (bỏ qua HTML/warning nếu có)
        final jsonStart = data.indexOf('{');
        if (jsonStart >= 0) {
          final decoded = jsonDecode(data.substring(jsonStart));
          if (decoded is Map<String, dynamic>) return decoded;
        }
      } catch (_) {}
    }
    return {'ok': 0, 'msg': 'Parse error'};
  }
}

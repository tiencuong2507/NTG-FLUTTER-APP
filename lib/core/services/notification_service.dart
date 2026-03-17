// lib/core/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'api_service.dart';

// Handle background messages - phải là top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await NotificationService().showLocalNotification(message);
}

class NotificationService extends GetxService {
  static NotificationService get to => Get.find();

  final _fcm = FirebaseMessaging.instance;
  final _localNotif = FlutterLocalNotificationsPlugin();

  // Android notification channels
  static const _msgChannel = AndroidNotificationChannel(
    'ntg_messages',
    'Tin nhắn',
    description: 'Thông báo tin nhắn mới',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('message'),
  );

  static const _callChannel = AndroidNotificationChannel(
    'ntg_calls',
    'Cuộc gọi',
    description: 'Thông báo cuộc gọi đến',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('ringtone'),
  );

  static const _taskChannel = AndroidNotificationChannel(
    'ntg_tasks',
    'Công việc',
    description: 'Thông báo công việc',
    importance: Importance.defaultImportance,
  );

  Future<NotificationService> init() async {
    // Request permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true, // Cho incoming call
    );

    // Tạo channels
    final androidPlugin = _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_msgChannel);
    await androidPlugin?.createNotificationChannel(_callChannel);
    await androidPlugin?.createNotificationChannel(_taskChannel);

    // Init local notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotif.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Lấy và đăng ký FCM token
    final token = await _fcm.getToken();
    if (token != null) {
      await ApiService().registerFcmToken(token);
    }

    // Refresh token
    _fcm.onTokenRefresh.listen((token) {
      ApiService().registerFcmToken(token);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle notification tap khi app đang chạy
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    return this;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final type = message.data['type'] ?? 'message';
    if (type == 'call') {
      // Incoming call - hiện full screen
      _showIncomingCallNotification(message);
    } else {
      showLocalNotification(message);
    }
  }

  void _handleNotificationOpen(RemoteMessage message) {
    final type = message.data['type'] ?? 'message';
    final roomId = int.tryParse(message.data['room_id'] ?? '');
    if (type == 'message' && roomId != null) {
      Get.toNamed('/chat/room/$roomId');
    } else if (type == 'task') {
      final taskId = message.data['task_id'];
      Get.toNamed('/tasks/$taskId');
    }
  }

  Future<void> showLocalNotification(RemoteMessage message) async {
    final type = message.data['type'] ?? 'message';
    final title = message.notification?.title ?? 'NTG';
    final body = message.notification?.body ?? '';

    String channelId;
    int notifId;
    if (type == 'call') {
      channelId = _callChannel.id;
      notifId = 999;
    } else if (type == 'task') {
      channelId = _taskChannel.id;
      notifId = 2;
    } else {
      channelId = _msgChannel.id;
      notifId = int.tryParse(message.data['room_id'] ?? '1') ?? 1;
    }

    await _localNotif.show(
      notifId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelId == _callChannel.id ? 'Cuộc gọi' : 'Tin nhắn',
          importance: channelId == _callChannel.id
              ? Importance.max
              : Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      payload: '${message.data['type']}:${message.data['room_id']}',
    );
  }

  Future<void> _showIncomingCallNotification(RemoteMessage message) async {
    final callerName = message.data['caller_name'] ?? 'Unknown';
    final callType = message.data['call_type'] ?? 'audio';
    final roomId = message.data['room_id'] ?? '';

    await _localNotif.show(
      999,
      callType == 'video' ? '📹 Cuộc gọi video đến' : '📞 Cuộc gọi đến',
      callerName,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _callChannel.id,
          'Cuộc gọi',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true, // Hiện full screen khi màn hình khóa
          ongoing: true,
          autoCancel: false,
          actions: [
            const AndroidNotificationAction('reject', '❌ Từ chối',
                cancelNotification: true),
            const AndroidNotificationAction('accept', '✅ Trả lời',
                cancelNotification: true),
          ],
        ),
      ),
      payload: 'call:$roomId:${message.data['caller_id']}:$callType',
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    final parts = response.payload!.split(':');
    if (parts[0] == 'call') {
      // Navigate to call screen
      Get.toNamed('/call/incoming', arguments: {
        'roomId': int.tryParse(parts[1]),
        'callerId': int.tryParse(parts[2]),
        'callType': parts[3],
      });
    } else if (parts[0] == 'message') {
      Get.toNamed('/chat/room/${parts[1]}');
    }
  }

  Future<void> cancelCallNotification() async {
    await _localNotif.cancel(999);
  }
}

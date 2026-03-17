# NTG ERP Mobile App

Ứng dụng nội bộ Nam Thinh Group - Flutter (Android + iOS)

## Cấu trúc thư mục

```
lib/
├── main.dart                          # Entry point + routing
├── core/
│   ├── constants/
│   │   └── app_constants.dart         # Colors, API URLs, config
│   └── services/
│       ├── api_service.dart           # HTTP + session management
│       ├── polling_service.dart       # Smart adaptive polling (tiết kiệm pin)
│       ├── call_service.dart          # WebRTC voice/video call
│       └── notification_service.dart # FCM push notifications
├── features/
│   ├── auth/
│   │   └── screens/login_screen.dart
│   ├── home/
│   │   └── screens/home_screen.dart  # Bottom nav (Chat/Danh bạ/Việc/TB/Tôi)
│   ├── chat/
│   │   ├── controllers/chat_controller.dart
│   │   ├── models/room_model.dart    # RoomModel + MessageModel
│   │   └── screens/
│   │       ├── chat_list_screen.dart # Danh sách cuộc hội thoại
│   │       └── chat_room_screen.dart # Màn hình chat
│   └── call/
│       └── screens/call_screen.dart  # Incoming + Active call screens
```

## Features đã implement

✅ Smart Polling (2s active / 8s idle / 15s background)  
✅ Login Screen  
✅ Chat List (Zalo-style)  
✅ Room menu (long press: ghim/mute/xóa)  
✅ Incoming Call Screen (full screen)  
✅ Active Call Screen (audio + video)  
✅ WebRTC service  
✅ FCM Push Notifications  
✅ API Service với session cookie  

## Còn cần làm

- [ ] Chat Room Screen (bubble messages, reactions, reply, file)
- [ ] Contacts Screen
- [ ] Tasks Screen  
- [ ] Profile Screen
- [ ] Notifications Screen

## Setup để build

### 1. Cài Flutter
```bash
flutter pub get
```

### 2. Firebase Setup
- Tạo project trên https://console.firebase.google.com
- Thêm Android app: package name `com.namthinh.ntgapp`  
- Download `google-services.json` → bỏ vào `android/app/`

### 3. Backend cần thêm (anh báo em làm)
- `/api/fcm.php` - lưu FCM token
- `/api/tasks.php` - task API  
- `/api/employees.php` - danh bạ nhân viên
- Thêm gửi FCM vào `api.php` khi có tin nhắn mới

### 4. Build APK
```bash
flutter build apk --release
# APK ở: build/app/outputs/flutter-apk/app-release.apk
```

## Lưu ý pin/performance

- **Adaptive polling**: 2s khi dùng → 8s idle (30s) → 15s background
- **Smart diff**: Chỉ re-render rooms khi có thay đổi thực sự
- **Lazy loading**: Chỉ load messages khi mở room
- **Image cache**: CachedNetworkImage tự cache ảnh
- **Optimistic UI**: Tin nhắn hiện ngay khi gửi, không cần chờ server

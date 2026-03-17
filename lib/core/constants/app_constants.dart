// lib/core/constants/app_constants.dart

class AppConstants {
  // API
  static const String baseUrl = 'https://erp.namthinh.com.vn';
  static const String apiUrl = '$baseUrl/modules/chat/nt/api.php';
  static const String erpApiUrl = '$baseUrl/api';
  
  // Storage keys
  static const String keyToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserName = 'user_name';
  static const String keyAvatar = 'user_avatar';
  static const String keyFcmToken = 'fcm_token';
  
  // Polling intervals (smart - adaptive)
  static const int pollActiveMs = 2000;    // 2s khi đang dùng
  static const int pollBackgroundMs = 15000; // 15s khi app background
  static const int pollIdleMs = 8000;      // 8s khi idle
  
  // Chat
  static const int msgPageSize = 30;
  static const int maxFileSize = 20 * 1024 * 1024; // 20MB
  
  // Call timeout
  static const int callTimeoutSec = 45;
}

class AppColors {
  // Primary - Blue như Zalo
  static const int primary = 0xFF1565C0;
  static const int primaryLight = 0xFF1E88E5;
  static const int primaryDark = 0xFF0D47A1;
  
  // Background
  static const int bgPrimary = 0xFFFFFFFF;
  static const int bgSecondary = 0xFFF5F5F5;
  static const int bgChat = 0xFFECEFF1;
  
  // Text
  static const int textPrimary = 0xFF212121;
  static const int textSecondary = 0xFF757575;
  static const int textHint = 0xFFBDBDBD;
  
  // Chat bubbles
  static const int bubbleMine = 0xFF1565C0;
  static const int bubbleOther = 0xFFFFFFFF;
  static const int bubbleMineText = 0xFFFFFFFF;
  static const int bubbleOtherText = 0xFF212121;
  
  // Status
  static const int online = 0xFF4CAF50;
  static const int unread = 0xFFE53935;
  static const int warning = 0xFFFFA000;
  
  // Task status colors
  static const int taskNew = 0xFF1565C0;
  static const int taskInProgress = 0xFFFFA000;
  static const int taskDone = 0xFF4CAF50;
  static const int taskOverdue = 0xFFE53935;
}

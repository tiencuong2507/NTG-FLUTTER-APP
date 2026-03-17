// lib/core/services/call_service.dart
// ========================================================
// FIX: Chuyển từ WebRTC (phức tạp, cần signaling server)
// sang giải pháp thực tế cho app nội bộ:
// - Audio call: Gọi điện thoại trực tiếp (tel:)
// - Video call: Deep link Zalo / mở link Google Meet
// - Fallback: In-app VOIP đơn giản (phase sau)
// ========================================================
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class CallService extends GetxService {
  static CallService get to => Get.find();

  /// Gọi thoại - dùng số điện thoại trực tiếp
  Future<void> startAudioCall({
    required String phoneNumber,
    required String contactName,
    int? roomId,
  }) async {
    if (phoneNumber.isEmpty) {
      Get.snackbar(
        'Không thể gọi',
        '$contactName chưa có số điện thoại trong hệ thống',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // Chuẩn hóa số điện thoại
    final phone = _normalizePhone(phoneNumber);
    final uri = Uri.parse('tel:$phone');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        // Log cuộc gọi vào chat
        if (roomId != null) {
          await ApiService().sendMessage(
            roomId: roomId,
            content: '📞 Đã gọi thoại cho $contactName',
            type: 4, // system message
          );
        }
      } else {
        Get.snackbar(
          'Lỗi',
          'Thiết bị không hỗ trợ gọi điện',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể thực hiện cuộc gọi: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Video call - mở Zalo hoặc tạo Google Meet link
  Future<void> startVideoCall({
    required String phoneNumber,
    required String contactName,
    int? roomId,
  }) async {
    if (phoneNumber.isEmpty) {
      // Fallback: tạo Google Meet link
      await _openGoogleMeet(contactName, roomId);
      return;
    }

    // Thử mở Zalo video call
    final phone = _normalizePhone(phoneNumber);
    final zaloUri = Uri.parse('https://zalo.me/$phone');

    try {
      if (await canLaunchUrl(zaloUri)) {
        await launchUrl(zaloUri, mode: LaunchMode.externalApplication);
        if (roomId != null) {
          await ApiService().sendMessage(
            roomId: roomId,
            content: '📹 Đã gọi video cho $contactName qua Zalo',
            type: 4,
          );
        }
      } else {
        // Fallback: Google Meet
        await _openGoogleMeet(contactName, roomId);
      }
    } catch (e) {
      await _openGoogleMeet(contactName, roomId);
    }
  }

  /// Tạo và mở Google Meet
  Future<void> _openGoogleMeet(String contactName, int? roomId) async {
    final meetUri = Uri.parse('https://meet.google.com/new');
    try {
      await launchUrl(meetUri, mode: LaunchMode.externalApplication);
      if (roomId != null) {
        await ApiService().sendMessage(
          roomId: roomId,
          content: '📹 Đã tạo cuộc họp video với $contactName (Google Meet)',
          type: 4,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Lỗi',
        'Không thể mở video call',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  /// Chuẩn hóa số điện thoại VN
  String _normalizePhone(String phone) {
    var p = phone.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');
    if (p.startsWith('0')) {
      p = '+84${p.substring(1)}';
    } else if (!p.startsWith('+')) {
      p = '+84$p';
    }
    return p;
  }
}

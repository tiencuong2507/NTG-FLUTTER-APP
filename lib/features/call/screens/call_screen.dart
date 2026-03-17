// lib/features/call/screens/call_screen.dart
// ========================================================
// FIX: Thay WebRTC screen bằng confirmation dialog đơn giản
// Gọi thoại qua tel:, video qua Zalo/Google Meet
// ========================================================
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/call_service.dart';
import '../../../core/constants/app_constants.dart';

class CallConfirmSheet extends StatelessWidget {
  final String contactName;
  final String? contactPhone;
  final String? contactAvatar;
  final int? roomId;
  final bool isVideo;

  const CallConfirmSheet({
    super.key,
    required this.contactName,
    this.contactPhone,
    this.contactAvatar,
    this.roomId,
    this.isVideo = false,
  });

  /// Hiện bottom sheet xác nhận gọi
  static void show({
    required BuildContext context,
    required String contactName,
    String? contactPhone,
    String? contactAvatar,
    int? roomId,
    bool isVideo = false,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CallConfirmSheet(
        contactName: contactName,
        contactPhone: contactPhone,
        contactAvatar: contactAvatar,
        roomId: roomId,
        isVideo: isVideo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(AppColors.primary).withOpacity(0.1),
              child: Text(
                contactName.isNotEmpty ? contactName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Name
            Text(
              contactName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),

            // Phone
            if (contactPhone != null && contactPhone!.isNotEmpty)
              Text(
                contactPhone!,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Audio call
                _CallButton(
                  icon: Icons.phone,
                  label: 'Gọi thoại',
                  color: Colors.green,
                  onTap: () {
                    Get.back();
                    CallService.to.startAudioCall(
                      phoneNumber: contactPhone ?? '',
                      contactName: contactName,
                      roomId: roomId,
                    );
                  },
                ),
                // Video call
                _CallButton(
                  icon: Icons.videocam,
                  label: 'Video call',
                  color: const Color(AppColors.primary),
                  onTap: () {
                    Get.back();
                    CallService.to.startVideoCall(
                      phoneNumber: contactPhone ?? '',
                      contactName: contactName,
                      roomId: roomId,
                    );
                  },
                ),
                // Zalo
                _CallButton(
                  icon: Icons.chat_bubble,
                  label: 'Nhắn Zalo',
                  color: Colors.blue.shade600,
                  onTap: () {
                    Get.back();
                    _openZaloChat(contactPhone ?? '');
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Info text
            if (contactPhone == null || contactPhone!.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chưa có số điện thoại. Gọi thoại sẽ không khả dụng.\nVideo call sẽ dùng Google Meet.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openZaloChat(String phone) async {
    if (phone.isEmpty) {
      Get.snackbar('Lỗi', 'Không có số điện thoại',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    var p = phone.replaceAll(RegExp(r'[\s\-\.\(\)]'), '');
    if (p.startsWith('+84')) p = '0${p.substring(3)}';
    final uri = Uri.parse('https://zalo.me/$p');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể mở Zalo',
          snackPosition: SnackPosition.BOTTOM);
    }
  }
}

// Nút gọi tròn
class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}



// lib/features/home/screens/home_screen.dart
// ========================================================
// THÊM MỚI:
// - Quick Actions bottom sheet (nút "+" ở FAB thứ 2)
//   hoặc mở từ Dashboard tab
// - 3 tính năng: Scan Vật Tư, Xin Nghỉ Phép, Chấm Công GPS
// ========================================================
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../chat/controllers/chat_controller.dart';
import '../../chat/screens/chat_list_screen.dart';
import '../../contacts/screens/contacts_screen.dart';
import '../../tasks/screens/tasks_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../chatbot/screens/chatbot_screen.dart';
import '../../../core/constants/app_constants.dart';

// Import 3 màn hình mới
import '../../vattu/screens/scan_vattu_screen.dart';
import '../../hanhchinh/screens/phieu_nghi_screen.dart';
import '../../chamcong/screens/chamcong_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  final _chatCtrl = Get.put(ChatController());
  int _userGroup = 0;
  String? _token;
  int? _userId;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userGroup = prefs.getInt('user_group') ?? 0;
      _token = prefs.getString(AppConstants.keyToken);
      _userId = prefs.getInt(AppConstants.keyUserId);
      _userName = prefs.getString('user_name') ?? '';
    });
  }

  final _tabs = [
    const _TabItem(
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Tin nhắn'),
    const _TabItem(
        icon: Icons.contacts_outlined,
        activeIcon: Icons.contacts,
        label: 'Danh bạ'),
    const _TabItem(
        icon: Icons.task_outlined,
        activeIcon: Icons.task,
        label: 'Công việc'),
    const _TabItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'Dashboard'),
    const _TabItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Tôi'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: const [
          ChatListScreen(),
          ContactsScreen(),
          TasksScreen(),
          DashboardScreen(),
          ProfileScreen(),
        ],
      ),

      // FAB Stack: AI chatbot + Quick Actions
      floatingActionButton: _currentTab != 4
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Actions FAB (3 tính năng mới)
                FloatingActionButton(
                  heroTag: 'quick_actions',
                  onPressed: () => _showQuickActions(context),
                  backgroundColor: const Color(AppColors.primary),
                  elevation: 3,
                  mini: true,
                  child: const Icon(Icons.grid_view_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(height: 8),
                // AI Chatbot FAB
                FloatingActionButton(
                  heroTag: 'ai_chatbot',
                  onPressed: () => Get.to(
                    () => const ChatbotScreen(),
                    transition: Transition.rightToLeft,
                  ),
                  backgroundColor: Colors.purple,
                  elevation: 4,
                  mini: false,
                  child: const Text('🤖', style: TextStyle(fontSize: 22)),
                ),
              ],
            )
          : null,

      bottomNavigationBar: Obx(() => BottomNavigationBar(
            currentIndex: _currentTab,
            onTap: (i) {
              // Chặn nhóm 240 (nhân viên) bấm Dashboard
              if (i == 3 && _userGroup == 240) {
                Get.snackbar(
                  'Thông báo',
                  'Bạn chưa được cấp quyền menu này',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.orange.shade100,
                  colorText: Colors.orange.shade900,
                  duration: const Duration(seconds: 2),
                  icon: Icon(Icons.lock_outline, color: Colors.orange.shade700),
                  margin: const EdgeInsets.all(12),
                  borderRadius: 10,
                );
                return;
              }
              setState(() => _currentTab = i);
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: const Color(AppColors.primary),
            unselectedItemColor: Colors.grey,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            elevation: 8,
            items: _tabs.asMap().entries.map((e) {
              final i = e.key;
              final tab = e.value;
              Widget icon = Icon(i == _currentTab ? tab.activeIcon : tab.icon);
              if (i == 0 && _chatCtrl.totalUnread > 0) {
                icon = Badge(
                  label: Text('${_chatCtrl.totalUnread}'),
                  child: icon,
                );
              }
              return BottomNavigationBarItem(icon: icon, label: tab.label);
            }).toList(),
          )),
    );
  }

  // ── QUICK ACTIONS BOTTOM SHEET ────────────────────────
  void _showQuickActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickActionsSheet(
        token: _token ?? '',
        userId: _userId ?? 0,
        userName: _userName,
      ),
    );
  }
}

// ─── QUICK ACTIONS SHEET ─────────────────────────────────────

class _QuickActionsSheet extends StatelessWidget {
  final String token;
  final int userId;
  final String userName;

  const _QuickActionsSheet({
    required this.token,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Tính năng nhanh',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: Colors.black87)),
          ),
          const SizedBox(height: 16),

          // Grid 3 nút
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.document_scanner,
                  label: 'Scan\nVật Tư',
                  sublabel: 'AI nhận diện',
                  color: const Color(0xFF0891B2),
                  badge: 'AI',
                  onTap: () {
                    Get.back();
                    Get.to(() => ScanVatTuScreen(token: token, loai: 'nhap'),
                        transition: Transition.rightToLeft);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionCard(
                  icon: Icons.event_available,
                  label: 'Xin\nNghỉ Phép',
                  sublabel: 'Phép & công tác',
                  color: const Color(0xFFF59E0B),
                  onTap: () {
                    Get.back();
                    Get.to(() => PhieuNghiScreen(token: token, userId: userId),
                        transition: Transition.rightToLeft);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionCard(
                  icon: Icons.fingerprint,
                  label: 'Chấm\nCông GPS',
                  sublabel: 'Vào / Ra ca',
                  color: const Color(0xFF16A34A),
                  onTap: () {
                    Get.back();
                    Get.to(() => ChamCongScreen(
                          token: token, userId: userId, userName: userName),
                        transition: Transition.rightToLeft);
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 4),

          // Hàng 2: placeholder cho tính năng khác
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.analytics_outlined,
                  label: 'Báo Cáo\nCông Việc',
                  sublabel: 'Thống kê',
                  color: Colors.purple,
                  onTap: () {
                    Get.back();
                    Get.snackbar('Báo Cáo', 'Coming soon!',
                        snackPosition: SnackPosition.BOTTOM);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionCard(
                  icon: Icons.qr_code_scanner,
                  label: 'Scan\nQR Code',
                  sublabel: 'Tra cứu nhanh',
                  color: Colors.indigo,
                  onTap: () {
                    Get.back();
                    Get.snackbar('QR Scanner', 'Coming soon!',
                        snackPosition: SnackPosition.BOTTOM);
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Placeholder trống
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── ACTION CARD WIDGET ──────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                if (badge != null)
                  Positioned(
                    top: -5, right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(badge!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 8,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800, height: 1.3)),
            const SizedBox(height: 2),
            Text(sublabel,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

// ─── TAB ITEM MODEL ──────────────────────────────────────────

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem(
      {required this.icon, required this.activeIcon, required this.label});
}

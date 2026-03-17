// lib/features/tasks/screens/tasks_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        final filters = ['all', 'assigned', 'created'];
        _filter = filters[_tabCtrl.index];
        _loadTasks();
      }
    });
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getTasks(status: _filter);
      if (res['ok'] == 1 && res['data'] != null) {
        _tasks = List<Map<String, dynamic>>.from(res['data']);
      }
    } catch (e) {
      debugPrint('Load tasks error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.bgSecondary),
      body: Column(children: [
        _buildHeader(),
        _buildTabs(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _tasks.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.task_outlined, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('Chưa có công việc nào', style: TextStyle(color: Colors.grey.shade500)),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _loadTasks,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _tasks.length,
                        itemBuilder: (ctx, i) => _buildTaskCard(_tasks[i]),
                      ),
                    ),
        ),
      ]),
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
        const Text('Công việc',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text('${_tasks.length} việc',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ]),
    );
  }

  Widget _buildTabs() {
    return Container(
      color: const Color(AppColors.primary),
      child: TabBar(
        controller: _tabCtrl,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Tất cả'),
          Tab(text: 'Được giao'),
          Tab(text: 'Đã tạo'),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final name = task['ten'] ?? '';
    final status = int.tryParse(task['trangthai']?.toString() ?? '0') ?? 0;
    final priority = int.tryParse(task['mucuutien']?.toString() ?? '0') ?? 0;
    final progress = int.tryParse(task['tiendo']?.toString() ?? '0') ?? 0;
    final deadline = task['ketthuc'] ?? '';
    final nguoigiao = task['nguoigiao'] ?? '';
    final desc = task['mota'] ?? '';
    final assignees = task['assignees'] as List<dynamic>? ?? [];
    final isOverdue = _isOverdue(deadline, status);
    final taskId = int.tryParse(task['id']?.toString() ?? '0') ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        onTap: () => _showTaskDetail(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header: priority + status
            Row(children: [
              _buildPriorityBadge(priority),
              const SizedBox(width: 8),
              Expanded(child: Text(name,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
              _buildStatusChip(status, isOverdue),
            ]),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            // Progress bar
            if (progress > 0) ...[
              Row(children: [
                Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                        status == 2 ? Colors.green : const Color(AppColors.primary)),
                    minHeight: 6,
                  ),
                )),
                const SizedBox(width: 8),
                Text('$progress%', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ]),
              const SizedBox(height: 8),
            ],
            // Footer: assignees + deadline
            Row(children: [
              // Assignee avatars
              ...assignees.take(3).map((a) => _buildSmallAvatar(a)),
              if (assignees.length > 3)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text('+${assignees.length - 3}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ),
              const Spacer(),
              // Deadline
              Icon(Icons.access_time, size: 14,
                  color: isOverdue ? Colors.red : Colors.grey.shade400),
              const SizedBox(width: 4),
              Text(_formatDeadline(deadline),
                  style: TextStyle(fontSize: 11,
                      color: isOverdue ? Colors.red : Colors.grey.shade500)),
            ]),
            // Quick actions
            const SizedBox(height: 8),
            Row(children: [
              Text('Giao bởi: $nguoigiao',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              const Spacer(),
              if (status == 0)
                _buildActionBtn('Bắt đầu', Icons.play_arrow, Colors.blue,
                    () => _updateStatus(taskId, 1)),
              if (status == 1)
                _buildActionBtn('Hoàn thành', Icons.check, Colors.green,
                    () => _updateStatus(taskId, 2)),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildActionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildSmallAvatar(dynamic assignee) {
    final a = assignee as Map<String, dynamic>;
    final name = a['hoten'] ?? '';
    final avatar = a['avatar'];
    final url = avatar != null ? '${AppConstants.baseUrl}/uploads/$avatar' : null;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Tooltip(
        message: name,
        child: CircleAvatar(
          radius: 12,
          backgroundColor: const Color(AppColors.primary).withOpacity(0.15),
          child: url != null
              ? ClipOval(child: CachedNetworkImage(
                  imageUrl: url, width: 24, height: 24, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Text(name.isNotEmpty ? name[0] : '?',
                      style: const TextStyle(fontSize: 10, color: Color(AppColors.primary))),
                ))
              : Text(name.isNotEmpty ? name[0] : '?',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                      color: Color(AppColors.primary))),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(int priority) {
    final colors = [Colors.grey, Colors.blue, Colors.orange, Colors.red];
    final labels = ['Thấp', 'TB', 'Cao', 'Gấp'];
    final idx = priority.clamp(0, 3);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors[idx].withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors[idx].withOpacity(0.3)),
      ),
      child: Text(labels[idx],
          style: TextStyle(fontSize: 10, color: colors[idx], fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildStatusChip(int status, bool isOverdue) {
    Color color;
    String label;
    if (isOverdue && status != 2) {
      color = Colors.red; label = 'Quá hạn';
    } else if (status == 0) {
      color = Colors.blue; label = 'Mới';
    } else if (status == 1) {
      color = Colors.orange; label = 'Đang làm';
    } else {
      color = Colors.green; label = 'Hoàn thành';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }

  bool _isOverdue(String? deadline, int status) {
    if (deadline == null || deadline.isEmpty || status == 2) return false;
    try {
      return DateTime.parse(deadline).isBefore(DateTime.now());
    } catch (_) { return false; }
  }

  String _formatDeadline(String? deadline) {
    if (deadline == null || deadline.isEmpty) return '';
    try {
      final dt = DateTime.parse(deadline);
      final now = DateTime.now();
      final diff = dt.difference(now);
      if (diff.isNegative) return 'Quá ${-diff.inDays} ngày';
      if (diff.inDays == 0) return 'Hôm nay ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
      if (diff.inDays == 1) return 'Ngày mai';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return deadline ?? ''; }
  }

  Future<void> _updateStatus(int taskId, int newStatus) async {
    try {
      final res = await _api.updateTaskStatus(taskId, newStatus.toString());
      if (res['ok'] == 1) {
        Get.snackbar('', newStatus == 1 ? 'Đã bắt đầu công việc' : 'Đã hoàn thành!',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 1));
        _loadTasks();
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không cập nhật được',
          snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showTaskDetail(Map<String, dynamic> task) {
    final name = task['ten'] ?? '';
    final desc = task['mota'] ?? '';
    final nguoigiao = task['nguoigiao'] ?? '';
    final deadline = task['ketthuc'] ?? '';
    final assignees = task['assignees'] as List<dynamic>? ?? [];
    final status = int.tryParse(task['trangthai']?.toString() ?? '0') ?? 0;
    final taskId = int.tryParse(task['id']?.toString() ?? '0') ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _detailRow(Icons.person, 'Giao bởi', nguoigiao),
            _detailRow(Icons.access_time, 'Deadline', _formatDeadline(deadline)),
            _detailRow(Icons.flag, 'Trạng thái',
                status == 0 ? 'Mới' : status == 1 ? 'Đang làm' : 'Hoàn thành'),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Mô tả:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(desc, style: TextStyle(color: Colors.grey.shade700)),
            ],
            const SizedBox(height: 12),
            const Text('Người thực hiện:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...assignees.map((a) {
              final m = a as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  _buildSmallAvatar(a),
                  const SizedBox(width: 8),
                  Text(m['hoten'] ?? '', style: const TextStyle(fontSize: 14)),
                ]),
              );
            }),
            const SizedBox(height: 20),
            if (status == 0)
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () { Get.back(); _updateStatus(taskId, 1); },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bắt đầu làm'),
              )),
            if (status == 1)
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () { Get.back(); _updateStatus(taskId, 2); },
                icon: const Icon(Icons.check),
                label: const Text('Hoàn thành'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              )),
          ]),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

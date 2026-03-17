// lib/features/dashboard/screens/dashboard_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _aiSummary;
  bool _loadingAI = false;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getDashboard();
      if (res['ok'] == 1 && res['data'] != null) {
        _data = Map<String, dynamic>.from(res['data']);
      }
    } catch (e) {
      debugPrint('Dashboard error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadAISummary() async {
    setState(() => _loadingAI = true);
    try {
      final res = await _api.askChatbot(
        'Hãy tạo báo cáo tổng hợp ngắn gọn về tình hình công ty Nam Thịnh Group: '
        'nhân sự, công việc, dự án. Trình bày dạng bullet points, có nhận xét và đề xuất.',
      );
      if (res['ok'] == 1) {
        setState(() => _aiSummary = res['answer']);
      } else {
        setState(() => _aiSummary = 'Chưa thể tạo báo cáo AI. ${res['msg'] ?? ''}');
      }
    } catch (e) {
      setState(() => _aiSummary = 'Lỗi kết nối AI.');
    } finally {
      setState(() => _loadingAI = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(AppColors.bgSecondary),
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      _buildOverviewCards(),
                      const SizedBox(height: 12),
                      _buildMyTasksCard(),
                      const SizedBox(height: 12),
                      _buildTasksOverview(),
                      const SizedBox(height: 12),
                      _buildDepartmentChart(),
                      const SizedBox(height: 12),
                      _buildProjectsList(),
                      const SizedBox(height: 12),
                      _buildChatStats(),
                      const SizedBox(height: 12),
                      _buildAISummary(),
                      const SizedBox(height: 20),
                    ]),
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
        left: 16, right: 16, bottom: 12,
      ),
      child: const Row(children: [
        Icon(Icons.dashboard_rounded, color: Colors.white, size: 24),
        SizedBox(width: 10),
        Text('Dashboard NTG',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ======== OVERVIEW CARDS ========
  Widget _buildOverviewCards() {
    final totalEmp = _data['total_employees'] ?? 0;
    final totalProjects = _data['total_projects'] ?? 0;
    final tasks = _data['tasks'] as Map<String, dynamic>? ?? {};
    final totalTasks = tasks['total'] ?? 0;
    final newEmp = _data['new_employees_30d'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10, mainAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _statCard('Nhân viên', '$totalEmp', Icons.people, Colors.blue, '+$newEmp tháng này'),
        _statCard('Dự án', '$totalProjects', Icons.business, Colors.orange, 'đang triển khai'),
        _statCard('Công việc', '$totalTasks', Icons.task_alt, Colors.green, '${tasks['overdue'] ?? 0} quá hạn'),
        _statCard('Tin nhắn', '${(_data['chat'] as Map?)?['messages_today'] ?? 0}', Icons.chat, Colors.purple, 'hôm nay'),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ]),
        const Spacer(),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ]),
    );
  }

  // ======== MY TASKS ========
  Widget _buildMyTasksCard() {
    final my = _data['my_tasks'] as Map<String, dynamic>? ?? {};
    final newT = my['new'] ?? 0;
    final doing = my['doing'] ?? 0;
    final done = my['done'] ?? 0;
    final overdue = my['overdue'] ?? 0;
    final total = newT + doing + done;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.assignment_ind, size: 20, color: Color(AppColors.primary)),
          SizedBox(width: 8),
          Text('Công việc của tôi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _miniStat('Mới', newT, Colors.blue),
          _miniStat('Đang làm', doing, Colors.orange),
          _miniStat('Hoàn thành', done, Colors.green),
          _miniStat('Quá hạn', overdue, Colors.red),
        ]),
        if (total > 0) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(children: [
                if (done > 0) Expanded(flex: done, child: Container(color: Colors.green)),
                if (doing > 0) Expanded(flex: doing, child: Container(color: Colors.orange)),
                if (newT > 0) Expanded(flex: newT, child: Container(color: Colors.blue)),
                if (overdue > 0) Expanded(flex: overdue, child: Container(color: Colors.red)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Expanded(
      child: Column(children: [
        Text('$value', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]),
    );
  }

  // ======== TASKS OVERVIEW ========
  Widget _buildTasksOverview() {
    final tasks = _data['tasks'] as Map<String, dynamic>? ?? {};
    final items = [
      {'label': 'Mới', 'value': tasks['new'] ?? 0, 'color': Colors.blue},
      {'label': 'Đang làm', 'value': tasks['doing'] ?? 0, 'color': Colors.orange},
      {'label': 'Hoàn thành', 'value': tasks['done'] ?? 0, 'color': Colors.green},
      {'label': 'Quá hạn', 'value': tasks['overdue'] ?? 0, 'color': Colors.red},
    ];
    final total = (tasks['total'] ?? 1) as int;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.pie_chart, size: 20, color: Colors.orange),
          SizedBox(width: 8),
          Text('Công việc toàn công ty', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          // Simple pie chart
          SizedBox(
            width: 100, height: 100,
            child: CustomPaint(painter: _PieChartPainter(items, total)),
          ),
          const SizedBox(width: 20),
          // Legend
          Expanded(child: Column(
            children: items.map((item) {
              final val = item['value'] as int;
              final pct = total > 0 ? (val / total * 100).toStringAsFixed(0) : '0';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(width: 12, height: 12,
                      decoration: BoxDecoration(color: item['color'] as Color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${item['label']}', style: const TextStyle(fontSize: 13))),
                  Text('$val ($pct%)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                ]),
              );
            }).toList(),
          )),
        ]),
      ]),
    );
  }

  // ======== DEPARTMENT CHART ========
  Widget _buildDepartmentChart() {
    final depts = _data['departments'] as List<dynamic>? ?? [];
    if (depts.isEmpty) return const SizedBox.shrink();
    final maxVal = depts.isNotEmpty
        ? depts.map((d) => int.tryParse(d['so_nv']?.toString() ?? '0') ?? 0).reduce(max)
        : 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.bar_chart, size: 20, color: Colors.blue),
          SizedBox(width: 8),
          Text('Nhân sự theo phòng ban', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('Nam: ${_data['male'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.blue)),
          const SizedBox(width: 16),
          Text('Nữ: ${_data['female'] ?? 0}', style: const TextStyle(fontSize: 12, color: Colors.pink)),
        ]),
        const SizedBox(height: 12),
        ...depts.take(10).map((d) {
          final name = d['ten'] ?? '';
          final count = int.tryParse(d['so_nv']?.toString() ?? '0') ?? 0;
          final ratio = maxVal > 0 ? count / maxVal : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 120, child: Text(name, style: const TextStyle(fontSize: 11),
                  overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: const AlwaysStoppedAnimation(Color(AppColors.primary)),
                  minHeight: 16,
                ),
              )),
              const SizedBox(width: 8),
              SizedBox(width: 24, child: Text('$count',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right)),
            ]),
          );
        }),
      ]),
    );
  }

  // ======== PROJECTS LIST ========
  Widget _buildProjectsList() {
    final projects = _data['projects'] as List<dynamic>? ?? [];
    if (projects.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.business, size: 20, color: Colors.orange),
          const SizedBox(width: 8),
          const Text('Dự án đang triển khai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('${projects.length} dự án', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ]),
        const SizedBox(height: 12),
        ...projects.map((p) {
          final name = (p['ten'] ?? '').toString().replaceAll('Dự án ', '');
          final count = int.tryParse(p['so_nv']?.toString() ?? '0') ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(width: 8, height: 8,
                  decoration: BoxDecoration(color: Colors.orange.shade300, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text('$count NV', style: TextStyle(fontSize: 11, color: Colors.orange.shade700)),
              ),
            ]),
          );
        }),
      ]),
    );
  }

  // ======== CHAT STATS ========
  Widget _buildChatStats() {
    final chat = _data['chat'] as Map<String, dynamic>? ?? {};

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.chat_bubble, size: 20, color: Colors.purple),
          SizedBox(width: 8),
          Text('Hoạt động Chat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _miniStat('Phòng chat', chat['total_rooms'] ?? 0, Colors.purple),
          _miniStat('Tổng tin nhắn', chat['total_messages'] ?? 0, Colors.blue),
          _miniStat('Hôm nay', chat['messages_today'] ?? 0, Colors.green),
        ]),
      ]),
    );
  }

  // ======== AI SUMMARY ========
  Widget _buildAISummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Text('🤖', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('Báo cáo AI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
          if (_aiSummary == null)
            TextButton.icon(
              onPressed: _loadingAI ? null : _loadAISummary,
              icon: Icon(_loadingAI ? Icons.hourglass_top : Icons.auto_awesome, size: 16),
              label: Text(_loadingAI ? 'Đang phân tích...' : 'Tạo báo cáo',
                  style: const TextStyle(fontSize: 12)),
            ),
          if (_aiSummary != null)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: _loadingAI ? null : _loadAISummary,
              tooltip: 'Tạo lại',
            ),
        ]),
        if (_loadingAI)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Column(children: [
              CircularProgressIndicator(strokeWidth: 2),
              SizedBox(height: 8),
              Text('AI đang phân tích dữ liệu...', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
          ),
        if (_aiSummary != null) ...[
          const SizedBox(height: 12),
          SelectableText(_aiSummary!,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.5)),
        ],
        if (_aiSummary == null && !_loadingAI)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Bấm "Tạo báo cáo" để AI phân tích tổng quan tình hình công ty.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ),
      ]),
    );
  }
}

// ======== SIMPLE PIE CHART PAINTER ========
class _PieChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> items;
  final int total;
  _PieChartPainter(this.items, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    double startAngle = -pi / 2;

    for (var item in items) {
      final value = item['value'] as int;
      if (value == 0) continue;
      final sweepAngle = total > 0 ? (value / total) * 2 * pi : 0.0;
      final paint = Paint()
        ..color = item['color'] as Color
        ..style = PaintingStyle.fill;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepAngle, true, paint,
      );
      startAngle += sweepAngle;
    }

    // White center circle (donut)
    canvas.drawCircle(center, radius * 0.55, Paint()..color = Colors.white);

    // Center text
    final textPainter = TextPainter(
      text: TextSpan(text: '$total', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

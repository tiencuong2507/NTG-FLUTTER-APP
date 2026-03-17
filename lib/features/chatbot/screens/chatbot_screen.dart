// lib/features/chatbot/screens/chatbot_screen.dart
// Updated 15/03/2026 — Compatible with /api/aibot.php (multi-provider)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/app_constants.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});
  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final _api = ApiService();
  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  final List<Map<String, String>> _history = [];

  final _suggestions = [
    'Có bao nhiêu nhân viên đang làm việc?',
    'Công việc nào đang quá hạn?',
    'Tồn kho vật tư hiện tại',
    'Ai đi trễ nhiều nhất tháng này?',
    'Dự án đang triển khai',
    'Tình hình chấm công hôm nay',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(_ChatMessage(
      content: 'Xin chào! Tôi là NTG Assistant 🤖\n\n'
          'Tôi có thể giúp bạn:\n'
          '• Tra cứu nhân sự, phòng ban, chấm công\n'
          '• Xem công việc, tiến độ dự án\n'
          '• Kiểm tra tồn kho vật tư\n'
          '• Phân tích báo cáo tổng hợp\n'
          '• Tìm kiếm thông tin bên ngoài\n\n'
          'Hỏi tôi bất cứ điều gì nhé!',
      isBot: true,
      time: DateTime.now(),
      provider: 'system',
    ));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = preset ?? _msgController.text.trim();
    if (text.isEmpty || _isTyping) return;

    setState(() {
      _messages.add(_ChatMessage(content: text, isBot: false, time: DateTime.now()));
      _isTyping = true;
    });
    if (preset == null) _msgController.clear();
    _scrollToBottom();

    _history.add({'role': 'user', 'content': text});

    try {
      final res = await _api.askChatbot(text, history: _history);

      // aibot.php returns: success, reply, provider, model, intent, cost_usd
      if (res['success'] == true) {
        final answer = res['reply'] ?? 'Không có phản hồi';
        final provider = res['provider'] ?? '';
        final model = res['model'] ?? '';
        final intent = res['intent'] ?? '';

        setState(() {
          _messages.add(_ChatMessage(
            content: answer,
            isBot: true,
            time: DateTime.now(),
            provider: provider,
            model: model,
            intent: intent,
          ));
          _isTyping = false;
        });

        _history.add({'role': 'assistant', 'content': answer});
        if (_history.length > 20) {
          _history.removeRange(0, _history.length - 20);
        }
      } else {
        // Fallback: support old format (ok/answer) from chatbot.php
        if (res['ok'] == 1 && res['answer'] != null) {
          final answer = res['answer'];
          setState(() {
            _messages.add(_ChatMessage(
              content: answer,
              isBot: true,
              time: DateTime.now(),
              provider: res['source'] ?? 'ai',
            ));
            _isTyping = false;
          });
          _history.add({'role': 'assistant', 'content': answer});
        } else {
          setState(() {
            _messages.add(_ChatMessage(
              content: res['error'] ?? res['msg'] ?? 'Có lỗi xảy ra, vui lòng thử lại.',
              isBot: true,
              time: DateTime.now(),
              isError: true,
            ));
            _isTyping = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          content: 'Không kết nối được server. Vui lòng thử lại.',
          isBot: true,
          time: DateTime.now(),
          isError: true,
        ));
        _isTyping = false;
      });
    }
    _scrollToBottom();
  }

  Color _providerColor(String provider) {
    switch (provider) {
      case 'gemini': return const Color(0xFF4285F4);
      case 'claude': return const Color(0xFFD97706);
      case 'openai': return const Color(0xFF10A37F);
      case 'grok':   return const Color(0xFF1DA1F2);
      default:       return Colors.grey;
    }
  }

  String _providerLabel(String provider) {
    switch (provider) {
      case 'gemini': return 'Gemini';
      case 'claude': return 'Claude';
      case 'openai': return 'GPT';
      case 'grok':   return 'Grok';
      case 'system': return '';
      default:       return 'AI';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFE65100),
            child: Text('AI', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('NTG Assistant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Multi-AI • Gemini + Claude + GPT', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        ]),
        elevation: 0.5,
      ),
      body: Column(children: [
        // Suggestions
        if (_messages.length <= 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(spacing: 8, runSpacing: 8, children: _suggestions.map((s) =>
              ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 12)),
                backgroundColor: Colors.orange.shade50,
                side: BorderSide(color: Colors.orange.shade200),
                onPressed: () => _sendMessage(s),
              ),
            ).toList()),
          ),
        // Messages
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(12),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _messages.length) {
                return _buildTypingIndicator();
              }
              return _buildMessage(_messages[i]);
            },
          ),
        ),
        // Input
        Container(
          padding: EdgeInsets.only(
            left: 12, right: 8, top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                focusNode: _focusNode,
                decoration: InputDecoration(
                  hintText: 'Hỏi bất cứ điều gì...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              decoration: BoxDecoration(
                color: _isTyping ? Colors.grey : const Color(AppColors.primary),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(_isTyping ? Icons.hourglass_top : Icons.send_rounded,
                    color: Colors.white, size: 22),
                onPressed: _isTyping ? null : () => _sendMessage(),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange.shade400)),
          const SizedBox(width: 8),
          Text('Đang suy nghĩ...', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildMessage(_ChatMessage msg) {
    final isBot = msg.isBot;
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () => _showMsgOptions(msg),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: msg.isError
                ? Colors.red.shade50
                : isBot
                    ? Colors.grey.shade100
                    : const Color(0xFFE65100),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isBot ? 4 : 16),
              bottomRight: Radius.circular(isBot ? 16 : 4),
            ),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              msg.content,
              style: TextStyle(
                fontSize: 14,
                color: msg.isError ? Colors.red.shade700 : (isBot ? Colors.black87 : Colors.white),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Text(
                _formatTime(msg.time),
                style: TextStyle(fontSize: 10, color: isBot ? Colors.grey.shade500 : Colors.white70),
              ),
              // Provider badge
              if (isBot && msg.provider != null && msg.provider != 'system' && _providerLabel(msg.provider!).isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _providerColor(msg.provider!).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _providerLabel(msg.provider!),
                    style: TextStyle(fontSize: 9, color: _providerColor(msg.provider!), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              // Intent badge
              if (isBot && msg.intent != null && msg.intent!.isNotEmpty && msg.intent != 'general') ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    msg.intent!,
                    style: const TextStyle(fontSize: 9, color: Colors.purple, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  void _showMsgOptions(_ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Sao chép'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: msg.content));
              Get.back();
              Get.snackbar('', 'Đã sao chép', snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 1));
            },
          ),
        ]),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _ChatMessage {
  final String content;
  final bool isBot;
  final DateTime time;
  final String? provider;
  final String? model;
  final String? intent;
  final bool isError;

  _ChatMessage({
    required this.content,
    required this.isBot,
    required this.time,
    this.provider,
    this.model,
    this.intent,
    this.isError = false,
  });
}

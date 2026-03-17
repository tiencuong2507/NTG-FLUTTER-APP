// lib/features/chat/screens/chat_room_screen.dart
// ========================================================
// FIX:
// 1. Nút gọi thoại/video - mở CallConfirmSheet thay vì rỗng
// 2. Gửi hình - đã fix ở api_service, thêm error handling tốt hơn
// 3. Thêm loading indicator khi gửi file
// 4. THÊM MỚI: Voice Message (hold-to-record + STT)
// ========================================================
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../controllers/chat_controller.dart';
import '../../../core/services/api_service.dart';
import '../models/room_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../call/screens/call_screen.dart';

class ChatRoomScreen extends StatefulWidget {
  final RoomModel room;
  const ChatRoomScreen({super.key, required this.room});
  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen>
    with TickerProviderStateMixin {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _ctrl = Get.find<ChatController>();
  final _api = ApiService();
  final _focusNode = FocusNode();
  int? _myUserId;
  String? _myToken;
  int? _replyToId;
  String? _replyToText;
  bool _isSendingFile = false;

  // @mention
  List<Map<String, dynamic>> _roomMembers = [];
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showMentions = false;

  // Call info
  String? _contactPhone;
  bool _contactLoaded = false;

  // ── VOICE MESSAGE STATE ──────────────────────────────
  final _recorder = AudioRecorder();
  final _stt = SpeechToText();
  bool _sttAvailable = false;
  bool _isRecording = false;
  bool _isCanceling = false;
  bool _isListening = false;
  int _recordSecs = 0;
  Timer? _recTimer;
  File? _voicePreview;
  int _previewDuration = 0;
  String? _recordPath;
  double _slideX = 0;
  String _sttText = '';
  late AnimationController _micPulse;
  late Animation<double> _micAnim;
  // ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _loadRoomMembers();
    _loadContactInfo();
    _msgController.addListener(_onTextChanged);
    ever(_ctrl.messages, (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    });

    // Init voice
    _micPulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _micAnim = Tween<double>(begin: 1.0, end: 1.35)
        .animate(CurvedAnimation(parent: _micPulse, curve: Curves.easeInOut));
    _micPulse.stop();

    _stt.initialize(
      onError: (_) {},
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _isListening = false);
          _micPulse.stop();
          if (_sttText.isNotEmpty) {
            final cur = _msgController.text;
            _msgController.text = cur.isEmpty ? _sttText : '$cur $_sttText';
            _msgController.selection = TextSelection.fromPosition(
                TextPosition(offset: _msgController.text.length));
            _sttText = '';
            if (mounted) setState(() {});
          }
        }
      },
    ).then((ok) { if (mounted) setState(() => _sttAvailable = ok); });
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myUserId = prefs.getInt(AppConstants.keyUserId);
      _myToken = prefs.getString(AppConstants.keyToken);
    });
  }

  Future<void> _loadRoomMembers() async {
    try {
      final res = await _api.getRoomMembers(widget.room.id);
      if (res['ok'] == 1 && res['data'] != null) {
        _roomMembers = List<Map<String, dynamic>>.from(res['data']);
      }
    } catch (_) {}
  }

  Future<void> _loadContactInfo() async {
    if (widget.room.type != 2) return;
    try {
      final res = await _api.getRoomContact(widget.room.id);
      if (res['ok'] == 1 && res['data'] != null) {
        setState(() {
          _contactPhone = res['data']['didong'] ?? res['data']['dienthoai'];
          _contactLoaded = true;
        });
      }
    } catch (_) {
      _contactLoaded = true;
    }
  }

  void _onTextChanged() {
    final text = _msgController.text;
    final cursor = _msgController.selection.baseOffset;
    if (cursor < 0) { _hideMentions(); return; }
    final before = text.substring(0, cursor);
    final atIdx = before.lastIndexOf('@');
    if (atIdx < 0 ||
        (atIdx > 0 && before[atIdx - 1] != ' ' && before[atIdx - 1] != '\n')) {
      _hideMentions(); return;
    }
    final query = before.substring(atIdx + 1).toLowerCase();
    if (query.contains(' ') && query.length > 20) { _hideMentions(); return; }
    final filtered = _roomMembers.where((m) {
      final name = (m['hoten'] ?? '').toString().toLowerCase();
      final id = m['id']?.toString();
      return id != _myUserId.toString() && name.contains(query);
    }).toList();
    if (filtered.isNotEmpty) {
      setState(() { _mentionSuggestions = filtered; _showMentions = true; });
    } else { _hideMentions(); }
  }

  void _hideMentions() {
    if (_showMentions) setState(() { _showMentions = false; _mentionSuggestions = []; });
  }

  void _insertMention(Map<String, dynamic> member) {
    final text = _msgController.text;
    final cursor = _msgController.selection.baseOffset;
    final before = text.substring(0, cursor);
    final atIdx = before.lastIndexOf('@');
    final after = text.substring(cursor);
    final name = member['hoten'] ?? '';
    final newText = '${text.substring(0, atIdx)}@$name $after';
    _msgController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: (atIdx + name.length + 2).toInt()),
    );
    _hideMentions();
    _focusNode.requestFocus();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _send() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _ctrl.sendMessage(text, replyId: _replyToId);
    _msgController.clear();
    _replyToId = null;
    _replyToText = null;
    setState(() {});
  }

  // ── VOICE RECORDING ──────────────────────────────────

  Future<void> _startRecord() async {
    if (!await _recorder.hasPermission()) {
      Get.snackbar('Cần quyền', 'Vui lòng cấp quyền microphone',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
      path: _recordPath!,
    );
    setState(() { _isRecording = true; _recordSecs = 0; _isCanceling = false; });
    _micPulse.repeat(reverse: true);
    _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSecs++);
      if (_recordSecs >= 120) _stopRecord(send: true);
    });
    HapticFeedback.mediumImpact();
  }

  Future<void> _stopRecord({bool send = false}) async {
    _recTimer?.cancel();
    _micPulse.stop();
    if (!await _recorder.isRecording()) {
      if (mounted) setState(() => _isRecording = false);
      return;
    }
    final path = await _recorder.stop();
    if (mounted) setState(() => _isRecording = false);
    if (_isCanceling || !send || path == null || _recordSecs < 1) {
      if (path != null) try { File(path).deleteSync(); } catch (_) {}
      if (mounted) setState(() { _slideX = 0; });
      return;
    }
    if (mounted) setState(() { _voicePreview = File(path); _previewDuration = _recordSecs; });
    HapticFeedback.heavyImpact();
  }

  Future<void> _sendVoice() async {
    if (_voicePreview == null || _myToken == null) return;
    final file = _voicePreview!;
    final dur = _previewDuration;
    if (mounted) setState(() { _voicePreview = null; _previewDuration = 0; });

    try {
      final req = http.MultipartRequest(
        'POST', Uri.parse('${AppConstants.baseUrl}/api/voice_upload.php'));
      req.headers['Authorization'] = 'Bearer $_myToken';
      req.fields['room'] = widget.room.id.toString();
      req.fields['duration'] = dur.toString();
      req.files.add(await http.MultipartFile.fromPath('audio', file.path,
          filename: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a'));
      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == 1) {
          _ctrl.refreshMessages();
          return;
        }
      }
      Get.snackbar('Lỗi', 'Gửi voice thất bại', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Lỗi', '$e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _toggleStt() async {
    if (!_sttAvailable) return;
    if (_isListening) {
      _stt.stop();
      setState(() => _isListening = false);
      _micPulse.stop();
      return;
    }
    setState(() { _isListening = true; _sttText = ''; });
    _micPulse.repeat(reverse: true);
    await _stt.listen(
      onResult: (r) { if (mounted) setState(() => _sttText = r.recognizedWords); },
      localeId: 'vi_VN',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
    );
  }

  // ─────────────────────────────────────────────────────

  @override
  void dispose() {
    _msgController.removeListener(_onTextChanged);
    _msgController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _micPulse.dispose();
    _recorder.dispose();
    _recTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(children: [
        Expanded(child: _buildMessageList()),
        _buildTypingIndicator(),
        if (_showMentions) _buildMentionSuggestions(),
        if (_replyToText != null) _buildReplyBar(),
        if (_isSendingFile)
          Container(
            color: const Color(AppColors.primary).withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: const Row(children: [
              SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 10),
              Text('Đang gửi file...', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        _buildInputBar(),
      ]),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.room.name, style: const TextStyle(fontSize: 16)),
          if (widget.room.memberCount > 0)
            Text('${widget.room.memberCount} thành viên',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone),
          onPressed: () => _onCallPressed(isVideo: false),
          tooltip: 'Gọi thoại',
        ),
        IconButton(
          icon: const Icon(Icons.videocam),
          onPressed: () => _onCallPressed(isVideo: true),
          tooltip: 'Gọi video',
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {},
          tooltip: 'Thêm',
        ),
      ],
    );
  }

  void _onCallPressed({required bool isVideo}) {
    CallConfirmSheet.show(
      context: context,
      contactName: widget.room.name,
      contactPhone: _contactPhone,
      roomId: widget.room.id,
      isVideo: isVideo,
    );
  }

  Widget _buildMessageList() {
    return Obx(() {
      if (_ctrl.isLoadingMessages.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_ctrl.messages.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text('Chưa có tin nhắn', style: TextStyle(color: Colors.grey.shade500)),
          ]),
        );
      }
      return ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        itemCount: _ctrl.messages.length,
        itemBuilder: (ctx, i) {
          final msg = _ctrl.messages[i];
          final isMine = msg.senderId == _myUserId;
          final showAvatar = !isMine &&
              (i == 0 || _ctrl.messages[i - 1].senderId != msg.senderId);
          final showName = !isMine && widget.room.type != 2 && showAvatar;
          final showTime = i == _ctrl.messages.length - 1 ||
              _ctrl.messages[i + 1].senderId != msg.senderId;
          return _buildMessageBubble(msg, isMine, showAvatar, showName, showTime);
        },
      );
    });
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMine, bool showAvatar,
      bool showName, bool showTime) {
    if (msg.recalled) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!isMine && showAvatar) _buildMsgAvatar(msg)
            else if (!isMine) const SizedBox(width: 36),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('Tin nhắn đã được thu hồi',
                  style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showMessageMenu(msg, isMine),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showName)
              Padding(
                padding: const EdgeInsets.only(left: 42, bottom: 2),
                child: Text(msg.senderName,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500)),
              ),
            Row(
              mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMine && showAvatar) _buildMsgAvatar(msg)
                else if (!isMine) const SizedBox(width: 36),
                const SizedBox(width: 6),
                Flexible(child: _buildBubbleContent(msg, isMine)),
              ],
            ),
            if (showTime)
              Padding(
                padding: EdgeInsets.only(
                    left: isMine ? 0 : 42, right: isMine ? 4 : 0, top: 2, bottom: 4),
                child: Text(_formatMsgTime(msg.time),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleContent(MessageModel msg, bool isMine) {
    // ── VOICE message (loai=5) ──
    if (msg.type == 5 && msg.fileUrl != null) {
      return _VoiceBubble(
        fileUrl: '${AppConstants.baseUrl}${msg.fileUrl}',
        noidung: msg.content,
        isMine: isMine,
        time: _formatMsgTime(msg.time),
      );
    }

    // Image message
    if (msg.type == 2 && msg.fileUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: '${AppConstants.baseUrl}${msg.fileUrl}',
          width: 200,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
              width: 200, height: 150, color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
          errorWidget: (_, __, ___) => Container(
              width: 200, height: 80, color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, color: Colors.grey)),
        ),
      );
    }

    // File message
    if (msg.type == 3 && msg.fileName != null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMine ? const Color(AppColors.bubbleMine) : const Color(AppColors.bubbleOther),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.attach_file, size: 18, color: isMine ? Colors.white70 : Colors.grey),
          const SizedBox(width: 6),
          Flexible(child: Text(msg.fileName!,
              style: TextStyle(fontSize: 13,
                  color: isMine ? Colors.white : const Color(AppColors.textPrimary)),
              overflow: TextOverflow.ellipsis)),
        ]),
      );
    }

    // Reply preview
    Widget? replyWidget;
    if (msg.replyContent != null && msg.replyContent!.isNotEmpty) {
      replyWidget = Container(
        padding: const EdgeInsets.all(6),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isMine ? Colors.white.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(
              color: isMine ? Colors.white54 : const Color(AppColors.primary), width: 3)),
        ),
        child: Text(msg.replyContent!,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11,
                color: isMine ? Colors.white70 : Colors.grey.shade600)),
      );
    }

    // Text message
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isMine ? const Color(AppColors.bubbleMine) : const Color(AppColors.bubbleOther),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyWidget != null) replyWidget,
          _buildRichContent(msg.content, isMine),
        ],
      ),
    );
  }

  Widget _buildRichContent(String text, bool isMine) {
    final baseColor = isMine
        ? const Color(AppColors.bubbleMineText)
        : const Color(AppColors.bubbleOtherText);
    final mentionColor = isMine ? Colors.yellow : const Color(AppColors.primary);
    final regex = RegExp(r'@([\p{L}\p{M}\s]+?)(?=\s@|\s*$|[,!?.;])', unicode: true);
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start),
            style: TextStyle(fontSize: 14, color: baseColor)));
      }
      spans.add(TextSpan(text: match.group(0),
          style: TextStyle(fontSize: 14, color: mentionColor, fontWeight: FontWeight.bold)));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd),
          style: TextStyle(fontSize: 14, color: baseColor)));
    }
    if (spans.isEmpty) return Text(text, style: TextStyle(fontSize: 14, color: baseColor));
    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildMsgAvatar(MessageModel msg) {
    final url = msg.senderAvatar != null
        ? '${AppConstants.baseUrl}/uploads/${msg.senderAvatar}' : null;
    return CircleAvatar(
      radius: 15,
      backgroundColor: const Color(AppColors.primary).withOpacity(0.1),
      child: url != null
          ? ClipOval(child: CachedNetworkImage(
              imageUrl: url, width: 30, height: 30, fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Text(
                  msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Color(AppColors.primary),
                      fontWeight: FontWeight.bold, fontSize: 12))))
          : Text(msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
              style: const TextStyle(color: Color(AppColors.primary),
                  fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildTypingIndicator() {
    return Obx(() {
      if (_ctrl.typingUsers.isEmpty) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        alignment: Alignment.centerLeft,
        child: Text('${_ctrl.typingUsers.join(", ")} đang nhập...',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500,
                fontStyle: FontStyle.italic)),
      );
    });
  }

  Widget _buildMentionSuggestions() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08),
            blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _mentionSuggestions.length,
        itemBuilder: (_, i) {
          final m = _mentionSuggestions[i];
          final name = m['hoten'] ?? '';
          final avatar = m['avatar'];
          final avatarUrl = avatar != null ? '${AppConstants.baseUrl}/uploads/$avatar' : null;
          return InkWell(
            onTap: () => _insertMention(m),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(AppColors.primary).withOpacity(0.1),
                  child: avatarUrl != null
                      ? ClipOval(child: CachedNetworkImage(
                          imageUrl: avatarUrl, width: 32, height: 32, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Text(name.isNotEmpty ? name[0] : '?',
                              style: const TextStyle(color: Color(AppColors.primary),
                                  fontSize: 12, fontWeight: FontWeight.bold))))
                      : Text(name.isNotEmpty ? name[0] : '?',
                          style: const TextStyle(color: Color(AppColors.primary),
                              fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReplyBar() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        Container(width: 3, height: 30, color: const Color(AppColors.primary),
            margin: const EdgeInsets.only(right: 8)),
        Expanded(child: Text(_replyToText ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => setState(() { _replyToId = null; _replyToText = null; }),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ]),
    );
  }

  // ── INPUT BAR (cũ + voice mới) ───────────────────────

  Widget _buildInputBar() {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // STT live preview
          if (_isListening && _sttText.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.record_voice_over, color: Colors.orange, size: 15),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_sttText,
                      style: const TextStyle(fontSize: 13, color: Colors.black87))),
                ]),
              ),
            ),

          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: _voicePreview != null
                ? _buildVoicePreviewBar()
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left side: changes based on recording state
                      Expanded(
                        child: _isRecording
                            ? _buildRecordingInfo()
                            : _buildInputArea(),
                      ),
                      // Right side: mic button ALWAYS mounted (never removed from tree)
                      if (!_isRecording && _msgController.text.trim().isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.send_rounded,
                              color: Color(AppColors.primary), size: 26),
                          onPressed: _send,
                        )
                      else ...[
                        if (!_isRecording && _sttAvailable)
                          AnimatedBuilder(
                            animation: _micAnim,
                            builder: (_, __) => GestureDetector(
                              onTap: _toggleStt,
                              child: Transform.scale(
                                scale: _isListening ? _micAnim.value : 1.0,
                                child: Container(
                                  width: 36, height: 36, margin: const EdgeInsets.only(right: 2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isListening
                                        ? Colors.orange
                                        : Colors.grey.shade200,
                                    boxShadow: _isListening ? [BoxShadow(
                                        color: Colors.orange.withOpacity(0.4),
                                        blurRadius: 8, spreadRadius: 1)] : null,
                                  ),
                                  child: Icon(
                                    _isListening ? Icons.stop : Icons.record_voice_over_outlined,
                                    color: _isListening ? Colors.white : Colors.grey.shade600,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Hold-to-record mic button — KEY: always in tree, never unmounted
                        GestureDetector(
                          onLongPressStart: (_) => _startRecord(),
                          onLongPressMoveUpdate: (d) {
                            setState(() {
                              _slideX = d.offsetFromOrigin.dx;
                              _isCanceling = _slideX < -55;
                            });
                          },
                          onLongPressEnd: (_) {
                            setState(() => _slideX = 0);
                            _stopRecord(send: true);
                          },
                          child: AnimatedBuilder(
                            animation: _micAnim,
                            builder: (_, __) => Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isRecording
                                    ? Colors.red
                                    : const Color(AppColors.primary).withOpacity(0.1),
                                boxShadow: _isRecording ? [BoxShadow(
                                    color: Colors.red.withOpacity(0.4 * _micAnim.value),
                                    blurRadius: 12, spreadRadius: 2)] : null,
                              ),
                              child: Icon(Icons.mic,
                                color: _isRecording ? Colors.white : const Color(AppColors.primary),
                                size: 22),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline,
              color: Color(AppColors.primary), size: 26),
          onPressed: _showAttachMenu,
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(AppColors.bgSecondary),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _msgController,
              focusNode: _focusNode,
              maxLines: 4, minLines: 1,
              decoration: InputDecoration(
                hintText: _isListening ? '🎤 Đang nghe...' : 'Nhập tin nhắn...',
                hintStyle: TextStyle(
                    color: _isListening ? Colors.orange : const Color(AppColors.textHint)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                isDense: true,
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
            ),
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildRecordingInfo() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        AnimatedOpacity(
          opacity: _isCanceling ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 150),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.arrow_back_ios, size: 13,
                color: _isCanceling ? Colors.red : Colors.grey),
            Text(_isCanceling ? 'Thả để hủy' : '← Trượt để hủy',
                style: TextStyle(
                    color: _isCanceling ? Colors.red : Colors.grey,
                    fontSize: 12)),
          ]),
        ),
        const Spacer(),
        AnimatedBuilder(
          animation: _micAnim,
          builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: Colors.red.withOpacity(_micAnim.value))),
            const SizedBox(width: 6),
            Text(
              '${(_recordSecs ~/ 60).toString().padLeft(2, '0')}:${(_recordSecs % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ]),
        ),
        const SizedBox(width: 10),
      ]),
    );
  }

  Widget _buildVoicePreviewBar() {
    return _VoicePreviewBar(
      file: _voicePreview!,
      duration: _previewDuration,
      onCancel: () => setState(() { _voicePreview = null; }),
      onSend: _sendVoice,
      primaryColor: const Color(AppColors.primary),
    );
  }

  void _showAttachMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.photo_library, color: Color(AppColors.primary)),
            title: const Text('Chọn ảnh từ thư viện'),
            onTap: () { Get.back(); _pickImage(ImageSource.gallery); },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Color(AppColors.primary)),
            title: const Text('Chụp ảnh'),
            onTap: () { Get.back(); _pickImage(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.attach_file, color: Color(AppColors.primary)),
            title: const Text('Chọn file'),
            onTap: () { Get.back(); _pickFile(); },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.assignment_add, color: Colors.orange),
            title: const Text('Giao việc'),
            onTap: () { Get.back(); _showCreateTaskDialog(); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: source, imageQuality: 80, maxWidth: 1920);
      if (picked != null) {
        setState(() => _isSendingFile = true);
        try {
          final res = await _api.sendFile(
              roomId: widget.room.id, filePath: picked.path,
              fileName: picked.name, fileType: 2);
          if (res['ok'] != 1) {
            Get.snackbar('Lỗi', res['msg'] ?? 'Gửi ảnh thất bại',
                snackPosition: SnackPosition.BOTTOM);
          }
        } catch (e) {
          Get.snackbar('Lỗi gửi ảnh', '$e', snackPosition: SnackPosition.BOTTOM);
        } finally {
          setState(() => _isSendingFile = false);
        }
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể chọn ảnh: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false, type: FileType.custom,
        allowedExtensions: ['pdf','xlsx','xls','doc','docx','zip','rar',
            'jpg','jpeg','png','gif'],
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.path == null) return;
        setState(() => _isSendingFile = true);
        try {
          final ext = file.extension?.toLowerCase() ?? '';
          final imgExts = ['jpg', 'jpeg', 'png', 'gif'];
          final fileType = imgExts.contains(ext) ? 2 : 3;
          final res = await _api.sendFile(
              roomId: widget.room.id, filePath: file.path!,
              fileName: file.name, fileType: fileType);
          if (res['ok'] != 1) {
            Get.snackbar('Lỗi', res['msg'] ?? 'Gửi file thất bại',
                snackPosition: SnackPosition.BOTTOM);
          }
        } catch (e) {
          Get.snackbar('Lỗi gửi file', '$e', snackPosition: SnackPosition.BOTTOM);
        } finally {
          setState(() => _isSendingFile = false);
        }
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không thể chọn file: $e', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showCreateTaskDialog() {
    final taskNameCtrl = TextEditingController();
    final taskDescCtrl = TextEditingController();
    DateTime deadline = DateTime.now().add(const Duration(days: 1));
    int priority = 1;
    List<Map<String, dynamic>> allUsers = [];
    Set<int> selectedMembers = {};
    bool loadingMembers = true;
    String searchQ = '';

    _api.getEmployees().then((res) {
      if (res['ok'] == 1 && res['data'] != null) {
        final seen = <String>{};
        allUsers = List<Map<String, dynamic>>.from(res['data']).where((e) {
          final id = e['nguoidung_id']?.toString() ?? '';
          return id.isNotEmpty && seen.add(id);
        }).toList();
      }
    });

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          if (loadingMembers && allUsers.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) =>
                setS(() => loadingMembers = false));
          }
          final filtered = allUsers.where((u) =>
              (u['hoten'] ?? '').toString().toLowerCase().contains(searchQ)).toList();
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2))),
                const Text('Giao việc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(
                    controller: taskNameCtrl,
                    decoration: InputDecoration(hintText: 'Tên công việc *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true)),
                const SizedBox(height: 10),
                TextField(
                    controller: taskDescCtrl, maxLines: 2,
                    decoration: InputDecoration(hintText: 'Mô tả (không bắt buộc)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true)),
                const SizedBox(height: 10),
                Row(children: [
                  const Text('Ưu tiên: ', style: TextStyle(fontSize: 13)),
                  ...[ 1, 2, 3].map((p) {
                    final labels = {1: 'Thấp', 2: 'Trung bình', 3: 'Cao'};
                    final colors = {1: Colors.green, 2: Colors.orange, 3: Colors.red};
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(labels[p]!, style: const TextStyle(fontSize: 12)),
                        selected: priority == p,
                        selectedColor: colors[p]!.withOpacity(0.2),
                        onSelected: (_) => setS(() => priority = p),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }),
                ]),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: ctx,
                        initialDate: deadline,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setS(() => deadline = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text('Deadline: ${deadline.day}/${deadline.month}/${deadline.year}',
                          style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                if (selectedMembers.isNotEmpty)
                  Wrap(spacing: 6, runSpacing: 6,
                    children: selectedMembers.map((id) {
                      final u = allUsers.firstWhere(
                          (u) => u['nguoidung_id']?.toString() == id.toString(),
                          orElse: () => {'hoten': 'ID:$id'});
                      return Chip(
                          label: Text(u['hoten'] ?? '', style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setS(() => selectedMembers.remove(id)),
                          visualDensity: VisualDensity.compact);
                    }).toList()),
                const SizedBox(height: 8),
                TextField(
                    decoration: InputDecoration(hintText: 'Tìm nhân viên...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    onChanged: (v) => setS(() => searchQ = v.toLowerCase())),
                const SizedBox(height: 8),
                Container(
                    height: 180,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8)),
                    child: loadingMembers
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final u = filtered[i];
                              final uid = int.tryParse(u['nguoidung_id']?.toString() ?? '');
                              final sel = uid != null && selectedMembers.contains(uid);
                              return ListTile(
                                  dense: true,
                                  leading: Icon(sel ? Icons.check_circle : Icons.circle_outlined,
                                      color: sel ? const Color(AppColors.primary) : Colors.grey,
                                      size: 22),
                                  title: Text(u['hoten'] ?? '',
                                      style: const TextStyle(fontSize: 13)),
                                  subtitle: Text(u['phongban'] ?? '',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                  onTap: () {
                                    if (uid != null) {
                                      setS(() {
                                        if (sel) selectedMembers.remove(uid);
                                        else selectedMembers.add(uid);
                                      });
                                    }
                                  });
                            })),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                        onPressed: () => _submitTask(
                            taskNameCtrl.text.trim(), taskDescCtrl.text.trim(),
                            selectedMembers.toList(), priority, deadline),
                        icon: const Icon(Icons.send),
                        label: const Text('Giao việc'),
                        style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12)))),
              ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitTask(String name, String desc, List<int> assignees,
      int priority, DateTime deadline) async {
    if (name.isEmpty) {
      Get.snackbar('Lỗi', 'Nhập tên công việc', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (assignees.isEmpty) {
      Get.snackbar('Lỗi', 'Chọn người thực hiện', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    try {
      final dl =
          '${deadline.year}-${deadline.month.toString().padLeft(2, '0')}-${deadline.day.toString().padLeft(2, '0')} '
          '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}:00';
      final res = await _api.createTask(
          name: name, description: desc, assigneeIds: assignees,
          priority: priority, deadline: dl, roomId: widget.room.id);
      if (res['ok'] == 1) {
        Get.back();
        _ctrl.sendMessage(
            '📋 Giao việc: $name\n⏰ Deadline: ${deadline.day}/${deadline.month}/${deadline.year}');
        Get.snackbar('', 'Đã giao việc thành công!',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 2));
      } else {
        Get.snackbar('Lỗi', res['msg'] ?? 'Không tạo được',
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      Get.snackbar('Lỗi', 'Không kết nối được server', snackPosition: SnackPosition.BOTTOM);
    }
  }

  void _showMessageMenu(MessageModel msg, bool isMine) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.reply), title: const Text('Trả lời'),
            onTap: () {
              Get.back();
              setState(() { _replyToId = msg.id; _replyToText = msg.content; });
              _focusNode.requestFocus();
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy), title: const Text('Sao chép'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: msg.content));
              Get.back();
              Get.snackbar('', 'Đã sao chép',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 1));
            },
          ),
          if (isMine && !msg.recalled)
            ListTile(
              leading: const Icon(Icons.undo, color: Colors.orange),
              title: const Text('Thu hồi', style: TextStyle(color: Colors.orange)),
              onTap: () { Get.back(); _ctrl.recallMessage(msg.id); },
            ),
        ]),
      ),
    );
  }

  String _formatMsgTime(String? time) {
    if (time == null || time.isEmpty) return '';
    try {
      final dt = DateTime.parse(time);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return time ?? ''; }
  }
}

// ─── VOICE PREVIEW BAR ───────────────────────────────────────

class _VoicePreviewBar extends StatefulWidget {
  final File file;
  final int duration;
  final VoidCallback onCancel;
  final VoidCallback onSend;
  final Color primaryColor;
  const _VoicePreviewBar({required this.file, required this.duration,
    required this.onCancel, required this.onSend, required this.primaryColor});
  @override
  State<_VoicePreviewBar> createState() => _VoicePreviewBarState();
}

class _VoicePreviewBarState extends State<_VoicePreviewBar> {
  final _player = AudioPlayer();
  bool _playing = false;
  @override
  void dispose() { _player.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Xóa
      GestureDetector(
        onTap: widget.onCancel,
        child: Container(width: 36, height: 36,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.1)),
          child: const Icon(Icons.delete_outline, color: Colors.red, size: 18)),
      ),
      const SizedBox(width: 8),
      // Waveform player
      Expanded(child: GestureDetector(
        onTap: () async {
          if (_playing) { await _player.pause(); setState(() => _playing = false); }
          else {
            await _player.play(DeviceFileSource(widget.file.path));
            setState(() => _playing = true);
            _player.onPlayerComplete.listen((_) {
              if (mounted) setState(() => _playing = false);
            });
          }
        },
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Icon(_playing ? Icons.pause : Icons.play_arrow,
                color: widget.primaryColor, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(18, (i) => Container(
                width: 2.5,
                height: 4 + 16 * (0.3 + 0.7 * ((i * 7 + 3) % 11) / 11),
                decoration: BoxDecoration(
                  color: _playing ? widget.primaryColor : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2)),
              )),
            )),
            const SizedBox(width: 6),
            Text(
              '${(widget.duration ~/ 60).toString().padLeft(2, '0')}:${(widget.duration % 60).toString().padLeft(2, '0')}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
      )),
      const SizedBox(width: 8),
      // Gửi
      GestureDetector(
        onTap: widget.onSend,
        child: Container(width: 40, height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: widget.primaryColor),
          child: const Icon(Icons.send, color: Colors.white, size: 18)),
      ),
      const SizedBox(width: 4),
    ]);
  }
}

// ─── VOICE BUBBLE ─────────────────────────────────────────────

class _VoiceBubble extends StatefulWidget {
  final String fileUrl;
  final String noidung;
  final bool isMine;
  final String time;
  const _VoiceBubble({required this.fileUrl, required this.noidung,
    required this.isMine, required this.time});
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final _player = AudioPlayer();
  bool _playing = false;
  double _progress = 0;
  StreamSubscription? _sub;

  int get _dur {
    final m = RegExp(r'\[Voice (\d+):(\d+)\]').firstMatch(widget.noidung);
    if (m == null) return 0;
    return int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  @override
  void dispose() { _sub?.cancel(); _player.dispose(); super.dispose(); }

  Future<void> _toggle() async {
    if (_playing) { await _player.pause(); setState(() => _playing = false); return; }
    await _player.play(UrlSource(widget.fileUrl));
    setState(() => _playing = true);
    _sub?.cancel();
    _sub = _player.onPositionChanged.listen((p) {
      final d = _dur;
      if (d > 0 && mounted) setState(() => _progress = p.inMilliseconds / (d * 1000));
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _progress = 0; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.isMine;
    final dur = _dur;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: mine ? const Color(AppColors.bubbleMine) : const Color(AppColors.bubbleOther),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: _toggle,
          child: Container(width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2)),
            child: Icon(_playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white, size: 18)),
        ),
        const SizedBox(width: 8),
        Flexible(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                backgroundColor: Colors.white.withOpacity(0.25),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 3)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(
                '${(dur ~/ 60).toString().padLeft(2, '0')}:${(dur % 60).toString().padLeft(2, '0')}',
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 10)),
              Text(widget.time,
                  style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10)),
            ]),
          ],
        )),
      ]),
    );
  }
}

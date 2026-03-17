// lib/features/chat/models/room_model.dart
class RoomModel {
  final int id;
  final String name;
  final int type; // 1=group, 2=direct
  final String? avatar;
  final String? otherAvatar;
  final String? lastMsg;
  final String? lastTime;
  final int unread;
  final bool pinned;
  final bool isMuted;
  final int memberCount;
  final int? projectId;

  const RoomModel({
    required this.id,
    required this.name,
    required this.type,
    this.avatar,
    this.otherAvatar,
    this.lastMsg,
    this.lastTime,
    this.unread = 0,
    this.pinned = false,
    this.isMuted = false,
    this.memberCount = 2,
    this.projectId,
  });

  factory RoomModel.fromJson(Map<String, dynamic> j) => RoomModel(
    id: int.tryParse(j['id']?.toString() ?? '0') ?? 0,
    name: j['ten'] ?? '',
    type: int.tryParse(j['loai']?.toString() ?? '1') ?? 1,
    avatar: j['avatar'],
    otherAvatar: j['other_avatar'],
    lastMsg: j['last_msg'],
    lastTime: j['last_time'],
    unread: int.tryParse(j['unread']?.toString() ?? '0') ?? 0,
    pinned: (j['pinned']?.toString() ?? '0') == '1',
    isMuted: (j['is_muted']?.toString() ?? '0') == '1',
    memberCount: int.tryParse(j['so_thanh_vien']?.toString() ?? '2') ?? 2,
    projectId: j['idduan'] != null ? int.tryParse(j['idduan'].toString()) : null,
  );

  RoomModel copyWith({
    String? lastMsg,
    String? lastTime,
    int? unread,
    bool? pinned,
    bool? isMuted,
  }) => RoomModel(
    id: id, name: name, type: type, avatar: avatar, otherAvatar: otherAvatar,
    lastMsg: lastMsg ?? this.lastMsg,
    lastTime: lastTime ?? this.lastTime,
    unread: unread ?? this.unread,
    pinned: pinned ?? this.pinned,
    isMuted: isMuted ?? this.isMuted,
    memberCount: memberCount, projectId: projectId,
  );

  bool operator ==(Object other) =>
      other is RoomModel && other.id == id &&
      other.lastMsg == lastMsg && other.unread == unread &&
      other.pinned == pinned && other.isMuted == isMuted;

  @override
  int get hashCode => id.hashCode;
}

// lib/features/chat/models/message_model.dart (trong cùng file cho gọn)
class MessageModel {
  final int id;
  final int senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final int type; // 1=text, 2=image, 3=file, 6=call_signal
  final bool recalled;
  final bool pinned;
  final int? replyId;
  final String? replyContent;
  final String? time;
  final List<dynamic>? reactions;
  final String? fileUrl;
  final String? fileName;
  final bool isTemp; // Optimistic UI

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    this.type = 1,
    this.recalled = false,
    this.pinned = false,
    this.replyId,
    this.replyContent,
    this.time,
    this.fileUrl,
    this.fileName,
    this.reactions,
    this.isTemp = false,
  });

  bool get isCallSignal => content.startsWith('__CALL__');
  bool get isImage => type == 2;
  bool get isFile => type == 3;
  bool get isSystem => type == 4;

  factory MessageModel.fromJson(Map<String, dynamic> j) => MessageModel(
    id: int.tryParse(j['id']?.toString() ?? '0') ?? 0,
    senderId: int.tryParse(j['idnguoidung']?.toString() ?? '0') ?? 0,
    senderName: j['hoten'] ?? j['ten'] ?? '',
    senderAvatar: j['avatar'],
    content: j['noidung'] ?? '',
    type: int.tryParse(j['loai']?.toString() ?? '1') ?? 1,
    recalled: (j['recalled']?.toString() ?? '0') == '1',
    pinned: (j['pinned']?.toString() ?? '0') == '1',
    replyId: j['reply_id'] != null ? int.tryParse(j['reply_id'].toString()) : null,
    replyContent: j['reply_content'],
    time: j['ngaygui'] ?? j['thoigian'] ?? j['created_at'],
    fileUrl: j['file_url'],
    fileName: j['file_ten'],
    reactions: j['reactions'] as List<dynamic>?,
  );

  // Optimistic temporary message
  factory MessageModel.temp(String text) => MessageModel(
    id: -DateTime.now().millisecondsSinceEpoch,
    senderId: 0,
    senderName: '',
    content: text,
    type: 1,
    isTemp: true,
    time: DateTime.now().toIso8601String(),
  );

  MessageModel copyWith({
    bool? recalled,
    List<dynamic>? reactions,
  }) => MessageModel(
    id: id, senderId: senderId, senderName: senderName,
    senderAvatar: senderAvatar, content: content, type: type,
    recalled: recalled ?? this.recalled,
    pinned: pinned, replyId: replyId, replyContent: replyContent,
    time: time, fileUrl: fileUrl, fileName: fileName,
    reactions: reactions ?? this.reactions,
  );
}

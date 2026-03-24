import 'package:cloud_firestore/cloud_firestore.dart';

class MessageReaction {
  final String emoji;
  final List<String> userIds;

  MessageReaction({
    required this.emoji,
    required this.userIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'emoji': emoji,
      'userIds': userIds,
    };
  }

  factory MessageReaction.fromMap(Map<String, dynamic> map) {
    return MessageReaction(
      emoji: map['emoji'] ?? '',
      userIds: List<String>.from(map['userIds'] ?? []),
    );
  }
}

class MessageReply {
  final String messageId;
  final String authorName;
  final String content;

  MessageReply({
    required this.messageId,
    required this.authorName,
    required this.content,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'authorName': authorName,
      'content': content,
    };
  }

  factory MessageReply.fromMap(Map<String, dynamic> map) {
    return MessageReply(
      messageId: map['messageId'] ?? '',
      authorName: map['authorName'] ?? '',
      content: map['content'] ?? '',
    );
  }
}

class Message {
  final String id;
  final String channelId;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime timestamp;
  final bool isEdited;
  final String? imageUrl;
  final List<String> attachments;
  final List<String> mentions;
  final List<MessageReaction> reactions;
  final MessageReply? replyTo;
  final bool isPinned;
  final DateTime? pinnedAt;

  Message({
    required this.id,
    required this.channelId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.timestamp,
    this.isEdited = false,
    this.imageUrl,
    this.attachments = const [],
    this.mentions = const [],
    this.reactions = const [],
    this.replyTo,
    this.isPinned = false,
    this.pinnedAt,
  });

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    return Message(
      id: id,
      channelId: map['channelId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isEdited: map['isEdited'] ?? false,
      imageUrl: map['imageUrl'],
      attachments: List<String>.from(map['attachments'] ?? []),
      mentions: List<String>.from(map['mentions'] ?? []),
      reactions: (map['reactions'] as List<dynamic>?)
              ?.map((r) => MessageReaction.fromMap(r as Map<String, dynamic>))
              .toList() ??
          [],
      replyTo: map['replyTo'] != null
          ? MessageReply.fromMap(map['replyTo'] as Map<String, dynamic>)
          : null,
      isPinned: map['isPinned'] ?? false,
      pinnedAt: (map['pinnedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'channelId': channelId,
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'isEdited': isEdited,
      'imageUrl': imageUrl,
      'attachments': attachments,
      'mentions': mentions,
      'reactions': reactions.map((r) => r.toMap()).toList(),
      'replyTo': replyTo?.toMap(),
      'isPinned': isPinned,
      'pinnedAt': pinnedAt != null ? Timestamp.fromDate(pinnedAt!) : null,
    };
  }
}
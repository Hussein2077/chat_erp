int asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse(value.toString());
}

DateTime? asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.parse(value.toString());
}

class UserModel {
  final int id;
  final String username;
  final String displayName;
  final String? avatarUrl;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: asInt(json['id']),
      username: json['username']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? json['username']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}

class AttachmentModel {
  final int id;
  final String fileName;
  final String contentType;
  final int fileSize;
  final DateTime createdAt;

  AttachmentModel({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.fileSize,
    required this.createdAt,
  });

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: asInt(json['id']),
      fileName: json['fileName']?.toString() ?? 'file',
      contentType: json['contentType']?.toString() ?? 'application/octet-stream',
      fileSize: asInt(json['fileSize'] ?? 0),
      createdAt: asDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class MessageModel {
  final int id;
  final int conversationId;
  final UserModel sender;
  final String type;
  final String? content;
  final List<AttachmentModel> attachments;
  final DateTime createdAt;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.sender,
    required this.type,
    this.content,
    required this.attachments,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: asInt(json['id']),
      conversationId: asInt(json['conversationId']),
      sender: UserModel.fromJson(Map<String, dynamic>.from(json['sender'] as Map)),
      type: json['type']?.toString() ?? 'TEXT',
      content: json['content']?.toString(),
      attachments: (json['attachments'] as List? ?? [])
          .map((a) => AttachmentModel.fromJson(Map<String, dynamic>.from(a as Map)))
          .toList(),
      createdAt: asDate(json['createdAt']) ?? DateTime.now(),
    );
  }
}

class ChatSummaryModel {
  final int id;
  final String type;
  final String? name;
  final String? avatarUrl;
  final MessageModel? lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  ChatSummaryModel({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
  });

  ChatSummaryModel copyWith({
    MessageModel? lastMessage,
    int? unreadCount,
    DateTime? updatedAt,
    String? name,
  }) {
    return ChatSummaryModel(
      id: id,
      type: type,
      name: name ?? this.name,
      avatarUrl: avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ChatSummaryModel.fromJson(Map<String, dynamic> json) {
    return ChatSummaryModel(
      id: asInt(json['id']),
      type: json['type']?.toString() ?? 'PRIVATE',
      name: json['name']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(Map<String, dynamic>.from(json['lastMessage'] as Map))
          : null,
      unreadCount: asInt(json['unreadCount'] ?? 0),
      updatedAt: asDate(json['updatedAt']) ?? DateTime.now(),
    );
  }
}

class ConversationModel {
  final int id;
  final String type;
  final String? name;

  ConversationModel({required this.id, required this.type, this.name});

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: asInt(json['id']),
      type: json['type']?.toString() ?? 'PRIVATE',
      name: json['name']?.toString(),
    );
  }
}

class ChatListEvent {
  final String eventType;
  final int chatId;
  final MessageModel? message;
  final int unreadCount;
  final DateTime? chatUpdatedAt;

  ChatListEvent({
    required this.eventType,
    required this.chatId,
    this.message,
    required this.unreadCount,
    this.chatUpdatedAt,
  });

  factory ChatListEvent.fromJson(Map<String, dynamic> json) {
    return ChatListEvent(
      eventType: json['eventType']?.toString() ?? 'NEW_MESSAGE',
      chatId: asInt(json['chatId']),
      message: json['message'] != null
          ? MessageModel.fromJson(Map<String, dynamic>.from(json['message'] as Map))
          : null,
      unreadCount: asInt(json['unreadCount'] ?? 0),
      chatUpdatedAt: asDate(json['chatUpdatedAt']),
    );
  }
}

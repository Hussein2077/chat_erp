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
      id: json['id'],
      username: json['username'],
      displayName: json['displayName'] ?? json['username'],
      avatarUrl: json['avatarUrl'],
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
      id: json['id'],
      fileName: json['fileName'],
      contentType: json['contentType'],
      fileSize: json['fileSize'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class MessageModel {
  final int id;
  final int conversationId;
  final UserModel sender;
  final String type; // TEXT, FILE, SYSTEM
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
      id: json['id'],
      conversationId: json['conversationId'],
      sender: UserModel.fromJson(json['sender']),
      type: json['type'],
      content: json['content'],
      attachments: (json['attachments'] as List? ?? [])
          .map((a) => AttachmentModel.fromJson(a))
          .toList(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class ChatSummaryModel {
  final int id;
  final String type; // PRIVATE, GROUP
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

  factory ChatSummaryModel.fromJson(Map<String, dynamic> json) {
    return ChatSummaryModel(
      id: json['id'],
      type: json['type'],
      name: json['name'],
      avatarUrl: json['avatarUrl'],
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(json['lastMessage'])
          : null,
      unreadCount: json['unreadCount'] ?? 0,
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

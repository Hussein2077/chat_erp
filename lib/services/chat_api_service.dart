import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth/user_session.dart';
import '../core/constants/api_constants.dart';
import '../models/chat_models.dart';

class ChatApiService {
  ChatApiService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.headers['X-User-Id'] = UserSession.currentUser.id.toString();
          return handler.next(options);
        },
      ),
    );
  }

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  Future<List<UserModel>> searchUsers(String query) async {
    final response = await _dio.get('/api/users/search', queryParameters: {'q': query});
    final List list = response.data['data'] as List? ?? [];
    return list.map((json) => UserModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();
  }

  Future<List<ChatSummaryModel>> listChats() async {
    final response = await _dio.get('/api/chats');
    final List list = response.data['data'] as List? ?? [];
    return list.map((json) => ChatSummaryModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();
  }

  Future<ConversationModel> getOrCreatePrivateChat(int targetUserId) async {
    final response = await _dio.post('/api/chats/private', data: {'userId': targetUserId});
    return ConversationModel.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<({List<MessageModel> messages, bool hasMore, int? nextCursor})> getMessages(
    int chatId, {
    int limit = 50,
    int? before,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (before != null) params['before'] = before;
    final response = await _dio.get('/api/chats/$chatId/messages', queryParameters: params);
    final List list = response.data['data'] as List? ?? [];
    final messages = list.map((json) => MessageModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();
    final pagination = Map<String, dynamic>.from(response.data['pagination'] as Map? ?? {});
    return (
      messages: messages,
      hasMore: pagination['hasMore'] == true,
      nextCursor: pagination['nextCursor'] == null ? null : asInt(pagination['nextCursor']),
    );
  }

  Future<MessageModel> sendTextMessage(int chatId, String text) async {
    final response = await _dio.post(
      '/api/chats/$chatId/messages',
      data: {'type': 'TEXT', 'content': text},
    );
    return MessageModel.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
  }

  Future<void> markRead(int chatId, int messageId) async {
    await _dio.post('/api/chats/$chatId/read', data: {'messageId': messageId});
  }

  Future<MessageModel> uploadFileMessage({
    required int chatId,
    required PlatformFile file,
    String? content,
  }) async {
    final MultipartFile multipartFile;
    if (file.bytes != null) {
      multipartFile = MultipartFile.fromBytes(file.bytes!, filename: file.name);
    } else if (file.path != null) {
      multipartFile = await MultipartFile.fromFile(file.path!, filename: file.name);
    } else {
      throw Exception('Invalid file data');
    }

    final formData = FormData.fromMap({
      'file': multipartFile,
      if (content != null && content.isNotEmpty) 'content': content,
    });

    final response = await _dio.post('/api/chats/$chatId/messages/files', data: formData);
    return MessageModel.fromJson(Map<String, dynamic>.from(response.data['data'] as Map));
  }

  String getFileDownloadUrl(int attachmentId) {
    return '${ApiConstants.baseUrl}/api/files/$attachmentId?userId=${UserSession.currentUser.id}';
  }

  Future<void> openAttachment(int attachmentId) async {
    final uri = Uri.parse(getFileDownloadUrl(attachmentId));
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }
}

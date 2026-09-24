import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants/api_constants.dart';
import '../core/auth/user_session.dart';
import '../models/chat_models.dart';

class ChatApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  ChatApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['X-User-Id'] = UserSession.currentUser.id.toString();
        return handler.next(options);
      },
    ));
  }

  Future<List<UserModel>> searchUsers(String query) async {
    final response = await _dio.get('/api/users/search', queryParameters: {'q': query});
    final List list = response.data['data'];
    return list.map((json) => UserModel.fromJson(json)).toList();
  }

  Future<List<ChatSummaryModel>> listChats() async {
    final response = await _dio.get('/api/chats');
    final List list = response.data['data'];
    return list.map((json) => ChatSummaryModel.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> getOrCreatePrivateChat(int targetUserId) async {
    final response = await _dio.post('/api/chats/private', data: {
      'userId': targetUserId,
    });
    return response.data['data'];
  }

  Future<Map<String, dynamic>> getMessages(int chatId, {int limit = 50, int? before}) async {
    final Map<String, dynamic> params = {'limit': limit};
    if (before != null) params['before'] = before;

    final response = await _dio.get(
      '/api/chats/$chatId/messages',
      queryParameters: params,
    );

    final List list = response.data['data'];
    final messages = list.map((json) => MessageModel.fromJson(json)).toList();
    final pagination = response.data['pagination'];

    return {
      'messages': messages,
      'hasMore': pagination['hasMore'] as bool,
      'nextCursor': pagination['nextCursor'] as int?,
    };
  }

  Future<void> markRead(int chatId, int messageId) async {
    await _dio.post('/api/chats/$chatId/read', data: {
      'messageId': messageId,
    });
  }

  /// Upload a file message. Works on Flutter Web (bytes) and native (path).
  Future<MessageModel> uploadFileMessage({
    required int chatId,
    required PlatformFile file,
    String? content,
  }) async {
    MultipartFile multipartFile;

    // Try path first (native), then readAsBytes (web)
    if (file.path != null) {
      multipartFile = await MultipartFile.fromFile(
        file.path!,
        filename: file.name,
      );
    } else {
      // Flutter Web: no path, read bytes async
      final bytes = await file.readAsBytes();
      multipartFile = MultipartFile.fromBytes(
        bytes,
        filename: file.name,
      );
    }

    final formData = FormData.fromMap({
      'file': multipartFile,
      if (content != null && content.isNotEmpty) 'content': content,
    });

    final response = await _dio.post(
      '/api/chats/$chatId/messages/files',
      data: formData,
    );

    return MessageModel.fromJson(response.data['data']);
  }

  String getFileDownloadUrl(int attachmentId) {
    return '${ApiConstants.baseUrl}/api/files/$attachmentId';
  }
}

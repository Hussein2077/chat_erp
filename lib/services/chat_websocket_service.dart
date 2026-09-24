import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import '../core/constants/api_constants.dart';
import '../core/auth/user_session.dart';
import '../models/chat_models.dart';

class ChatWebSocketService {
  StompClient? _client;
  final Map<int, StompUnsubscribe> _subscriptions = {};

  void connect({required Function() onConnected}) {
    _client = StompClient(
      config: StompConfig(
        url: ApiConstants.wsUrl,
        onConnect: (StompFrame frame) {
          onConnected();
        },
        onWebSocketError: (dynamic error) => print('WebSocket Error: $error'),
        onStompError: (StompFrame frame) => print('STOMP Error: ${frame.body}'),
        stompConnectHeaders: {
          'X-User-Id': UserSession.currentUser.id.toString(),
        },
      ),
    );

    _client?.activate();
  }

  void subscribeToChat(int chatId, Function(MessageModel message) onMessageReceived) {
    if (_client == null || !_client!.connected) return;

    final unsubscribeFn = _client!.subscribe(
      destination: '/topic/chats/$chatId',
      callback: (StompFrame frame) {
        if (frame.body != null) {
          final json = jsonDecode(frame.body!);
          final message = MessageModel.fromJson(json);
          onMessageReceived(message);
        }
      },
    );

    _subscriptions[chatId] = unsubscribeFn;
  }

  void unsubscribeFromChat(int chatId) {
    _subscriptions[chatId]?.call();
    _subscriptions.remove(chatId);
  }

  void sendMessage(int chatId, String text) {
    if (_client == null || !_client!.connected) return;

    _client!.send(
      destination: '/app/chats/$chatId/messages',
      headers: {
        'X-User-Id': UserSession.currentUser.id.toString(),
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'type': 'TEXT',
        'content': text,
      }),
    );
  }

  void disconnect() {
    _client?.deactivate();
  }
}

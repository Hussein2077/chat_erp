import 'dart:convert';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../core/auth/user_session.dart';
import '../core/constants/api_constants.dart';
import '../models/chat_models.dart';

class ChatWebSocketService {
  StompClient? _client;
  final Map<String, StompUnsubscribe> _subscriptions = {};

  bool get isConnected => _client?.connected == true;

  void connect({
    required void Function() onConnected,
    void Function(String message)? onError,
  }) {
    disconnect();
    _client = StompClient(
      config: StompConfig(
        url: ApiConstants.wsUrl,
        reconnectDelay: const Duration(seconds: 3),
        onConnect: (_) => onConnected(),
        onWebSocketError: (dynamic error) => onError?.call(error.toString()),
        onStompError: (frame) => onError?.call(frame.body ?? 'STOMP error'),
        stompConnectHeaders: {
          'X-User-Id': UserSession.currentUser.id.toString(),
        },
        webSocketConnectHeaders: {
          'X-User-Id': UserSession.currentUser.id.toString(),
        },
      ),
    );
    _client!.activate();
  }

  void subscribeToChat(int chatId, void Function(MessageModel message) onMessage) {
    _subscribe('/topic/chats/$chatId', (frame) {
      if (frame.body == null) return;
      onMessage(MessageModel.fromJson(Map<String, dynamic>.from(jsonDecode(frame.body!) as Map)));
    });
  }

  void subscribeToChatList(void Function(ChatListEvent event) onEvent) {
    final userId = UserSession.currentUser.id;
    _subscribe('/topic/users/$userId/chats', (frame) {
      if (frame.body == null) return;
      onEvent(ChatListEvent.fromJson(Map<String, dynamic>.from(jsonDecode(frame.body!) as Map)));
    });
  }

  void unsubscribeFromChat(int chatId) {
    _subscriptions.remove('/topic/chats/$chatId')?.call();
  }

  void sendMessage(int chatId, String text) {
    if (!isConnected) return;
    _client!.send(
      destination: '/app/chats/$chatId/messages',
      headers: {
        'X-User-Id': UserSession.currentUser.id.toString(),
        'content-type': 'application/json',
      },
      body: jsonEncode({'type': 'TEXT', 'content': text}),
    );
  }

  void disconnect() {
    for (final unsubscribe in _subscriptions.values) {
      unsubscribe();
    }
    _subscriptions.clear();
    _client?.deactivate();
    _client = null;
  }

  void _subscribe(String destination, void Function(StompFrame frame) callback) {
    if (!isConnected) return;
    _subscriptions.remove(destination)?.call();
    _subscriptions[destination] = _client!.subscribe(destination: destination, callback: callback);
  }
}

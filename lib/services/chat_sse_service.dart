import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_models.dart';
import '../core/constants/api_constants.dart';
import '../models/global_chat_event.dart';

/// Service that connects to the Spring Boot SSE endpoint
/// `/api/chats/events` and streams `GlobalChatEvent` objects.
///
/// The Flutter UI can listen to `eventStream` and update the chat list
/// in real‑time.
class ChatSseService {
  final _controller = StreamController<GlobalChatEvent>.broadcast();
  Stream<GlobalChatEvent> get eventStream => _controller.stream;

  /// Starts the SSE connection for the current user.
  /// Call this once (e.g. in `initState` of the home screen).
  Future<void> start() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/api/chats/events');
    final request = http.Request('GET', uri);
    request.headers['Accept'] = 'text/event-stream';
    request.headers['X-User-Id'] = UserSession.currentUser.id.toString();

    final client = http.Client();
    final streamedResponse = await client.send(request);
    // The response body is a UTF‑8 stream of text lines.
    final lineStream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    String? eventName;
    StringBuffer? dataBuffer;

    await for (final line in lineStream) {
      if (line.isEmpty) {
        // Dispatch when we have a complete event.
        if (eventName != null && dataBuffer != null) {
          final data = dataBuffer.toString();
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final event = GlobalChatEvent.fromJson(json);
            _controller.add(event);
          } catch (_) {
            // ignore malformed events – they are non‑critical.
          }
        }
        // Reset for next event.
        eventName = null;
        dataBuffer = null;
        continue;
      }

      if (line.startsWith('event:')) {
        eventName = line.substring('event:'.length).trim();
        // We currently ignore the name because the payload already
        // contains a `type` field, but keeping it allows future extensions.
      } else if (line.startsWith('data:')) {
        final dataPart = line.substring('data:'.length).trim();
        dataBuffer ??= StringBuffer();
        if (dataBuffer.isNotEmpty) dataBuffer.writeln();
        dataBuffer.write(dataPart);
      }
      // Comments (lines starting with ':') are ignored – used for heartbeats.
    }
  }

  /// Close the internal stream when the UI is disposed.
  void dispose() {
    _controller.close();
  }
}

# chat_erp

A Flutter web chat client for the Spring Boot chat backend ([`demo`](https://github.com/Hussein2077/demo)). It's a demo of one-to-one chat with live messages, file attachments and read receipts.

## Features

- Switch between demo users to simulate different accounts
- Search users and start (or reopen) a private chat
- Chat list per user, with pull to refresh
- Real-time messaging over STOMP/WebSocket
- Paginated message history
- File upload (image / PDF) and download
- Read receipts

## Tech stack

Flutter Web, `dio` for REST, `stomp_dart_client` for WebSocket, `file_picker`, `intl`.

## Project structure

```
lib/
├── core/            # constants (API/WS URLs), user session
├── models/          # chat models
├── services/        # ChatApiService (REST), ChatWebSocketService (STOMP)
└── main.dart
```

## Getting started

1. Start the backend from the [`demo`](https://github.com/Hussein2077/demo) repo on port 8080:
   ```bash
   ./mvnw spring-boot:run
   ```
2. Run this app on port 3000, which is the origin the backend allows for CORS:
   ```bash
   flutter pub get
   flutter run -d chrome --web-port=3000
   ```

The backend URLs are set in `lib/core/constants/api_constants.dart` (`http://localhost:8080` and `ws://localhost:8080/ws/websocket`).

For a step-by-step walkthrough of every flow, see [TESTING_GUIDE.md](TESTING_GUIDE.md). To test real-time sync, open the app in two browser sessions as two different users.

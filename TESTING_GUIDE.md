# Local Run and Testing Guide for Flutter Chat

This guide explains how to run the Flutter web chat application locally and test all the integrated APIs (even without a real database, as the Spring backend is configured with in-memory storage).

## Prerequisites

1. **Spring Boot Backend**: Ensure the backend located in `C:\Users\Ultimate\Documents\GitHub\demo` is running locally on port 8080.
   - Run via IDE or via Maven: `mvnw spring-boot:run`
2. **Flutter Environment**: Ensure Flutter SDK is installed and configured for Web development.

## How to Run the Flutter App Locally

1. Open a terminal in your Flutter project directory: `C:\Users\Ultimate\StudioProjects\chat_erp`.
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the Flutter web application on port 3000 (which is a standard port mapped for CORS in the backend):
   ```bash
   flutter run -d chrome --web-port=3000
   ```

## How to Test the APIs without a Real Database

Since the backend runs with an in-memory configuration (no real database required to spin it up), you can test the APIs in an ephemeral way:

1. **Test User Switching & Authentication (Mocked)**:
   - In the top-right corner of the `ChatListScreen` (the main screen), you'll see a dropdown with users (Ahmed, Mohamed, Ali, etc.).
   - Switch between them to act as different users and test isolation (e.g., viewing only your chats).

2. **Test Search Users & Create Chat (`/api/users/search`, `/api/chats/private`)**:
   - Click the Search icon in the AppBar.
   - Type a name (e.g., "mohamed") to trigger the search API.
   - Tap on a user from the list to create or get a private chat with them.

3. **Test List Chats (`/api/chats`)**:
   - The main screen automatically fetches all chats for the currently selected user on load and on return from the chat screen.
   - Pull to refresh triggers the API again.

4. **Test Real-Time Chat & Message History (`/api/chats/{id}/messages`, STOMP WS)**:
   - To truly test the websocket real-time sync:
     - Open `http://localhost:3000` in **Chrome**. Select User 1 (Ahmed). Open the private chat with Mohamed.
     - Open `http://localhost:3000` in **Incognito / another browser**. Select User 2 (Mohamed). Open the private chat with Ahmed.
   - Send a message from User 1. It will immediately show up for User 2 via WebSockets (`/app/chats/{chatId}/messages`).
   - The history endpoint is automatically tested when you enter the `ChatScreen`.

5. **Test File Upload / Download (`/api/chats/{id}/messages/files`, `/api/files/{id}`)**:
   - In the `ChatScreen`, click the attachment (paperclip) icon.
   - Select an image or PDF from your PC.
   - The file is uploaded via `MultipartFile`. The message will appear in the list with a file link.
   - Click the file link to test the download API endpoint directly in your browser.

6. **Test Read Receipts (`/api/chats/{chatId}/read`)**:
   - When you enter a chat room, it automatically marks the latest message as read.
   - When a new WebSocket message is received while the screen is open, it also calls the read API to update the backend count.

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'core/auth/user_session.dart';
import 'models/chat_models.dart';
import 'services/chat_api_service.dart';
import 'services/chat_websocket_service.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ChatListScreen(),
    );
  }
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatApiService _apiService = ChatApiService();
  List<ChatSummaryModel> _chats = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);
    try {
      final chats = await _apiService.listChats();
      setState(() => _chats = chats);
    } catch (e) {
      print('Failed to load chats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchUsersScreen()),
              );
              _loadChats(); // Reload chats when coming back
            },
          ),
          DropdownButton<MockUser>(
            value: UserSession.currentUser,
            icon: const Icon(Icons.person, color: Colors.white),
            dropdownColor: Colors.blue,
            style: const TextStyle(color: Colors.white),
            onChanged: (MockUser? newValue) {
              if (newValue != null) {
                setState(() {
                  UserSession.switchUser(newValue);
                  _loadChats();
                });
              }
            },
            items: UserSession.staticUsers.map<DropdownMenuItem<MockUser>>((MockUser user) {
              return DropdownMenuItem<MockUser>(
                value: user,
                child: Text(user.displayName),
              );
            }).toList(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadChats,
              child: ListView.builder(
                itemCount: _chats.length,
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  return ListTile(
                    title: Text(chat.name ?? 'Chat ${chat.id}'),
                    subtitle: Text(chat.lastMessage?.content ?? 'No messages yet'),
                    trailing: chat.unreadCount > 0
                        ? CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: Text(
                              chat.unreadCount.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: chat.id,
                            chatName: chat.name ?? 'Chat ${chat.id}',
                          ),
                        ),
                      ).then((_) => _loadChats());
                    },
                  );
                },
              ),
            ),
    );
  }
}

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final ChatApiService _apiService = ChatApiService();
  List<UserModel> _users = [];
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();

  Future<void> _searchUsers(String query) async {
    setState(() => _isLoading = true);
    try {
      final users = await _apiService.searchUsers(query);
      setState(() => _users = users);
    } catch (e) {
      print('Search error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startChat(int userId) async {
    try {
      final chatData = await _apiService.getOrCreatePrivateChat(userId);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatData['id'],
              chatName: chatData['name'] ?? 'Private Chat',
            ),
          ),
        );
      }
    } catch (e) {
      print('Create chat error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Users'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search...',
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _searchUsers(_searchController.text),
                ),
              ),
              onSubmitted: _searchUsers,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return ListTile(
                  title: Text(user.displayName),
                  subtitle: Text('@${user.username}'),
                  onTap: () => _startChat(user.id),
                );
              },
            ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final int chatId;
  final String chatName;

  const ChatScreen({super.key, required this.chatId, required this.chatName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatApiService _apiService = ChatApiService();
  final ChatWebSocketService _wsService = ChatWebSocketService();
  final TextEditingController _msgController = TextEditingController();
  
  List<MessageModel> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _wsService.connect(onConnected: _onWsConnected);
  }

  void _onWsConnected() {
    _wsService.subscribeToChat(widget.chatId, (message) {
      if (mounted) {
        setState(() {
          _messages.insert(0, message);
        });
        _apiService.markRead(widget.chatId, message.id);
      }
    });
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getMessages(widget.chatId);
      setState(() {
        _messages = res['messages'] as List<MessageModel>;
      });
      if (_messages.isNotEmpty) {
        _apiService.markRead(widget.chatId, _messages.first.id);
      }
    } catch (e) {
      print('Load messages error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _wsService.sendMessage(widget.chatId, text);
    _msgController.clear();
  }

  Future<void> _uploadFile() async {
    try {
      final file = await FilePicker.pickFile();
      if (file != null) {
        final message = await _apiService.uploadFileMessage(
          chatId: widget.chatId,
          file: file,
        );
        setState(() {
          _messages.insert(0, message);
        });
      }
    } catch (e) {
      print('File upload error: $e');
    }
  }

  @override
  void dispose() {
    _wsService.unsubscribeFromChat(widget.chatId);
    _wsService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chatName)),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg.sender.id == UserSession.currentUser.id;
                      
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue[100] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg.sender.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              if (msg.content != null && msg.content!.isNotEmpty)
                                Text(msg.content!),
                              if (msg.attachments.isNotEmpty)
                                ...msg.attachments.map((att) => InkWell(
                                  onTap: () {
                                    launchUrl(Uri.parse(_apiService.getFileDownloadUrl(att.id)));
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.attach_file),
                                      Text(att.fileName),
                                    ],
                                  ),
                                ))
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _uploadFile,
                ),
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(hintText: 'Type a message...'),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

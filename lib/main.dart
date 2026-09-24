import 'dart:async';
import 'dart:convert';
import 'package:chat_erp/models/global_chat_event.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'core/auth/user_session.dart';
import 'core/constants/api_constants.dart';
import 'models/chat_models.dart';
import 'services/chat_api_service.dart';
import 'services/chat_sse_service.dart';

void main() {
  runApp(const ChatApp());
}

// ─── App ────────────────────────────────────────────────────────────────────

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF075E54),
          primary: const Color(0xFF075E54),
          secondary: const Color(0xFF25D366),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ─── Login Screen ───────────────────────────────────────────────────────────

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF075E54),
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 24)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chat, size: 64, color: Color(0xFF075E54)),
              const SizedBox(height: 16),
              const Text(
                'Chat ERP',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select your account to continue',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ...UserSession.staticUsers.map((user) => _UserTile(user: user)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final MockUser user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          UserSession.switchUser(user);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _Avatar(name: user.displayName, radius: 20),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '@${user.username}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Home Screen (two-pane) ──────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ChatApiService _api = ChatApiService();
  final ChatSseService _sse = ChatSseService();
  StreamSubscription<GlobalChatEvent>? _sseSub;

  // Chat list state
  List<ChatSummaryModel> _chats = [];
  bool _loadingChats = false;

  // Selected chat state
  ChatSummaryModel? _selectedChat;
  List<MessageModel> _messages = [];
  bool _loadingMessages = false;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _searching = false;

  // WS
  StompClient? _stomp;
  StompUnsubscribe? _currentSub;
  bool _wsConnected = false;

  // Message input
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadChats();
    _connectWs();
    // Start SSE and listen for chat list updates
    _sse.start();
    _sseSub = _sse.eventStream.listen((event) {
      // Refresh chat list on any SSE event
      _refreshChatList();
    });
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────

  void _connectWs() {
    _stomp = StompClient(
      config: StompConfig(
        url: ApiConstants.wsUrl,
        onConnect: (_) {
          setState(() => _wsConnected = true);
          // Re-subscribe to selected chat if any
          if (_selectedChat != null) {
            _subscribeTo(_selectedChat!.id);
          }
        },
        onDisconnect: (_) => setState(() => _wsConnected = false),
        onWebSocketError: (e) => debugPrint('WS error: $e'),
        stompConnectHeaders: {
          'X-User-Id': UserSession.currentUser.id.toString(),
        },
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _stomp!.activate();
  }

  void _subscribeTo(int chatId) {
    _currentSub?.call();
    _currentSub = null;
    if (!(_stomp?.connected ?? false)) return;

    _currentSub = _stomp!.subscribe(
      destination: '/topic/chats/$chatId',
      callback: (frame) {
        if (frame.body == null) return;
        final msg = MessageModel.fromJson(jsonDecode(frame.body!));
        if (mounted) {
          setState(() => _messages.insert(0, msg));
          _api.markRead(chatId, msg.id);
          _refreshChatList();
        }
      },
    );
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  Future<void> _loadChats() async {
    setState(() => _loadingChats = true);
    try {
      final chats = await _api.listChats();
      setState(() => _chats = chats);
    } catch (e) {
      debugPrint('loadChats: $e');
    } finally {
      setState(() => _loadingChats = false);
    }
  }

  Future<void> _refreshChatList() async {
    try {
      final chats = await _api.listChats();
      setState(() => _chats = chats);
    } catch (_) {}
  }

  Future<void> _selectChat(ChatSummaryModel chat) async {
    setState(() {
      _selectedChat = chat;
      _messages = [];
      _loadingMessages = true;
      _searchResults = [];
      _searchCtrl.clear();
    });
    _subscribeTo(chat.id);

    try {
      final res = await _api.getMessages(chat.id);
      final msgs = res['messages'] as List<MessageModel>;
      setState(() => _messages = msgs);
      if (msgs.isNotEmpty) await _api.markRead(chat.id, msgs.first.id);
    } catch (e) {
      debugPrint('loadMessages: $e');
    } finally {
      setState(() => _loadingMessages = false);
    }
  }

  Future<void> _openChatWith(UserModel user) async {
    try {
      final data = await _api.getOrCreatePrivateChat(user.id);
      await _loadChats();
      final chat = _chats.firstWhere(
        (c) => c.id == data['id'],
        orElse: () => ChatSummaryModel.fromJson(data),
      );
      await _selectChat(chat);
    } catch (e) {
      debugPrint('openChat: $e');
    }
  }

  Future<void> _searchUsers(String q) async {
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final users = await _api.searchUsers(q);
      setState(() => _searchResults = users);
    } catch (_) {
    } finally {
      setState(() => _searching = false);
    }
  }

  // ── Send ────────────────────────────────────────────────────────────────────

  void _sendText() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _selectedChat == null) return;
    if (!(_stomp?.connected ?? false)) {
      debugPrint('WS not connected');
      return;
    }
    _stomp!.send(
      destination: '/app/chats/${_selectedChat!.id}/messages',
      headers: {
        'X-User-Id': UserSession.currentUser.id.toString(),
        'content-type': 'application/json',
      },
      body: jsonEncode({'type': 'TEXT', 'content': text}),
    );
    _msgCtrl.clear();
  }

  Future<void> _sendFile() async {
    if (_selectedChat == null) return;
    try {
      final file = await FilePicker.pickFile();
      if (file == null) return;
      final msg = await _api.uploadFileMessage(
        chatId: _selectedChat!.id,
        file: file,
      );
      setState(() => _messages.insert(0, msg));
      _refreshChatList();
    } catch (e) {
      debugPrint('uploadFile: $e');
    }
  }

  @override
  void dispose() {
    _currentSub?.call();
    _stomp?.deactivate();
    _sseSub?.cancel();
    _sse.dispose();
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left panel — chat list
          SizedBox(
            width: 340,
            child: _LeftPanel(
              currentUser: UserSession.currentUser,
              chats: _chats,
              selectedChat: _selectedChat,
              loadingChats: _loadingChats,
              searchCtrl: _searchCtrl,
              searchResults: _searchResults,
              searching: _searching,
              wsConnected: _wsConnected,
              onRefresh: _loadChats,
              onSearch: _searchUsers,
              onSelectChat: _selectChat,
              onSelectUser: _openChatWith,
              onLogout: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // Right panel — messages
          Expanded(
            child: _selectedChat == null
                ? const _EmptyPanel()
                : _ChatPanel(
                    chat: _selectedChat!,
                    messages: _messages,
                    loading: _loadingMessages,
                    msgCtrl: _msgCtrl,
                    scrollCtrl: _scrollCtrl,
                    api: _api,
                    onSend: _sendText,
                    onFile: _sendFile,
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Left Panel ─────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final MockUser currentUser;
  final List<ChatSummaryModel> chats;
  final ChatSummaryModel? selectedChat;
  final bool loadingChats;
  final TextEditingController searchCtrl;
  final List<UserModel> searchResults;
  final bool searching;
  final bool wsConnected;
  final VoidCallback onRefresh;
  final Function(String) onSearch;
  final Function(ChatSummaryModel) onSelectChat;
  final Function(UserModel) onSelectUser;
  final VoidCallback onLogout;

  const _LeftPanel({
    required this.currentUser,
    required this.chats,
    required this.selectedChat,
    required this.loadingChats,
    required this.searchCtrl,
    required this.searchResults,
    required this.searching,
    required this.wsConnected,
    required this.onRefresh,
    required this.onSearch,
    required this.onSelectChat,
    required this.onSelectUser,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          color: const Color(0xFF075E54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              _Avatar(name: currentUser.displayName, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          wsConnected ? Icons.wifi : Icons.wifi_off,
                          size: 11,
                          color: wsConnected
                              ? const Color(0xFF25D366)
                              : Colors.red.shade300,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          wsConnected ? 'Online' : 'Connecting...',
                          style: TextStyle(
                            color: wsConnected
                                ? const Color(0xFF25D366)
                                : Colors.red.shade300,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                onPressed: onRefresh,
                tooltip: 'Refresh',
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                onPressed: onLogout,
                tooltip: 'Switch user',
              ),
            ],
          ),
        ),
        // Search bar
        Container(
          color: const Color(0xFFF0F0F0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search or start new chat',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        // List
        Expanded(
          child: loadingChats && chats.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : searchCtrl.text.isNotEmpty
              ? _SearchResultsList(
                  results: searchResults,
                  searching: searching,
                  onSelectUser: onSelectUser,
                )
              : _ChatList(
                  chats: chats,
                  selectedChat: selectedChat,
                  onSelectChat: onSelectChat,
                ),
        ),
      ],
    );
  }
}

class _ChatList extends StatelessWidget {
  final List<ChatSummaryModel> chats;
  final ChatSummaryModel? selectedChat;
  final Function(ChatSummaryModel) onSelectChat;

  const _ChatList({
    required this.chats,
    required this.selectedChat,
    required this.onSelectChat,
  });

  @override
  Widget build(BuildContext context) {
    if (chats.isEmpty) {
      return const Center(
        child: Text(
          'No chats yet.\nSearch for a user to start.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72, endIndent: 0),
      itemBuilder: (_, i) {
        final chat = chats[i];
        final isSelected = selectedChat?.id == chat.id;
        final lastMsg = chat.lastMessage;
        return InkWell(
          onTap: () => onSelectChat(chat),
          child: Container(
            color: isSelected ? const Color(0xFFF0F0F0) : null,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _Avatar(name: chat.name ?? 'Chat', radius: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.name ?? 'Chat ${chat.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatTime(chat.updatedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: chat.unreadCount > 0
                                  ? const Color(0xFF25D366)
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMsg?.content ??
                                  (lastMsg?.attachments.isNotEmpty == true
                                      ? '📎 ${lastMsg!.attachments.first.fileName}'
                                      : 'No messages'),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (chat.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF25D366),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                chat.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SearchResultsList extends StatelessWidget {
  final List<UserModel> results;
  final bool searching;
  final Function(UserModel) onSelectUser;

  const _SearchResultsList({
    required this.results,
    required this.searching,
    required this.onSelectUser,
  });

  @override
  Widget build(BuildContext context) {
    if (searching) return const Center(child: CircularProgressIndicator());
    if (results.isEmpty) {
      return const Center(
        child: Text('No users found', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) {
        final user = results[i];
        return ListTile(
          leading: _Avatar(name: user.displayName, radius: 20),
          title: Text(user.displayName),
          subtitle: Text('@${user.username}'),
          onTap: () => onSelectUser(user),
        );
      },
    );
  }
}

// ─── Right Panel ─────────────────────────────────────────────────────────────

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFECE5DD),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select a chat to start messaging',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Or search for a user to create a new chat',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  final ChatSummaryModel chat;
  final List<MessageModel> messages;
  final bool loading;
  final TextEditingController msgCtrl;
  final ScrollController scrollCtrl;
  final ChatApiService api;
  final VoidCallback onSend;
  final VoidCallback onFile;

  const _ChatPanel({
    required this.chat,
    required this.messages,
    required this.loading,
    required this.msgCtrl,
    required this.scrollCtrl,
    required this.api,
    required this.onSend,
    required this.onFile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chat header
        Container(
          color: const Color(0xFF075E54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              _Avatar(name: chat.name ?? 'Chat', radius: 18),
              const SizedBox(width: 12),
              Text(
                chat.name ?? 'Chat ${chat.id}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  chat.type,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: Container(
            color: const Color(0xFFECE5DD),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet. Say hello! 👋',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    controller: scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (_, i) =>
                        _MessageBubble(message: messages[i], api: api),
                  ),
          ),
        ),
        // Input bar
        Container(
          color: const Color(0xFFF0F0F0),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.attach_file, color: Colors.grey),
                onPressed: onFile,
                tooltip: 'Attach file',
              ),
              Expanded(
                child: TextField(
                  controller: msgCtrl,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFF075E54),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final ChatApiService api;

  const _MessageBubble({required this.message, required this.api});

  @override
  Widget build(BuildContext context) {
    final isMe = message.sender.id == UserSession.currentUser.id;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.55,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFDCF8C6) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender name (only for received messages)
            if (!isMe)
              Text(
                message.sender.displayName,
                style: const TextStyle(
                  color: Color(0xFF075E54),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            // Text content
            if (message.content != null && message.content!.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: isMe ? 0 : 2),
                child: Text(
                  message.content!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            // Attachments
            ...message.attachments.map(
              (att) => _AttachmentRow(
                attachment: att,
                downloadUrl: api.getFileDownloadUrl(att.id),
              ),
            ),
            // Time
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _formatTime(message.createdAt),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  final AttachmentModel attachment;
  final String downloadUrl;

  const _AttachmentRow({required this.attachment, required this.downloadUrl});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(downloadUrl)),
      child: Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.insert_drive_file,
              size: 18,
              color: Color(0xFF075E54),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                attachment.fileName,
                style: const TextStyle(fontSize: 13, color: Color(0xFF075E54)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.download, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String name;
  final double radius;

  const _Avatar({required this.name, required this.radius});

  Color _color() {
    final colors = [
      const Color(0xFF1ABC9C),
      const Color(0xFF2ECC71),
      const Color(0xFF3498DB),
      const Color(0xFF9B59B6),
      const Color(0xFFE74C3C),
      const Color(0xFFF39C12),
    ];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: _color(),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final local = dt.toLocal();
  if (now.difference(local).inDays == 0) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  return '${local.day}/${local.month}';
}

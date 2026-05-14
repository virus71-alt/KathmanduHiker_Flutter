import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../utils/feedback.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String friendId;
  final String friendName;
  final VoidCallback onBack;
  final VoidCallback onProfileClick;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.friendId,
    required this.friendName,
    required this.onBack,
    required this.onProfileClick,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _db = FirebaseFirestore.instance;
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  List<ChatMessage> _messages = [];
  StreamSubscription? _sub;

  String get _chatId => widget.currentUserId.compareTo(widget.friendId) < 0
      ? '${widget.currentUserId}_${widget.friendId}'
      : '${widget.friendId}_${widget.currentUserId}';

  @override
  void initState() {
    super.initState();
    _sub = _db
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .listen((s) {
      if (!mounted) return;
      setState(() => _messages = s.docs.map(ChatMessage.fromDoc).toList());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
      // Mark friend's unread badge as cleared on this side
      _db.collection('users').doc(widget.currentUserId).update({
        'unreadChatIds': FieldValue.arrayRemove([_chatId]),
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    AppFeedback.success();
    _ctl.clear();
    final ts = DateTime.now().millisecondsSinceEpoch;
    await _db.collection('chats').doc(_chatId).collection('messages').add({
      'senderId': widget.currentUserId,
      'text': text,
      'timestamp': ts,
      'status': 'sent',
      'isUnsent': false,
      'reactions': {},
      'deletedBy': <String>[],
    });
    await _db.collection('users').doc(widget.friendId).update({
      'unreadChatIds': FieldValue.arrayUnion([_chatId]),
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            AppFeedback.tap();
            widget.onBack();
          },
        ),
        title: GestureDetector(
          onTap: () {
            AppFeedback.tap();
            widget.onProfileClick();
          },
          child: Row(children: [
            const CircleAvatar(child: Icon(Icons.person)),
            const SizedBox(width: 10),
            Text(widget.friendName),
          ]),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text('Say hi 👋',
                        style: TextStyle(color: colors.onSurfaceVariant)))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final mine = m.senderId == widget.currentUserId;
                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: mine ? colors.primary : colors.surfaceContainerHighest,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(mine ? 16 : 4),
                              bottomRight: Radius.circular(mine ? 4 : 16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.isUnsent ? 'Message unsent' : m.text,
                                style: TextStyle(
                                  color: mine
                                      ? colors.onPrimary
                                      : colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('HH:mm').format(
                                  DateTime.fromMillisecondsSinceEpoch(m.timestamp),
                                ),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: (mine ? colors.onPrimary : colors.onSurface)
                                      .withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctl,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(hintText: 'Message…'),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

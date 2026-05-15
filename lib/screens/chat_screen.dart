import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';
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

  static const _quickReactions = ['❤️', '😂', '😮', '😢', '👍', '🔥'];

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
      // Filter out messages the current user has soft-deleted on their side.
      final msgs = s.docs
          .map(ChatMessage.fromDoc)
          .where((m) => !m.deletedBy.contains(widget.currentUserId))
          .toList();
      setState(() => _messages = msgs);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
          );
        }
      });
      // Clear unread badge for this chat on this user's side.
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
      'reactions': <String, String>{},
      'deletedBy': <String>[],
    });
    await _db.collection('users').doc(widget.friendId).update({
      'unreadChatIds': FieldValue.arrayUnion([_chatId]),
    });
  }

  Future<void> _react(ChatMessage m, String emoji) async {
    AppFeedback.tap();
    final newReactions = Map<String, String>.from(m.reactions);
    if (newReactions[widget.currentUserId] == emoji) {
      newReactions.remove(widget.currentUserId);
    } else {
      newReactions[widget.currentUserId] = emoji;
    }
    await _db
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc(m.id)
        .update({'reactions': newReactions});
  }

  Future<void> _unsend(ChatMessage m) async {
    AppFeedback.warning();
    await _db
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc(m.id)
        .update({'isUnsent': true, 'text': ''});
  }

  Future<void> _deleteForMe(ChatMessage m) async {
    AppFeedback.warning();
    await _db
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .doc(m.id)
        .update({
      'deletedBy': FieldValue.arrayUnion([widget.currentUserId])
    });
  }

  Future<void> _copy(ChatMessage m) async {
    AppFeedback.tap();
    await Clipboard.setData(ClipboardData(text: m.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Copied')),
      );
    }
  }

  void _openActions(ChatMessage m) {
    final mine = m.senderId == widget.currentUserId;
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                // Emoji reactions row
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: _quickReactions
                        .map((e) => InkWell(
                              borderRadius: BorderRadius.circular(99),
                              onTap: () {
                                Navigator.pop(sheetCtx);
                                _react(m, e);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                child: Text(e,
                                    style: const TextStyle(fontSize: 26)),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 14),
                if (!m.isUnsent)
                  _actionTile(Icons.content_copy_rounded, 'Copy', () {
                    Navigator.pop(sheetCtx);
                    _copy(m);
                  }),
                _actionTile(Icons.delete_sweep_outlined, 'Delete for me', () {
                  Navigator.pop(sheetCtx);
                  _deleteForMe(m);
                }),
                if (mine && !m.isUnsent)
                  _actionTile(
                    Icons.undo_rounded,
                    'Unsend',
                    () {
                      Navigator.pop(sheetCtx);
                      _unsend(m);
                    },
                    tint: scheme.error,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionTile(IconData icon, String label, VoidCallback onTap,
      {Color? tint}) {
    final scheme = Theme.of(context).colorScheme;
    final color = tint ?? scheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: AppText.labelLg(color).copyWith(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            AppFeedback.tap();
            widget.onBack();
          },
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: () {
            AppFeedback.tap();
            widget.onProfileClick();
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryFixed,
                  child: Text(
                    widget.friendName.isNotEmpty
                        ? widget.friendName[0].toUpperCase()
                        : '?',
                    style: AppText.labelLg(AppColors.primary)
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.friendName,
                          style: AppText.labelLg(scheme.onSurface)
                              .copyWith(fontWeight: FontWeight.w700)),
                      Text('Tap for profile',
                          style: AppText.labelSm(scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.waving_hand_rounded,
                              size: 36, color: scheme.primary),
                        ),
                        const SizedBox(height: 12),
                        Text('Say hi to ${widget.friendName}',
                            style: AppText.bodyMd(scheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _messageBubble(_messages[i], i),
                  ),
          ),
          _composer(),
        ],
      ),
    );
  }

  Widget _messageBubble(ChatMessage m, int i) {
    final mine = m.senderId == widget.currentUserId;
    final scheme = Theme.of(context).colorScheme;
    final isUnsent = m.isUnsent;
    final bg = mine
        ? scheme.primary
        : (Theme.of(context).brightness == Brightness.dark
            ? scheme.surfaceContainerHigh
            : scheme.surfaceContainerHigh);
    final fg = mine ? scheme.onPrimary : scheme.onSurface;
    final showTime = i == 0 ||
        (m.timestamp - _messages[i - 1].timestamp).abs() > 5 * 60 * 1000;

    return Column(
      crossAxisAlignment:
          mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (showTime)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                _formatTimestamp(m.timestamp),
                style: AppText.labelSm(scheme.onSurfaceVariant),
              ),
            ),
          ),
        GestureDetector(
          onLongPress: isUnsent ? null : () => _openActions(m),
          onDoubleTap: isUnsent ? null : () => _react(m, '❤️'),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            decoration: BoxDecoration(
              color: isUnsent
                  ? scheme.surfaceContainerLow
                  : bg,
              border: isUnsent
                  ? Border.all(
                      color: scheme.outlineVariant,
                      style: BorderStyle.solid,
                      width: 1.2)
                  : null,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 4),
                bottomRight: Radius.circular(mine ? 4 : 18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUnsent)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.do_not_disturb_alt_rounded,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(
                        'Message unsent',
                        style: AppText.labelSm(scheme.onSurfaceVariant)
                            .copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  )
                else
                  Text(m.text,
                      style: AppText.bodyMd(fg).copyWith(height: 1.35)),
              ],
            ),
          ),
        ),
        if (m.reactions.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(mine ? 0 : 12, 2, mine ? 12 : 0, 4),
            child: _reactionsRow(m),
          ),
      ],
    );
  }

  Widget _reactionsRow(ChatMessage m) {
    final scheme = Theme.of(context).colorScheme;
    // Group by emoji → count
    final counts = <String, int>{};
    for (final v in m.reactions.values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    final mine = m.reactions[widget.currentUserId];
    return Wrap(
      spacing: 4,
      children: counts.entries.map((e) {
        final selected = mine == e.key;
        return InkWell(
          onTap: () => _react(m, e.key),
          borderRadius: BorderRadius.circular(99),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.15)
                  : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.key, style: const TextStyle(fontSize: 14)),
                if (e.value > 1) ...[
                  const SizedBox(width: 4),
                  Text('${e.value}',
                      style: AppText.labelSm(scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _composer() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: TextField(
                  controller: _ctl,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Message…',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: _ctl.text.trim().isEmpty ? 0 : 48,
              child: _ctl.text.trim().isEmpty
                  ? const SizedBox.shrink()
                  : Material(
                      color: scheme.primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _send,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.send_rounded,
                              color: scheme.onPrimary, size: 20),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(int ts) {
    final t = DateTime.fromMillisecondsSinceEpoch(ts);
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return DateFormat('h:mm a').format(t);
    }
    if (t.year == now.year) {
      return DateFormat('MMM d, h:mm a').format(t);
    }
    return DateFormat('MMM d, yyyy').format(t);
  }
}

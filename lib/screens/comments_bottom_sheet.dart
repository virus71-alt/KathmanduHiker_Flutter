import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/comment.dart';
import '../utils/feedback.dart';

class CommentsBottomSheet extends StatefulWidget {
  final List<Comment> comments;
  final Future<void> Function(String text) onSendComment;
  const CommentsBottomSheet({super.key, required this.comments, required this.onSendComment});

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('💬 Discussion',
              style: TextStyle(
                  color: colors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: widget.comments.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No comments yet. Start the discussion!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colors.onSurfaceVariant)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.comments.length,
                    separatorBuilder: (_, __) => const Divider(height: 12),
                    itemBuilder: (_, i) {
                      final c = widget.comments[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('👤 ${c.authorName}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(c.text),
                        trailing: Text(
                          DateFormat('MMM d').format(
                            DateTime.fromMillisecondsSinceEpoch(c.timestamp),
                          ),
                          style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctl,
                  decoration: const InputDecoration(hintText: 'Share a tip…'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final t = _ctl.text.trim();
                  if (t.isEmpty) return;
                  AppFeedback.success();
                  await widget.onSendComment(t);
                  _ctl.clear();
                },
                child: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

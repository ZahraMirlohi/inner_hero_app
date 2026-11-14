import 'package:flutter/material.dart';
import '/l10n/app_strings.dart';
import '/services/chat_service.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

/// فوروارد پیام‌ها به یکی از گفتگوهای هم‌مسیر یا گروهِ کاربر.
Future<void> forwardMessages(
  BuildContext context, {
  required ChatService chat,
  required String me,
  required String? myName,
  required String excludeConvId,
  required List<ChatMessage> msgs,
}) async {
  msgs = msgs.where((m) => !m.isDeleted && !m.isSystem).toList();
  if (msgs.isEmpty) return;
  final targets = <({String convId, String name})>[];
  try {
    final convs = await chat.getUserConversations(me);
    final buddyOther = <String, String>{};
    for (final c in convs) {
      if (c.id == excludeConvId) continue;
      if (c.type == ConversationType.squad) {
        targets.add((convId: c.id, name: c.displayName));
      } else if (c.type == ConversationType.buddy) {
        final o = c.memberIds.where((id) => id != me);
        if (o.isNotEmpty) buddyOther[c.id] = o.first;
      }
    }
    if (buddyOther.isNotEmpty) {
      final rows = await chat.client
          .from('profiles')
          .select('user_id, name')
          .inFilter('user_id', buddyOther.values.toList());
      final names = {for (final r in rows) r['user_id'] as String: r['name'] as String?};
      buddyOther.forEach((cid, uid) => targets.add((convId: cid, name: names[uid] ?? '')));
    }
  } catch (_) {}
  if (!context.mounted) return;
  if (targets.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.tr('bc.k152'))));
    return;
  }
  final target = await showModalBottomSheet<({String convId, String name})>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.tr('bc.k153'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          for (final t in targets)
            ListTile(
              leading: const Icon(Icons.forum_outlined),
              title: Text(t.name.isEmpty ? context.tr('bc.k001') : t.name),
              onTap: () => Navigator.pop(ctx, t),
            ),
        ],
      ),
    ),
  );
  if (target == null || !context.mounted) return;
  try {
    for (final m in msgs) {
      await chat.sendMessage(
        conversationId: target.convId,
        senderId: me,
        content: m.content,
        type: m.type.name,
        metadata: m.metadata,
        senderName: myName,
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('bc.k154', {'p0': target.name}))));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('bc.k155')), backgroundColor: Colors.red));
    }
  }
}

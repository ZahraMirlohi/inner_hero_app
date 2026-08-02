// lib/features/chat/widgets/message_actions_menu.dart

import 'package:flutter/material.dart';
import '../models/message_model.dart';

class MessageActionsMenu extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDeleteForEveryone;
  final VoidCallback onCopy;
  final Function(String) onReact; // ✅ اینجا درست است
  final VoidCallback onForward;

  const MessageActionsMenu({
    super.key,
    required this.message,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onDeleteForEveryone,
    required this.onCopy,
    required this.onReact,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    final isOwnMessage = message.isFromMe;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // واکنش‌ها (Reactions)
          _buildReactionRow(),
          const Divider(height: 1, thickness: 1),

          // اقدامات
          _buildActionItem(icon: Icons.reply, label: 'پاسخ', onTap: onReply),

          if (isOwnMessage && message.canBeEdited)
            _buildActionItem(icon: Icons.edit, label: 'ویرایش', onTap: onEdit),

          if (!message.isDeleted)
            _buildActionItem(icon: Icons.copy, label: 'کپی', onTap: onCopy),

          if (isOwnMessage)
            _buildActionItem(
              icon: Icons.delete_outline,
              label: 'حذف برای من',
              color: Colors.red,
              onTap: onDelete,
            ),

          if (isOwnMessage && !message.isDeleted)
            _buildActionItem(
              icon: Icons.delete_forever,
              label: 'حذف برای همه',
              color: Colors.red,
              onTap: onDeleteForEveryone,
            ),

          _buildActionItem(
            icon: Icons.share,
            label: 'اشتراک‌گذاری',
            onTap: onForward,
          ),

          // اطلاعات پیام
          if (message.isEdited && !message.isDeleted)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'ویرایش شده در ${_formatTime(message.editedAt)}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ متد _buildReactionRow - نسخه اصلاح شده
  Widget _buildReactionRow() {
    final popularReactions = ['❤️', '🔥', '💪', '🎉', '😂', '😍', '🙏', '👍'];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: popularReactions.length,
        itemBuilder: (context, index) {
          final emoji = popularReactions[index];

          // ✅ اصلاح: استفاده از ?. برای جلوگیری از null
          final isSelected =
              message.reactions?.any((r) => r.emoji == emoji) ?? false;

          return GestureDetector(
            onTap: () => onReact(emoji),
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.blue.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(color: Colors.blue, width: 1)
                    : null,
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey.shade700),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color ?? Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// lib/features/chat/widgets/message_actions_menu.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/message_model.dart';
import '/providers/theme_provider.dart';

class MessageActionsMenu extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onReply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDeleteForEveryone;
  final VoidCallback onCopy;
  final Function(String) onReact;
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
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;
    final isOwnMessage = message.isFromMe;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // نشانگر کشیدن
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // واکنش‌ها
          _buildReactionRow(primaryColor, theme),
          const Divider(height: 1, thickness: 1),

          // اقدامات
          _buildActionItem(
            icon: Icons.reply,
            label: 'پاسخ',
            onTap: onReply,
            primaryColor: primaryColor,
            theme: theme,
          ),

          if (isOwnMessage && message.canBeEdited)
            _buildActionItem(
              icon: Icons.edit,
              label: 'ویرایش',
              onTap: onEdit,
              primaryColor: primaryColor,
              theme: theme,
            ),

          if (!message.isDeleted)
            _buildActionItem(
              icon: Icons.copy,
              label: 'کپی',
              onTap: onCopy,
              primaryColor: primaryColor,
              theme: theme,
            ),

          if (isOwnMessage)
            _buildActionItem(
              icon: Icons.delete_outline,
              label: 'حذف برای من',
              color: Colors.orange,
              onTap: onDelete,
              primaryColor: primaryColor,
              theme: theme,
            ),

          if (isOwnMessage && !message.isDeleted)
            _buildActionItem(
              icon: Icons.delete_forever,
              label: 'حذف برای همه',
              color: Colors.red,
              onTap: onDeleteForEveryone,
              primaryColor: primaryColor,
              theme: theme,
            ),

          _buildActionItem(
            icon: Icons.share,
            label: 'اشتراک‌گذاری',
            onTap: onForward,
            primaryColor: primaryColor,
            theme: theme,
          ),

          // اطلاعات پیام
          if (message.isEdited && !message.isDeleted)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Text(
                'ویرایش شده در ${_formatTime(message.editedAt)}',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.textSecondaryColor,
                ),
              ),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildReactionRow(Color primaryColor, ThemeProvider theme) {
    final popularReactions = ['❤️', '🔥', '💪', '🎉', '😂', '😍', '🙏', '👍'];

    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: popularReactions.length,
        itemBuilder: (context, index) {
          final emoji = popularReactions[index];
          final isSelected =
              message.reactions?.any((r) => r.emoji == emoji) ?? false;

          return GestureDetector(
            onTap: () => onReact(emoji),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: primaryColor, width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
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
    required Color primaryColor,
    required ThemeProvider theme,
    Color? color,
  }) {
    final finalColor = color ?? primaryColor;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: finalColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: finalColor),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color ?? theme.textColor,
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

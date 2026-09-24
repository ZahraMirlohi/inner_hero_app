// lib/features/chat/widgets/xp_gift_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/theme_provider.dart';

class XPGiftDialog extends StatefulWidget {
  final String senderName;
  final String receiverName;
  final int maxXP;

  const XPGiftDialog({
    super.key,
    required this.senderName,
    required this.receiverName,
    required this.maxXP,
  });

  @override
  State<XPGiftDialog> createState() => _XPGiftDialogState();
}

class _XPGiftDialogState extends State<XPGiftDialog> {
  int _selectedAmount = 10;
  final TextEditingController _messageController = TextEditingController();
  final List<int> _presetAmounts = [5, 10, 20, 50, 100];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: theme.surfaceColor,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.stars, color: primaryColor, size: 26),
          ),
          const SizedBox(width: 12),
          Text(
            '🎁 هدیه XP',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ارسال هدیه برای ${widget.receiverName}',
              style: TextStyle(
                fontSize: 14,
                color: theme.textSecondaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'مقدار XP:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presetAmounts.map((amount) {
                final isSelected = _selectedAmount == amount;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAmount = amount;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor
                          : primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: primaryColor.withValues(alpha: 0.2),
                            ),
                    ),
                    child: Text(
                      '$amount XP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : primaryColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'سفارشی:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textColor,
                    ),
                  ),
                ),
                Container(
                  width: 100,
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: DropdownButton<int>(
                      value: _selectedAmount,
                      underline: const SizedBox(),
                      dropdownColor: theme.surfaceColor,
                      items: List.generate(50, (i) => (i + 1) * 5).map((value) {
                        return DropdownMenuItem(
                          value: value,
                          child: Center(
                            child: Text(
                              value.toString(),
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.textColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedAmount = value;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'پیام همراه هدیه (اختیاری)...',
                hintStyle: TextStyle(color: theme.textSecondaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: primaryColor.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'موجودی شما: ${widget.maxXP} XP',
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'انصراف',
            style: TextStyle(color: theme.textSecondaryColor),
          ),
        ),
        ElevatedButton(
          onPressed: _selectedAmount > widget.maxXP
              ? null
              : () {
                  Navigator.pop(context, {
                    'amount': _selectedAmount,
                    'message': _messageController.text.trim(),
                  });
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.send, size: 18),
              const SizedBox(width: 8),
              Text(
                'ارسال $_selectedAmount XP',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

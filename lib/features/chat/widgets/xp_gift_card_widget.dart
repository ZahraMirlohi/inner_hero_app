// lib/features/chat/widgets/xp_gift_card_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/services/xp_gift_service.dart';
import '/providers/theme_provider.dart';

class XPGiftCardWidget extends StatefulWidget {
  final String giftId;
  final int amount;
  final String senderName;
  final String receiverName;
  final String message;
  final bool isMe;
  final VoidCallback onDelivered;

  const XPGiftCardWidget({
    super.key,
    required this.giftId,
    required this.amount,
    required this.senderName,
    required this.receiverName,
    required this.message,
    required this.isMe,
    required this.onDelivered,
  });

  @override
  State<XPGiftCardWidget> createState() => _XPGiftCardWidgetState();
}

class _XPGiftCardWidgetState extends State<XPGiftCardWidget> {
  bool _isDelivered = false;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isChecking = false;

  final SupabaseService _supabase = SupabaseService();
  final XPGiftService _giftService = XPGiftService();

  @override
  void initState() {
    super.initState();
    _checkDeliveryStatus();
  }

  @override
  void didUpdateWidget(XPGiftCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.giftId != widget.giftId && !_isChecking) {
      _checkDeliveryStatus();
    }
  }

  Future<void> _checkDeliveryStatus() async {
    if (_isChecking || _isInitialized) return;
    _isChecking = true;

    try {
      final gift = await _giftService.getGiftById(widget.giftId);
      if (gift != null && mounted) {
        final newStatus = gift.isDelivered;

        if (_isDelivered != newStatus) {
          setState(() {
            _isDelivered = newStatus;
            _isInitialized = true;
          });
        } else {
          _isInitialized = true;
        }
      }
    } catch (e) {
      print('❌ Error checking gift status: $e');
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _receiveGift(Color primaryColor) async {
    if (_isDelivered || _isLoading || _isChecking) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _giftService.receiveGift(widget.giftId);

      if (success && mounted) {
        setState(() {
          _isDelivered = true;
          _isLoading = false;
          _isInitialized = true;
        });

        widget.onDelivered();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 ${widget.amount} XP دریافت شد!'),
              backgroundColor: primaryColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error receiving gift: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    if (!_isInitialized) {
      return Container(
        width: 280,
        height: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.15),
          ),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primaryColor,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              _isDelivered ? primaryColor : primaryColor.withValues(alpha: 0.3),
          width: _isDelivered ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ==================== هدر ====================
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _isDelivered ? Icons.check_circle : Icons.stars,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isDelivered ? '✅ هدیه دریافت شد' : '🎁 هدیه XP',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    Text(
                      'از ${widget.senderName} به ${widget.receiverName}',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${widget.amount} XP',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // پیام
          if (widget.message.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.12),
                ),
              ),
              child: Text(
                '"${widget.message}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: theme.textColor,
                ),
              ),
            ),

          const SizedBox(height: 10),

          // دکمه دریافت (فقط برای گیرنده)
          if (!_isDelivered && !widget.isMe)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () => _receiveGift(primaryColor),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'دریافت هدیه 🎁',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

          // وضعیت دریافت شده
          if (_isDelivered)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: primaryColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.isMe
                        ? 'هدیه توسط ${widget.receiverName} دریافت شد'
                        : 'هدیه دریافت شد ✅',
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // وضعیت در انتظار (برای فرستنده)
          if (!_isDelivered && widget.isMe)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.hourglass_empty,
                    color: Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'در انتظار دریافت توسط ${widget.receiverName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

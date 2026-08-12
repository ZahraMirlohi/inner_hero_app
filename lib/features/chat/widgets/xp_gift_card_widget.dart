// lib/features/chat/widgets/xp_gift_card_widget.dart

import 'package:flutter/material.dart';
import '/services/supabase_service.dart';
import '/services/xp_gift_service.dart';

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
    // ✅ فقط یک بار در ابتدا چک کن
    _checkDeliveryStatus();
  }

  @override
  void didUpdateWidget(XPGiftCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ اگر giftId تغییر کرد، دوباره چک کن
    if (oldWidget.giftId != widget.giftId && !_isChecking) {
      _checkDeliveryStatus();
    }
  }

  Future<void> _checkDeliveryStatus() async {
    // ✅ جلوگیری از اجرای همزمان
    if (_isChecking || _isInitialized) return;

    _isChecking = true;

    try {
      final gift = await _giftService.getGiftById(widget.giftId);
      if (gift != null && mounted) {
        final newStatus = gift.isDelivered;

        // ✅ فقط در صورت تغییر وضعیت، setState صدا بزن
        if (_isDelivered != newStatus) {
          setState(() {
            _isDelivered = newStatus;
            _isInitialized = true;
          });
        } else {
          _isInitialized = true;
        }

        print('📊 Gift status: ${_isDelivered ? "Delivered" : "Pending"}');
      }
    } catch (e) {
      print('❌ Error checking gift status: $e');
    } finally {
      _isChecking = false;
    }
  }

  Future<void> _receiveGift() async {
    // ✅ اگر قبلاً دریافت شده یا در حال بارگذاری است، کاری نکن
    if (_isDelivered || _isLoading || _isChecking) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _giftService.receiveGift(widget.giftId);

      if (success && mounted) {
        // ✅ وضعیت را به روزرسانی کن
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
              backgroundColor: Colors.green,
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
    // ✅ تا زمانی که مقداردهی اولیه انجام نشده، یک ویجت ساده نشان بده
    if (!_isInitialized) {
      return Container(
        width: 280,
        height: 120,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isDelivered
              ? [Colors.green.shade100, Colors.green.shade50]
              : [
                  const Color(0xFFFFA500).withValues(alpha: 0.15),
                  const Color(0xFFFFD700).withValues(alpha: 0.15),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDelivered
              ? Colors.green
              : const Color(0xFFFFA500).withValues(alpha: 0.3),
          width: _isDelivered ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _isDelivered
                ? Colors.green.withValues(alpha: 0.1)
                : const Color(0xFFFFA500).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ✅ هدر
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isDelivered
                      ? Colors.green.withValues(alpha: 0.15)
                      : const Color(0xFFFFA500).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isDelivered ? Icons.check_circle : Icons.stars,
                  color: _isDelivered ? Colors.green : const Color(0xFFFFA500),
                  size: 20,
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
                        color: _isDelivered
                            ? Colors.green
                            : const Color(0xFFFFA500),
                      ),
                    ),
                    Text(
                      'از ${widget.senderName} به ${widget.receiverName}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isDelivered
                      ? Colors.green.withValues(alpha: 0.15)
                      : const Color(0xFFFFA500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.amount} XP',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isDelivered
                        ? Colors.green
                        : const Color(0xFFFFA500),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ✅ پیام
          if (widget.message.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"${widget.message}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade700,
                ),
              ),
            ),

          const SizedBox(height: 10),

          // ✅ دکمه دریافت (فقط برای گیرنده و زمانی که هنوز دریافت نشده)
          if (!_isDelivered && !widget.isMe)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _receiveGift,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA500),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
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
                        ),
                      ),
              ),
            ),

          // ✅ وضعیت دریافت شده (برای هر دو طرف)
          if (_isDelivered)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    widget.isMe
                        ? 'هدیه توسط ${widget.receiverName} دریافت شد'
                        : 'هدیه دریافت شد ✅',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

          // ✅ وضعیت در انتظار (برای فرستنده)
          if (!_isDelivered && widget.isMe)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
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

// lib/features/chat/models/xp_gift.dart

class XPGift {
  final String id;
  final String senderId;
  final String senderName;
  final String receiverId;
  final String receiverName;
  final int amount;
  final String message;
  final DateTime sentAt;
  final bool isDelivered;
  final DateTime? deliveredAt;

  XPGift({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.receiverId,
    required this.receiverName,
    required this.amount,
    this.message = '',
    required this.sentAt,
    this.isDelivered = false,
    this.deliveredAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_name': senderName,
      'receiver_id': receiverId,
      'receiver_name': receiverName,
      'amount': amount,
      'message': message,
      'sent_at': sentAt.toIso8601String(),
      'is_delivered': isDelivered,
      'delivered_at': deliveredAt?.toIso8601String(),
    };
  }

  factory XPGift.fromMap(Map<String, dynamic> map) {
    return XPGift(
      id: map['id'] ?? '',
      senderId: map['sender_id'] ?? '',
      senderName: map['sender_name'] ?? 'کاربر',
      receiverId: map['receiver_id'] ?? '',
      receiverName: map['receiver_name'] ?? 'کاربر',
      amount: map['amount'] ?? 0,
      message: map['message'] ?? '',
      sentAt: DateTime.parse(
        map['sent_at'] ?? DateTime.now().toIso8601String(),
      ),
      isDelivered: map['is_delivered'] ?? false,
      deliveredAt: map['delivered_at'] != null
          ? DateTime.parse(map['delivered_at'])
          : null,
    );
  }
}

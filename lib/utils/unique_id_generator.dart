// lib/utils/unique_id_generator.dart

class UniqueIdGenerator {
  // ✅ تولید ID یکتا با فرمت INNER-XXXXXXXX
  static String generate() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 100000000).toString().padLeft(8, '0');
    return 'INNER-${random.toUpperCase()}';
  }

  // ✅ روش مطمئن‌تر با ترکیب timestamp + random
  static String generateSecure() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 100000000).toString().padLeft(8, '0');
    final hash = (timestamp + DateTime.now().microsecond).toString();
    final shortHash = hash.substring(hash.length - 4);
    return 'INNER-${random.substring(0, 4)}${shortHash.toUpperCase()}';
  }

  // ✅ روش با استفاده از DateTime + Random
  static String generateWithRandom() {
    final now = DateTime.now();
    final random = (now.millisecondsSinceEpoch % 100000000).toString().padLeft(
      8,
      '0',
    );
    final extra = (now.microsecond % 10000).toString().padLeft(4, '0');
    return 'INNER-${random.substring(0, 4)}${extra.toUpperCase()}';
  }

  // ✅ اعتبارسنجی ID یکتا
  static bool isValid(String id) {
    final pattern = RegExp(r'^INNER-[A-Z0-9]{8}$');
    return pattern.hasMatch(id);
  }
}

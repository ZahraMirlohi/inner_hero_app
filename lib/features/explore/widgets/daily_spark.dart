import 'package:flutter/material.dart';
import '/services/supabase_service.dart';

class DailySpark extends StatefulWidget {
  const DailySpark({super.key});

  @override
  State<DailySpark> createState() => _DailySparkState();
}

class _DailySparkState extends State<DailySpark> {
  final _supabase = SupabaseService();
  List<Map<String, dynamic>> _dailySpark = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDailySpark();
  }

  Future<void> _loadDailySpark() async {
    try {
      final spark = await _supabase.getDailySpark();
      setState(() {
        _dailySpark = spark;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_dailySpark.isEmpty) {
      return const SizedBox();
    }

    final spark = _dailySpark[DateTime.now().day % _dailySpark.length];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFB347).withAlpha(230),
            const Color(0xFFFF6B6B).withAlpha(230),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B6B).withAlpha(40),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              spark['type'] == 'quote'
                  ? Icons.format_quote
                  : spark['type'] == 'challenge'
                  ? Icons.bolt
                  : Icons.lightbulb,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spark['type'] == 'quote'
                      ? '✨ جرقه روزانه'
                      : spark['type'] == 'challenge'
                      ? '⚡ چالش روزانه'
                      : '💡 واقعیت علمی',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  spark['text'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                if (spark['author'] != null &&
                    spark['author'].toString().isNotEmpty)
                  Text(
                    '- ${spark['author']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(204),
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

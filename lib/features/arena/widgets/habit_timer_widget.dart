// lib/features/arena/widgets/habit_timer_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '/services/supabase_service.dart';

class HabitTimerWidget extends StatefulWidget {
  final String habitId;
  final String habitTitle;
  final VoidCallback onTimeSaved;

  const HabitTimerWidget({
    super.key,
    required this.habitId,
    required this.habitTitle,
    required this.onTimeSaved,
  });

  @override
  State<HabitTimerWidget> createState() => _HabitTimerWidgetState();
}

class _HabitTimerWidgetState extends State<HabitTimerWidget> {
  Timer? _timer;
  int _elapsedSeconds = 0;
  bool _isRunning = false;
  bool _isPaused = false;
  bool _isSaved = false;
  final SupabaseService _supabase = SupabaseService();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;

    setState(() {
      _isRunning = true;
      _isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = true;
    });
  }

  void _resumeTimer() {
    if (_timer != null && _timer!.isActive) return;

    setState(() {
      _isRunning = true;
      _isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isPaused = false;
      _elapsedSeconds = 0;
      _isSaved = false;
    });
  }

  Future<void> _saveTime() async {
    if (_elapsedSeconds < 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حداقل ۵ ثانیه زمان را ثبت کنید'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isSaved = true;
      _isRunning = false;
    });

    _timer?.cancel();

    try {
      final user = await _supabase.getCurrentUser();
      if (user == null) return;

      final today = DateTime.now();
      final dateStr = today.toIso8601String().split('T').first;

      // ✅ حذف رکورد قبلی
      await _supabase.client
          .from('habit_time_tracking')
          .delete()
          .eq('habit_id', widget.habitId)
          .eq('user_id', user.id)
          .eq('date', dateStr);

      // ✅ درج رکورد جدید
      await _supabase.client.from('habit_time_tracking').insert({
        'habit_id': widget.habitId,
        'user_id': user.id,
        'date': dateStr,
        'total_seconds': _elapsedSeconds,
        'last_updated': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        widget.onTimeSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaved = false;
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

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final timeString = _formatTime(_elapsedSeconds);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            widget.habitTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Text(
            timeString,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.bold,
              color: _isSaved ? Colors.green : const Color(0xFF4A90E2),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          if (_isSaved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '✅ زمان ثبت شد',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (_isRunning)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '⏱️ در حال انجام...',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (_isPaused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '⏸️ مکث شده',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isRunning && !_isPaused && !_isSaved)
                _buildControlButton(
                  icon: Icons.play_arrow,
                  label: 'شروع',
                  color: Colors.green,
                  onTap: _startTimer,
                ),
              if (_isRunning)
                _buildControlButton(
                  icon: Icons.pause,
                  label: 'مکث',
                  color: Colors.orange,
                  onTap: _pauseTimer,
                ),
              if (_isPaused)
                _buildControlButton(
                  icon: Icons.play_arrow,
                  label: 'ادامه',
                  color: Colors.green,
                  onTap: _resumeTimer,
                ),
              const SizedBox(width: 8),
              if (!_isSaved && (_isRunning || _isPaused || _elapsedSeconds > 0))
                _buildControlButton(
                  icon: Icons.refresh,
                  label: 'بازنشانی',
                  color: Colors.grey,
                  onTap: _resetTimer,
                ),
              const SizedBox(width: 8),
              if (!_isSaved && _elapsedSeconds > 0 && !_isRunning)
                _buildControlButton(
                  icon: Icons.save,
                  label: 'ذخیره زمان',
                  color: Colors.blue,
                  onTap: _saveTime,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

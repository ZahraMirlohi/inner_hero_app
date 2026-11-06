import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/services/supabase_service.dart';
import '/providers/theme_provider.dart';
import '/core/app_palette.dart';
import '/l10n/app_strings.dart';

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
  static const Color _ink = Color(0xFF090909);

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

// lib/features/arena/widgets/habit_timer_widget.dart

  void _showSnack(String text, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bg,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF090909),
          ),
        ),
      ),
    );
  }

  Future<void> _saveTime() async {
    if (_elapsedSeconds < 5) {
      if (mounted) {
        _showSnack(context.tr('ad.tmr.minSeconds'), const Color(0xFFFFA500));
      }
      return;
    }

    setState(() {
      _isSaved = true;
      _isRunning = false;
      _isPaused = false;
    });
    _timer?.cancel();

    try {
      final user = await _supabase.getCurrentUser();
      if (user == null) return;
      final today = DateTime.now();
      final dateStr = today.toIso8601String().split('T').first;

      await _supabase.client
          .from('habit_time_tracking')
          .delete()
          .eq('habit_id', widget.habitId)
          .eq('user_id', user.id)
          .eq('date', dateStr);

      await _supabase.client.from('habit_time_tracking').insert({
        'habit_id': widget.habitId,
        'user_id': user.id,
        'date': dateStr,
        'total_seconds': _elapsedSeconds,
        'last_updated': DateTime.now().toIso8601String(),
      });

      // بعد از تاخیر کوچیک callback رو صدا بزن
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            widget.onTimeSaved();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaved = false;
        });
        _showSnack(
          context.tr('ad.tmr.error', {'e': e.toString()}),
          Provider.of<ThemeProvider>(context, listen: false).errorColor,
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
    final theme = Provider.of<ThemeProvider>(context);
    final Color accent = theme.effectivePrimary;
    final bool dark = theme.isDarkMode;
    final Color onTone = dark ? theme.textColor : _ink;
    final sky = theme.tone(Tone.sky);
    final apricot = theme.tone(Tone.apricot);
    final mint = theme.tone(Tone.mint);

    final bool canSave = !_isSaved && _elapsedSeconds > 0;
    final bool canReset = !_isSaved && (_isRunning || _isPaused || _elapsedSeconds > 0);

    Widget? status;
    if (_isSaved) {
      status = _statusPill(context.tr('ad.tmr.saved'), Icons.check_circle_rounded,
          mint.bg, onTone);
    } else if (_isRunning) {
      status = _statusPill(context.tr('ad.tmr.running'), Icons.timer_outlined,
          sky.bg, onTone);
    } else if (_isPaused) {
      status = _statusPill(context.tr('ad.tmr.paused'),
          Icons.pause_circle_outline_rounded, apricot.bg, onTone);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.habitTitle,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textSecondaryColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _formatTime(_elapsedSeconds),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: 2,
              color: _isSaved
                  ? (dark ? mint.fg : theme.textColor)
                  : theme.textColor,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 30,
            child: Center(child: status ?? const SizedBox.shrink()),
          ),
          const SizedBox(height: 10),
          if (!_isSaved)
            Row(
              children: [
                if (!_isRunning && !_isPaused)
                  Expanded(
                    child: _actionButton(
                      icon: Icons.play_arrow_rounded,
                      label: context.tr('ad.tmr.start'),
                      bg: accent,
                      fg: theme.onPrimaryColor,
                      onTap: _startTimer,
                    ),
                  ),
                if (_isRunning)
                  Expanded(
                    child: _actionButton(
                      icon: Icons.pause_rounded,
                      label: context.tr('ad.tmr.pause'),
                      bg: apricot.bg,
                      fg: onTone,
                      onTap: _pauseTimer,
                    ),
                  ),
                if (_isPaused)
                  Expanded(
                    child: _actionButton(
                      icon: Icons.play_arrow_rounded,
                      label: context.tr('ad.tmr.resume'),
                      bg: accent,
                      fg: theme.onPrimaryColor,
                      onTap: _resumeTimer,
                    ),
                  ),
                if (canReset) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.refresh_rounded,
                      label: context.tr('ad.tmr.reset'),
                      bg: theme.cardColor,
                      fg: theme.textColor,
                      onTap: _resetTimer,
                    ),
                  ),
                ],
                if (canSave) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionButton(
                      icon: Icons.save_rounded,
                      label: context.tr('ad.tmr.save'),
                      bg: dark ? accent : _ink,
                      fg: dark ? theme.onPrimaryColor : Colors.white,
                      onTap: _saveTime,
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: 10),
          Text(
            context.tr('ad.tmr.minSeconds'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: theme.textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String text, IconData icon, Color bg, Color fg) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// دیالوگ پایان تایمر (ArenaTimerEnd). اگر کاربر «بله، انجام شد» را بزند true برمی‌گرداند.
Future<bool?> showHabitTimerEndDialog(BuildContext context, String habitTitle) {
  return showDialog<bool>(
    context: context,
    barrierColor: const Color(0xFF090909).withValues(alpha: 0.42),
    builder: (ctx) {
      final theme = Provider.of<ThemeProvider>(ctx);
      final bool dark = theme.isDarkMode;
      final Color accent = theme.effectivePrimary;
      final Color ink = dark ? theme.textColor : const Color(0xFF090909);
      return Dialog(
        backgroundColor: theme.cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.celebration_rounded, size: 36, color: ink),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                ctx.tr('ad.tmr.endTitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                ctx.tr('ad.tmr.endQuestion', {'t': habitTitle}),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.8,
                  color: theme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: theme.cardSecondaryColor,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Text(
                          ctx.tr('ad.tmr.notYet'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 13,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: dark ? accent : const Color(0xFF090909),
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Text(
                          ctx.tr('ad.tmr.yesDone'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: dark ? theme.onPrimaryColor : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

// lib/features/onboarding/screens/onboarding_screen.dart
//
// اولین ورود: ۲ صفحهٔ معرفی (انیمیشنی) + ۵ سوال کوتاه که همه اختیاری‌اند:
//   نام کاربری و عکس ← هدف ← اولین کار (ساخته می‌شود) ← شخصیت ← ساعت‌ها
// هر صفحه رنگ پاستلی خودش را دارد و بین صفحه‌ها نرم جابه‌جا می‌شویم.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '/core/app_palette.dart';
import '/features/arena/models/task_model.dart';
import '/l10n/app_strings.dart';
import '/models/offline_operation.dart';
import '/providers/auth_provider.dart';
import '/providers/settings_provider.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '/services/notification_service.dart';
import '/services/sound_service.dart';
import '/services/storage_service.dart';
import '/services/supabase_service.dart';

enum _UsernameState { idle, checking, ok, taken, invalid }

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  // ۰ خوش‌آمد، ۱ امکانات | ۲ پروفایل، ۳ هدف، ۴ اولین کار، ۵ شخصیت، ۶ ساعت‌ها
  static const int _introCount = 2;
  static const int _total = 7;
  static const List<Tone> _tones = [
    Tone.lilac,
    Tone.sky,
    Tone.mint,
    Tone.butter,
    Tone.peach,
    Tone.rose,
    Tone.lime,
  ];

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  int _page = 0;
  bool _forward = true;
  bool _busy = false;
  bool _celebrating = false;

  // پروفایل
  final TextEditingController _username = TextEditingController();
  Timer? _debounce;
  _UsernameState _uState = _UsernameState.idle;
  Uint8List? _avatar;

  // هدف و اولین کار
  String? _goal;
  String? _suggestion;
  final TextEditingController _customTask = TextEditingController();

  // شخصیت
  String? _energy;
  String? _style;

  // ساعت‌ها
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _remind = const TimeOfDay(hour: 20, minute: 0);

  static const _goals = <String, (IconData, Tone)>{
    'health': (Icons.favorite_rounded, Tone.mint),
    'study': (Icons.menu_book_rounded, Tone.sky),
    'work': (Icons.work_rounded, Tone.lilac),
    'mind': (Icons.self_improvement_rounded, Tone.rose),
    'sleep': (Icons.bedtime_rounded, Tone.butter),
    'money': (Icons.savings_rounded, Tone.apricot),
  };

  @override
  void dispose() {
    _float.dispose();
    _debounce?.cancel();
    _username.dispose();
    _customTask.dispose();
    super.dispose();
  }

  // ───────────────────────── ناوبری ─────────────────────────

  void _goTo(int page) {
    if (page < 0 || page >= _total) return;
    setState(() {
      _forward = page > _page;
      _page = page;
    });
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String? get _taskTitle {
    final custom = _customTask.text.trim();
    if (custom.isNotEmpty) return custom;
    return _suggestion;
  }

  Future<void> _next() async {
    if (_busy) return;
    SoundService.instance.play(Sfx.tap);

    if (_page == 2) {
      final ok = await _commitProfile();
      if (!ok) return;
    } else if (_page == 4) {
      await _commitFirstTask();
    }

    if (_page == _total - 1) {
      await _finish();
    } else {
      _goTo(_page + 1);
    }
  }

  void _skipQuestion() {
    SoundService.instance.play(Sfx.tap);
    if (_page == 3) {
      // بدون هدف، اولین کار هم معنا ندارد
      _goal = null;
      _suggestion = null;
    }
    if (_page == _total - 1) {
      _finish();
    } else {
      _goTo(_page + 1);
    }
  }

  // ───────────────────────── ذخیره‌ها ─────────────────────────

  /// نام کاربری و عکس. false یعنی همین‌جا بمان.
  Future<bool> _commitProfile() async {
    final name = _username.text.trim().toLowerCase();
    final auth = context.read<AuthProvider>();
    final uid = auth.userId;
    final messenger = ScaffoldMessenger.of(context);
    final failText = context.tr('ob.username_save_error');

    if (name.isNotEmpty && _uState != _UsernameState.ok) {
      SoundService.instance.play(Sfx.error);
      return false; // پیام وضعیت زیر فیلد دیده می‌شود
    }

    setState(() => _busy = true);
    try {
      if (uid != null && name.isNotEmpty) {
        try {
          await SupabaseService().setUsername(uid, name);
          auth.setHasUsername(true);
        } catch (_) {
          messenger.showSnackBar(SnackBar(content: Text(failText)));
        }
      }
      if (uid != null && _avatar != null) {
        try {
          final url = await StorageService().uploadAvatar(
            userId: uid,
            bytes: _avatar!,
            originalFileName: 'avatar.jpg',
          );
          await SupabaseService().updateAvatarUrl(uid, url);
        } catch (_) {
          // عکس اختیاری است؛ بعداً از پروفایل می‌شود گذاشت
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return true;
  }

  /// اولین کار را برای امروز می‌سازد (آفلاین هم کار می‌کند)
  Future<void> _commitFirstTask() async {
    final title = _taskTitle;
    final uid = context.read<AuthProvider>().userId;
    if (title == null || uid == null) return;

    final sync = context.read<SyncProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final okText = context.tr('ob.task_created');
    final errText = context.tr('ob.task_error');

    setState(() => _busy = true);
    try {
      final now = DateTime.now();
      final task = Task(
        id: now.millisecondsSinceEpoch.toString(),
        userId: uid,
        title: title,
        dueDate: DateTime(now.year, now.month, now.day),
        xpReward: 10,
        createdAt: now,
        updatedAt: now,
      );

      try {
        if (!sync.isOnline) throw Exception('offline');
        await SupabaseService().createTask(task); // سرور شناسهٔ واقعی می‌سازد
        await sync.refreshHabitsAndTasks();
      } catch (_) {
        // آفلاین یا خطا: محلی ذخیره و در صف ارسال
        await sync.saveTaskToLocal(task);
        await sync.addOfflineOperation(
          type: OperationType.createTask,
          data: {...task.toMap(), 'id': task.id},
        );
      }
      SoundService.instance.play(Sfx.check);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(okText)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(errText)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    final auth = context.read<AuthProvider>();
    final lang = context.read<SettingsProvider>().language;
    final answers = OnboardingAnswers(
      goal: _goal,
      firstTask: _taskTitle,
      energy: _energy,
      style: _style,
      wakeTime: _hhmm(_wake),
      remindTime: _hhmm(_remind),
      language: lang,
    );

    // ساعت یادآوری را به سرویس اعلان بده (اجازه فقط وقتی خواسته می‌شود که کاربر ساعت را انتخاب کرده)
    unawaited(() async {
      await NotificationService.instance
          .setReminderTime(_remind.hour, _remind.minute);
      await NotificationService.instance.requestPermission();
      await NotificationService.instance.reschedule();
    }());

    setState(() => _celebrating = true);
    SoundService.instance.play(Sfx.levelUp);
    await Future.delayed(const Duration(milliseconds: 2300));
    // ذخیره بی‌صدا: اگر نشد، بعداً خودکار دوباره تلاش می‌شود
    await auth.completeOnboarding(answers);
    // بعد از این، HeroApp خودکار صفحهٔ بعد را نشان می‌دهد
  }

  // ───────────────────────── پروفایل ─────────────────────────

  void _onUsernameChanged(String raw) {
    _debounce?.cancel();
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) {
      setState(() => _uState = _UsernameState.idle);
      return;
    }
    if (!RegExp(r'^[a-z][a-z0-9_.]{2,29}$').hasMatch(v)) {
      setState(() => _uState = _UsernameState.invalid);
      return;
    }
    setState(() => _uState = _UsernameState.checking);
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      bool available;
      try {
        available = await SupabaseService().isUsernameAvailable(v);
      } catch (_) {
        available = false;
      }
      if (!mounted || _username.text.trim().toLowerCase() != v) return;
      setState(() =>
          _uState = available ? _UsernameState.ok : _UsernameState.taken);
    });
  }

  Future<void> _pickAvatar() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _avatar = bytes);
    } catch (_) {}
  }

  Future<void> _pickTime(bool wake) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: wake ? _wake : _remind,
    );
    if (picked != null && mounted) {
      setState(() => wake ? _wake = picked : _remind = picked);
    }
  }

  // ───────────────────────── ساخت صفحه ─────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final tone = theme.tone(_tones[_page]);
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        color: tone.bg,
        child: Stack(
          children: [
            _blobs(tone),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _celebrating
                    ? _celebration(theme, tone)
                    : Column(
                        key: const ValueKey('flow'),
                        children: [
                          _topBar(theme, tone),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 420),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) {
                                final incoming = child.key == ValueKey(_page);
                                final dir =
                                    (_forward ? 1.0 : -1.0) * (rtl ? -1 : 1);
                                final offset = Tween<Offset>(
                                  begin: Offset(
                                      (incoming ? 0.14 : -0.14) * dir, 0),
                                  end: Offset.zero,
                                ).animate(anim);
                                return FadeTransition(
                                  opacity: anim,
                                  child: SlideTransition(
                                      position: offset, child: child),
                                );
                              },
                              child: KeyedSubtree(
                                key: ValueKey(_page),
                                child: _pageBody(theme, tone),
                              ),
                            ),
                          ),
                          _bottomBar(theme, tone),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// دایره‌های شناور پس‌زمینه
  Widget _blobs(ToneColors tone) {
    return AnimatedBuilder(
      animation: _float,
      builder: (context, _) {
        final t = _float.value * 2 * math.pi;
        return Stack(
          children: [
            Positioned(
              top: -60 + math.sin(t) * 14,
              right: -50 + math.cos(t) * 10,
              child: _blob(240, tone.fg.withValues(alpha: 0.10)),
            ),
            Positioned(
              bottom: 80 + math.cos(t) * 16,
              left: -70 + math.sin(t) * 10,
              child: _blob(190, tone.fg.withValues(alpha: 0.08)),
            ),
          ],
        );
      },
    );
  }

  Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _topBar(ThemeProvider theme, ToneColors tone) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                for (var i = 0; i < _total; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _page
                            ? tone.fg
                            : tone.fg.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 76,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _page < _introCount ? 1 : 0,
              child: TextButton(
                onPressed:
                    _page < _introCount ? () => _goTo(_introCount) : null,
                child: Text(
                  context.tr('ob.skip'),
                  style: TextStyle(color: tone.fg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(ThemeProvider theme, ToneColors tone) {
    final isLast = _page == _total - 1;
    final label = _page == 0
        ? context.tr('ob.start')
        : (isLast ? context.tr('ob.finish') : context.tr('ob.next'));
    final isQuestion = _page >= _introCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 6, 24, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: _page > 0
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: _Pressable(
                          onTap: _busy ? null : () => _goTo(_page - 1),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: theme.textColor,
                              textDirection: Directionality.of(context),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: _Pressable(
                  onTap: _busy ? null : _next,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: _busy
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: theme.onPrimaryColor,
                            ),
                          )
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              label,
                              key: ValueKey(label),
                              style: TextStyle(
                                color: theme.onPrimaryColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: isQuestion
                ? TextButton(
                    onPressed: _busy ? null : _skipQuestion,
                    child: Text(
                      context.tr('ob.skip_question'),
                      style: TextStyle(color: theme.textSecondaryColor),
                    ),
                  )
                : const SizedBox(height: 8),
          ),
        ],
      ),
    );
  }

  Widget _pageBody(ThemeProvider theme, ToneColors tone) {
    switch (_page) {
      case 0:
        return _welcomePage(theme, tone);
      case 1:
        return _featuresPage(theme);
      case 2:
        return _profilePage(theme, tone);
      case 3:
        return _goalPage(theme);
      case 4:
        return _taskPage(theme);
      case 5:
        return _personalityPage(theme);
      default:
        return _timePage(theme);
    }
  }

  // ───────────────────────── صفحه‌های معرفی ─────────────────────────

  Widget _welcomePage(ThemeProvider theme, ToneColors tone) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Reveal(
                delay: const Duration(milliseconds: 60),
                child: AnimatedBuilder(
                  animation: _float,
                  builder: (context, _) {
                    final pulse =
                        1 + 0.06 * math.sin(_float.value * 2 * math.pi * 2);
                    return SizedBox(
                      width: 210,
                      height: 210,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: pulse + 0.1,
                            child: _blob(200, tone.fg.withValues(alpha: 0.12)),
                          ),
                          Transform.scale(
                            scale: pulse,
                            child: _blob(150, tone.fg.withValues(alpha: 0.18)),
                          ),
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.bolt_rounded,
                                size: 58, color: theme.onPrimaryColor),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 26),
              _Reveal(
                delay: const Duration(milliseconds: 220),
                child: Text(
                  context.tr('ob.welcome_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Reveal(
                delay: const Duration(milliseconds: 340),
                child: Text(
                  context.tr('ob.welcome_body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textSecondaryColor,
                    fontSize: 15,
                    height: 1.85,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedBuilder(
                animation: _float,
                builder: (context, _) {
                  double bob(double phase) =>
                      math.sin(_float.value * 2 * math.pi + phase) * 5;
                  return Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Reveal(
                        delay: const Duration(milliseconds: 460),
                        child: Transform.translate(
                          offset: Offset(0, bob(0)),
                          child: _chip(theme, Tone.peach,
                              Icons.local_fire_department_rounded,
                              context.tr('ob.chip_streak')),
                        ),
                      ),
                      _Reveal(
                        delay: const Duration(milliseconds: 560),
                        child: Transform.translate(
                          offset: Offset(0, bob(2)),
                          child: _chip(theme, Tone.butter,
                              Icons.emoji_events_rounded,
                              context.tr('ob.chip_challenge')),
                        ),
                      ),
                      _Reveal(
                        delay: const Duration(milliseconds: 660),
                        child: Transform.translate(
                          offset: Offset(0, bob(4)),
                          child: _chip(theme, Tone.sky, Icons.groups_rounded,
                              context.tr('ob.chip_buddy')),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(ThemeProvider theme, Tone tone, IconData icon, String label) {
    final t = theme.tone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: t.fg),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: theme.textColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5)),
        ],
      ),
    );
  }

  Widget _featuresPage(ThemeProvider theme) {
    final items = <(IconData, Tone, String, String)>[
      (Icons.local_fire_department_rounded, Tone.peach, 'ob.feat1_t', 'ob.feat1_b'),
      (Icons.emoji_events_rounded, Tone.butter, 'ob.feat2_t', 'ob.feat2_b'),
      (Icons.groups_rounded, Tone.sky, 'ob.feat3_t', 'ob.feat3_b'),
      (Icons.psychology_rounded, Tone.lilac, 'ob.feat4_t', 'ob.feat4_b'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
      children: [
        _Reveal(
          child: Text(
            context.tr('ob.feat_title'),
            style: TextStyle(
              color: theme.textColor,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (var i = 0; i < items.length; i++)
          _Reveal(
            delay: Duration(milliseconds: 120 + i * 110),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.tone(items[i].$2).bg,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(items[i].$1,
                          size: 28, color: theme.tone(items[i].$2).fg),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(items[i].$3),
                            style: TextStyle(
                              color: theme.textColor,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            context.tr(items[i].$4),
                            style: TextStyle(
                              color: theme.textSecondaryColor,
                              fontSize: 12.5,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ───────────────────────── سوال‌ها ─────────────────────────

  Widget _header(ThemeProvider theme, ToneColors tone, int n, String titleKey,
      String subKey) {
    return _Reveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: tone.fg.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              context.tr('ob.q_progress', {'n': '$n', 'total': '5'}),
              style: TextStyle(
                  color: tone.fg, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(titleKey),
            style: TextStyle(
              color: theme.textColor,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(subKey),
            style: TextStyle(
                color: theme.textSecondaryColor, fontSize: 13.5, height: 1.6),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _profilePage(ThemeProvider theme, ToneColors tone) {
    String? status;
    Color statusColor = theme.textSecondaryColor;
    switch (_uState) {
      case _UsernameState.checking:
        status = context.tr('ob.username_checking');
        break;
      case _UsernameState.ok:
        status = context.tr('ob.username_ok');
        statusColor = theme.successColor;
        break;
      case _UsernameState.taken:
        status = context.tr('ob.username_taken');
        statusColor = theme.errorColor;
        break;
      case _UsernameState.invalid:
        status = context.tr('ob.username_invalid');
        statusColor = theme.errorColor;
        break;
      case _UsernameState.idle:
        status = context.tr('ob.username_rules');
        break;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
      children: [
        _header(theme, tone, 1, 'ob.profile_title', 'ob.profile_sub'),
        _Reveal(
          delay: const Duration(milliseconds: 120),
          child: Center(
            child: _Pressable(
              onTap: _pickAvatar,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      shape: BoxShape.circle,
                      image: _avatar == null
                          ? null
                          : DecorationImage(
                              image: MemoryImage(_avatar!),
                              fit: BoxFit.cover,
                            ),
                    ),
                    child: _avatar == null
                        ? Icon(Icons.person_rounded,
                            size: 54, color: tone.fg.withValues(alpha: 0.7))
                        : null,
                  ),
                  PositionedDirectional(
                    bottom: -2,
                    end: -2,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.photo_camera_rounded,
                          size: 20, color: theme.onPrimaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _avatar == null
                ? context.tr('ob.add_photo')
                : context.tr('ob.change_photo'),
            style: TextStyle(color: tone.fg, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 18),
        _Reveal(
          delay: const Duration(milliseconds: 220),
          child: TextField(
            controller: _username,
            onChanged: _onUsernameChanged,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              hintText: context.tr('ob.username_hint'),
              hintStyle: TextStyle(color: theme.textSecondaryColor),
              prefixIcon:
                  Icon(Icons.alternate_email_rounded, color: tone.fg),
              filled: true,
              fillColor: theme.cardColor,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Padding(
            key: ValueKey(_uState),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              status,
              style: TextStyle(color: statusColor, fontSize: 12.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _goalPage(ThemeProvider theme) {
    final tone = theme.tone(_tones[3]);
    final keys = _goals.keys.toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
      children: [
        _header(theme, tone, 2, 'ob.goal_title', 'ob.goal_sub'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            for (var i = 0; i < keys.length; i++)
              _Reveal(
                delay: Duration(milliseconds: 100 + i * 70),
                child: _goalCard(theme, keys[i]),
              ),
          ],
        ),
      ],
    );
  }

  Widget _goalCard(ThemeProvider theme, String key) {
    final (icon, toneKey) = _goals[key]!;
    final t = theme.tone(toneKey);
    final selected = _goal == key;
    return _Pressable(
      onTap: () {
        SoundService.instance.play(Sfx.check);
        setState(() {
          _goal = key;
          _suggestion = null;
          _customTask.clear();
        });
      },
      child: AnimatedScale(
        scale: selected ? 1.04 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          decoration: BoxDecoration(
            color: selected ? t.bg : theme.cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selected ? theme.cardColor : t.bg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: t.fg, size: 28),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('ob.goal_$key'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                top: 10,
                end: 10,
                child: AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration:
                        BoxDecoration(color: t.fg, shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, size: 16, color: t.onFg),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _taskPage(ThemeProvider theme) {
    final tone = theme.tone(_tones[4]);
    final goal = _goal ?? 'mind';
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
      children: [
        _header(theme, tone, 3, 'ob.task_title', 'ob.task_sub'),
        for (var i = 1; i <= 3; i++)
          _Reveal(
            delay: Duration(milliseconds: 100 + i * 80),
            child: _option(
              theme,
              tone,
              context.tr('ob.sug_${goal}_$i'),
              _suggestion == context.tr('ob.sug_${goal}_$i') &&
                  _customTask.text.trim().isEmpty,
              () => setState(() {
                _suggestion = context.tr('ob.sug_${goal}_$i');
                _customTask.clear();
              }),
            ),
          ),
        _Reveal(
          delay: const Duration(milliseconds: 460),
          child: TextField(
            controller: _customTask,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: theme.textColor),
            decoration: InputDecoration(
              hintText: context.tr('ob.task_custom'),
              hintStyle: TextStyle(color: theme.textSecondaryColor),
              prefixIcon: Icon(Icons.edit_rounded, color: tone.fg),
              filled: true,
              fillColor: theme.cardColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _option(ThemeProvider theme, ToneColors tone, String label,
      bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Pressable(
        onTap: () {
          SoundService.instance.play(Sfx.check);
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? tone.fg : theme.cardColor,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? tone.onFg : theme.textColor,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: Icon(Icons.check_circle_rounded, color: tone.onFg),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _personalityPage(ThemeProvider theme) {
    final tone = theme.tone(_tones[5]);
    Widget group(String titleKey, List<(String, String)> opts, String? value,
        ValueChanged<String> onPick, int baseDelay) {
      return _Reveal(
        delay: Duration(milliseconds: baseDelay),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(titleKey),
              style: TextStyle(
                color: theme.textColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final o in opts)
              _option(theme, tone, context.tr(o.$2), value == o.$1,
                  () => onPick(o.$1)),
            const SizedBox(height: 14),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
      children: [
        _header(theme, tone, 4, 'ob.person_title', 'ob.person_sub'),
        group(
          'ob.energy_title',
          const [
            ('intro', 'ob.energy_intro'),
            ('mixed', 'ob.energy_mixed'),
            ('extro', 'ob.energy_extro'),
          ],
          _energy,
          (v) => setState(() => _energy = v),
          100,
        ),
        group(
          'ob.style_title',
          const [
            ('planner', 'ob.style_planner'),
            ('mixed', 'ob.style_mixed'),
            ('flow', 'ob.style_flow'),
          ],
          _style,
          (v) => setState(() => _style = v),
          260,
        ),
      ],
    );
  }

  Widget _timePage(ThemeProvider theme) {
    final tone = theme.tone(_tones[6]);
    final loc = MaterialLocalizations.of(context);

    Widget row(String label, TimeOfDay t, bool wake, IconData icon, Tone tn,
        int delay) {
      final c = theme.tone(tn);
      return _Reveal(
        delay: Duration(milliseconds: delay),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _Pressable(
            onTap: () => _pickTime(wake),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: c.fg),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            color: theme.textColor,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: c.bg,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      loc.formatTimeOfDay(t),
                      style: TextStyle(
                          color: c.fg, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
      children: [
        _header(theme, tone, 5, 'ob.time_title', 'ob.time_sub'),
        row(context.tr('ob.wake_time'), _wake, true, Icons.wb_sunny_rounded,
            Tone.butter, 100),
        row(context.tr('ob.remind_time'), _remind, false,
            Icons.notifications_active_rounded, Tone.peach, 220),
      ],
    );
  }

  // ───────────────────────── جشن پایانی ─────────────────────────

  Widget _celebration(ThemeProvider theme, ToneColors tone) {
    return Center(
      key: const ValueKey('celebration'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 260,
            height: 260,
            child: Lottie.asset(
              'assets/animations/celebration.json',
              repeat: false,
              errorBuilder: (_, __, ___) => Icon(
                Icons.emoji_events_rounded,
                size: 120,
                color: tone.fg,
              ),
            ),
          ),
          _Reveal(
            delay: const Duration(milliseconds: 200),
            child: Text(
              context.tr('ob.finish_title'),
              style: TextStyle(
                color: theme.textColor,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _Reveal(
            delay: const Duration(milliseconds: 420),
            child: Text(
              context.tr('ob.finish_sub'),
              style: TextStyle(
                  color: theme.textSecondaryColor, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════ ابزارهای انیمیشن ═══════════════════════════

/// ظاهر شدن نرم (محو شدن + بالا آمدن) با تاخیر دلخواه؛ برای ورود پلکانی اجزا
class _Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _Reveal({required this.child, this.delay = Duration.zero});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _shown = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay + const Duration(milliseconds: 30), () {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _shown ? Offset.zero : const Offset(0, 0.12),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// کمی کوچک شدن هنگام لمس
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

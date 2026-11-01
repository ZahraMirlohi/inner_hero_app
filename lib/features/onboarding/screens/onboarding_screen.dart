// lib/features/onboarding/screens/onboarding_screen.dart
//
// اولین ورود: سه اسلاید معرفی + چند سوال کوتاه. پاسخ‌ها در AuthProvider.completeOnboarding
// (محلی + جدول user_onboarding) ذخیره می‌شوند و بعدها برای پیشنهاد عادت و مربی هوش مصنوعی به‌کار می‌روند.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/l10n/app_strings.dart';
import '/providers/auth_provider.dart';
import '/providers/settings_provider.dart';
import '/providers/theme_provider.dart';
import '/services/sound_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _introCount = 3;
  static const int _questionCount = 4;
  static const int _total = _introCount + _questionCount;

  final PageController _pages = PageController();
  int _page = 0;
  bool _saving = false;

  final Set<String> _goals = {};
  String? _obstacle;
  String? _level;
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _remind = const TimeOfDay(hour: 20, minute: 0);

  static const _goalKeys = [
    'health', 'study', 'work', 'mind', 'sleep', 'money', 'social', 'other',
  ];
  static const _obstacleKeys = ['forget', 'lazy', 'busy', 'motivation', 'all'];
  static const _levelKeys = ['new', 'sometimes', 'pro'];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  bool get _isIntro => _page < _introCount;
  bool get _isLast => _page == _total - 1;

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _go(int page) async {
    await _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  bool _canContinue() {
    switch (_page - _introCount) {
      case 0:
        return _goals.isNotEmpty;
      case 1:
        return _obstacle != null;
      case 2:
        return _level != null;
      default:
        return true;
    }
  }

  Future<void> _next() async {
    if (!_isIntro && !_canContinue()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('ob.pick_one'))));
      SoundService.instance.play(Sfx.error);
      return;
    }
    SoundService.instance.play(Sfx.tap);
    if (_isLast) {
      await _finish();
    } else {
      await _go(_page + 1);
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final lang = context.read<SettingsProvider>().language;
    final messenger = ScaffoldMessenger.of(context);
    final errorText = context.tr('ob.save_error');

    final ok = await auth.completeOnboarding(
      OnboardingAnswers(
        goals: _goals.toList(),
        obstacle: _obstacle,
        level: _level,
        wakeTime: _hhmm(_wake),
        remindTime: _hhmm(_remind),
        language: lang,
      ),
    );
    SoundService.instance.play(Sfx.complete);
    if (!ok) messenger.showSnackBar(SnackBar(content: Text(errorText)));
    // بعد از ذخیره، HeroApp خودکار صفحهٔ بعد را نشان می‌دهد
  }

  Future<void> _pickTime(bool wake) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: wake ? _wake : _remind,
    );
    if (picked != null) {
      setState(() => wake ? _wake = picked : _remind = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(theme),
            Expanded(
              child: PageView(
                controller: _pages,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _slide(theme, Icons.checklist_rounded, 'ob.slide1_title',
                      'ob.slide1_body'),
                  _slide(theme, Icons.local_fire_department_rounded,
                      'ob.slide2_title', 'ob.slide2_body'),
                  _slide(theme, Icons.groups_rounded, 'ob.slide3_title',
                      'ob.slide3_body'),
                  _goalsPage(theme),
                  _singleChoicePage(
                    theme,
                    titleKey: 'ob.obstacle_title',
                    subKey: 'ob.obstacle_sub',
                    keys: _obstacleKeys,
                    prefix: 'ob.obstacle_',
                    selected: _obstacle,
                    onSelect: (v) => setState(() => _obstacle = v),
                  ),
                  _singleChoicePage(
                    theme,
                    titleKey: 'ob.level_title',
                    subKey: 'ob.level_sub',
                    keys: _levelKeys,
                    prefix: 'ob.level_',
                    selected: _level,
                    onSelect: (v) => setState(() => _level = v),
                  ),
                  _timePage(theme),
                ],
              ),
            ),
            _bottomBar(theme),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── اجزا ─────────────────────────

  Widget _topBar(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_page + 1) / _total,
                minHeight: 8,
                backgroundColor: theme.cardSecondaryColor,
                color: theme.primaryColor,
              ),
            ),
          ),
          if (_isIntro) ...[
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => _go(_introCount),
              child: Text(context.tr('ob.skip')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar(ThemeProvider theme) {
    final label = _isLast
        ? context.tr('ob.finish')
        : (_page == _introCount - 1
            ? context.tr('ob.lets_start')
            : context.tr('ob.next'));

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        children: [
          if (_page > 0 && !_saving)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: SizedBox(
                height: 56,
                width: 56,
                child: Material(
                  color: theme.cardColor,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _go(_page - 1),
                    child: Icon(Icons.arrow_back_rounded,
                        color: theme.textColor,
                        textDirection: Directionality.of(context)),
                  ),
                ),
              ),
            ),
          Expanded(
            child: SizedBox(
              height: 56,
              child: Material(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(28),
                child: InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: _saving ? null : _next,
                  child: Center(
                    child: _saving
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: theme.onPrimaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                context.tr('ob.saving'),
                                style: TextStyle(color: theme.onPrimaryColor),
                              ),
                            ],
                          )
                        : Text(
                            label,
                            style: TextStyle(
                              color: theme.onPrimaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slide(ThemeProvider theme, IconData icon, String titleKey,
      String bodyKey) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 56, color: theme.onPrimaryColor),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            context.tr(titleKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            context.tr(bodyKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textSecondaryColor,
              fontSize: 15,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionHeader(ThemeProvider theme, int n, String titleKey,
      String subKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('ob.q_progress',
              {'n': '$n', 'total': '$_questionCount'}),
          style: TextStyle(color: theme.textSecondaryColor, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(titleKey),
          style: TextStyle(
            color: theme.textColor,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr(subKey),
          style: TextStyle(color: theme.textSecondaryColor, fontSize: 14),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _option(ThemeProvider theme, String label, bool selected,
      VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? theme.primaryColor.withValues(alpha: 0.22)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            SoundService.instance.play(Sfx.tap);
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 15,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: selected
                        ? theme.primaryColor
                        : theme.cardSecondaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: selected
                      ? Icon(Icons.check_rounded,
                          size: 18, color: theme.onPrimaryColor)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _goalsPage(ThemeProvider theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      children: [
        _questionHeader(theme, 1, 'ob.goals_title', 'ob.goals_sub'),
        for (final k in _goalKeys)
          _option(
            theme,
            context.tr('ob.goal_$k'),
            _goals.contains(k),
            () => setState(() {
              if (!_goals.add(k)) _goals.remove(k);
            }),
          ),
      ],
    );
  }

  Widget _singleChoicePage(
    ThemeProvider theme, {
    required String titleKey,
    required String subKey,
    required List<String> keys,
    required String prefix,
    required String? selected,
    required ValueChanged<String> onSelect,
  }) {
    final n = prefix == 'ob.obstacle_' ? 2 : 3;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      children: [
        _questionHeader(theme, n, titleKey, subKey),
        for (final k in keys)
          _option(theme, context.tr('$prefix$k'), selected == k,
              () => onSelect(k)),
      ],
    );
  }

  Widget _timePage(ThemeProvider theme) {
    final loc = MaterialLocalizations.of(context);
    Widget row(String label, TimeOfDay t, bool wake) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              borderRadius: BorderRadius.circular(28),
              onTap: () => _pickTime(wake),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
                child: Row(
                  children: [
                    Icon(
                      wake
                          ? Icons.wb_sunny_rounded
                          : Icons.notifications_active_rounded,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(label,
                          style: TextStyle(
                              color: theme.textColor, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        loc.formatTimeOfDay(t),
                        style: TextStyle(
                          color: theme.textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      children: [
        _questionHeader(theme, 4, 'ob.time_title', 'ob.time_sub'),
        row(context.tr('ob.wake_time'), _wake, true),
        row(context.tr('ob.remind_time'), _remind, false),
      ],
    );
  }
}

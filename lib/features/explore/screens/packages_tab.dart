import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/package_model.dart';
import '../../../services/supabase_service.dart';
import '/providers/theme_provider.dart';
import '/providers/sync_provider.dart';
import '/core/app_palette.dart';
import '../widgets/card_image.dart';

class PackagesTab extends StatefulWidget {
  final List<Package> packages;
  final String currentUserId;
  final VoidCallback onRefresh;

  const PackagesTab({
    super.key,
    required this.packages,
    required this.currentUserId,
    required this.onRefresh,
  });

  @override
  State<PackagesTab> createState() => _PackagesTabState();
}

class _PackagesTabState extends State<PackagesTab> {
  final _supabase = SupabaseService();

  Set<String> _activePackageIds = {};
  bool _isLoadingActive = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadActivePackages();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  String _getCategoryText(String category) {
    switch (category) {
      case 'health':
        return 'سلامت';
      case 'study':
        return 'مطالعه';
      case 'productivity':
        return 'بهره‌وری';
      case 'sport':
        return 'ورزش';
      case 'nutrition':
        return 'تغذیه';
      case 'personal':
        return 'رشد شخصی';
      case 'fitness':
        return 'تناسب اندام';
      case 'mindfulness':
        return 'ذهن‌آگاهی';
      case 'reading':
        return 'مطالعه';
      case 'writing':
        return 'نوشتن';
      default:
        return category;
    }
  }

  String _getFrequencyText(String frequencyType) {
    switch (frequencyType) {
      case 'daily':
        return 'روزانه';
      case 'weekly':
        return 'هفتگی';
      case 'monthly':
        return 'ماهانه';
      default:
        return frequencyType;
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'psychology':
        return Icons.psychology;
      case 'attach_money':
        return Icons.attach_money;
      case 'favorite':
        return Icons.favorite;
      case 'forest':
        return Icons.forest;
      case 'whatshot':
        return Icons.whatshot;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'diamond':
        return Icons.diamond;
      case 'beach_access':
        return Icons.beach_access;
      case 'flare':
        return Icons.flare;
      case 'star':
        return Icons.star;
      case 'school':
        return Icons.school;
      case 'book':
        return Icons.book;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'science':
        return Icons.science;
      case 'restaurant':
        return Icons.restaurant;
      case 'bedtime':
        return Icons.bedtime;
      case 'water_drop':
        return Icons.water_drop;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'run_circle':
        return Icons.run_circle;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'checklist':
        return Icons.checklist;
      case 'sort':
        return Icons.sort;
      case 'timer':
        return Icons.timer;
      case 'breakfast_dining':
        return Icons.breakfast_dining;
      case 'apple':
        return Icons.apple;
      case 'no_food':
        return Icons.no_food;
      case 'flag':
        return Icons.flag;
      case 'edit_note':
        return Icons.edit_note;
      case 'description':
        return Icons.description;
      default:
        return Icons.inventory_2;
    }
  }

  Future<void> _loadActivePackages() async {
    // خط ۸۰: اینجا setState صدا زده می‌شه
    // قبلش چک کن mounted باشه
    if (!mounted) return;

    setState(() => _isLoadingActive = true);

    try {
      final userPackages = await _getUserActivePackages(widget.currentUserId);

      // خط ۱۱۴: اینجا setState صدا زده می‌شه
      // قبلش چک کن mounted باشه
      if (!mounted) return;

      setState(() {
        _activePackageIds = userPackages.map((p) => p.id).toSet();
        _isLoadingActive = false;
      });
    } catch (e) {
      print('Error loading active packages: $e');

      if (!mounted) return;

      setState(() {
        _activePackageIds = {};
        _isLoadingActive = false;
      });
    }
  }

  Future<List<Package>> _getUserActivePackages(String userId) async {
    try {
      final userPackagesResponse = await _supabase.client
          .from('user_packages')
          .select('package_id')
          .eq('user_id', userId)
          .eq('is_active', true);

      if (userPackagesResponse.isEmpty) return [];

      final packageIds = userPackagesResponse
          .map((item) => item['package_id'] as String)
          .toList();

      final packagesResponse = await _supabase.client
          .from('packages')
          .select('*')
          .inFilter('id', packageIds);

      return packagesResponse.map((item) {
        final id = item['id'] as String;
        return Package.fromMap(item, id);
      }).toList();
    } catch (e) {
      print('Error getting user active packages: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final Color primaryColor = theme.primaryColor;

    return Container(
      color: theme.backgroundColor, // از Color(0xFFF7FCEB)
      child: _buildBody(primaryColor, theme),
    );
  }

  Widget _buildBody(Color primaryColor, ThemeProvider theme) {
    if (_isLoadingActive) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 16),
            Text(
              'در حال بارگذاری بسته‌ها...',
              style: TextStyle(
                color: theme.textSecondaryColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.packages.isEmpty) {
      return _buildEmptyState(primaryColor, theme);
    }

    final activePackages =
        widget.packages.where((p) => _activePackageIds.contains(p.id)).toList();
    final inactivePackages = widget.packages
        .where((p) => !_activePackageIds.contains(p.id))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 96, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── بسته‌های فعال (افقی) ───
          if (activePackages.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.check_circle_rounded,
              tone: Tone.mint,
              title: 'بسته‌های فعال من',
              color: primaryColor,
              count: activePackages.length,
            ),
            const SizedBox(height: 12),
            ...activePackages.map(
              (package) => _PackageCard(
                package: package,
                isActive: true,
                primaryColor: primaryColor,
                primaryLight: themeProviderLight(context),
                onChanged: () {
                  widget.onRefresh();
                  _loadActivePackages();
                },
                onDeactivate: () =>
                    _showDeactivateDialog(package, primaryColor),
                onView: () => _showPackageDetailDialog(package, primaryColor),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ─── بسته‌های موجود (عمودی) ───
          if (inactivePackages.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.inventory_2_rounded,
              tone: Tone.lime,
              title: 'بسته‌های موجود',
              color: primaryColor,
              count: inactivePackages.length,
            ),
            const SizedBox(height: 12),
            ...inactivePackages.map(
              (package) => _PackageCard(
                package: package,
                isActive: false,
                primaryColor: primaryColor,
                primaryLight: themeProviderLight(context),
                onChanged: () {
                  widget.onRefresh();
                  _loadActivePackages();
                },
                onActivate: () =>
                    _showActivatePreviewDialog(package, primaryColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color themeProviderLight(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    return themeProvider.primaryLight;
  }

  // ═══════════════════════════════════════════════════════════
  // دیالوگ مشاهده جزئیات بسته (فقط خواندنی)
  // ═══════════════════════════════════════════════════════════
  void _showPackageDetailDialog(Package package, Color primaryColor) =>
      _showPackageSheet(package, primaryColor, activate: false);

  // ═══════════════════════════════════════════════════════════
  // هدر بخش
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required int count,
    Tone tone = Tone.lime,
  }) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration:
              BoxDecoration(color: theme.tone(tone).bg, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: const Color(0xFF090909)),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.textColor)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // Empty State
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState(Color primaryColor, ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: primaryColor.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'هنوز بسته‌ای وجود ندارد',
            style: TextStyle(
              color: theme.textSecondaryColor, // 
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'به زودی بسته‌های جدید اضافه می‌شوند',
            style: TextStyle(
              color: theme.textSecondaryColor, // 
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // فعال‌سازی بسته
  // ═══════════════════════════════════════════════════════════
  Future<void> _activatePackage(Package package, Color primaryColor) async {
    try {
      await _supabase.activatePackage(widget.currentUserId, package.id);

      // چک کن mounted
      if (!mounted) return;

      setState(() => _activePackageIds.add(package.id));

      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('بسته "${package.title}" فعال شد! '),
            backgroundColor: primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // غیرفعال‌سازی بسته (با دیالوگ)
  // ═══════════════════════════════════════════════════════════
  void _showDeactivateDialog(Package package, Color primaryColor) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierColor: const Color(0xFF090909).withValues(alpha: 0.42),
      builder: (ctx) => Dialog(
        backgroundColor: theme.cardColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                    color: const Color(0xFFFFD3CF), shape: BoxShape.circle),
                child: const Icon(Icons.power_settings_new_rounded,
                    size: 28, color: Color(0xFF090909)),
              ),
              const SizedBox(height: 14),
              Text('غیرفعال کردن «${package.title}»؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: theme.textColor)),
              const SizedBox(height: 8),
              Text(
                  'عادت‌های این بسته از لیستت حذف می‌شن و پیشرفتشون از بین می‌ره. هر وقت خواستی می‌تونی دوباره فعالش کنی.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      color: theme.textSecondaryColor)),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _sheetButton('انصراف', null, theme.cardSecondaryColor,
                        theme.textColor, () => Navigator.pop(ctx)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _sheetButton('غیرفعال کردن', null,
                        theme.errorColor, Colors.white, () {
                      Navigator.pop(ctx);
                      _deactivatePackage(package, primaryColor);
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
// دیالوگ پیش‌نمایش و فعال‌سازی بسته
// ═══════════════════════════════════════════════════════════
  void _showActivatePreviewDialog(Package package, Color primaryColor) =>
      _showPackageSheet(package, primaryColor, activate: true);

  String _freqLabel(String t) {
    switch (t) {
      case 'weekly':
        return 'هفتگی';
      case 'monthly':
        return 'ماهانه';
      default:
        return 'روزانه';
    }
  }

  void _showPackageSheet(Package package, Color primaryColor,
      {required bool activate}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    const ink = Color(0xFF090909);
    final soft = theme.tone(Tone.lime).bg;

    Widget infoRow(IconData icon, String label, String value) => Container(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: ink),
              ),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textColor)),
              const Spacer(),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: theme.textSecondaryColor)),
            ],
          ),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0xFF090909).withValues(alpha: 0.42),
      builder: (ctx) => SafeArea(top: false, child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scroll) => Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: theme.borderColor,
                    borderRadius: BorderRadius.circular(3)),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                              color: ink, shape: BoxShape.circle),
                          child: Icon(_getIconData(package.icon),
                              size: 30, color: theme.effectivePrimary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(package.title,
                                  style: TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                      color: theme.textColor)),
                              const SizedBox(height: 4),
                              Text(package.description,
                                  style: TextStyle(
                                      fontSize: 13,
                                      height: 1.6,
                                      color: theme.textSecondaryColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.backgroundColor,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        children: [
                          infoRow(Icons.checklist_rounded, 'تعداد عادت‌ها',
                              '${package.habits.length} عادت'),
                          infoRow(Icons.star_rounded, 'پاداش XP',
                              '+${package.xpReward} XP'),
                          infoRow(Icons.military_tech_rounded, 'نشان',
                              package.badge),
                          infoRow(Icons.category_rounded, 'دسته‌بندی',
                              _getCategoryText(package.category)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('عادت‌های این بسته:',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: theme.textColor)),
                    const SizedBox(height: 6),
                    for (final h in package.habits)
                      Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                  color: ink, shape: BoxShape.circle),
                              child: Icon(_getIconData(h.iconName),
                                  size: 18, color: theme.effectivePrimary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(h.title,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textColor)),
                            ),
                            _sheetChip(_freqLabel(h.frequencyType),
                                theme.tone(Tone.mint).bg),
                            const SizedBox(width: 6),
                            _sheetChip('+${h.xpReward}',
                                theme.tone(Tone.peach).bg),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    20, 8, 20, MediaQuery.of(ctx).padding.bottom + 16),
                child: Row(
                  children: [
                    if (activate) ...[
                      Expanded(
                        child: _sheetButton('انصراف', null, theme.cardSecondaryColor,
                            theme.textColor, () => Navigator.pop(ctx)),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      flex: activate ? 2 : 1,
                      child: activate
                          ? _sheetButton(
                              'فعال‌سازی بسته',
                              Icons.play_arrow_rounded,
                              ink,
                              theme.effectivePrimary, () {
                              Navigator.pop(ctx);
                              _activatePackage(package, primaryColor);
                            })
                          : _sheetButton('بستن', null, ink, Colors.white,
                              () => Navigator.pop(ctx)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }

  Widget _sheetChip(String t, Color bg) => Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
        child: Text(t,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF090909))),
      );

  Widget _sheetButton(
      String label, IconData? icon, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(28)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 6)],
            Text(label,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
          ],
        ),
      ),
    );
  }

// ═══════════════════════════════════════════════════════════
// ردیف اطلاعات در دیالوگ
// ═══════════════════════════════════════════════════════════
  Widget _buildPreviewInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color primaryColor,
    required ThemeProvider theme, // پارامتر جدید
    Color? iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: (iconColor ?? primaryColor).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              icon,
              size: 18,
              color: iconColor ?? primaryColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.textSecondaryColor, // 
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: theme.textColor, // 
          ),
        ),
      ],
    );
  }

  Future<void> _deactivatePackage(Package package, Color primaryColor) async {
    try {
      // ۱. غیرفعال‌سازی بسته در دیتابیس
      await _supabase.deactivatePackage(widget.currentUserId, package.id);

      if (!mounted) return;

      // ۲. حذف عادت‌های این بسته از کش محلی
      try {
        final syncProvider = Provider.of<SyncProvider>(context, listen: false);

        // پیدا کردن عادت‌های این بسته در کش
        final habitsToRemove = syncProvider.habits.where((habit) {
          // عادت‌های بسته با '' شروع می‌شن
          return habit.title.startsWith('📦') &&
              habit.title.contains(package.title);
        }).toList();

        // حذف هر عادت
        for (final habit in habitsToRemove) {
          syncProvider.removeHabit(habit.id);
        }

        print(
            '✅ Removed ${habitsToRemove.length} habits from package "${package.title}"');
      } catch (e) {
        print('Error removing package habits from cache: $e');
      }

      // ۳. ریفرش
      if (!mounted) return;
      setState(() => _activePackageIds.remove(package.id));
      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('بسته "${package.title}" غیرفعال شد'),
            backgroundColor: const Color(0xFF090909),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// کارت بسته (ترکیب ایده ۲ + ۴)
// ═══════════════════════════════════════════════════════════════

class _PackageCard extends StatelessWidget {
  final Package package;
  final bool isActive;
  final Color primaryColor;
  final Color primaryLight; // اضافه شد
  final VoidCallback onChanged;
  final VoidCallback? onActivate;
  final VoidCallback? onDeactivate;
  final VoidCallback? onView; // اضافه شد

  const _PackageCard({
    required this.package,
    required this.isActive,
    required this.primaryColor,
    required this.primaryLight,
    required this.onChanged,
    this.onActivate,
    this.onDeactivate,
    this.onView,
  });

  // پالت رنگ‌های پاستیلی ساده
  static const List<Color> _pastelColors = [
    Color(0xFFFFE0B2), // نارنجی پاستیلی
    Color(0xFFB3E5FC), // آبی پاستیلی
    Color(0xFFC8E6C9), // سبز پاستیلی
    Color(0xFFF8BBD0), // صورتی پاستیلی
    Color(0xFFD1C4E9), // بنفش پاستیلی
    Color(0xFFFFF9C4), // زرد پاستیلی
  ];

  // انتخاب رنگ پاستیلی بر اساس hashCode پکیج
  Color get _iconBgColor {
    final index = package.id.hashCode.abs() % _pastelColors.length;
    return _pastelColors[index];
  }

  // رنگ تیره‌تر برای آیکون (هم‌خانواده با پاستیلی)
  Color get _iconColor {
    final index = package.id.hashCode.abs() % _pastelColors.length;
    const darkerColors = [
      Color.fromARGB(255, 255, 130, 58), // نارنجی تیره
      Color.fromARGB(255, 42, 154, 189), // آبی تیره
      Color.fromARGB(255, 95, 125, 46), // سبز تیره
      Color.fromARGB(255, 175, 66, 126), // صورتی تیره
      Color.fromARGB(255, 124, 73, 182), // بنفش تیره
      Color.fromARGB(255, 255, 153, 57), // زرد تیره
    ];
    return darkerColors[index];
  }

  static const _ink = Color(0xFF090909);
  static const _tones = [Tone.lilac, Tone.butter, Tone.sky, Tone.peach, Tone.rose, Tone.lime];

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final tone = isActive
        ? theme.tone(Tone.mint)
        : theme.tone(_tones[package.id.hashCode.abs() % _tones.length]);
    final habits = package.habits.take(3).toList();
    final remaining = package.habits.length - habits.length;
    final white70 = Colors.white.withValues(alpha: 0.7);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration:
                    const BoxDecoration(color: _ink, shape: BoxShape.circle),
                child: Icon(_getIconData(package.icon),
                    size: 26, color: theme.effectivePrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(package.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _ink)),
                    if (package.category.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _chip(package.category, bg: white70),
                    ],
                  ],
                ),
              ),
              if (isActive)
                _chip('فعال',
                    icon: Icons.check_circle_rounded,
                    bg: const Color(0xFF2ECC71),
                    bold: true),
              if (CardImage.has(package.imageUrl)) ...[
                const SizedBox(width: 10),
                CardImage(
                  url: package.imageUrl,
                  width: 72,
                  height: 72,
                  borderRadius: BorderRadius.circular(20),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(package.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, height: 1.8, color: Color(0xFF3C4034))),
          const SizedBox(height: 12),
          for (final h in habits)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration:
                        BoxDecoration(color: white70, shape: BoxShape.circle),
                    child: Icon(_getIconData(h.iconName), size: 14, color: _ink),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(h.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _ink)),
                  ),
                ],
              ),
            ),
          if (remaining > 0)
            Text('... و $remaining عادت دیگر',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3C4034))),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip('${package.habits.length} عادت',
                  icon: Icons.checklist_rounded, bg: white70),
              _chip('+${package.xpReward} XP',
                  icon: Icons.star_rounded, bg: white70, bold: true),
              if (package.badge.isNotEmpty && package.badge != '📦')
                _chip(package.badge, bg: white70),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isActive && onView != null)
                _pill('مشاهده', Icons.visibility_outlined, Colors.white, _ink,
                    onView!),
              if (isActive && onDeactivate != null) ...[
                const SizedBox(width: 8),
                _pill('غیرفعال', Icons.power_settings_new_rounded,
                    const Color(0xFFFFD3CF), _ink, onDeactivate!),
              ],
              if (!isActive && onActivate != null)
                _pill('فعال‌سازی', Icons.play_arrow_rounded, _ink,
                    Colors.white, onActivate!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String text,
      {IconData? icon, required Color bg, bool bold = false}) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: _ink),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: _ink)),
        ],
      ),
    );
  }

  Widget _pill(String label, IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // آیکون‌ها
  // ═══════════════════════════════════════════════════════════
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'fitness_center':
        return Icons.fitness_center;
      case 'psychology':
        return Icons.psychology;
      case 'attach_money':
        return Icons.attach_money;
      case 'favorite':
        return Icons.favorite;
      case 'forest':
        return Icons.forest;
      case 'whatshot':
        return Icons.whatshot;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'diamond':
        return Icons.diamond;
      case 'beach_access':
        return Icons.beach_access;
      case 'flare':
        return Icons.flare;
      case 'star':
        return Icons.star;
      case 'school':
        return Icons.school;
      case 'book':
        return Icons.book;
      case 'self_improvement':
        return Icons.self_improvement;
      case 'science':
        return Icons.science;
      case 'restaurant':
        return Icons.restaurant;
      case 'bedtime':
        return Icons.bedtime;
      case 'water_drop':
        return Icons.water_drop;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'run_circle':
        return Icons.run_circle;
      case 'calendar_today':
        return Icons.calendar_today;
      case 'checklist':
        return Icons.checklist;
      case 'sort':
        return Icons.sort;
      case 'timer':
        return Icons.timer;
      case 'breakfast_dining':
        return Icons.breakfast_dining;
      case 'apple':
        return Icons.apple;
      case 'no_food':
        return Icons.no_food;
      case 'flag':
        return Icons.flag;
      case 'edit_note':
        return Icons.edit_note;
      case 'description':
        return Icons.description;
      default:
        return Icons.inventory_2;
    }
  }
}

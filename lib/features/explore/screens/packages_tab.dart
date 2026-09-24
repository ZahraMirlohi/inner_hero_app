// lib/features/explore/screens/packages_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/package_model.dart';
import '../../../services/supabase_service.dart';
import '/providers/theme_provider.dart';
import '/providers/sync_provider.dart';

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
    // ⚠️ خط ۸۰: اینجا setState صدا زده می‌شه
    // قبلش چک کن mounted باشه
    if (!mounted) return;

    setState(() => _isLoadingActive = true);

    try {
      final userPackages = await _getUserActivePackages(widget.currentUserId);

      // ⚠️ خط ۱۱۴: اینجا setState صدا زده می‌شه
      // قبلش چک کن mounted باشه
      if (!mounted) return;

      setState(() {
        _activePackageIds = userPackages.map((p) => p.id).toSet();
        _isLoadingActive = false;
      });
    } catch (e) {
      print('❌ Error loading active packages: $e');

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
      print('❌ Error getting user active packages: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color primaryColor = themeProvider.primaryColor;

    // ═══════════════════════════════════════════════════════
    // 🎨 پس‌زمینه ملایم
    // ═══════════════════════════════════════════════════════
    return Container(
      color: const Color(0xFFF7FCEB),
      child: _buildBody(primaryColor),
    );
  }

  Widget _buildBody(Color primaryColor) {
    if (_isLoadingActive) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 16),
            const Text(
              'در حال بارگذاری بسته‌ها...',
              style: TextStyle(color: Color(0xFF73786B), fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (widget.packages.isEmpty) {
      return _buildEmptyState(primaryColor);
    }

    final activePackages =
        widget.packages.where((p) => _activePackageIds.contains(p.id)).toList();
    final inactivePackages = widget.packages
        .where((p) => !_activePackageIds.contains(p.id))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 100, 16, 120), // ✅ از 12 به 100
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── بسته‌های فعال (افقی) ───
          if (activePackages.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.check_circle,
              title: 'بسته‌های فعال من',
              color: primaryColor,
              count: activePackages.length,
            ),
            const SizedBox(height: 12),
            // ✅ اسکرول افقی
            SizedBox(
              height: 260, // ✅ ارتفاع ثابت برای کارت‌های فعال
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                itemCount: activePackages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: SizedBox(
                      width: 260, // ✅ عرض ثابت برای هر کارت
                      child: _PackageCard(
                        package: activePackages[index],
                        isActive: true,
                        primaryColor: primaryColor,
                        primaryLight: themeProviderLight(context),
                        onChanged: () {
                          widget.onRefresh();
                          _loadActivePackages();
                        },
                        onDeactivate: () => _showDeactivateDialog(
                          activePackages[index],
                          primaryColor,
                        ),
                        // ✅ اصلاح شد
                        onView: () => _showPackageDetailDialog(
                          // ✅ دیالوگ جدید
                          activePackages[index],
                          primaryColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ─── بسته‌های موجود (عمودی) ───
          if (inactivePackages.isNotEmpty) ...[
            _buildSectionHeader(
              icon: Icons.inventory_2,
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
  // 📋 دیالوگ مشاهده جزئیات بسته (فقط خواندنی)
  // ═══════════════════════════════════════════════════════════
  void _showPackageDetailDialog(Package package, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // ─── نشانگر کشیدن ───
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 60,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ─── محتوای اسکرول‌شونده ───
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ═══════════════════════════════════════
                          // ─── هدر: آیکون + عنوان + بج «فعال» ───
                          // ═══════════════════════════════════════
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          primaryColor.withValues(alpha: 0.30),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    _getIconData(package.icon),
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      package.title,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF090909),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          _getCategoryText(package.category),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF73786B),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // ✅ بج «فعال»
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withValues(
                                                alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 11,
                                                color: primaryColor,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                'فعال',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: primaryColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ═══════════════════════════════════════
                          // ─── توضیحات ───
                          // ═══════════════════════════════════════
                          Text(
                            package.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF090909),
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ═══════════════════════════════════════
                          // ─── اطلاعات بسته ───
                          // ═══════════════════════════════════════
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildPreviewInfoRow(
                                  icon: Icons.checklist,
                                  label: 'تعداد عادت‌ها',
                                  value: '${package.habits.length} عادت',
                                  primaryColor: primaryColor,
                                ),
                                const SizedBox(height: 12),
                                _buildPreviewInfoRow(
                                  icon: Icons.stars,
                                  label: 'پاداش XP',
                                  value: '+${package.xpReward} XP',
                                  primaryColor: primaryColor,
                                  iconColor: const Color(0xFFFFA500),
                                ),
                                const SizedBox(height: 12),
                                _buildPreviewInfoRow(
                                  icon: Icons.emoji_events,
                                  label: 'نشان',
                                  value: package.badge,
                                  primaryColor: primaryColor,
                                  iconColor: const Color(0xFF9B59B6),
                                ),
                                const SizedBox(height: 12),
                                _buildPreviewInfoRow(
                                  icon: Icons.category,
                                  label: 'دسته‌بندی',
                                  value: _getCategoryText(package.category),
                                  primaryColor: primaryColor,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ═══════════════════════════════════════
                          // ─── لیست عادت‌ها ───
                          // ═══════════════════════════════════════
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.list_alt,
                                  color: primaryColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'عادت‌های این بسته',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF090909),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${package.habits.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // لیست همه عادت‌ها
                          ...package.habits.map((habit) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF090909)
                                      .withValues(alpha: 0.06),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // آیکون عادت
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color:
                                          primaryColor.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _getIconData(habit.iconName),
                                        size: 18,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // عنوان + توضیحات
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          habit.title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF090909),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (habit.description.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            habit.description,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF73786B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // فرکانس
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _getFrequencyText(habit.frequencyType),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // ═══════════════════════════════════════
                  // ─── دکمه بستن (ثابت پایین) ───
                  // ═══════════════════════════════════════
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      MediaQuery.of(context).padding.bottom + 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color:
                              const Color(0xFF090909).withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF090909),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'بستن',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ هدر بخش
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
    required int count,
  }) {
    return Center(
      // ✅ وسط‌چین
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF090909).withValues(alpha: 0.08), // ✅ مشکی
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF090909), // ✅ مشکی
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF090909), // ✅ مشکی
            ),
          ),
          const SizedBox(width: 8),
          // ✅ شمارنده کنار عنوان
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF090909).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF090909),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📦 Empty State
  // ═══════════════════════════════════════════════════════════
  Widget _buildEmptyState(Color primaryColor) {
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
          const Text(
            'هنوز بسته‌ای وجود ندارد',
            style: TextStyle(
              color: Color(0xFF73786B),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'به زودی بسته‌های جدید اضافه می‌شوند',
            style: TextStyle(color: Color(0xFF73786B), fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ فعال‌سازی بسته
  // ═══════════════════════════════════════════════════════════
  Future<void> _activatePackage(Package package, Color primaryColor) async {
    try {
      await _supabase.activatePackage(widget.currentUserId, package.id);

      // ✅ چک کن mounted
      if (!mounted) return;

      setState(() => _activePackageIds.add(package.id));

      widget.onRefresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('بسته "${package.title}" فعال شد! 🎉'),
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
  // 🗑️ غیرفعال‌سازی بسته (با دیالوگ)
  // ═══════════════════════════════════════════════════════════
  void _showDeactivateDialog(Package package, Color primaryColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFEF4444),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'غیرفعال کردن بسته',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF090909),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'آیا از غیرفعال کردن بسته "${package.title}" مطمئن هستید؟',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFA500).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFA500).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.info_outline,
                        color: Color(0xFFFFA500),
                        size: 16,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'نکات مهم:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFA500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '• تمام عادت‌های این بسته از لیست شما حذف می‌شوند\n'
                    '• پیشرفت عادت‌ها از دست می‌رود\n'
                    '• می‌توانید دوباره فعال کنید',
                    style: TextStyle(fontSize: 11, height: 1.6),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'انصراف',
              style: TextStyle(color: Color(0xFF73786B)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deactivatePackage(package, primaryColor);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('غیرفعال کردن'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
// 📋 دیالوگ پیش‌نمایش و فعال‌سازی بسته
// ═══════════════════════════════════════════════════════════
  void _showActivatePreviewDialog(
    Package package,
    Color primaryColor,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // ─── نشانگر کشیدن ───
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 60,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // ─── محتوای اسکرول‌شونده ───
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ═══════════════════════════════════════
                          // ─── هدر: آیکون + عنوان ───
                          // ═══════════════════════════════════════
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF090909),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    _getIconData(package.icon),
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      package.title,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF090909),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _getCategoryText(package.category),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF73786B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ═══════════════════════════════════════
                          // ─── توضیحات ───
                          // ═══════════════════════════════════════
                          Text(
                            package.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF090909),
                              height: 1.6,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ═══════════════════════════════════════
                          // ─── اطلاعات بسته ───
                          // ═══════════════════════════════════════
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7FCEB),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildPreviewInfoRow(
                                  icon: Icons.checklist,
                                  label: 'تعداد عادت‌ها',
                                  value: '${package.habits.length} عادت',
                                  primaryColor: primaryColor,
                                ),
                                const SizedBox(height: 12),
                                _buildPreviewInfoRow(
                                  icon: Icons.stars,
                                  label: 'پاداش XP',
                                  value: '+${package.xpReward} XP',
                                  primaryColor: primaryColor,
                                  iconColor: const Color(0xFFFFA500),
                                ),
                                const SizedBox(height: 12),
                                _buildPreviewInfoRow(
                                  icon: Icons.emoji_events,
                                  label: 'نشان',
                                  value: package.badge,
                                  primaryColor: primaryColor,
                                  iconColor: const Color(0xFF9B59B6),
                                ),
                                const SizedBox(height: 12),
                                _buildPreviewInfoRow(
                                  icon: Icons.category,
                                  label: 'دسته‌بندی',
                                  value: _getCategoryText(package.category),
                                  primaryColor: primaryColor,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ═══════════════════════════════════════
                          // ─── لیست عادت‌ها ───
                          // ═══════════════════════════════════════
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.list_alt,
                                  color: primaryColor,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'عادت‌های این بسته',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF090909),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${package.habits.length}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // لیست همه عادت‌ها
                          ...package.habits.map((habit) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF090909)
                                      .withValues(alpha: 0.06),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // آیکون عادت
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF090909)
                                          .withValues(alpha: 0.06),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        _getIconData(habit.iconName),
                                        size: 18,
                                        color: const Color(0xFF090909),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // عنوان + فرکانس
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          habit.title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF090909),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (habit.description.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            habit.description,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF73786B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // فرکانس
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          primaryColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _getFrequencyText(habit.frequencyType),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 20),

                          // ═══════════════════════════════════════
                          // ─── هشدار ───
                          // ═══════════════════════════════════════
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFA500)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFFFA500)
                                    .withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: Color(0xFFFFA500),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'با فعال‌سازی این بسته، ${package.habits.length} عادت جدید به لیست عادت‌های شما اضافه می‌شود و می‌توانید پیشرفت خود را دنبال کنید.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF090909),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // ═══════════════════════════════════════
                  // ─── دکمه‌های اقدام (ثابت پایین) ───
                  // ═══════════════════════════════════════
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      MediaQuery.of(context).padding.bottom + 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color:
                              const Color(0xFF090909).withValues(alpha: 0.06),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // دکمه انصراف
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF73786B),
                              side: BorderSide(
                                color: const Color(0xFF090909)
                                    .withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text(
                              'انصراف',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // دکمه فعال‌سازی
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _activatePackage(package, primaryColor);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.play_arrow_rounded, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'فعال‌سازی بسته',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

// ═══════════════════════════════════════════════════════════
// 🏷️ ردیف اطلاعات در دیالوگ
// ═══════════════════════════════════════════════════════════
  Widget _buildPreviewInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color primaryColor,
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
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF73786B),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF090909),
          ),
        ),
      ],
    );
  }

  Future<void> _deactivatePackage(Package package, Color primaryColor) async {
    try {
      // ✅ ۱. غیرفعال‌سازی بسته در دیتابیس
      await _supabase.deactivatePackage(widget.currentUserId, package.id);

      if (!mounted) return;

      // ✅ ۲. حذف عادت‌های این بسته از کش محلی
      try {
        final syncProvider = Provider.of<SyncProvider>(context, listen: false);

        // پیدا کردن عادت‌های این بسته در کش
        final habitsToRemove = syncProvider.habits.where((habit) {
          // عادت‌های بسته با '📦' شروع می‌شن
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
        print('⚠️ Error removing package habits from cache: $e');
      }

      // ✅ ۳. ریفرش
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
// 🎯 کارت بسته (ترکیب ایده ۲ + ۴)
// ═══════════════════════════════════════════════════════════════

class _PackageCard extends StatelessWidget {
  final Package package;
  final bool isActive;
  final Color primaryColor;
  final Color primaryLight; // ✅ اضافه شد
  final VoidCallback onChanged;
  final VoidCallback? onActivate;
  final VoidCallback? onDeactivate;
  final VoidCallback? onView; // ✅ اضافه شد

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

  // ✅ پالت رنگ‌های پاستیلی ساده
  static const List<Color> _pastelColors = [
    Color(0xFFFFE0B2), // نارنجی پاستیلی
    Color(0xFFB3E5FC), // آبی پاستیلی
    Color(0xFFC8E6C9), // سبز پاستیلی
    Color(0xFFF8BBD0), // صورتی پاستیلی
    Color(0xFFD1C4E9), // بنفش پاستیلی
    Color(0xFFFFF9C4), // زرد پاستیلی
  ];

  // ✅ انتخاب رنگ پاستیلی بر اساس hashCode پکیج
  Color get _iconBgColor {
    final index = package.id.hashCode.abs() % _pastelColors.length;
    return _pastelColors[index];
  }

  // ✅ رنگ تیره‌تر برای آیکون (هم‌خانواده با پاستیلی)
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

  @override
  Widget build(BuildContext context) {
    // ✅ کارت فعال: رنگ اصلی | کارت غیرفعال: سفید
    final Color cardColor =
        isActive ? const Color.fromARGB(255, 216, 124, 159) : Colors.white;

    // ✅ رنگ متن: روی رنگ اصلی → مشکی | روی سفید → مشکی
    const Color textColor = Color(0xFF090909);

    // ✅ رنگ متن‌های ثانویه: روی رنگ اصلی → نیمه‌شفاف مشکی | روی سفید → خاکستری
    final Color subtleTextColor = isActive
        ? const Color(0xFF090909).withValues(alpha: 0.7)
        : const Color(0xFF73786B);

    return Container(
      margin: isActive ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? primaryColor.withValues(alpha: 0.35) // ✅ سایه رنگی
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor, // ✅ رنگ اصلی برای فعال
          borderRadius: BorderRadius.circular(24),
          border: isActive
              ? null // ✅ بدون بوردر برای فعال
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ═══════════════════════════════════════════════
              // ─── ردیف اول: عنوان + آیکون ───
              // ═══════════════════════════════════════════════
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 32,
                          height: 2,
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.white.withValues(alpha: 0.5)
                                : const Color(0xFFC57B97)
                                    .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildFloatingIcon(),
                ],
              ),

              const SizedBox(height: 10),

              // ─── توضیحات ───
              Text(
                package.description,
                style: TextStyle(
                  fontSize: 12,
                  color: subtleTextColor, // ✅
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 12),

              // ─── پیش‌نمایش عادت‌ها ───
              _buildHabitPreview(),

              const SizedBox(height: 12),

              // ─── ردیف پایین: اطلاعات + دکمه‌ها ───
              _buildBottomRow(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 آیکون شناور با پس‌زمینه پاستیلی
  // ═══════════════════════════════════════════════════════════
  Widget _buildFloatingIcon() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: _iconBgColor, // ✅ پس‌زمینه پاستیلی
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _iconBgColor.withValues(alpha: 0.5),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          _getIconData(package.icon),
          color: _iconColor, // ✅ آیکون رنگ تیره هم‌خانواده
          size: 26,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 پیش‌نمایش عادت‌ها
  // ═══════════════════════════════════════════════════════════
  Widget _buildHabitPreview() {
    final habits = package.habits.take(3).toList();
    final remaining = package.habits.length - habits.length;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 233, 233, 233),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFC57B97).withValues(alpha: 0.10),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...habits.map((habit) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC57B97).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Icon(
                        _getIconData(habit.iconName),
                        size: 11,
                        color: const Color(0xFFC57B97),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        habit.title,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF090909),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )),
          if (remaining > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '... و $remaining عادت دیگر',
                style: const TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF73786B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 ردیف پایین: اطلاعات + دکمه‌ها
  // ═══════════════════════════════════════════════════════════
  Widget _buildBottomRow() {
    return Row(
      children: [
        // تعداد عادت‌ها
        _buildInfoChip(
          icon: Icons.checklist,
          label: '${package.habits.length}',
        ),
        const SizedBox(width: 6),
        // XP
        _buildInfoChip(
          icon: Icons.stars,
          label: '+${package.xpReward}',
          iconColor: const Color(0xFFFFA500),
        ),
        const Spacer(),

        // ✅ دکمه‌ها
        if (isActive && onDeactivate != null && onView != null) ...[
          // دکمه مشاهده (مشکی روی سبز، خوانا)
          _buildViewButton(onView!),
          const SizedBox(width: 6),
          // دکمه غیرفعال (primaryLight — روی سبز متفاوت است)
          _buildDeactivateButton(onDeactivate!),
        ] else if (!isActive && onActivate != null) ...[
          _buildActivateButton(onActivate!),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏷️ Info Chip
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        // ✅ روی فعال: سفید نیمه‌شفاف | روی غیرفعال: مشکی ملایم
        color: isActive
            ? Colors.white.withValues(alpha: 0.25)
            : const Color(0xFF090909).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isActive
                ? Colors.white
                : (iconColor ?? const Color(0xFF090909)),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : const Color(0xFF090909),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ دکمه مشاهده (مشکی)
  // ═══════════════════════════════════════════════════════════
  // ✅ دکمه مشاهده — روی کارت فعال: سفید با متن مشکی | روی کارت غیرفعال: مشکی
  Widget _buildViewButton(VoidCallback onView) {
    return GestureDetector(
      onTap: onView,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color.fromARGB(255, 0, 0, 0) // ✅ روی سبز: سفید
              : const Color.fromARGB(255, 255, 255, 255), // روی سفید: مشکی
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_outlined,
              size: 12,
              color: isActive
                  ? const Color.fromARGB(255, 255, 255, 255)
                  : const Color.fromARGB(255, 0, 0, 0),
            ),
            const SizedBox(width: 3),
            Text(
              'مشاهده',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? const Color.fromARGB(255, 255, 255, 255)
                    : const Color.fromARGB(255, 0, 0, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ دکمه غیرفعال — روی کارت فعال: سفید با متن مشکی | روی غیرفعال: primaryLight
  Widget _buildDeactivateButton(VoidCallback onDeactivate) {
    return GestureDetector(
      onTap: onDeactivate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withValues(alpha: 0.95) // ✅ روی سبز: سفید
              : const Color.fromARGB(
                  255, 209, 180, 255), // روی سفید: primaryLight
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF090909).withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline,
              size: 12,
              color: Color(0xFF090909),
            ),
            SizedBox(width: 3),
            Text(
              'غیرفعال',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF090909),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🟢 دکمه فعال‌سازی (مشکی)
  // ═══════════════════════════════════════════════════════════
  Widget _buildActivateButton(VoidCallback onActivate) {
    return GestureDetector(
      onTap: onActivate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFF090909), // ✅ مشکی
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'فعال‌سازی',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 آیکون‌ها
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

// lib/features/explore/screens/packages_tab.dart

import 'package:flutter/material.dart';
import '../models/package_model.dart';
import '../../../services/supabase_service.dart';
import 'package:provider/provider.dart';
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

  // ✅ لیست ID بسته‌های فعال کاربر
  Set<String> _activePackageIds = {};
  bool _isLoadingActive = true;

  @override
  void initState() {
    super.initState();
    _loadActivePackages();
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

// lib/features/explore/screens/packages_tab.dart

  Future<void> _loadActivePackages() async {
    setState(() {
      _isLoadingActive = true;
    });

    try {
      // ✅ دریافت بسته‌های فعال کاربر از دیتابیس
      final userPackages = await _getUserActivePackages(widget.currentUserId);

      setState(() {
        _activePackageIds = userPackages.map((p) => p.id).toSet();
        _isLoadingActive = false;
      });
    } catch (e) {
      print('❌ Error loading active packages: $e');
      setState(() {
        _activePackageIds = {};
        _isLoadingActive = false;
      });
    }
  }

  // ✅ متد دریافت بسته‌های فعال کاربر بدون استفاده از رابطه
  Future<List<Package>> _getUserActivePackages(String userId) async {
    try {
      // ✅ ابتدا ID بسته‌های فعال کاربر را بگیر
      final userPackagesResponse = await _supabase.client
          .from('user_packages')
          .select('package_id')
          .eq('user_id', userId)
          .eq('is_active', true);

      if (userPackagesResponse.isEmpty) return [];

      // ✅ استخراج ID بسته‌ها
      final packageIds = userPackagesResponse
          .map((item) => item['package_id'] as String)
          .toList();

      // ✅ دریافت اطلاعات کامل بسته‌ها
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
    if (_isLoadingActive) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
      );
    }

    if (widget.packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'هنوز بسته‌ای وجود ندارد',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              'به زودی بسته‌های جدید اضافه می‌شوند',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      );
    }

    // ✅ تفکیک بسته‌های فعال و غیرفعال
    final activePackages =
        widget.packages.where((p) => _activePackageIds.contains(p.id)).toList();

    final inactivePackages = widget.packages
        .where((p) => !_activePackageIds.contains(p.id))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // هدر
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2,
                  color: Color(0xFF4A90E2),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'بسته‌های آموزشی',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.packages.length} بسته',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF4A90E2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'با فعال‌سازی هر بسته، به مجموعه‌ای از عادت‌های هدفمند دسترسی پیدا می‌کنید',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // ✅ بسته‌های فعال
          if (activePackages.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'بسته‌های فعال من',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${activePackages.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...activePackages.map(
              (package) => _buildPackageCard(package, isActive: true),
            ),
            const SizedBox(height: 24),
          ],

          // ✅ بسته‌های غیرفعال
          if (inactivePackages.isNotEmpty) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2,
                    size: 18,
                    color: Color(0xFF4A90E2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'بسته‌های موجود',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A90E2).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${inactivePackages.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF4A90E2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...inactivePackages.map(
              (package) => _buildPackageCard(package, isActive: false),
            ),
          ],
        ],
      ),
    );
  }

// lib/features/explore/screens/packages_tab.dart

// ✅ قسمت ویژگی‌ها (با Wrap)
  Widget _buildPackageCard(Package package, {bool isActive = false}) {
    final color = isActive ? Colors.green : _parseColor(package.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.green.shade300 : color.withOpacity(0.15),
          width: isActive ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? Colors.green.withOpacity(0.08)
                : color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================================
          // بخش بالایی (کم‌حجم‌تر)
          // ============================================================
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // آیکون
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.12)
                        : color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconData(package.icon),
                    color: isActive ? Colors.green : color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),

                // عنوان و زیرعنوان
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        package.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? Colors.green.shade800
                              : const Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${package.habits.length} عادت',
                        style: TextStyle(
                          fontSize: 11,
                          color: isActive
                              ? Colors.green.shade600
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // وضعیت
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 12,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 2),
                        const Text(
                          'فعال',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),

                // نشان
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.08)
                        : color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    package.badge,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ============================================================
          // بخش پایین (جمع‌وجور) - ✅ اصلاح شده
          // ============================================================
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // توضیحات (خلاصه)
                Text(
                  package.description,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isActive ? Colors.green.shade700 : Colors.grey.shade600,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // ✅ ویژگی‌ها (با Wrap به جای Row)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    _buildFeatureChip(
                      icon: Icons.fitness_center,
                      label: '${package.habits.length}',
                      color: isActive ? Colors.green : color,
                    ),
                    _buildFeatureChip(
                      icon: Icons.stars,
                      label: '+${package.xpReward}',
                      color: isActive ? Colors.green : color,
                    ),
                    _buildFeatureChip(
                      icon: Icons.category,
                      label: _getCategoryText(package.category),
                      color: isActive ? Colors.green : color,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // دکمه‌ها
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        onPressed: () {
                          _showPackageDetailDialog(package, isActive);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isActive ? Colors.green : color,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                          minimumSize: const Size(0, 36),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isActive ? Icons.info_outline : Icons.visibility,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isActive ? 'اطلاعات' : 'فعال‌سازی',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!isActive) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+${package.xpReward}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: () {
                            _showDeactivatePackageDialog(package);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side:
                                const BorderSide(color: Colors.red, width: 0.5),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: const Size(0, 36),
                          ),
                          child: const Text(
                            'غیرفعال',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ اصلاح متد _activatePackage

  Future<void> _activatePackage(Package package) async {
    try {
      // ✅ 1. فعال‌سازی در دیتابیس
      await _supabase.activatePackage(widget.currentUserId, package.id);

      // ✅ 2. به‌روزرسانی لیست بسته‌های فعال
      setState(() {
        _activePackageIds.add(package.id);
      });

      // ✅ 3. ریفرش صفحه برای نمایش عادت‌ها
      widget.onRefresh();

      // ✅ 4. نمایش پیام موفقیت
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('بسته "${package.title}" فعال شد! 🎉'),
            backgroundColor: Colors.green,
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

  void _showDeactivatePackageDialog(Package package) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'غیرفعال کردن بسته',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'نکات مهم:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '• تمام عادت‌های این بسته از لیست شما حذف می‌شوند\n'
                    '• پیشرفت عادت‌های این بسته از دست می‌رود\n'
                    '• می‌توانید دوباره این بسته را فعال کنید',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deactivatePackage(package);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
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

// lib/features/explore/screens/packages_tab.dart

  Future<void> _deactivatePackage(Package package) async {
    try {
      // ✅ 1. غیرفعال کردن در دیتابیس
      await _supabase.deactivatePackage(widget.currentUserId, package.id);

      // ✅ 2. حذف عادت‌های بسته از لیست محلی
      final syncProvider = Provider.of<SyncProvider>(context, listen: false);

      final currentHabits = syncProvider.habits;
      final updatedHabits = currentHabits
          .where((habit) =>
              !habit.title.startsWith('📦') ||
              !habit.title.contains(package.title))
          .toList();

      // ✅ استفاده از saveHabits
      await syncProvider.saveHabits(updatedHabits);

      // ✅ 3. به‌روزرسانی وضعیت بسته در لیست
      setState(() {
        _activePackageIds.remove(package.id);
      });

      // ✅ 4. نمایش پیام موفقیت
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('بسته "${package.title}" غیرفعال شد 🗑️'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );

        // ✅ 5. ریفرش صفحه
        widget.onRefresh();
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

  Widget _buildFeatureChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.1), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // ✅ مهم: اندازه کوچک‌ترین
        children: [
          Icon(icon, size: 10, color: color.withOpacity(0.7)),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  void _showPackageDetailDialog(Package package, bool isActive) {
    final color = isActive ? Colors.green : _parseColor(package.color);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(_getIconData(package.icon), color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                package.title,
                style: const TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'فعال',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                package.description,
                style: TextStyle(color: Colors.grey.shade700, height: 1.5),
              ),
              const SizedBox(height: 16),

              // اطلاعات بسته
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'تعداد عادت‌ها:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${package.habits.length}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'پاداش XP:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '+${package.xpReward} XP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'نشان:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          package.badge,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'دسته‌بندی:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          package.category,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // لیست عادت‌ها
              if (package.habits.isNotEmpty) ...[
                const Text(
                  '📋 عادت‌های این بسته:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...package.habits.take(5).map(
                      (habit) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 14,
                              color: isActive
                                  ? Colors.green.withValues(alpha: 0.6)
                                  : color.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                habit.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isActive
                                      ? Colors.green.shade700
                                      : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (package.habits.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'و ${package.habits.length - 5} عادت دیگر...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('بازگشت'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (isActive) {
                // ✅ اگر فعال است، اطلاعات نشان داده می‌شود
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('بسته فعال است!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 1),
                  ),
                );
              } else {
                // ✅ فعال‌سازی بسته
                _activatePackage(package);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? Colors.green : color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(isActive ? 'اطلاعات' : 'فعال‌سازی بسته'),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      }
      return const Color(0xFF4A90E2);
    } catch (e) {
      return const Color(0xFF4A90E2);
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
      case 'inventory_2':
        return Icons.inventory_2;
      case 'school':
        return Icons.school;
      default:
        return Icons.inventory_2;
    }
  }
}

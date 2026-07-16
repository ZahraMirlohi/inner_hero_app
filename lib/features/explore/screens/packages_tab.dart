import 'package:flutter/material.dart';
import '../models/package_model.dart';
import '../models/user_packages.dart';
import '../widgets/package_card.dart';
import '/services/supabase_service.dart';

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

  @override
  Widget build(BuildContext context) {
    if (widget.packages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'هنوز بسته‌ای وجود ندارد',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<UserPackage>>(
      future: _supabase.getUserPackages(widget.currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4A90E2)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade300, size: 48),
                const SizedBox(height: 12),
                Text(
                  'خطا در بارگذاری بسته‌ها',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: widget.onRefresh,
                  child: const Text('تلاش مجدد'),
                ),
              ],
            ),
          );
        }

        final userPackages = snapshot.data ?? [];
        final activePackageIds = userPackages
            .where((p) => p.isActive)
            .map((p) => p.packageId)
            .toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.85,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: widget.packages.length,
          itemBuilder: (context, index) {
            final package = widget.packages[index];
            final isActive = activePackageIds.contains(package.id);

            return PackageCard(
              package: package,
              isActive: isActive,
              onChanged: widget.onRefresh,
            );
          },
        );
      },
    );
  }
}

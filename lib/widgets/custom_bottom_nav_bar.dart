// lib/widgets/custom_bottom_nav_bar.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/providers/theme_provider.dart';

class BottomNavItem {
  final IconData icon;
  final String label;

  const BottomNavItem({
    required this.icon,
    required this.label,
  });
}

/// نوار پایین: کپسول مشکی، آیتم فعال = کپسول رنگی با آیکون + برچسب.
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavItem> items;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final navColor = theme.isDarkMode ? Colors.white : const Color(0xFF090909);
    final inactive =
        theme.isDarkMode ? Colors.grey.shade400 : const Color(0xFF8A8A8A);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Center(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            width: 320,
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: navColor,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(items.length, (i) {
                final active = i == currentIndex;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!active) onTap(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    height: 48,
                    padding: EdgeInsets.symmetric(horizontal: active ? 14 : 10),
                    decoration: BoxDecoration(
                      color: active ? theme.primaryColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          items[i].icon,
                          size: 24,
                          color: active ? theme.onPrimaryColor : inactive,
                        ),
                        if (active) ...[
                          const SizedBox(width: 6),
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: Text(
                              items[i].label,
                              style: TextStyle(
                                color: theme.onPrimaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

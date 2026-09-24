// lib/widgets/custom_bottom_nav_bar.dart

import 'package:flutter/material.dart';

class BottomNavItem {
  final IconData icon;
  final String label;

  const BottomNavItem({
    required this.icon,
    required this.label,
  });
}

class CustomBottomNavBar extends StatefulWidget {
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
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;

  // ✅ اندازه‌های ثابت
  static const double _containerWidth = 280;
  static const double _containerHeight = 60;
  static const double _itemSize = 44;
  static const double _iconSize = 24;
  static const double _horizontalPadding = 8;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: widget.currentIndex.toDouble(),
      end: widget.currentIndex.toDouble(),
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void didUpdateWidget(CustomBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.currentIndex != widget.currentIndex) {
      _slideAnimation = Tween<double>(
        begin: oldWidget.currentIndex.toDouble(),
        end: widget.currentIndex.toDouble(),
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOutCubic,
        ),
      );
      _scaleAnimation = Tween<double>(
        begin: 0.6,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOutBack,
        ),
      );
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ محاسبه فاصله بین آیتم‌ها
    final double availableWidth = _containerWidth - (_horizontalPadding * 2);
    final double totalItemsWidth = _itemSize * widget.items.length;
    final double totalSpacing = availableWidth - totalItemsWidth;
    final double spacing = totalSpacing / (widget.items.length - 1);

    const double inactiveVerticalOffset = 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Center(
        // ✅ اجبار به LTR برای اینکه ترتیب آیتم‌ها به‌هم نریزد
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            width: _containerWidth,
            height: _containerHeight,
            padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
            decoration: BoxDecoration(
              color: const Color(0xFF090909),
              borderRadius: BorderRadius.circular(_containerHeight / 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 2,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ✅ دایره سبز متحرک
                AnimatedBuilder(
                  animation: _slideAnimation,
                  builder: (context, child) {
                    final double progress = _slideAnimation.value;
                    final double leftPosition =
                        (progress * (_itemSize + spacing));

                    return Positioned(
                      left: leftPosition,
                      top: (_containerHeight - _itemSize) / 2,
                      child: AnimatedBuilder(
                        animation: _scaleAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: _itemSize,
                              height: _itemSize,
                              decoration: const BoxDecoration(
                                color: Color(0xFFB0CC5D),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  widget.items[widget.currentIndex].icon,
                                  color: const Color(0xFF090909),
                                  size: _iconSize,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

                // ✅ همه آیتم‌ها
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(widget.items.length, (index) {
                    final isActive = index == widget.currentIndex;

                    return GestureDetector(
                      onTap: () {
                        if (widget.currentIndex != index) {
                          widget.onTap(index);
                        }
                      },
                      child: SizedBox(
                        width: _itemSize,
                        height: _itemSize,
                        child: isActive
                            ? const SizedBox()
                            : Transform.translate(
                                offset: Offset(0, inactiveVerticalOffset),
                                child: Center(
                                  child: Icon(
                                    widget.items[index].icon,
                                    color: const Color(0xFF6A6A6A),
                                    size: _iconSize,
                                  ),
                                ),
                              ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

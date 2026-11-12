// lib/widgets/bottom_safe.dart
//
// منطقهٔ امن پایین صفحه: روی اندروید جدید محتوا زیر دکمه‌های گوشی می‌رود؛ این ویجت صفحه را بالاتر می‌آورد.

import 'package:flutter/material.dart';

class BottomSafe extends StatelessWidget {
  final Widget child;
  const BottomSafe({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(top: false, child: child),
    );
  }
}

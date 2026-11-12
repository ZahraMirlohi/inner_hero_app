import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../l10n/app_strings.dart';
import '../../../providers/theme_provider.dart';

/// حباب لرزان «درخواست هم‌مسیر جدید»؛ با لمس، onTap صدا زده می‌شود.
class NewRequestPopup extends StatefulWidget {
  final int count;
  final VoidCallback onTap;
  final VoidCallback onClose;
  const NewRequestPopup(
      {super.key,
      required this.count,
      required this.onTap,
      required this.onClose});

  @override
  State<NewRequestPopup> createState() => _NewRequestPopupState();
}

class _NewRequestPopupState extends State<NewRequestPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final text = widget.count > 1
        ? context.tr('mp.req.many', {'n': '${widget.count}'})
        : context.tr('mp.req.one');
    return AnimatedBuilder(
      animation: _c,
      // لرزش کوتاه در ابتدای هر چرخه، بعد استراحت
      builder: (_, child) {
        final t = _c.value;
        final a = t < 0.5 ? math.sin(t * 2 * math.pi * 4) * 0.05 : 0.0;
        return Transform.rotate(angle: a, child: child);
      },
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              color: const Color(0xFF090909),
              borderRadius: BorderRadius.circular(28),
              boxShadow: theme.softShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_alt_rounded,
                    size: 20, color: theme.effectivePrimary),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(text,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: widget.onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

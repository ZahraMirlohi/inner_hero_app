import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/app_strings.dart';

/// پس‌زمینهٔ شخصی هر چت‌روم (فقط روی همین دستگاه ذخیره می‌شود)
class ChatBackground {
  static String _key(String convId) => 'chat_bg_$convId';

  static Future<String?> load(String convId) async {
    if (kIsWeb) return null;
    try {
      final p = (await SharedPreferences.getInstance()).getString(_key(convId));
      return (p != null && File(p).existsSync()) ? p : null;
    } catch (_) {
      return null;
    }
  }

  /// انتخاب عکس از گالری؛ مسیر ذخیره‌شده را برمی‌گرداند (null = لغو)
  static Future<String?> pick(String convId) async {
    if (kIsWeb) return null;
    try {
      final x = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
      if (x == null) return null;
      final dir = await getApplicationDocumentsDirectory();
      final dest = '${dir.path}/chat_bg_$convId.jpg';
      await File(x.path).copy(dest);
      await FileImage(File(dest)).evict();
      await (await SharedPreferences.getInstance()).setString(_key(convId), dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String convId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = prefs.getString(_key(convId));
      await prefs.remove(_key(convId));
      if (p != null && File(p).existsSync()) await File(p).delete();
    } catch (_) {}
  }
}

/// لایهٔ زیر پیام‌ها؛ با پوشش ملایم تا متن خوانا بماند
class ChatBackgroundLayer extends StatelessWidget {
  final String? path;
  final bool dark;
  const ChatBackgroundLayer({super.key, required this.path, required this.dark});

  @override
  Widget build(BuildContext context) {
    if (path == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(fit: StackFit.expand, children: [
          Image.file(File(path!), fit: BoxFit.cover),
          ColoredBox(
              color: (dark ? Colors.black : Colors.white)
                  .withValues(alpha: dark ? 0.45 : 0.35)),
        ]),
      ),
    );
  }
}

/// شیت انتخاب/حذف پس‌زمینه؛ مسیر جدید (یا null برای حذف) را به onChanged می‌دهد
Future<void> showChatBackgroundSheet(
    BuildContext context, String convId, ValueChanged<String?> onChanged) {
  return showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.wallpaper_rounded),
          title: Text(ctx.tr('bg.pick')),
          onTap: () async {
            Navigator.pop(ctx);
            final p = await ChatBackground.pick(convId);
            if (p != null) onChanged(p);
          },
        ),
        ListTile(
          leading: const Icon(Icons.hide_image_outlined),
          title: Text(ctx.tr('bg.remove')),
          onTap: () async {
            Navigator.pop(ctx);
            await ChatBackground.clear(convId);
            onChanged(null);
          },
        ),
      ]),
    ),
  );
}

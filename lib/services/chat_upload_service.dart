// انتخاب چندتایی و آپلود فایل/عکس/موزیک برای چت گروه و کانال
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AttachKind { image, file, music }

class ChatAttachment {
  final String name;
  final int size;
  final Uint8List bytes;
  final AttachKind kind;
  ChatAttachment(this.name, this.size, this.bytes, this.kind);
}

class ChatUploadService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// چند فایل را یک‌جا انتخاب می‌کند؛ فایل‌های ناخوانا نادیده گرفته می‌شوند.
  static Future<List<ChatAttachment>> pick(AttachKind kind) async {
    final out = <ChatAttachment>[];
    if (kind == AttachKind.image) {
      final images = await ImagePicker()
          .pickMultiImage(maxWidth: 1024, maxHeight: 1024, imageQuality: 80);
      for (final x in images) {
        final b = await x.readAsBytes();
        out.add(ChatAttachment(x.name, b.length, b, kind));
      }
      return out;
    }
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: kind == AttachKind.music ? FileType.audio : FileType.any,
      withData: false,
    );
    if (res == null) return out;
    for (final f in res.files) {
      try {
        final bytes = f.bytes ?? await File(f.path!).readAsBytes();
        out.add(ChatAttachment(f.name, bytes.length, bytes, kind));
      } catch (_) {}
    }
    return out;
  }

  /// آدرس عمومی فایل آپلودشده؛ در خطا استثنا می‌دهد.
  static Future<String> upload(ChatAttachment a, String folder) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('وارد حساب کاربری نشده‌اید');
    final ext = a.name.contains('.') ? a.name.substring(a.name.lastIndexOf('.')) : '';
    final path =
        '$folder/${user.id}/${DateTime.now().microsecondsSinceEpoch}$ext';
    await _client.storage.from('chat_files').uploadBinary(
          path,
          a.bytes,
          fileOptions: FileOptions(
            contentType: lookupMimeType(a.name) ?? 'application/octet-stream',
            upsert: true,
          ),
        );
    return _client.storage.from('chat_files').getPublicUrl(path);
  }
}

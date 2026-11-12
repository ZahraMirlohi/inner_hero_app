// lib/features/chat/screens/buddy_finder_screen.dart

import '/l10n/app_strings.dart';
import '/widgets/bottom_safe.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/buddy_matcher_service.dart';
import '/services/chat_service.dart';
import '/providers/theme_provider.dart';
import '/features/profile/models/user_personality.dart';
import '/features/profile/screens/personality_screen.dart';
import '/features/chat/models/conversation_model.dart';
import 'buddy_chat_screen.dart';
import 'user_profile_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BuddyFinderScreen extends StatefulWidget {
  const BuddyFinderScreen({super.key});

  @override
  State<BuddyFinderScreen> createState() => _BuddyFinderScreenState();
}

class _BuddyFinderScreenState extends State<BuddyFinderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BuddyMatcherService _matcherService = BuddyMatcherService();
  final ChatService _chatService = ChatService();
  final SupabaseClient _supabaseClient = Supabase.instance.client;

  // ==================== داده‌ها ====================
  List<Map<String, dynamic>> _allMatches = [];
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _myBuddies = [];

  bool _isLoading = true;
  String? _userId;
  bool _isInitialized = false;

  // فلگ برای تشخیص تغییرات (ارسال/لغو/قبول/رد درخواست)
  bool _hasChanges = false;

  // ==================== فیلترها ====================
  Gender? _filterGender;
  double _minMatchScore = 0;
  bool _showFilters = false;
  String? _myUsername;

  // ==================== وضعیت جستجو ====================
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;
  bool _hasSearched = false;
  Map<String, dynamic>? _searchResult;
  String? _searchError;
  String _lastSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // جستجوی کاربر با username یا phone
  // ═══════════════════════════════════════════════════════════
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty || _userId == null) return;

    // اگه قبلاً همین query رو جستجو کرده، دوباره نکن
    if (_lastSearchQuery == query && _hasSearched) {
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchError = null;
      _searchResult = null;
      _lastSearchQuery = query;
    });

    try {
      final result = await _matcherService.searchUserByUsernameOrPhone(
        currentUserId: _userId!,
        query: query,
      );

      if (!mounted) return;

      if (result == null) {
        setState(() {
          _isSearching = false;
          _searchError = context.tr('ct.bf.nouser');
        });
      } else {
        setState(() {
          _isSearching = false;
          _searchResult = result;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchError = context.tr('ct.bf.searchErr', {'e': e.toString()});
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchFocusNode.unfocus();
      _hasSearched = false;
      _searchResult = null;
      _searchError = null;
      _lastSearchQuery = '';
    });
  }

  // ═══════════════════════════════════════════════════════════
  // اشتراک‌گذاری لینک دعوت
  // ═══════════════════════════════════════════════════════════
  Future<void> _shareInvitationLink() async {
    try {
      final appLink =
          dotenv.env['APP_DOWNLOAD_LINK'] ?? 'https://innerhero.app/download';
      final appName = dotenv.env['APP_NAME'] ?? 'Dacko';

      final myUsername = _myUsername ?? context.tr('ct.bf.friend');

      final message = context.tr('ct.bf.share1',
          {'app': appName, 'u': myUsername, 'link': appLink});

      await Share.share(
        message,
        subject: context.tr('ct.bf.shareSubj', {'app': appName}),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('ct.bf.shareErr', {'e': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareUserNotFoundInvitation(String query) async {
    try {
      final appLink =
          dotenv.env['APP_DOWNLOAD_LINK'] ?? 'https://innerhero.app/download';
      final appName = dotenv.env['APP_NAME'] ?? 'Dacko';

      final myUsername = _myUsername ?? context.tr('ct.bf.friend');

      final message = context.tr('ct.bf.share2',
          {'app': appName, 'u': myUsername, 'link': appLink});

      await Share.share(
        message,
        subject: context.tr('ct.bf.shareSubj', {'app': appName}),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('ct.bf.shareErr', {'e': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== بارگذاری داده‌ها ====================
  Future<void> _loadData() async {
    final user = await _matcherService.getCurrentUser();
    if (user == null) {
      if (mounted) {
        // چک mounted
        setState(() => _isLoading = false);
      }
      return;
    }

    if (!mounted) return; // اینجا هم چک کن

    setState(() {
      _userId = user.id;
      _isLoading = true;
    });

    // دریافت username کاربر فعلی
    try {
      final myProfile = await _supabaseClient
          .from('profiles')
          .select('username')
          .eq('user_id', user.id)
          .maybeSingle();

      if (myProfile != null && mounted) {
        setState(() {
          _myUsername = myProfile['username'] as String?;
        });
      }
    } catch (e) {
      print('Error loading my username: $e');
    }

    try {
      final matches = await _matcherService.findMatchingBuddies(
        user.id,
        minMatchScore: 0,
        filterGender: null,
      );

      if (!mounted) return; // بعد از await دوباره چک کن

      _categorizeMatches(matches);
      await _mergeRequestsAndBuddies();
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });

      _applyFilters();
    } catch (e) {
      print('Error loading data: $e');
      if (!mounted) return; // بعد از catch هم چک کن
      setState(() => _isLoading = false);
    }
  }

  // درخواست‌های در انتظار و هم‌مسیرهای فعلی را مستقیم از دیتابیس می‌گیرد
  // (مستقل از اینکه طرف مقابل «دنبال هم‌مسیر» باشد یا پروفایل شخصیت داشته باشد)
  Future<void> _mergeRequestsAndBuddies() async {
    final uid = _userId;
    if (uid == null) return;
    try {
      final reqs = await _supabaseClient
          .from('buddy_requests')
          .select('id, from_user_id, to_user_id')
          .or('from_user_id.eq.$uid,to_user_id.eq.$uid')
          .eq('status', 'pending');

      final myConvs = await _supabaseClient
          .from('conversation_members')
          .select('conversation_id')
          .eq('user_id', uid);
      final convIds = [for (final c in myConvs) c['conversation_id'] as String];
      final buddyConv = <String, String>{};
      if (convIds.isNotEmpty) {
        final convs = await _supabaseClient
            .from('conversations')
            .select('id')
            .inFilter('id', convIds)
            .eq('type', 'buddy')
            .eq('is_active', true);
        final ids = [for (final c in convs) c['id'] as String];
        if (ids.isNotEmpty) {
          final members = await _supabaseClient
              .from('conversation_members')
              .select('conversation_id, user_id')
              .inFilter('conversation_id', ids);
          for (final m in members) {
            if (m['user_id'] != uid) {
              buddyConv[m['user_id'] as String] = m['conversation_id'] as String;
            }
          }
        }
      }

      final reqByUser = <String, Map<String, dynamic>>{};
      for (final r in reqs) {
        final other = r['from_user_id'] == uid ? r['to_user_id'] : r['from_user_id'];
        reqByUser[other as String] = r;
      }

      final needed = {...reqByUser.keys, ...buddyConv.keys};
      final known = {for (final m in _allMatches) m['user_id'] as String: m};
      final missing = needed.where((id) => !known.containsKey(id)).toList();
      final profiles = <String, Map<String, dynamic>>{};
      if (missing.isNotEmpty) {
        final rows = await _supabaseClient
            .from('profiles')
            .select('user_id, name, avatar_url, total_xp, current_streak')
            .inFilter('user_id', missing);
        for (final p in rows) {
          profiles[p['user_id'] as String] = p;
        }
      }

      final pending = <Map<String, dynamic>>[];
      final buddies = <Map<String, dynamic>>[];
      for (final id in needed) {
        final pr = profiles[id];
        final e = Map<String, dynamic>.from(known[id] ??
            {
              'user_id': id,
              'name': pr?['name'] ?? context.tr('ct.user'),
              'gender': 'other',
              'avatar_url': pr?['avatar_url'],
              'total_xp': pr?['total_xp'] ?? 0,
              'current_streak': pr?['current_streak'] ?? 0,
              'match_score': 0.0,
              'common_habits': [],
              'common_interests': [],
            });
        if (buddyConv.containsKey(id)) {
          e['is_buddy'] = true;
          e['has_pending_request'] = false;
          e['conversation_id'] = buddyConv[id];
          buddies.add(e);
        } else {
          final r = reqByUser[id]!;
          e['is_buddy'] = false;
          e['has_pending_request'] = true;
          e['is_sent_by_me'] = r['from_user_id'] == uid;
          e['is_received_by_me'] = r['to_user_id'] == uid;
          e['request_id'] = r['id'];
          pending.add(e);
        }
        final i = _allMatches.indexWhere((m) => m['user_id'] == id);
        if (i != -1) {
          _allMatches[i] = e;
        } else {
          _allMatches.add(e);
        }
      }
      _pendingRequests = pending;
      _myBuddies = buddies;
      _searchResults = _searchResults
          .where((m) => !needed.contains(m['user_id']))
          .toList();
    } catch (e) {
      print('merge requests/buddies error: $e');
    }
  }

  // دسته‌بندی کاربران به سه گروه
  void _categorizeMatches(List<Map<String, dynamic>> matches) {
    final pending = <Map<String, dynamic>>[];
    final buddies = <Map<String, dynamic>>[];
    final searchable = <Map<String, dynamic>>[];

    for (var match in matches) {
      final isBuddy = match['is_buddy'] == true;
      final hasPending = match['has_pending_request'] == true;

      if (isBuddy) {
        buddies.add(match);
      } else if (hasPending) {
        pending.add(match);
      } else {
        searchable.add(match);
      }
    }

    _allMatches = matches;
    _searchResults = searchable;
    _pendingRequests = pending;
    _myBuddies = buddies;
  }

  // اعمال فیلترها روی نتایج جستجو
  void _applyFilters() {
    if (!_isInitialized) return;
    if (!mounted) return;

    var filtered = _allMatches.where((match) {
      final isBuddy = match['is_buddy'] == true;
      final hasPending = match['has_pending_request'] == true;
      if (isBuddy || hasPending) return false;

      if (_filterGender != null) {
        final genderStr = match['gender'] as String?;
        if (genderStr != _filterGender!.toString().split('.').last) {
          return false;
        }
      }

      final score = match['match_score'] as double? ?? 0;
      if (score < _minMatchScore) return false;

      return true;
    }).toList();

    filtered.sort(
      (a, b) =>
          (b['match_score'] as double).compareTo(a['match_score'] as double),
    );
    if (!mounted) return; // قبل از setState چک کن
    setState(() {
      _searchResults = filtered;
    });
  }

  // ==================== ارسال درخواست ====================
  // جلوگیری از کلیک چندباره: تا پایان کار هر درخواست، کلیک دوباره نادیده گرفته می‌شود
  final Set<String> _inFlight = {};

  Future<void> _sendRequest(String toUserId, Color primaryColor) async {
    if (!_inFlight.add('s$toUserId')) return;
    try {
      await _sendRequestImpl(toUserId, primaryColor);
    } finally {
      _inFlight.remove('s$toUserId');
    }
  }

  Future<void> _sendRequestImpl(String toUserId, Color primaryColor) async {
    if (_userId == null) return;

    try {
      await _matcherService.sendBuddyRequestWithMatch(
        _userId!,
        toUserId,
        message: 'سلام! من از طریق سیستم هم‌مسیر با شما آشنا شدم. '
            'به نظر می‌رسد علاقه‌مندی‌های مشترکی داریم. '
            'خوشحال می‌شوم با هم هم‌مسیر باشیم! ',
      );

      if (!mounted) return;

      // فقط state لوکال را آپدیت کن (بدون reload کل داده)
      setState(() {
        _hasChanges = true; // علامت‌گذاری تغییر

        final index = _searchResults.indexWhere(
          (m) => m['user_id'] == toUserId,
        );
        final fromSearch =
            _searchResult != null && _searchResult!['user_id'] == toUserId;
        if (fromSearch) {
          // کارت نتیجه‌ی جستجو هم وضعیت «ارسال شد» را نشان بدهد
          _searchResult = {
            ..._searchResult!,
            'has_pending_request': true,
            'is_sent_by_me': true,
          };
        }
        if (index != -1 || fromSearch) {
          final updated = Map<String, dynamic>.from(
              index != -1 ? _searchResults[index] : _searchResult!);
          updated['has_pending_request'] = true;
          updated['is_sent_by_me'] = true;
          if (index != -1) _searchResults.removeAt(index);
          _pendingRequests.removeWhere((m) => m['user_id'] == toUserId);
          _pendingRequests.insert(0, updated);

          final allIndex = _allMatches.indexWhere(
            (m) => m['user_id'] == toUserId,
          );
          if (allIndex != -1) {
            _allMatches[allIndex] = updated;
          } else {
            _allMatches.add(updated);
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('ct.bf.sent')),
            backgroundColor: primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('ct.err', {'e': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== لغو درخواست ====================
  Future<void> _cancelRequest(String toUserId, Color primaryColor) async {
    if (_userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(context.tr('ct.bf.cancelTitle')),
        content: Text(context.tr('ct.bf.cancelQ')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('bd.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              context.tr('ct.bf.cancelTitle'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _matcherService.cancelBuddyRequest(_userId!, toUserId);

      if (!mounted) return;

      setState(() {
        _hasChanges = true; // علامت‌گذاری تغییر

        final index = _pendingRequests.indexWhere(
          (m) => m['user_id'] == toUserId,
        );
        if (index != -1) {
          final updated = Map<String, dynamic>.from(_pendingRequests[index]);
          updated['has_pending_request'] = false;
          updated['is_sent_by_me'] = false;
          updated['request_id'] = null;
          _pendingRequests.removeAt(index);

          final score = updated['match_score'] as double? ?? 0;
          final genderStr = updated['gender'] as String?;
          final matchesFilters = score >= _minMatchScore &&
              (_filterGender == null ||
                  genderStr == _filterGender!.toString().split('.').last);

          if (matchesFilters) {
            _searchResults.insert(0, updated);
          }

          final allIndex = _allMatches.indexWhere(
            (m) => m['user_id'] == toUserId,
          );
          if (allIndex != -1) {
            _allMatches[allIndex] = updated;
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('ct.bf.cancelled')),
            backgroundColor: primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('ct.err', {'e': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== پاسخ به درخواست ====================
// lib/features/chat/screens/buddy_finder_screen.dart

// ==================== پاسخ به درخواست ====================
  Future<void> _respondToRequest(
    String requestId,
    bool accept,
    Color primaryColor,
  ) async {
    if (!_inFlight.add('r$requestId')) return;
    try {
      await _respondToRequestImpl(requestId, accept, primaryColor);
    } finally {
      _inFlight.remove('r$requestId');
    }
  }

  Future<void> _respondToRequestImpl(
    String requestId,
    bool accept,
    Color primaryColor,
  ) async {
    if (_userId == null) return;

    final pendingItem = _pendingRequests.firstWhere(
      (m) => m['request_id'] == requestId,
      orElse: () => <String, dynamic>{},
    );
    final otherUserId = pendingItem['user_id'] as String?;

    try {
      await _matcherService.respondToBuddyRequest(requestId, accept);

      if (!mounted) return;

      if (accept && otherUserId != null) {
        // برای accept، فقط state لوکال را آپدیت کن (بدون reload از دیتابیس)
        setState(() {
          _hasChanges = true;

          // حذف از pending
          _pendingRequests.removeWhere((m) => m['request_id'] == requestId);

          // اضافه به buddies (با conversation_id که بعداً در _loadData می‌آید)
          final updated = Map<String, dynamic>.from(pendingItem);
          updated['is_buddy'] = true;
          updated['has_pending_request'] = false;
          updated['is_received_by_me'] = false;
          updated['request_id'] = null;
          _myBuddies.insert(0, updated);

          // آپدیت در allMatches
          final allIndex = _allMatches.indexWhere(
            (m) => m['user_id'] == otherUserId,
          );
          if (allIndex != -1) {
            _allMatches[allIndex] = updated;
          }
        });

        // conversation_id را به صورت جداگانه دریافت کن (بدون setState)
        _fetchConversationIdInBackground(otherUserId);
      } else if (otherUserId != null) {
        // برای reject، فقط state لوکال
        setState(() {
          _hasChanges = true;

          final index = _pendingRequests.indexWhere(
            (m) => m['request_id'] == requestId,
          );
          if (index != -1) {
            final updated = Map<String, dynamic>.from(_pendingRequests[index]);
            updated['has_pending_request'] = false;
            updated['is_received_by_me'] = false;
            updated['request_id'] = null;
            _pendingRequests.removeAt(index);

            final score = updated['match_score'] as double? ?? 0;
            final genderStr = updated['gender'] as String?;
            final matchesFilters = score >= _minMatchScore &&
                (_filterGender == null ||
                    genderStr == _filterGender!.toString().split('.').last);

            if (matchesFilters) {
              _searchResults.insert(0, updated);
            }

            final allIndex = _allMatches.indexWhere(
              (m) => m['user_id'] == otherUserId,
            );
            if (allIndex != -1) {
              _allMatches[allIndex] = updated;
            }
          }
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr(accept ? 'ct.bf.accepted' : 'ct.bf.rejected')),
            backgroundColor: accept ? primaryColor : Colors.grey,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('ct.err', {'e': e.toString()})),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

// دریافت conversation_id در پس‌زمینه (بدون setState)
  Future<void> _fetchConversationIdInBackground(String otherUserId) async {
    // تأخیر برای اطمینان از ثبت conversation در دیتابیس
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final matches = await _matcherService.findMatchingBuddies(_userId!);
      final updated = matches.firstWhere(
        (m) => m['user_id'] == otherUserId,
        orElse: () => <String, dynamic>{},
      );

      if (!mounted || updated.isEmpty) return;

      setState(() {
        final index = _myBuddies.indexWhere((m) => m['user_id'] == otherUserId);
        if (index != -1) {
          _myBuddies[index] = updated;
        }

        final allIndex = _allMatches.indexWhere(
          (m) => m['user_id'] == otherUserId,
        );
        if (allIndex != -1) {
          _allMatches[allIndex] = updated;
        }
      });
    } catch (e) {
      print('Error fetching conversation ID: $e');
    }
  }

// متد قدیمی _reloadOnlyUser را حذف کن
  // فقط یک کاربر را reload کن (برای accept)
  Future<void> _reloadOnlyUser(String otherUserId) async {
    if (_userId == null) return;

    try {
      final matches = await _matcherService.findMatchingBuddies(_userId!);
      final updated = matches.firstWhere(
        (m) => m['user_id'] == otherUserId,
        orElse: () => <String, dynamic>{},
      );

      if (!mounted || updated.isEmpty) return;

      setState(() {
        _pendingRequests.removeWhere((m) => m['user_id'] == otherUserId);
        _myBuddies.removeWhere((m) => m['user_id'] == otherUserId);
        _searchResults.removeWhere((m) => m['user_id'] == otherUserId);

        final allIndex = _allMatches.indexWhere(
          (m) => m['user_id'] == otherUserId,
        );
        if (allIndex != -1) {
          _allMatches[allIndex] = updated;
        } else {
          _allMatches.add(updated);
        }

        if (updated['is_buddy'] == true) {
          _myBuddies.insert(0, updated);
        } else if (updated['has_pending_request'] == true) {
          _pendingRequests.insert(0, updated);
        } else {
          _searchResults.insert(0, updated);
        }
      });
    } catch (e) {
      print('Error reloading user: $e');
    }
  }

  // ==================== Build ====================
// ==================== Build ====================
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final primaryColor = theme.primaryColor;

    // PopScope حذف شد - مشکل AnimationController رفع می‌شود
    return BottomSafe(child: Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: Text(
          context.tr('bd.tab.buddies'),
          style: TextStyle(color: theme.textColor),
        ),
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        foregroundColor: theme.textColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,),
          onPressed: () {
            // چک کن می‌تونه pop کنه
            if (Navigator.canPop(context)) {
              Navigator.pop(context, _hasChanges);
            } else {
              // اگه نمی‌تونه، به صفحه اصلی برگرده
              Navigator.of(context).maybePop();
            }
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: primaryColor),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              labelPadding: EdgeInsets.zero,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color:
                    theme.isDarkMode ? const Color(0xFF2A2A2A) : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              dividerColor: Colors.transparent,
              labelColor: theme.isDarkMode ? Colors.white : primaryColor,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.85),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(height: 44, text: context.tr('ct.bf.tab.search', {'n': '${_searchResults.length}'})),
                Tab(
                  height: 44,
                  text: context.tr('ct.bf.tab.pending', {'n': '${_pendingRequests.length}'}),
                ),
                Tab(height: 44, text: context.tr('ct.bf.tab.buddies', {'n': '${_myBuddies.length}'})),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSearchTab(theme, primaryColor),
                _buildPendingTab(theme, primaryColor),
                _buildBuddiesTab(theme, primaryColor),
              ],
            ),
    ));
  }

  // ==================== تب جستجو ====================
  Widget _buildSearchTab(ThemeProvider theme, Color primaryColor) {
    return Column(
      children: [
        // باکس جستجو (جدید)
        _buildSearchBox(theme, primaryColor),

        // نمایش نتیجه جستجو (اگر جستجو شده)
        if (_hasSearched) ...[
          Expanded(
            child: _isSearching
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: primaryColor),
                        const SizedBox(height: 16),
                        Text(
                          context.tr('ct.bf.searching'),
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : _searchResult != null
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            // نمایش نتیجه
                            _buildMatchCard(
                              _searchResult!,
                              theme,
                              primaryColor,
                            ),
                            const SizedBox(height: 12),
                            // دکمه پاک کردن
                            TextButton.icon(
                              onPressed: _clearSearch,
                              icon: Icon(
                                Icons.close,
                                size: 18,
                                color: theme.textSecondaryColor,
                              ),
                              label: Text(
                                context.tr('ct.bf.clearSearch'),
                                style: TextStyle(
                                  color: theme.textSecondaryColor,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildNotFoundState(theme, primaryColor),
          ),
        ] else ...[
          // حالت عادی: فیلترها + نتایج
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('ct.bf.suggested', {'n': '${_searchResults.length}'}),
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textSecondaryColor,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _showFilters = !_showFilters);
                  },
                  icon: Icon(
                    _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                    size: 18,
                  ),
                  label: Text(context.tr('ct.bf.filter')),
                  style: TextButton.styleFrom(
                    foregroundColor: primaryColor,
                  ),
                ),
              ],
            ),
          ),
          if (_showFilters) _buildFilters(theme, primaryColor),
          Expanded(
            child: _searchResults.isEmpty
                ? _buildEmptyState(
                    icon: Icons.search_off,
                    title: context.tr('ct.bf.noResults'),
                    subtitle: context.tr('ct.bf.noResults.sub'),
                    theme: theme,
                    primaryColor: primaryColor,
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: primaryColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        return _buildMatchCard(
                          _searchResults[index],
                          theme,
                          primaryColor,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // باکس جستجو
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBox(ThemeProvider theme, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _searchFocusNode.hasFocus
              ? primaryColor.withValues(alpha: 0.5)
              : theme.borderColor,
          width: _searchFocusNode.hasFocus ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(
            Icons.search,
            color: primaryColor,
            size: 22,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(color: theme.textColor),
              decoration: InputDecoration(
                hintText: context.tr('ct.bf.hint'),
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: theme.textSecondaryColor,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(),
              onChanged: (value) {
                // اگه کاربر خالی کرد، پاک کن
                if (value.trim().isEmpty && _hasSearched) {
                  _clearSearch();
                }
              },
            ),
          ),
          // دکمه پاک کردن (اگر متن دارد)
          if (_searchController.text.isNotEmpty)
            IconButton(
              onPressed: _clearSearch,
              icon: Icon(
                Icons.close,
                color: theme.textSecondaryColor,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          // دکمه جستجو
          GestureDetector(
            onTap: _performSearch,
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                context.tr('ct.bf.searchBtn'),
                style: TextStyle(
                  color:
                      theme.isDarkMode ? const Color(0xFF090909) : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // حالت کاربر پیدا نشد
  // ═══════════════════════════════════════════════════════════
  Widget _buildNotFoundState(ThemeProvider theme, Color primaryColor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_search,
                size: 48,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchError ?? context.tr('ct.bf.notFound'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('ct.bf.inviteHint'),
              style: TextStyle(
                fontSize: 13,
                color: theme.textSecondaryColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // در _buildNotFoundState
            ElevatedButton.icon(
              onPressed: () => _shareUserNotFoundInvitation(_lastSearchQuery),
              icon: const Icon(
                Icons.share,
                size: 18,
                color: Colors.white,
              ),
              label: Text(
                context.tr('ct.bf.invite'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // دکمه پاک کردن
            TextButton.icon(
              onPressed: _clearSearch,
              icon: Icon(
                Icons.close,
                size: 16,
                color: theme.textSecondaryColor,
              ),
              label: Text(
                context.tr('ct.bf.newSearch'),
                style: TextStyle(
                  fontSize: 13,
                  color: theme.textSecondaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== تب در انتظار ====================
  Widget _buildPendingTab(ThemeProvider theme, Color primaryColor) {
    if (_pendingRequests.isEmpty) {
      return _buildEmptyState(
        icon: Icons.hourglass_empty,
        title: context.tr('ct.bf.nopending'),
        subtitle: context.tr('ct.bf.nopending.sub'),
        theme: theme,
        primaryColor: primaryColor,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _pendingRequests.length,
        itemBuilder: (context, index) {
          return _buildMatchCard(
            _pendingRequests[index],
            theme,
            primaryColor,
          );
        },
      ),
    );
  }

  // ==================== تب هم‌مسیرها ====================
  Widget _buildBuddiesTab(ThemeProvider theme, Color primaryColor) {
    if (_myBuddies.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: context.tr('ct.chat.nobuddy'),
        subtitle: context.tr('ct.chat.nobuddy.sub'),
        theme: theme,
        primaryColor: primaryColor,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _myBuddies.length,
        itemBuilder: (context, index) {
          return _buildMatchCard(
            _myBuddies[index],
            theme,
            primaryColor,
          );
        },
      ),
    );
  }

  // ==================== پنل فیلتر ====================
  Widget _buildFilters(ThemeProvider theme, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('ct.bf.filters'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterGender = null;
                    _minMatchScore = 0;
                  });
                  _applyFilters();
                },
                child: Text(
                  context.tr('ct.bf.clear'),
                  style: TextStyle(color: primaryColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                context.tr('ct.bf.gender'),
                style: TextStyle(fontSize: 13, color: theme.textColor),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context.tr('ct.bf.all'),
                _filterGender == null,
                () {
                  setState(() => _filterGender = null);
                  _applyFilters();
                },
                primaryColor,
              ),
              _buildFilterChip(
                context.tr('ct.bf.male'),
                _filterGender == Gender.male,
                () {
                  setState(() => _filterGender = Gender.male);
                  _applyFilters();
                },
                primaryColor,
              ),
              _buildFilterChip(
                context.tr('ct.bf.female'),
                _filterGender == Gender.female,
                () {
                  setState(() => _filterGender = Gender.female);
                  _applyFilters();
                },
                primaryColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                context.tr('ct.bf.score'),
                style: TextStyle(fontSize: 13, color: theme.textColor),
              ),
              Expanded(
                child: Slider(
                  value: _minMatchScore,
                  min: 0,
                  max: 80,
                  divisions: 8,
                  activeColor: primaryColor,
                  onChanged: (value) {
                    setState(() => _minMatchScore = value);
                  },
                  onChangeEnd: (_) => _applyFilters(),
                ),
              ),
              Text(
                '${_minMatchScore.toInt()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    Color primaryColor,
  ) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (theme.isDarkMode
                  ? const Color(0xFF2A2A2A)
                  : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected ? Colors.white : theme.textSecondaryColor,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ==================== کارت تطابق ====================
  Widget _buildMatchCard(
    Map<String, dynamic> match,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    final score = match['match_score'] as double? ?? 0;
    final commonHabits = match['common_habits'] as List? ?? [];
    final commonInterests = match['common_interests'] as List? ?? [];
    final isBuddy = match['is_buddy'] ?? false;
    final hasPendingRequest = match['has_pending_request'] ?? false;
    final isSentByMe = match['is_sent_by_me'] ?? false;
    final isReceivedByMe = match['is_received_by_me'] ?? false;
    final requestId = match['request_id'] as String?;
    final userId = match['user_id'];

    Color borderColor = theme.borderColor;
    if (isBuddy) {
      borderColor = primaryColor;
    } else if (hasPendingRequest) {
      borderColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: borderColor, width: isBuddy ? 2 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (match['name'] ?? context.tr('ct.user')).substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            match['name'] ?? context.tr('ct.user'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (isBuddy)
                          _buildStatusBadge(context.tr('ct.bf.badge.buddy'), primaryColor)
                        else if (isReceivedByMe)
                          _buildStatusBadge(context.tr('ct.bf.badge.new'), Colors.orange)
                        else if (isSentByMe)
                          _buildStatusBadge(context.tr('ct.bf.badge.wait'), Colors.blue),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _getScoreColor(score),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${score.toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.stars,
                          size: 14,
                          color: Color(0xFFFFA500),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${match['total_xp'] ?? 0} XP',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.local_fire_department,
                          size: 14,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('ct.bf.days', {'n': '${match['current_streak'] ?? 0}'}),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (commonHabits.isNotEmpty || commonInterests.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...commonHabits.take(3).map(
                      (habit) => _buildTagChip('🏃 $habit', primaryColor),
                    ),
                ...commonInterests.take(2).map(
                      (interest) => _buildTagChip('❤️ $interest', primaryColor),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  match,
                  theme,
                  primaryColor,
                  isSentByMe: isSentByMe,
                  isReceivedByMe: isReceivedByMe,
                  isBuddy: isBuddy,
                  requestId: requestId,
                  userId: userId,
                  score: score,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showUserProfile(userId, theme, primaryColor),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(
                    color: primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.person_outline,
                  size: 20,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTagChip(String label, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ==================== دکمه اقدام ====================
  Widget _buildActionButton(
    Map<String, dynamic> match,
    ThemeProvider theme,
    Color primaryColor, {
    required bool isSentByMe,
    required bool isReceivedByMe,
    required bool isBuddy,
    required String? requestId,
    required String userId,
    required double score,
  }) {
    final conversationId = match['conversation_id'] as String?;

    if (isBuddy) {
      return ElevatedButton.icon(
        onPressed: () {
          if (conversationId != null && _userId != null) {
            // memberIds باید شامل هر دو کاربر باشه
            final conv = Conversation(
              id: conversationId,
              type: ConversationType.buddy,
              name: match['name'],
              memberIds: [_userId!, userId], // هم خودم هم کاربر مقابل
              lastMessageAt: DateTime.now(),
              createdAt: DateTime.now(),
            );

            print('Opening chat with members: ${conv.memberIds}');

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BuddyChatScreen(conversation: conv),
              ),
            );
          } else {
            print(
                '❌ Cannot open chat - conversationId: $conversationId, _userId: $_userId');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  conversationId == null
                      ? context.tr('ct.bf.chatNotFound')
                      : context.tr('ct.bf.chatErr'),
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        icon: const Icon(Icons.chat, size: 18, color: Colors.white),
        label: Text(
          context.tr('ct.chat.title'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    }

    if (isSentByMe) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: theme.isDarkMode
                    ? const Color(0xFF2A2A2A)
                    : Colors.grey.shade200,
              ),
              child: Text(
                context.tr('ct.bf.badge.wait'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.isDarkMode
                      ? Colors.grey.shade400
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _cancelRequest(userId, primaryColor),
            icon: const Icon(Icons.close, color: Colors.white),
            tooltip: context.tr('ct.bf.cancelReq'),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      );
    }

    if (isReceivedByMe && requestId != null) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => _respondToRequest(requestId, true, primaryColor),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                context.tr('ct.bf.accept'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  _respondToRequest(requestId, false, primaryColor),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                context.tr('ct.bf.reject'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ElevatedButton(
      onPressed: () => _sendRequest(userId, primaryColor),
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(
        context.tr('ct.bf.sendReq'),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  // ==================== نمایش پروفایل ====================
  void _showUserProfile(
    String userId,
    ThemeProvider theme,
    Color primaryColor,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(userId: userId),
      ),
    );
  }

  // ==================== Empty State ====================
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeProvider theme,
    required Color primaryColor,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
                icon,
                size: 56,
                color: primaryColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: theme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PersonalityScreen(),
                  ),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.person_add, color: Colors.white),
              label: Text(
                context.tr('ct.bf.completePersonality'),
                style: const TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 70) return const Color(0xFF2ECC71);
    if (score >= 50) return const Color(0xFFFFA500);
    return Colors.grey;
  }
}

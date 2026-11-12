// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '/core/app_theme.dart';
import '/features/auth/screens/login_screen.dart';
import '/features/auth/screens/reset_password_screen.dart';
import '/features/home/screens/main_screen.dart';
import '/features/onboarding/screens/onboarding_screen.dart';
import '/features/profile/screens/username_setup_screen.dart';
import '/l10n/app_strings.dart';
import '/providers/auth_provider.dart';
import '/providers/settings_provider.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';

class HeroApp extends StatelessWidget {
  const HeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<ThemeProvider, SettingsProvider, AuthProvider>(
      builder: (context, themeProvider, settings, authProvider, child) {
        return MaterialApp(
          title: AppStrings.t(settings.language, 'app.name'),
          debugShowCheckedModeBanner: false,
          locale: settings.locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // جهت متن (RTL/LTR) خودکار از زبان انتخابی می‌آید.
          theme: AppTheme.build(themeProvider),
          // با ورود/خروج، کل پشتهٔ صفحه‌ها ریست می‌شود؛ تغییرهای دیگر (معرفی، username و ...)
          // داخل همان مسیر با Consumer بازسازی می‌شوند.
          home: _AppNavigator(
            loggedIn: authProvider.isLoggedIn,
            buildHome: _buildHome,
          ),
        );
      },
    );
  }

  // تعیین صفحه اصلی بر اساس وضعیت کاربر
  Widget _buildHome(AuthProvider auth) {
    if (auth.isLoading) {
      return const _LoadingScreen(messageKey: 'common.loading');
    }

    if (!auth.isLoggedIn) {
      return const LoginScreen();
    }

    if (auth.needsPasswordReset) {
      return const ResetPasswordScreen();
    }

    if (!auth.onboardingDone) {
      return const OnboardingScreen();
    }

    if (!auth.hasUsername && auth.userId != null) {
      return UsernameSetupScreen(
        userId: auth.userId!,
        currentUsername: null,
        isFirstTime: true,
        onCompleted: () {
          auth.setHasUsername(true);
        },
      );
    }

    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        if (!syncProvider.isInitialized) {
          return const _LoadingScreen(messageKey: 'common.loading_data');
        }
        return const MainScreen();
      },
    );
  }
}

/// ناوبری داخلی برنامه. چون داخل `home` ساخته می‌شود، دکمهٔ بک سیستم باید صراحتاً به آن برسد
/// (وگرنه همیشه برنامه بسته می‌شود). اگر صفحه‌ای برای برگشتن نبود، برنامه می‌بندد.
class _AppNavigator extends StatefulWidget {
  final bool loggedIn;
  final Widget Function(AuthProvider auth) buildHome;
  const _AppNavigator({required this.loggedIn, required this.buildHome});

  @override
  State<_AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<_AppNavigator> {
  var _keys = {
    true: GlobalKey<NavigatorState>(debugLabel: 'nav_in'),
    false: GlobalKey<NavigatorState>(debugLabel: 'nav_out'),
  };
  String? _uid;

  @override
  Widget build(BuildContext context) {
    // با عوض شدن کاربر، کل درخت صفحه‌ها (و حالت/کش هر صفحه) از نو ساخته می‌شود
    final uid = context.select<AuthProvider, String?>((a) => a.userId);
    if (uid != _uid) {
      _uid = uid;
      _keys = {
        true: GlobalKey<NavigatorState>(debugLabel: 'nav_in_$uid'),
        false: GlobalKey<NavigatorState>(debugLabel: 'nav_out_$uid'),
      };
    }
    final key = _keys[widget.loggedIn]!;
    return NavigatorPopHandler(
      onPop: () async {
        final handled = await key.currentState?.maybePop() ?? false;
        if (!handled) SystemNavigator.pop();
      },
      child: Navigator(
        key: key,
        onGenerateRoute: (routeSettings) {
          return MaterialPageRoute(
            builder: (context) => Consumer<AuthProvider>(
              builder: (context, auth, _) => widget.buildHome(auth),
            ),
          );
        },
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  final String messageKey;
  const _LoadingScreen({required this.messageKey});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.primaryColor),
            const SizedBox(height: 16),
            Text(
              context.tr(messageKey),
              style: TextStyle(color: theme.textSecondaryColor),
            ),
          ],
        ),
      ),
    );
  }
}

// lib/app.dart

import 'package:flutter/material.dart';
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
          home: Navigator(
            key: ValueKey('nav_${authProvider.isLoggedIn}'),
            onGenerateRoute: (routeSettings) {
              return MaterialPageRoute(
                builder: (context) => Consumer<AuthProvider>(
                  builder: (context, auth, _) => _buildHome(auth),
                ),
              );
            },
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

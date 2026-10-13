// lib/app.dart

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '/features/auth/screens/login_screen.dart';
import '/features/home/screens/main_screen.dart';
import '/providers/auth_provider.dart';
import '/providers/sync_provider.dart';
import '/providers/theme_provider.dart';
import '/features/profile/screens/username_setup_screen.dart';

class HeroApp extends StatelessWidget {
  const HeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ استفاده از Navigator با key
    return Consumer2<ThemeProvider, AuthProvider>(
      builder: (context, themeProvider, authProvider, child) {
        return MaterialApp(
          title: 'قهرمان درون',
          debugShowCheckedModeBanner: false,
          locale: const Locale('fa', 'IR'),
          supportedLocales: const [
            Locale('fa', 'IR'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          theme: ThemeData(
            fontFamily: 'Vazir',
            scaffoldBackgroundColor: themeProvider.backgroundColor,
            useMaterial3: true,
            colorScheme: ColorScheme.light(
              primary: themeProvider.primaryColor,
              secondary: themeProvider.primaryColor,
              surface: themeProvider.surfaceColor,
              background: themeProvider.backgroundColor,
              onPrimary: themeProvider.textColor,
              onSurface: themeProvider.textColor,
              onBackground: themeProvider.textColor,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: themeProvider.surfaceColor,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                color: themeProvider.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'Vazir',
              ),
              iconTheme: IconThemeData(color: themeProvider.textColor),
            ),
            textTheme: TextTheme(
              bodyLarge: TextStyle(
                  fontFamily: 'Vazir', color: themeProvider.textColor),
              bodyMedium: TextStyle(
                  fontFamily: 'Vazir', color: themeProvider.textColor),
              titleLarge: TextStyle(
                  fontFamily: 'Vazir', color: themeProvider.textColor),
            ),
            dividerColor: themeProvider.textColor.withValues(alpha: 0.1),
            cardColor: themeProvider.surfaceColor,
            dialogBackgroundColor: themeProvider.surfaceColor,
            listTileTheme: ListTileThemeData(
              textColor: themeProvider.textColor,
              iconColor: themeProvider.textColor,
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return themeProvider.primaryColor;
                }
                return null;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return themeProvider.primaryColor.withValues(alpha: 0.5);
                }
                return null;
              }),
            ),
          ),
          // ✅ home مستقیماً از authProvider می‌خواند
          home: Navigator(
            key: ValueKey(
              'nav_${authProvider.isLoggedIn}_${authProvider.hasUsername}',
            ),
            onGenerateRoute: (settings) {
              return MaterialPageRoute(
                builder: (context) => _buildHome(authProvider),
              );
            },
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏠 تعیین صفحه اصلی بر اساس وضعیت کاربر
  // ═══════════════════════════════════════════════════════════
  Widget _buildHome(AuthProvider auth) {
    // ۱. در حال بارگذاری
    if (auth.isLoading) {
      print('🏠 Showing Loading');
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Color(0xFF4A90E2)),
              SizedBox(height: 16),
              Text(
                'در حال بارگذاری...',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      );
    }

    // ۲. لاگین نکرده → LoginScreen
    if (!auth.isLoggedIn) {
      print('🚪 Showing LoginScreen');
      return const LoginScreen();
    }

    // ۳. username ندارد
    if (!auth.hasUsername && auth.userId != null) {
      print('🆔 Showing UsernameSetupScreen');
      return UsernameSetupScreen(
        userId: auth.userId!,
        currentUsername: null,
        isFirstTime: true,
        onCompleted: () {
          auth.setHasUsername(true);
        },
      );
    }

    // ۴. کاربر لاگین کرده → MainScreen
    print('🏠 Showing MainScreen');
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, child) {
        if (!syncProvider.isInitialized) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(color: Color(0xFF4A90E2)),
                  SizedBox(height: 16),
                  Text(
                    'در حال بارگذاری اطلاعات...',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
          );
        }
        return const MainScreen();
      },
    );
  }
}

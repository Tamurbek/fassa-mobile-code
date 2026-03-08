import 'package:flutter/material.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'logic/pos_controller.dart';
import 'theme/app_theme.dart';
import 'presentation/pages/main_navigation_screen.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/auth/pin_code_screen.dart';
import 'translations/app_translations.dart';
import 'presentation/pages/settings_screen.dart';
import 'presentation/pages/reports_screen.dart';
import 'presentation/pages/auth/role_selection_screen.dart';
import 'presentation/pages/auth/staff_selection_page.dart';
import 'presentation/pages/auth/terminal_login_page.dart';
import 'presentation/pages/auth/qr_scanner_page.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'logic/background_service.dart';
import 'presentation/components/location_checker.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';
import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'presentation/pages/customer_display_page.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'package:screenshot/screenshot.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main(List<String> args) async {
  HttpOverrides.global = MyHttpOverrides();
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize locale data early for all windows
  await initializeDateFormatting('uz_UZ', null);
  await initializeDateFormatting('en_US', null);
  await initializeDateFormatting('ru_RU', null);

  if (Platform.isWindows) {
    await WindowsSingleInstance.ensureSingleInstance(
      args,
      "fassa_pos_terminal",
      onSecondWindow: (args) {
        windowManager.show();
        windowManager.focus();
      },
    );
  }

  if (args.firstOrNull == 'multi_window') {
    await GetStorage.init();
    final windowId = int.parse(args[1]);
    final argument = args.length > 2 ? jsonDecode(args[2]) as Map<String, dynamic> : <String, dynamic>{};
    
    runApp(CustomerDisplayApp(windowId: windowId, initialData: argument));
    return;
  }

  await initializeService();
  await GetStorage.init();
  
  // Initialize Controller
  Get.put(POSController());
  
  // Run app before window manager stuff to ensure native window exists
  runApp(const FassaApp());

  // Disable for macOS to avoid native crash (nil window unwrap)
  if (Platform.isWindows || Platform.isLinux) {
    // Small delay to ensure native objects are ready
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        size: Size(1200, 800),
        minimumSize: Size(1000, 700),
        center: true,
        backgroundColor: Colors.white, 
        skipTaskbar: false,
        title: "Fassa POS Terminal",
      );
      
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
        await windowManager.setPreventClose(true);
      });

      // Tray management
      String trayIconPath = 'assets/images/app_icon.ico';
      await trayManager.setIcon(trayIconPath);
      Menu menu = Menu(
        items: [
          MenuItem(label: 'Terminalni ochish', onClick: (_) => windowManager.show()),
          MenuItem.separator(),
          MenuItem(label: 'Tizimdan chiqish', onClick: (_) => Get.find<POSController>().quitApp()),
        ],
      );
      await trayManager.setContextMenu(menu);
    } catch (e) {
      print("WindowManager init error: $e");
    }
  }
}

class CustomerDisplayApp extends StatelessWidget {
  final int windowId;
  final Map<String, dynamic> initialData;
  const CustomerDisplayApp({super.key, required this.windowId, required this.initialData});

  @override
  Widget build(BuildContext context) {
    final bool isDark = GetStorage().read('is_dark_mode') ?? false;
    
    return GetMaterialApp(
      title: 'Customer Display',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: CustomerDisplayPage(initialData: initialData),
    );
  }
}

class FassaApp extends StatelessWidget {
  const FassaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Get stored locale or default to uz_UZ
    final storage = GetStorage();
    final pos = Get.find<POSController>();
    pos.restaurantName.value = storage.read('restaurant_name') ?? "Fassa";
    String? storedLang = storage.read('lang');
    Locale initialLocale = const Locale('uz', 'UZ');
    if (storedLang != null) {
      try {
        final parts = storedLang.split('_');
        if (parts.length >= 2) {
          initialLocale = Locale(parts[0], parts[1]);
        } else if (parts.length == 1) {
          initialLocale = Locale(parts[0]);
        }
      } catch (e) {
        print("Locale parse error: $e");
      }
    }

    return GetMaterialApp(
      title: 'FassaPos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: pos.isDarkMode.value ? ThemeMode.dark : ThemeMode.light,
      translations: AppTranslations(),
      locale: initialLocale,
      fallbackLocale: const Locale('en', 'US'),
      builder: (context, child) => Screenshot(
        controller: pos.screenshotController,
        child: LocationChecker(child: child!),
      ),
      home: _getInitialScreen(),
      getPages: [
        GetPage(name: '/login', page: () => const LoginPage()),
        GetPage(name: '/pin', page: () => const PinCodeScreen()),
        GetPage(name: '/main', page: () => const MainNavigationScreen()),
        GetPage(name: '/settings', page: () => const SettingsScreen()),
        GetPage(name: '/reports', page: () => const ReportsScreen()),
        GetPage(name: '/staff-selection', page: () => const StaffSelectionPage()),
        GetPage(name: '/terminal-login', page: () => const TerminalLoginPage()),
      ],
    );
  }

  Widget _getInitialScreen() {
    final pos = Get.find<POSController>();
    
    // Always force Terminal (CASHIER) role for this app
    if (pos.deviceRole.value != "CASHIER") {
      pos.setDeviceRole("CASHIER");
    }
    
    // 1. Check if terminal is linked/logged in
    if (pos.currentTerminal.value == null) {
      return const LoginPage(); 
    }
    
    // 2. Check if staff is authenticated (PIN screen)
    if (!pos.isPinAuthenticated.value) {
      return const StaffSelectionPage(); 
    }
    
    // 3. Authenticated - Go to Main Screen
    return const MainNavigationScreen();
  }
}

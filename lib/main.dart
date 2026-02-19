import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'logic/pos_controller.dart';
import 'theme/app_theme.dart';
import 'presentation/pages/main_navigation_screen.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/auth/pin_code_screen.dart';
import 'translations/app_translations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  
  // Initialize Controller
  Get.put(POSController());
  
  runApp(const FastFoodApp());
}

class FastFoodApp extends StatelessWidget {
  const FastFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Get stored locale or default to uz_UZ
    final storage = GetStorage();
    String? storedLang = storage.read('lang');
    Locale initialLocale = storedLang != null 
        ? Locale(storedLang.split('_')[0], storedLang.split('_')[1])
        : const Locale('uz', 'UZ');

    return GetMaterialApp(
      title: 'Fast Food POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      translations: AppTranslations(),
      locale: initialLocale,
      fallbackLocale: const Locale('en', 'US'),
      home: _getInitialScreen(),
      getPages: [
        GetPage(name: '/login', page: () => const LoginPage()),
        GetPage(name: '/pin', page: () => const PinCodeScreen()),
        GetPage(name: '/main', page: () => const MainNavigationScreen()),
      ],
    );
  }

  Widget _getInitialScreen() {
    final storage = GetStorage();
    final pos = Get.find<POSController>();
    
    // 1. Check if user is logged in
    var storedUser = storage.read('user');
    if (storedUser == null) {
      return const LoginPage();
    }
    
    // 2. Refresh initial user data in controller if needed
    // (This is already handled in POSController.onInit)

    // 3. User is logged in, check PIN
    if (pos.pinCode.value == null) {
      return const PinCodeScreen(isSettingNewPin: true);
    } else {
      return const PinCodeScreen();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/responsive.dart';
import '../../logic/pos_controller.dart';
import '../widgets/printing_overlay.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatelessWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    var currentIndex = 0.obs;

    final List<Widget> pages = [
      const OrdersScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    return Obx(() => Stack(
      children: [
        Responsive(
          mobile: Scaffold(
            body: IndexedStack(
              index: currentIndex.value,
              children: pages,
            ),
            bottomNavigationBar: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMobileNavItem(0, currentIndex, Icons.receipt_long_rounded, "orders".tr),
                    if (pos.isAdmin)
                      _buildMobileNavItem(1, currentIndex, Icons.bar_chart_rounded, "reports".tr),
                    _buildMobileNavItem(2, currentIndex, Icons.person_outline_rounded, "profile".tr),
                  ],
                ),
              ),
            ),
          ),
          desktop: Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: currentIndex.value,
                  onDestinationSelected: (int index) {
                    currentIndex.value = index;
                  },
                  labelType: NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 20,
                      child: const Icon(Icons.restaurant_menu, color: Colors.white),
                    ),
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.receipt_long_rounded),
                      selectedIcon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary),
                      label: Text("orders".tr),
                    ),
                    if (pos.isAdmin)
                      NavigationRailDestination(
                        icon: const Icon(Icons.bar_chart_rounded),
                        selectedIcon: const Icon(Icons.bar_chart_rounded, color: AppColors.primary),
                        label: Text("reports".tr),
                      ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.person_outline_rounded),
                      selectedIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                      label: Text("profile".tr),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: IndexedStack(
                    index: currentIndex.value,
                    children: pages,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Subscription Warning Banner
        if (pos.subscriptionDaysLeft.value != null && 
            pos.subscriptionDaysLeft.value! <= 3 && 
            pos.subscriptionDaysLeft.value! >= 0)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: Responsive.isMobile(context) ? 16 : null,
            right: 16,
            width: Responsive.isMobile(context) ? null : 350,
            child: _buildSubscriptionBanner(pos),
          ),

        if (pos.isPrinting.value)
          const PrintingOverlay(),
      ],
    ));
  }

  Widget _buildSubscriptionBanner(POSController pos) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warning_amber_rounded, 
                color: Colors.orange.shade800, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Obuna tugashiga ${pos.subscriptionDaysLeft.value} kun qoldi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'Cheklovlar oldini olish uchun uzaytiring',
                    style: TextStyle(
                      color: Colors.orange.shade800.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileNavItem(int index, RxInt currentIndex, IconData icon, String label) {
    final isSelected = currentIndex.value == index;
    return GestureDetector(
      onTap: () => currentIndex.value = index,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary.withOpacity(0.4),
                size: 24,
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(top: 4),
              width: isSelected ? 4 : 0,
              height: 4,
              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}


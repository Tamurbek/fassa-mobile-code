import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../logic/pos_controller.dart';
import 'login_page.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pos = Get.find<POSController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.fastfood, color: Color(0xFFFF9500), size: 80),
              const SizedBox(height: 24),
              const Text(
                "FAST FOOD PRO",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Iltimos, ish rejimini tanlang",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 60),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildRoleCard(
                    title: "Administrator",
                    subtitle: "Barcha sozlamalar va hisobotlar",
                    icon: Icons.admin_panel_settings_rounded,
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      pos.setDeviceRole("ADMIN");
                      Get.to(() => const LoginPage());
                    },
                  ),
                  _buildRoleCard(
                    title: "Kassir",
                    subtitle: "Sotuv va buyurtmalar boshqaruvi",
                    icon: Icons.point_of_sale_rounded,
                    color: const Color(0xFFFF9500),
                    onTap: () {
                      pos.setDeviceRole("CASHIER");
                      Get.to(() => const LoginPage());
                    },
                  ),
                  _buildRoleCard(
                    title: "Afitsiant",
                    subtitle: "Stollar va buyurtmalarni qabul qilish",
                    icon: Icons.restaurant_menu_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () {
                      pos.setDeviceRole("WAITER");
                      Get.to(() => const LoginPage());
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

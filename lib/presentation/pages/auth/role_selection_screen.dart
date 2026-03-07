import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../logic/pos_controller.dart';
import 'login_page.dart';
import 'qr_scanner_page.dart';

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
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Image.asset('assets/logo.png'),
              ),
              const SizedBox(height: 24),
              const Text(
                "Fassa",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Qurilmani qanday ishlatmoqchisiz?",
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
                    title: "Kassa Terminali",
                    subtitle: "Asosiy kompyuter yoki planshet (Admin parqi) orqali terminalni sozlash",
                    icon: Icons.point_of_sale_rounded,
                    color: const Color(0xFF3B82F6),
                    onTap: () {
                      pos.setDeviceRole("CASHIER");
                      Get.to(() => const LoginPage());
                    },
                  ),
                  _buildRoleCard(
                    title: "Ofitsiant / Telefon",
                    subtitle: "Qurilmani QR-kod yordamida cafega ulab, shaxsiy pin kod bilan kirish",
                    icon: Icons.qr_code_scanner_rounded,
                    color: const Color(0xFF10B981),
                    onTap: () {
                      pos.setDeviceRole("WAITER");
                      Get.to(() => const QRScannerPage());
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
        width: 300,
        padding: const EdgeInsets.all(24),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
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


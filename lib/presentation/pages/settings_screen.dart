import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../logic/pos_controller.dart';
import 'package:fast_food_app/presentation/pages/product_management_screen.dart';
import 'package:fast_food_app/presentation/pages/printer_management_screen.dart';
import 'package:fast_food_app/presentation/pages/preparation_area_management_screen.dart';
import 'package:fast_food_app/presentation/pages/waiter_management_screen.dart';
import 'package:fast_food_app/presentation/pages/inventory_management_page.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    final storage = GetStorage();
    final double sw = MediaQuery.of(context).size.width;
    final bool tablet = sw >= 700;
    final double maxW = tablet ? 900.0 : double.infinity;
    final double pad = tablet ? 32.0 : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(
          "settings".tr,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: ListView(
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 40),
            children: [
              // ── 1. PROFIL ────────────────────────────────
              _ProfileHeader(pos: pos),
              const SizedBox(height: 32),

              // ── 2. BOSHQARUV BO'LIMLARI ──────────────────
              if (pos.isAdmin) ...[
                _SectionTitle(title: "Boshqaruv"),
                const SizedBox(height: 10),
                _NavGrid(tablet: tablet),
                const SizedBox(height: 32),
              ],

              // ── 3. PRINTER SOZLAMALARI ───────────────────
              if (pos.isAdmin) ...[
                _SectionTitle(title: "printer_settings".tr),
                const SizedBox(height: 10),
                _SettingsGroup(children: [
                  Obx(() => _NavRow(
                    icon: Icons.receipt_long_rounded,
                    iconColor: const Color(0xFF0A84FF),
                    title: "printer_paper_size".tr,
                    trailing: pos.printerPaperSize.value,
                    onTap: () => _paperSizeDialog(context, pos),
                  )),
                  Obx(() => _SwitchRow(
                    icon: Icons.print_rounded,
                    iconColor: const Color(0xFF30D158),
                    title: "auto_print_receipt".tr,
                    value: pos.autoPrintReceipt.value,
                    onChanged: (v) { pos.autoPrintReceipt.value = v; storage.write('auto_print_receipt', v); },
                  )),
                  Obx(() => _SwitchRow(
                    icon: Icons.soup_kitchen_rounded,
                    iconColor: const Color(0xFFFF9F0A),
                    title: "enable_kitchen_print".tr,
                    value: pos.enableKitchenPrint.value,
                    onChanged: (v) => pos.setEnableKitchenPrint(v),
                  )),
                  Obx(() => _SwitchRow(
                    icon: Icons.description_rounded,
                    iconColor: const Color(0xFF5E5CE6),
                    title: "enable_bill_print".tr,
                    value: pos.enableBillPrint.value,
                    onChanged: (v) => pos.setEnableBillPrint(v),
                  )),
                  Obx(() => _SwitchRow(
                    icon: Icons.credit_card_rounded,
                    iconColor: const Color(0xFF34C759),
                    title: "enable_payment_print".tr,
                    value: pos.enablePaymentPrint.value,
                    onChanged: (v) => pos.setEnablePaymentPrint(v),
                  )),
                  Obx(() => _SwitchRow(
                    icon: Icons.hub_rounded,
                    iconColor: const Color(0xFFFF375F),
                    title: "Asosiy printer terminali",
                    value: pos.isMainPrinterTerminal.value,
                    onChanged: (v) => pos.setIsMainPrinterTerminal(v),
                    isLast: true,
                  )),
                ]),
                const SizedBox(height: 32),
              ],

              // ── 4. RESTORAN MA'LUMOTLARI ─────────────────
              if (pos.isAdmin) ...[
                _SectionTitle(title: "restaurant_info".tr),
                const SizedBox(height: 10),
                _SettingsGroup(children: [
                  Obx(() => _NavRow(
                    icon: Icons.storefront_rounded,
                    iconColor: const Color(0xFFFF9500),
                    title: "restaurant_name".tr,
                    trailing: pos.restaurantName.value,
                    onTap: () => _editDialog(context, "restaurant_name".tr, pos.restaurantName, 'restaurant_name', onSave: (v) => pos.updateCafeInfo(name: v)),
                  )),
                  Obx(() => _NavRow(
                    icon: Icons.location_on_rounded,
                    iconColor: const Color(0xFFFF3B30),
                    title: "restaurant_address".tr,
                    trailing: pos.restaurantAddress.value,
                    onTap: () => _editDialog(context, "restaurant_address".tr, pos.restaurantAddress, 'restaurant_address', onSave: (v) => pos.updateCafeInfo(address: v)),
                  )),
                  Obx(() => _NavRow(
                    icon: Icons.call_rounded,
                    iconColor: const Color(0xFF30D158),
                    title: "restaurant_phone".tr,
                    trailing: pos.restaurantPhone.value,
                    onTap: () => _editDialog(context, "restaurant_phone".tr, pos.restaurantPhone, 'restaurant_phone', onSave: (v) => pos.updateCafeInfo(phone: v)),
                  )),
                  Obx(() => _NavRow(
                    icon: Icons.camera_alt_rounded,
                    iconColor: const Color(0xFFE1306C),
                    title: "instagram_link".tr,
                    trailing: pos.instagramLink.value.isNotEmpty ? pos.instagramLink.value.split('/').last : "",
                    onTap: () => _editDialog(context, "instagram_link".tr, pos.instagramLink, 'instagram_link', onSave: (v) => pos.updateCafeInfo(instagramLink: v)),
                  )),
                  Obx(() => _SwitchRow(
                    icon: Icons.phone_android_rounded,
                    iconColor: const Color(0xFF5AC8FA),
                    title: "show_phone_on_receipt".tr,
                    value: pos.showPhoneOnReceipt.value,
                    onChanged: (v) => pos.updateCafeInfo(extraData: {'show_phone_on_receipt': v}),
                  )),
                  Obx(() => _SwitchRow(
                    icon: Icons.qr_code_rounded,
                    iconColor: const Color(0xFF000000),
                    title: "show_instagram_qr".tr,
                    value: pos.showInstagramQr.value,
                    onChanged: (v) => pos.updateCafeInfo(extraData: {'show_instagram_qr': v}),
                    isLast: true,
                  )),
                ]),
                const SizedBox(height: 32),
              ],

              // ── 5. INTERFEYS ─────────────────────────────
              _SectionTitle(title: "Ko'rinish"),
              const SizedBox(height: 10),
              _SettingsGroup(children: [
                Obx(() => _SwitchRow(
                  icon: Icons.dark_mode_rounded,
                  iconColor: const Color(0xFF636366),
                  title: "Tungi rejim",
                  value: pos.isDarkMode.value,
                  onChanged: (_) => pos.toggleTheme(),
                )),
                Obx(() => _SwitchRow(
                  icon: Icons.fullscreen_rounded,
                  iconColor: const Color(0xFF0A84FF),
                  title: "To'liq ekran",
                  value: pos.isFullScreen.value,
                  onChanged: (_) => pos.toggleFullScreen(),
                )),
                Obx(() => _SwitchRow(
                  icon: Icons.restart_alt_rounded,
                  iconColor: const Color(0xFF34C759),
                  title: "Avto-yuklash (boot)",
                  value: pos.isAutoStart.value,
                  onChanged: (_) => pos.toggleAutoStart(),
                  isLast: !Platform.isMacOS && !Platform.isWindows && !Platform.isLinux,
                )),
                if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) ...[
                  _NavRow(
                    icon: Icons.monitor_rounded,
                    iconColor: const Color(0xFF5E5CE6),
                    title: "Mijoz ekranini ochish",
                    onTap: () => pos.openCustomerDisplay(),
                  ),
                  Obx(() => _SwitchRow(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: const Color(0xFFFF9F0A),
                    title: "Mijoz ekranini avto-ochish",
                    value: pos.autoOpenCustomerDisplay.value,
                    onChanged: (v) { pos.autoOpenCustomerDisplay.value = v; GetStorage().write('auto_open_customer_display', v); },
                    isLast: true,
                  )),
                ],
              ]),
              const SizedBox(height: 32),

              // ── 6. TIZIM ─────────────────────────────────
              _SectionTitle(title: "system".tr),
              const SizedBox(height: 10),
              _SettingsGroup(children: [
                _NavRow(
                  icon: Icons.language_rounded,
                  iconColor: const Color(0xFF0A84FF),
                  title: "language".tr,
                  trailing: Get.locale?.languageCode == 'uz' ? "O'zbekcha" : (Get.locale?.languageCode == 'ru' ? "Русский" : "English"),
                  onTap: () => _langSheet(context),
                ),
                _NavRow(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF636366),
                  title: "app_version".tr,
                  trailing: "v1.2.0",
                  onTap: () {},
                  isLast: !pos.isAdmin,
                ),
                if (pos.isAdmin)
                  _NavRow(
                    icon: Icons.delete_forever_rounded,
                    iconColor: const Color(0xFFFF3B30),
                    title: "clear_data".tr,
                    isDestructive: true,
                    onTap: () => _clearDialog(context, pos, storage),
                    isLast: true,
                  ),
              ]),
              const SizedBox(height: 40),

              // ── 7. CHIQISH ───────────────────────────────
              _LogoutButton(pos: pos),
              const SizedBox(height: 20),
              const Center(
                child: Text("© 2026 Fassa POS",
                    style: TextStyle(color: Color(0xFFC7C7CC), fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────
  static void _paperSizeDialog(BuildContext ctx, POSController pos) {
    Get.defaultDialog(
      title: "printer_paper_size".tr,
      titleStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      backgroundColor: const Color(0xFFF2F2F7),
      radius: 20,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      content: Obx(() => Column(
        children: ["58mm", "80mm"].map((s) => RadioListTile<String>(
          title: Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
          value: s,
          groupValue: pos.printerPaperSize.value,
          activeColor: const Color(0xFFFF9500),
          onChanged: (v) { pos.printerPaperSize.value = v!; GetStorage().write('printer_paper_size', v); Get.back(); },
        )).toList(),
      )),
    );
  }

  static void _editDialog(BuildContext ctx, String title, RxString obs, String key, {Function(String)? onSave}) {
    final ctrl = TextEditingController(text: obs.value);
    Get.defaultDialog(
      title: title,
      titleStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
      backgroundColor: const Color(0xFFF2F2F7),
      radius: 20,
      content: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            hintText: title,
          ),
        ),
      ),
      confirm: ElevatedButton(
        onPressed: () { if (onSave != null) onSave(ctrl.text); else { obs.value = ctrl.text; GetStorage().write(key, ctrl.text); } Get.back(); },
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9500), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text("save".tr, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  static void _langSheet(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text("Tilni tanlang", style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...[("O'zbekcha", 'uz', 'UZ'), ("English", 'en', 'US'), ("Русский", 'ru', 'RU')].map((t) {
            final sel = Get.locale?.languageCode == t.$2;
            return ListTile(
              title: Text(t.$1, style: TextStyle(fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
              trailing: sel ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF9500)) : null,
              onTap: () { Get.updateLocale(Locale(t.$2, t.$3)); GetStorage().write('lang', '${t.$2}_${t.$3}'); Get.back(); },
            );
          }),
        ]),
      ),
    );
  }

  static void _clearDialog(BuildContext ctx, POSController pos, GetStorage storage) {
    Get.defaultDialog(
      title: "clear_data_confirm".tr,
      middleText: "clear_data_msg".tr,
      textConfirm: "yes".tr,
      textCancel: "no".tr,
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      radius: 20,
      onConfirm: () async {
        pos.allOrders.clear(); pos.currentOrder.clear(); storage.remove('all_orders');
        pos.printedKitchenQuantities.clear(); storage.remove('printed_kitchen_items');
        pos.processedPrintIds.clear();
        Get.back(); // close dialog
        
        try {
          await pos.api.clearOrders();
          Get.snackbar("Muvaffaqiyatli", "Hamma ma'lumotlar tozalandi (Backend'dan ham!)", backgroundColor: Colors.green, colorText: Colors.white);
        } catch (e) {
          Get.snackbar("Xato", "Mahalliy ma'lumotlar tozalandi, biroq server xatosi yuz berdi", backgroundColor: Colors.orange, colorText: Colors.white);
        }
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PROFIL HEADER
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileHeader extends StatelessWidget {
  final POSController pos;
  const _ProfileHeader({required this.pos});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF9500), Color(0xFFFF5C00)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFFFF9500).withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Row(children: [
        Container(
          width: 68, height: 68,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
          child: ClipOval(child: Image.asset('assets/logo.png', width: 52, height: 52)),
        ),
        const SizedBox(width: 18),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Obx(() => Text(pos.restaurantName.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white))),
          const SizedBox(height: 3),
          Obx(() => Row(children: [
            const Icon(Icons.place_rounded, size: 13, color: Colors.white70),
            const SizedBox(width: 3),
            Flexible(child: Text(pos.restaurantAddress.value, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
          ])),
          const SizedBox(height: 10),
          Obx(() => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.diamond_rounded, size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Text(pos.isVip.value ? "VIP — CHEKSIZ OBUNA" : "STANDART PLAN",
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
            ]),
          )),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  BOSHQARUV GRID (4 ta navigatsiya kartasi)
// ══════════════════════════════════════════════════════════════════════════════
class _NavGrid extends StatelessWidget {
  final bool tablet;
  const _NavGrid({required this.tablet});

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.badge_rounded, label: "Xodimlar", color: const Color(0xFF5E5CE6), onTap: () => Get.to(() => const StaffManagementScreen())),
      _NavItem(icon: Icons.restaurant_menu_rounded, label: "Menyu", color: const Color(0xFF30D158), onTap: () => Get.to(() => ProductManagementScreen())),
      _NavItem(icon: Icons.inventory_2_rounded, label: "Inventar", color: const Color(0xFFFF375F), onTap: () => Get.to(() => const InventoryManagementPage())),
      _NavItem(icon: Icons.tune_rounded, label: "Printerlar", color: const Color(0xFF0A84FF), onTap: () => Get.to(() => const PrinterManagementScreen())),
      _NavItem(icon: Icons.soup_kitchen_rounded, label: "Tayyorlash joylari", color: const Color(0xFFFF9F0A), onTap: () => Get.to(() => const PreparationAreaManagementScreen())),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: tablet ? 5 : 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: tablet ? 1.1 : 1.0,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => _NavCard(item: items[i]),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.color, required this.onTap});
}

class _NavCard extends StatelessWidget {
  final _NavItem item;
  const _NavCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: item.color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(item.icon, color: item.color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(item.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E))),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SECTION TITLE
// ══════════════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Text(title.toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF8E8E93), letterSpacing: 0.8)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SETTINGS GROUP (oq karta, ichi qatorlar)
// ══════════════════════════════════════════════════════════════════════════════
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  NAV ROW (chevron bilan navigatsiya)
// ══════════════════════════════════════════════════════════════════════════════
class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? trailing;
  final bool isDestructive;
  final bool isLast;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon, required this.iconColor, required this.title,
    this.trailing, this.isDestructive = false, this.isLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            _IconBox(icon: icon, color: isDestructive ? const Color(0xFFFF3B30) : iconColor),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDestructive ? const Color(0xFFFF3B30) : const Color(0xFF1C1C1E)))),
            if (trailing != null) ...[
              Text(trailing!, style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
              const SizedBox(width: 4),
            ],
            const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFC7C7CC)),
          ]),
        ),
      ),
      if (!isLast) const Padding(padding: EdgeInsets.only(left: 58), child: Divider(height: 1, color: Color(0xFFF2F2F7))),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SWITCH ROW (toggle bilan)
// ══════════════════════════════════════════════════════════════════════════════
class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final bool value;
  final bool isLast;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon, required this.iconColor, required this.title,
    required this.value, required this.onChanged, this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          _IconBox(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF1C1C1E)))),
          Switch.adaptive(
            value: value, onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: const Color(0xFF34C759),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE5E5EA),
          ),
        ]),
      ),
      if (!isLast) const Padding(padding: EdgeInsets.only(left: 58), child: Divider(height: 1, color: Color(0xFFF2F2F7))),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ICON BOX
// ══════════════════════════════════════════════════════════════════════════════
class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 32,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: Colors.white, size: 17),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  LOGOUT BUTTON
// ══════════════════════════════════════════════════════════════════════════════
class _LogoutButton extends StatelessWidget {
  final POSController pos;
  const _LogoutButton({required this.pos});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: () => pos.logout(),
        leading: _IconBox(icon: Icons.logout_rounded, color: const Color(0xFFFF3B30)),
        title: Text("logout".tr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFFF3B30))),
        trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFC7C7CC)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

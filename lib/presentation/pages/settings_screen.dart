import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../theme/app_colors.dart';
import '../../logic/pos_controller.dart';
import 'package:fast_food_app/presentation/pages/product_management_screen.dart';
import 'package:fast_food_app/presentation/pages/printer_management_screen.dart';
import 'package:fast_food_app/presentation/pages/preparation_area_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    final storage = GetStorage();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("settings".tr),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildProfileHeader(pos),
          const SizedBox(height: 32),
          
          _buildSectionTitle("printer_settings".tr),
          Obx(() => _buildSettingsItem(
            Icons.receipt, 
            "printer_paper_size".tr, 
            pos.printerPaperSize.value, 
            () => _showPaperSizeDialog(context, pos)
          )),
          Obx(() => _buildSwitchItem(
            Icons.print, 
            "auto_print_receipt".tr, 
            pos.autoPrintReceipt.value, 
            (val) {
              pos.autoPrintReceipt.value = val;
              storage.write('auto_print_receipt', val);
            }
          )),
          _buildSettingsItem(Icons.devices, "printer_management".tr, "", () => Get.to(() => const PrinterManagementScreen())),
          _buildSettingsItem(Icons.restaurant, "preparation_area_management".tr, "", () => Get.to(() => const PreparationAreaManagementScreen())),

          const SizedBox(height: 24),
          _buildSectionTitle("menu_management".tr),
          _buildSettingsItem(Icons.restaurant_menu, "menu_management".tr, "products".tr, () => Get.to(() => const ProductManagementScreen())),
          const SizedBox(height: 24),

          _buildSectionTitle("restaurant_info".tr),
          Obx(() => _buildSettingsItem(
            Icons.store, 
            "restaurant_name".tr, 
            pos.restaurantName.value, 
            () => _showEditDialog(context, "restaurant_name".tr, pos.restaurantName, 'restaurant_name', onSave: (val) => pos.updateCafeInfo(name: val))
          )),
          Obx(() => _buildSettingsItem(
            Icons.location_on, 
            "restaurant_address".tr, 
            pos.restaurantAddress.value, 
            () => _showEditDialog(context, "restaurant_address".tr, pos.restaurantAddress, 'restaurant_address', onSave: (val) => pos.updateCafeInfo(address: val))
          )),
          Obx(() => _buildSettingsItem(
            Icons.phone, 
            "restaurant_phone".tr, 
            pos.restaurantPhone.value, 
            () => _showEditDialog(context, "restaurant_phone".tr, pos.restaurantPhone, 'restaurant_phone', onSave: (val) => pos.updateCafeInfo(phone: val))
          )),

          const SizedBox(height: 24),
          _buildSectionTitle("service_fee_settings".tr),
          Obx(() => _buildSettingsItem(
            Icons.room_service, 
            "dine_in_service_fee".tr, 
            "${pos.serviceFeeDineIn.value}%", 
            () => _showEditDialog(context, "dine_in_service_fee".tr, pos.serviceFeeDineIn.value.toString().obs, '', isNumeric: true, onSave: (val) => pos.updateCafeInfo(serviceFeeDineInVal: double.tryParse(val)))
          )),
          Obx(() => _buildSettingsItem(
            Icons.shopping_bag, 
            "takeaway_service_fee".tr, 
            "${pos.serviceFeeTakeaway.value} so'm", 
            () => _showEditDialog(context, "takeaway_service_fee".tr, pos.serviceFeeTakeaway.value.toString().obs, '', isNumeric: true, onSave: (val) => pos.updateCafeInfo(serviceFeeTakeawayVal: double.tryParse(val)))
          )),
          Obx(() => _buildSettingsItem(
            Icons.delivery_dining, 
            "delivery_service_fee".tr, 
            "${pos.serviceFeeDelivery.value} so'm", 
            () => _showEditDialog(context, "delivery_service_fee".tr, pos.serviceFeeDelivery.value.toString().obs, '', isNumeric: true, onSave: (val) => pos.updateCafeInfo(serviceFeeDeliveryVal: double.tryParse(val)))
          )),

          const SizedBox(height: 24),
          _buildSectionTitle("system".tr),
          _buildSettingsItem(Icons.language, "language".tr, Get.locale?.languageCode == 'uz' ? "O'zbekcha" : (Get.locale?.languageCode == 'ru' ? "Русский" : "English"), () => _showLanguageSwitcher(context)),
          _buildSettingsItem(Icons.cleaning_services_outlined, "clear_data".tr, "", () => _confirmClearData(context, pos, storage)),
          _buildSettingsItem(Icons.info_outline, "app_version".tr, "v1.0.5", () {}),
          
          const SizedBox(height: 40),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(POSController pos) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: AppColors.primary,
                child: Text(pos.restaurantName.value.isNotEmpty ? pos.restaurantName.value.substring(0, 1).toUpperCase() : "C", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Obx(() => Text(pos.restaurantName.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    Obx(() => Text(pos.restaurantAddress.value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.background),
          const SizedBox(height: 16),
          Obx(() {
            final isVip = pos.isVip.value;
            final daysLeft = pos.subscriptionDaysLeft.value;
            
            return Row(
              children: [
                Icon(
                  isVip ? Icons.workspace_premium_rounded : Icons.timer_outlined,
                  size: 20,
                  color: isVip ? Colors.amber.shade700 : (daysLeft != null && daysLeft <= 3 ? Colors.red : Colors.green),
                ),
                const SizedBox(width: 8),
                Text(
                  isVip 
                    ? "VIP — Cheksiz obuna" 
                    : "Obuna muddati: " + (daysLeft != null ? daysLeft.toString() + " kun qoldi" : "Yuklanmoqda..."),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isVip ? Colors.amber.shade800 : (daysLeft != null && daysLeft <= 3 ? Colors.red : Colors.green.shade700),
                  ),
                ),
                if (!isVip && pos.subscriptionEndDate.value != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      "(${pos.subscriptionEndDate.value!.split('T')[0]})",
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 1.2)),
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 5)],
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)) : null,
        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      ),
    );
  }

  Widget _buildSwitchItem(IconData icon, String title, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 5)],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        activeColor: AppColors.primary,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade50,
        foregroundColor: Colors.red,
        elevation: 0,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.logout_rounded),
          const SizedBox(width: 12),
          Text("logout".tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showLanguageSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Sizning tilingiz / Ваш язык / Your Language", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildLangItem("O'zbekcha", 'uz', 'UZ'),
            _buildLangItem("English", 'en', 'US'),
            _buildLangItem("Русский", 'ru', 'RU'),
          ],
        ),
      ),
    );
  }

  Widget _buildLangItem(String label, String langCode, String countryCode) {
    return ListTile(
      title: Text(label),
      onTap: () {
        final locale = Locale(langCode, countryCode);
        Get.updateLocale(locale);
        GetStorage().write('lang', '${langCode}_$countryCode');
        Get.back();
      },
      trailing: Get.locale?.languageCode == langCode ? const Icon(Icons.check, color: AppColors.primary) : null,
    );
  }

  void _showPaperSizeDialog(BuildContext context, POSController pos) {
    Get.defaultDialog(
      title: "printer_paper_size".tr,
      content: Column(
        children: ["58mm", "80mm"].map((size) => RadioListTile(
          title: Text(size),
          value: size,
          groupValue: pos.printerPaperSize.value,
          activeColor: AppColors.primary,
          onChanged: (val) {
            pos.printerPaperSize.value = val.toString();
            GetStorage().write('printer_paper_size', val);
            Get.back();
          },
        )).toList(),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String title, RxString observable, String storageKey, {bool isNumeric = false, Function(String)? onSave}) {
    final controller = TextEditingController(text: observable.value);
    Get.defaultDialog(
      title: title,
      content: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          controller: controller,
          keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            hintText: title,
          ),
        ),
      ),
      confirm: ElevatedButton(
        onPressed: () {
          if (onSave != null) {
            onSave(controller.text);
          } else {
            observable.value = controller.text;
            if (storageKey.isNotEmpty) {
              GetStorage().write(storageKey, controller.text);
            }
          }
          Get.back();
        },
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
        child: Text("save".tr),
      ),
      cancel: TextButton(
        onPressed: () => Get.back(),
        child: Text("cancel".tr),
      ),
    );
  }

  void _confirmClearData(BuildContext context, POSController pos, GetStorage storage) {
    Get.defaultDialog(
      title: "clear_data_confirm".tr,
      middleText: "clear_data_msg".tr,
      textConfirm: "Yes, Reset",
      textCancel: "cancel".tr,
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        pos.allOrders.clear();
        pos.currentOrder.clear();
        storage.remove('all_orders');
        Get.back();
        Get.snackbar("Reset", "Application data has been cleared.", backgroundColor: Colors.red, colorText: Colors.white);
      },
    );
  }
}

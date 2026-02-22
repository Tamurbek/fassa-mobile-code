import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../data/services/api_service.dart';
import '../../theme/app_colors.dart';
import '../../logic/pos_controller.dart';

class StaffManagementScreen extends StatelessWidget {
  const StaffManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Xodimlar boshqaruvi"),
        centerTitle: true,
      ),
      body: Obx(() {
        final staff = pos.users.where((u) => u['role'] == "WAITER" || u['role'] == "CASHIER").toList();
        
        if (staff.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text("Hozircha xodimlar yo'q", 
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: staff.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final member = staff[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: member['role'] == "CASHIER" ? Colors.orange.withOpacity(0.1) : AppColors.primary.withOpacity(0.1),
                  child: Icon(
                    member['role'] == "CASHIER" ? Icons.point_of_sale_rounded : Icons.person_rounded, 
                    color: member['role'] == "CASHIER" ? Colors.orange : AppColors.primary,
                    size: 20,
                  ),
                ),
                title: Text(member['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${member['role'] == "CASHIER" ? "Kassir" : "Afitsant"} • ${member['email']}", style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (member['role'] == "WAITER")
                      IconButton(
                        icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 24),
                        onPressed: () => _showQRDialog(context, pos, member),
                        tooltip: "QR kod orqali telefonni ulash",
                      ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                      onPressed: () => _showStaffDialog(context, pos, member: member),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _confirmDelete(context, pos, member),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showStaffDialog(context, pos),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showQRDialog(BuildContext context, POSController pos, Map<String, dynamic> member) async {
    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    final token = await pos.getStaffQRToken(member['id']);
    Get.back(); // Close loading

    if (token == null) {
      Get.snackbar("Xato", "QR kod yaratib bo'lmadi", backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(member['name'], textAlign: TextAlign.center, 
          style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Telefoningizdan ushbu QR kodni skanerlang", 
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: QrImageView(
                data: "${ApiService().currentBaseUrl}|$token",
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Colors.black),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Colors.black),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Bu kod 5 daqiqa davomida amal qiladi", 
              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Get.back(), 
              child: const Text("Yopish", style: TextStyle(fontWeight: FontWeight.bold))
            ),
          )
        ],
      ),
    );
  }

  void _showStaffDialog(BuildContext context, POSController pos, {Map<String, dynamic>? member}) {
    final isEditing = member != null;
    final nameController = TextEditingController(text: member?['name'] ?? '');
    final emailController = TextEditingController(text: member?['email'] ?? '');
    final passwordController = TextEditingController();
    final RxString selectedRole = (member?['role'] ?? 'WAITER').toString().obs;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEditing ? "Xodimni tahrirlash" : "Yangi xodim qo'shish"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: "Ism",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Obx(() => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedRole.value,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'WAITER', child: Text("Afitsant")),
                      DropdownMenuItem(value: 'CASHIER', child: Text("Kassir")),
                    ],
                    onChanged: (val) {
                      if (val != null) selectedRole.value = val;
                    },
                  ),
                ),
              )),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email / Login",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  labelText: isEditing ? "Yangi parol (ixtiyoriy)" : "Parol",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Bekor qilish")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || emailController.text.isEmpty || (!isEditing && passwordController.text.isEmpty)) {
                Get.snackbar("Xato", "Barcha maydonlarni to'ldiring", backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }

              try {
                final Map<String, dynamic> data = {
                  'name': nameController.text.trim(),
                  'email': emailController.text.trim(),
                  'role': selectedRole.value,
                };
                if (passwordController.text.isNotEmpty) {
                  data['password'] = passwordController.text;
                }

                if (isEditing) {
                  await pos.updateUserProfile(member['id'], data);
                  Get.snackbar("Muvaffaqiyatli", "Ma'lumotlar yangilandi", backgroundColor: Colors.green, colorText: Colors.white);
                } else {
                  await pos.addUser(data);
                  Get.snackbar("Muvaffaqiyatli", "Yangi xodim qo'shildi", backgroundColor: Colors.green, colorText: Colors.white);
                }
                Get.back();
              } catch (e) {
                Get.snackbar("Xato", "Amalni bajarib bo'lmadi: $e", backgroundColor: Colors.red, colorText: Colors.white);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isEditing ? "Saqlash" : "Qo'shish"),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, POSController pos, Map<String, dynamic> member) {
    Get.defaultDialog(
      title: "O'chirishni tasdiqlang",
      middleText: "${member['name']} tizimdan o'chirilsinmi?",
      textConfirm: "Ha, o'chirish",
      textCancel: "Bekor qilish",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        try {
          await pos.deleteUser(member['id']);
          Get.back();
          Get.snackbar("O'chirildi", "Xodim tizimdan olib tashlandi", backgroundColor: Colors.orange, colorText: Colors.white);
        } catch (e) {
          Get.snackbar("Xato", "O'chirib bo'lmadi: $e", backgroundColor: Colors.red, colorText: Colors.white);
        }
      },
    );
  }
}

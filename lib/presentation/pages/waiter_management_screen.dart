import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../logic/pos_controller.dart';

class WaiterManagementScreen extends StatelessWidget {
  const WaiterManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Afitsantlar boshqaruvi"),
        centerTitle: true,
      ),
      body: Obx(() {
        final waiters = pos.users.where((u) => u['role'] == "WAITER").toList();
        
        if (waiters.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text("Hozircha afitsantlar yo'q", 
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: waiters.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final waiter = waiters[index];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(waiter['name'][0].toUpperCase(), 
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
                title: Text(waiter['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(waiter['email'], style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                      onPressed: () => _showWaiterDialog(context, pos, waiter: waiter),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      onPressed: () => _confirmDelete(context, pos, waiter),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWaiterDialog(context, pos),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showWaiterDialog(BuildContext context, POSController pos, {Map<String, dynamic>? waiter}) {
    final isEditing = waiter != null;
    final nameController = TextEditingController(text: waiter?['name'] ?? '');
    final emailController = TextEditingController(text: waiter?['email'] ?? '');
    final passwordController = TextEditingController();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isEditing ? "Afitsantni tahrirlash" : "Yangi afitsant qo'shish"),
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
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: "Email / Login",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.emailAddress,
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
                  'role': 'WAITER',
                };
                if (passwordController.text.isNotEmpty) {
                  data['password'] = passwordController.text;
                }

                if (isEditing) {
                  await pos.updateUserProfile(waiter['id'], data);
                  Get.snackbar("Muvaffaqiyatli", "Ma'lumotlar yangilandi", backgroundColor: Colors.green, colorText: Colors.white);
                } else {
                  await pos.addUser(data);
                  Get.snackbar("Muvaffaqiyatli", "Yangi afitsant qo'shildi", backgroundColor: Colors.green, colorText: Colors.white);
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

  void _confirmDelete(BuildContext context, POSController pos, Map<String, dynamic> waiter) {
    Get.defaultDialog(
      title: "O'chirishni tasdiqlang",
      middleText: "${waiter['name']} tizimdan o'chirilsinmi?",
      textConfirm: "Ha, o'chirish",
      textCancel: "Bekor qilish",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () async {
        try {
          await pos.deleteUser(waiter['id']);
          Get.back();
          Get.snackbar("O'chirildi", "Afitsant tizimdan olib tashlandi", backgroundColor: Colors.orange, colorText: Colors.white);
        } catch (e) {
          Get.snackbar("Xato", "O'chirib bo'lmadi: $e", backgroundColor: Colors.red, colorText: Colors.white);
        }
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../logic/pos_controller.dart';
import '../../data/models/preparation_area_model.dart';
import '../../theme/app_colors.dart';

class PreparationAreaManagementScreen extends StatelessWidget {
  const PreparationAreaManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    return Scaffold(
      appBar: AppBar(
        title: Text("preparation_areas".tr), 
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(context, pos, null),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Obx(() {
        if (pos.preparationAreas.isEmpty) {
          return const Center(child: Text("No preparation areas found.")); 
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pos.preparationAreas.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final area = pos.preparationAreas[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Slidable(
                key: ValueKey(area.id),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => _showDialog(context, pos, area),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: 'edit'.tr,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    SlidableAction(
                      onPressed: (context) => _confirmDelete(context, pos, area),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'delete'.tr,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ],
                ),
                child: Container(
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.restaurant, color: AppColors.secondary),
                    ),
                    title: Text(area.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${_getItemCount(pos, area)} items assigned"),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  int _getItemCount(POSController pos, PreparationAreaModel area) {
    return pos.products.where((p) => p.preparationAreaId == area.id).length;
  }

  void _confirmDelete(BuildContext context, POSController pos, PreparationAreaModel area) {
    int count = _getItemCount(pos, area);
    Get.defaultDialog(
      title: "Confirm Delete",
      middleText: "Delete '${area.name}'?\nIt has $count items assigned.",
      textConfirm: "Delete",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        pos.deletePreparationArea(area.id);
        Get.back();
      },
    );
  }

  void _showDialog(BuildContext context, POSController pos, PreparationAreaModel? area) {
    final controller = TextEditingController(text: area?.name ?? "");
    Get.defaultDialog(
      title: area == null ? "Add Area" : "Edit Area",
      content: TextField(
        controller: controller, 
        decoration: const InputDecoration(labelText: "Area Name", border: OutlineInputBorder())
      ),
      confirm: ElevatedButton(
        onPressed: () {
          if (controller.text.isNotEmpty) {
            if (area == null) {
              pos.addPreparationArea(PreparationAreaModel(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: controller.text,
                cafeId: pos.currentUser.value?['cafe_id'] ?? '',
              ));
            } else {
              pos.updatePreparationArea(PreparationAreaModel(
                id: area.id,
                name: controller.text,
                cafeId: area.cafeId,
              ));
            }
            Get.back();
          }
        },
        child: Text("save".tr),
      ),
      cancel: TextButton(onPressed: () => Get.back(), child: Text("cancel".tr)),
    );
  }
}

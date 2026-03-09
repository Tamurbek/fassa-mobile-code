import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../logic/pos_controller.dart';
import '../../data/models/preparation_area_model.dart';
import '../../theme/app_colors.dart';

class PreparationAreaManagementScreen extends StatelessWidget {
  const PreparationAreaManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text("preparation_areas".tr, style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDialog(context, pos, null),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Obx(() {
        if (pos.preparationAreas.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.soup_kitchen_rounded, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text("no_areas_found".tr, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            ]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pos.preparationAreas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final area = pos.preparationAreas[index];
            final count = pos.products.where((p) => p.preparationAreaId == area.id).length;
            return _AreaCard(
              area: area,
              productCount: count,
              onEdit: () => _showDialog(context, pos, area),
              onDelete: () => _confirmDelete(context, pos, area, count),
            );
          },
        );
      }),
    );
  }

  void _confirmDelete(BuildContext context, POSController pos, PreparationAreaModel area, int count) {
    Get.defaultDialog(
      title: "confirm_delete".tr,
      titleStyle: const TextStyle(fontWeight: FontWeight.w800),
      middleText: "${"delete".tr} '${area.name}'?\n${"items_assigned".tr}: $count",
      textConfirm: "delete".tr,
      textCancel: "cancel".tr,
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      radius: 20,
      onConfirm: () { pos.deletePreparationArea(area.id); Get.back(); },
    );
  }

  void _showDialog(BuildContext context, POSController pos, PreparationAreaModel? area) {
    final ctrl = TextEditingController(text: area?.name ?? "");
    Get.defaultDialog(
      title: area == null ? "add_area".tr : "edit_area".tr,
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
            hintText: "area_name".tr,
          ),
        ),
      ),
      confirm: ElevatedButton(
        onPressed: () async {
          if (ctrl.text.trim().isNotEmpty) {
            Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
            try {
              if (area == null) {
                await pos.addPreparationArea(PreparationAreaModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: ctrl.text.trim(),
                  cafeId: pos.currentUser.value?['cafe_id'] ?? '',
                ));
              } else {
                await pos.updatePreparationArea(PreparationAreaModel(
                  id: area.id, name: ctrl.text.trim(), cafeId: area.cafeId,
                ));
              }
              Get.back(); // loading
              Get.back(); // dialog
              Get.snackbar("success".tr, area == null ? "area_added".tr : "area_updated".tr,
                  backgroundColor: Colors.green, colorText: Colors.white);
            } catch (e) {
              Get.back();
              Get.snackbar("error".tr, "Save failed: $e", backgroundColor: Colors.red, colorText: Colors.white);
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF9500), foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text("save".tr, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      cancel: TextButton(onPressed: () => Get.back(), child: Text("cancel".tr)),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final PreparationAreaModel area;
  final int productCount;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AreaCard({
    required this.area, required this.productCount,
    required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // ─── Ma'lumotlar ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF30D158).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.soup_kitchen_rounded, color: Color(0xFF30D158), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(area.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: productCount > 0 ? const Color(0xFF0A84FF).withOpacity(0.08) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "$productCount ${"items_assigned".tr}",
                    style: TextStyle(
                      fontSize: 12,
                      color: productCount > 0 ? const Color(0xFF0A84FF) : Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
            ])),
          ]),
        ),

        // ─── Divider ───────────────────────────────────────────
        Divider(height: 1, color: Colors.grey.shade100),

        // ─── Edit / Delete tugmalari ───────────────────────────
        Row(children: [
          Expanded(
            child: TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: Text("edit".tr, style: const TextStyle(fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0A84FF),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16))),
              ),
            ),
          ),
          Container(width: 1, height: 36, color: Colors.grey.shade100),
          Expanded(
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_rounded, size: 16),
              label: Text("delete".tr, style: const TextStyle(fontWeight: FontWeight.w600)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF3B30),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(bottomRight: Radius.circular(16))),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

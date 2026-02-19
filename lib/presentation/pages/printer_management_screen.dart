import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../logic/pos_controller.dart';
import '../../data/models/printer_model.dart';
import '../../data/models/preparation_area_model.dart';
import '../../theme/app_colors.dart';
import 'save_printer_screen.dart'; // Import new screen

class PrinterManagementScreen extends StatelessWidget {
  const PrinterManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    return Scaffold(
      appBar: AppBar(
        title: Text("printer_management".tr),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => const SavePrinterScreen()),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Obx(() {
        if (pos.printers.isEmpty) {
          return Center(child: Text("no_printers".tr)); 
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pos.printers.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final printer = pos.printers[index];
            final printerAreas = pos.preparationAreas.where((a) => printer.preparationAreaIds.contains(a.id)).toList();
            
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Slidable(
                key: ValueKey(printer.id),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => Get.to(() => SavePrinterScreen(printer: printer)),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: 'edit'.tr,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    SlidableAction(
                      onPressed: (context) => _confirmDeletePrinter(context, pos, printer),
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
                      child: const Icon(Icons.print, color: AppColors.primary),
                    ),
                    title: Text(printer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${printer.ipAddress ?? 'USB/BT'}:${printer.port}"),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: printerAreas.isEmpty ? Colors.orange.shade50 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                            border: printerAreas.isEmpty ? Border.all(color: Colors.orange.withOpacity(0.3)) : null,
                          ),
                          child: Text(
                            printerAreas.isEmpty 
                                ? "KASSA" 
                                : printerAreas.map((a) => a.name).join(", "),
                            style: TextStyle(
                              fontSize: 10, 
                              color: printerAreas.isEmpty ? Colors.orange.shade900 : Colors.black87,
                              fontWeight: printerAreas.isEmpty ? FontWeight.bold : FontWeight.normal,
                            )
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _confirmDeletePrinter(BuildContext context, POSController pos, PrinterModel printer) {
    Get.defaultDialog(
      title: "Confirm Delete",
      middleText: "Delete printer '${printer.name}'?",
      textConfirm: "Delete",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        pos.deletePrinter(printer.id);
        Get.back();
      },
    );
  }
}

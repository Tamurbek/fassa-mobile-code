import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../logic/pos_controller.dart';
import '../../data/models/printer_model.dart';
import '../../theme/app_colors.dart';
import 'save_printer_screen.dart';

class PrinterManagementScreen extends StatelessWidget {
  const PrinterManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text("printer_management".tr, style: const TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        backgroundColor: const Color(0xFFF2F2F7),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => const SavePrinterScreen()),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Obx(() {
        if (pos.printers.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.print_disabled_rounded, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text("no_printers".tr, style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            ]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pos.printers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final printer = pos.printers[index];
            final areas = pos.preparationAreas
                .where((a) => printer.preparationAreaIds.contains(a.id))
                .toList();
            return _PrinterCard(
              printer: printer,
              areaNames: areas.isEmpty ? ["cashier_label".tr] : areas.map((a) => a.name).toList(),
              onEdit: () => Get.to(() => SavePrinterScreen(printer: printer)),
              onDelete: () => _confirmDelete(context, pos, printer),
              onToggle: (val) {
                final updated = PrinterModel(
                  id: printer.id, name: printer.name, ipAddress: printer.ipAddress,
                  port: printer.port, connectionType: printer.connectionType,
                  isActive: val, cafeId: printer.cafeId,
                  preparationAreaIds: printer.preparationAreaIds,
                  tableAreaNames: printer.tableAreaNames,
                  printReceipts: printer.printReceipts,
                  printPayments: printer.printPayments,
                  paperSize: printer.paperSize,
                );
                pos.updatePrinter(updated);
              },
              isActive: printer.isActive,
            );
          },
        );
      }),
    );
  }

  void _confirmDelete(BuildContext context, POSController pos, PrinterModel printer) {
    Get.defaultDialog(
      title: "confirm_delete".tr,
      titleStyle: const TextStyle(fontWeight: FontWeight.w800),
      middleText: "${"delete".tr} '${printer.name}'?",
      textConfirm: "delete".tr,
      textCancel: "cancel".tr,
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      radius: 20,
      onConfirm: () { pos.deletePrinter(printer.id); Get.back(); },
    );
  }
}

class _PrinterCard extends StatelessWidget {
  final PrinterModel printer;
  final List<String> areaNames;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final bool isActive;

  const _PrinterCard({
    required this.printer, required this.areaNames,
    required this.onEdit, required this.onDelete,
    required this.onToggle, required this.isActive,
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
        // ─── Ma'lumotlar qatori ────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFFF9500).withOpacity(0.12) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.print_rounded, color: isActive ? const Color(0xFFFF9500) : Colors.grey.shade400, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(printer.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text("${printer.ipAddress ?? 'USB/BT'}:${printer.port}",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const SizedBox(height: 6),
              Wrap(spacing: 4, runSpacing: 4, children: areaNames.map((name) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A84FF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(name, style: const TextStyle(fontSize: 11, color: Color(0xFF0A84FF), fontWeight: FontWeight.w600)),
              )).toList()),
            ])),
            // Aktiv holat switch
            Transform.scale(
              scale: 0.8,
              child: Switch.adaptive(
                value: isActive,
                onChanged: onToggle,
                activeTrackColor: const Color(0xFF34C759),
              ),
            ),
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
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16))),
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
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomRight: Radius.circular(16))),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

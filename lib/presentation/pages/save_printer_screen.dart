import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/printer_model.dart';
import '../../data/models/preparation_area_model.dart';
import '../../logic/pos_controller.dart';
import '../../theme/app_colors.dart';

class SavePrinterScreen extends StatefulWidget {
  final PrinterModel? printer;
  
  const SavePrinterScreen({super.key, this.printer});

  @override
  State<SavePrinterScreen> createState() => _SavePrinterScreenState();
}

class _SavePrinterScreenState extends State<SavePrinterScreen> {
  final POSController pos = Get.find<POSController>();
  
  late TextEditingController _nameController;
  late TextEditingController _ipController;
  late TextEditingController _portController;
  final RxString _selectedAreaId = "".obs;
  final RxString _paperSize = "80mm".obs;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.printer?.name ?? "");
    _ipController = TextEditingController(text: widget.printer?.ipAddress ?? "192.168.1.100");
    _portController = TextEditingController(text: widget.printer?.port.toString() ?? "9100");
    _selectedAreaId.value = widget.printer?.preparationAreaId ?? "";
    _paperSize.value = widget.printer?.paperSize ?? "80mm";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      Get.snackbar("error".tr, "name_required".tr, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    final newPrinter = PrinterModel(
      id: widget.printer?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      ipAddress: _ipController.text.trim().isEmpty ? null : _ipController.text.trim(),
      port: int.tryParse(_portController.text) ?? 9100,
      connectionType: 'NETWORK',
      isActive: widget.printer?.isActive ?? true,
      cafeId: pos.currentUser.value?['cafe_id'] ?? '',
      preparationAreaId: _selectedAreaId.value.isEmpty ? null : _selectedAreaId.value,
      paperSize: _paperSize.value,
    );

    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    try {
      if (widget.printer == null) {
        await pos.addPrinter(newPrinter);
      } else {
        await pos.updatePrinter(newPrinter);
      }
      Get.back(); // Close loading dialog
      Get.back(); // Go back
      Get.snackbar("success".tr, widget.printer == null ? "Printer Added" : "Printer Updated",
        backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.back(); // Close loading dialog
      Get.snackbar("error".tr, "Save failed: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.printer == null ? "add_printer".tr : "edit_printer".tr),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: AppColors.primary),
            onPressed: _save,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField("printer_name".tr, _nameController),
            const SizedBox(height: 16),
            _buildTextField("IP Address", _ipController, keyboardType: TextInputType.url),
            const SizedBox(height: 16),
            _buildTextField("Port", _portController, keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            
            Text("preparation_area".tr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Obx(() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAreaId.value.isEmpty ? null : _selectedAreaId.value,
                  hint: const Text("Select Area"),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text("None")),
                    ...pos.preparationAreas.map((area) => DropdownMenuItem(
                      value: area.id,
                      child: Text(area.name),
                    )),
                  ],
                  onChanged: (val) => _selectedAreaId.value = val ?? "",
                ),
              ),
            )),
            const SizedBox(height: 16),

            Text("Paper Size", style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Obx(() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _paperSize.value,
                  isExpanded: true,
                  items: ["58mm", "80mm"].map((size) => DropdownMenuItem(
                    value: size,
                    child: Text(size),
                  )).toList(),
                  onChanged: (val) => _paperSize.value = val ?? "80mm",
                ),
              ),
            )),
            const SizedBox(height: 32),
            if (widget.printer != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => pos.testPrinter(widget.printer!),
                  icon: const Icon(Icons.print),
                  label: const Text("Test Print"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text("save".tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

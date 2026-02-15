import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/food_item.dart';
import '../../logic/pos_controller.dart';
import '../../theme/app_colors.dart';
import '../widgets/common_image.dart';

class SaveProductScreen extends StatefulWidget {
  final FoodItem? item; // If null, we are creating a new product
  
  const SaveProductScreen({super.key, this.item});

  @override
  State<SaveProductScreen> createState() => _SaveProductScreenState();
}

class _SaveProductScreenState extends State<SaveProductScreen> {
  final POSController pos = Get.find<POSController>();
  final ImagePicker _picker = ImagePicker();
  
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _imageController;
  late String _selectedCategory;
  late String _selectedPrepArea;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? "");
    _descriptionController = TextEditingController(text: widget.item?.description ?? "");
    _priceController = TextEditingController(text: widget.item?.price.toString() ?? "");
    _imageController = TextEditingController(text: widget.item?.imageUrl ?? "");
    
    // Determine initial category
    _selectedCategory = widget.item?.category ?? (pos.categories.length > 1 ? pos.categories[1] : (pos.categories.isNotEmpty ? pos.categories[0] : "General"));
    if (!pos.categories.contains(_selectedCategory)) {
      _selectedCategory = "General";
      if (!pos.categories.contains("General")) {
        pos.addCategory("General");
      }
    }

    // Determine initial preparation area
    _selectedPrepArea = widget.item?.preparationArea ?? (pos.preparationAreas.isNotEmpty ? pos.preparationAreas[0] : "Kitchen");
    if (!pos.preparationAreas.contains(_selectedPrepArea)) {
       // If prep area from item is not in list (e.g. deleted), default to first or add it back?
       // Safe default
       if (pos.preparationAreas.isNotEmpty) {
         _selectedPrepArea = pos.preparationAreas[0];
       } else {
         pos.addPreparationArea("Kitchen");
         _selectedPrepArea = "Kitchen";
       }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _imageController.text = image.path;
        });
      }
    } catch (e) {
      Get.snackbar("error".tr, "${"pick_image_error".tr}: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _save() {
    if (_nameController.text.trim().isEmpty) {
      Get.snackbar("error".tr, "name_required".tr, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }
    
    double? price = double.tryParse(_priceController.text);
    if (price == null) {
      Get.snackbar("error".tr, "invalid_price".tr, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    final newItem = FoodItem(
      id: widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      price: price,
      imageUrl: _imageController.text.trim().isNotEmpty 
          ? _imageController.text.trim() 
          : "", 
      category: _selectedCategory,
      preparationArea: _selectedPrepArea,
    );

    if (widget.item == null) {
      pos.addProduct(newItem);
    } else {
      pos.updateProduct(newItem);
    }

    Get.back(); // Go back to management screen
    Get.snackbar("success".tr, widget.item == null ? "product_added".tr : "product_updated".tr,
      backgroundColor: Colors.green, colorText: Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.item == null ? "add_product".tr : "edit_product".tr),
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
            _buildTextField("product_name".tr, _nameController),
            const SizedBox(height: 16),
            _buildTextField("description".tr, _descriptionController, maxLines: 3),
            const SizedBox(height: 16),
            _buildTextField("price".tr, _priceController, keyboardType: TextInputType.number, prefixText: "\$ "),
            const SizedBox(height: 16),
            
            Text("category".tr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Obx(() => DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: pos.categories.contains(_selectedCategory) ? _selectedCategory : pos.categories.first,
                  isExpanded: true,
                  items: pos.categories.where((c) => c != "All").map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCategory = val;
                      });
                    }
                  },
                ),
              )),
            ),

            const SizedBox(height: 16),
            Text("preparation_area".tr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Obx(() => DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: pos.preparationAreas.contains(_selectedPrepArea) ? _selectedPrepArea : (pos.preparationAreas.isNotEmpty ? pos.preparationAreas.first : ""),
                  isExpanded: true,
                  items: pos.preparationAreas.map((c) => DropdownMenuItem(value: c, child: Text(c.tr))).toList(), // Added .tr to display
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedPrepArea = val;
                      });
                    }
                  },
                ),
              )),
            ),

            const SizedBox(height: 24),
            Text("product_image".tr, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _imageController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: "enter_image_url".tr,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onChanged: (val) => setState(() {}), // Update preview
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.upload_file, color: Colors.white),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Image Preview
            Center(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CommonImage(
                    imageUrl: _imageController.text,
                    width: 150,
                    height: 150,
                    fit: BoxFit.cover,
                  ),
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
            foregroundColor: Colors.white, // Text color
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text("save".tr ?? "Save", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType, String? prefixText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixText: prefixText,
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

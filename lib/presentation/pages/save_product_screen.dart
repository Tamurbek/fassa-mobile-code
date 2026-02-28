import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/food_item.dart';
import '../../logic/pos_controller.dart';
import '../../theme/app_colors.dart';
import '../../data/services/api_service.dart';
import '../widgets/common_image.dart';

class SaveProductScreen extends StatefulWidget {
  final FoodItem? item;

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
  final RxString _selectedPrepAreaId = "".obs;
  final RxBool _hasVariants = false.obs;
  final RxBool _isAvailable = true.obs;
  final RxList<FoodVariant> _variants = <FoodVariant>[].obs;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item?.name ?? "");
    _descriptionController = TextEditingController(text: widget.item?.description ?? "");
    _priceController = TextEditingController(
        text: widget.item?.hasVariants == true ? "" : (widget.item?.price.toString() ?? ""));
    _imageController = TextEditingController(text: widget.item?.imageUrl ?? "");

    _selectedCategory = widget.item?.category ??
        (pos.categories.length > 1 ? pos.categories[1] : (pos.categories.isNotEmpty ? pos.categories[0] : "General"));
    if (!pos.categories.contains(_selectedCategory)) {
      _selectedCategory = "General";
      if (!pos.categories.contains("General")) {
        pos.addCategory("General");
      }
    }

    _selectedPrepAreaId.value =
        widget.item?.preparationAreaId ?? (pos.preparationAreas.isNotEmpty ? pos.preparationAreas[0].id : "");
    _hasVariants.value = widget.item?.hasVariants ?? false;
    _isAvailable.value = widget.item?.isAvailable ?? true;
    if (widget.item?.variants != null) {
      _variants.assignAll(widget.item!.variants);
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
      Get.snackbar("error".tr, "${"pick_image_error".tr}: $e",
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void _addVariant() {
    _variants.add(FoodVariant(
      id: "new_${DateTime.now().millisecondsSinceEpoch}",
      name: "",
      price: 0.0,
      isAvailable: true,
    ));
  }

  void _removeVariant(int index) {
    _variants.removeAt(index);
  }

  void _updateVariant(int index, {String? name, double? price, bool? isAvailable}) {
    final old = _variants[index];
    _variants[index] = FoodVariant(
      id: old.id,
      name: name ?? old.name,
      price: price ?? old.price,
      isAvailable: isAvailable ?? old.isAvailable,
    );
  }

  void _save() async {
    if (_nameController.text.trim().isEmpty) {
      Get.snackbar("error".tr, "name_required".tr, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    double price = 0;
    if (!_hasVariants.value) {
      price = double.tryParse(_priceController.text) ?? 0;
      if (price <= 0 && _priceController.text.isNotEmpty) {
        Get.snackbar("error".tr, "invalid_price".tr, backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
    }

    String imageUrl = _imageController.text.trim();

    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http') && !imageUrl.startsWith('/uploads')) {
      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
      try {
        imageUrl = await ApiService().uploadImage(imageUrl);
        Get.back();
      } catch (e) {
        Get.back();
        Get.snackbar("error".tr, "upload_failed".tr, backgroundColor: Colors.red, colorText: Colors.white);
        return;
      }
    }

    final selectedArea = pos.preparationAreas.firstWhereOrNull((a) => a.id == _selectedPrepAreaId.value);

    final newItem = FoodItem(
      id: widget.item?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      price: price,
      imageUrl: imageUrl,
      category: _selectedCategory,
      preparationArea: selectedArea?.name ?? "Kitchen",
      preparationAreaId: _selectedPrepAreaId.value.isEmpty ? null : _selectedPrepAreaId.value,
      hasVariants: _hasVariants.value,
      variants: _hasVariants.value ? _variants.toList() : [],
      isAvailable: _isAvailable.value,
    );

    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    try {
      if (widget.item == null) {
        await pos.addProduct(newItem);
      } else {
        await pos.updateProduct(newItem);
      }
      Get.back();
      Get.back();
      Get.snackbar("success".tr, widget.item == null ? "product_added".tr : "product_updated".tr,
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.back();
      Get.snackbar("error".tr, "${"save_failed".tr}: $e", backgroundColor: Colors.red, colorText: Colors.white);
    }
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
            _buildSectionHeader("base_info".tr),
            _buildCard([
              _buildTextField("product_name".tr, _nameController, hint: "Lavash"),
              const SizedBox(height: 16),
              _buildTextField("description".tr, _descriptionController, maxLines: 2, hint: "Tavsif..."),
              const SizedBox(height: 16),
              _buildDropdown("category".tr, pos.categories.where((c) => c != "All").toList(), _selectedCategory,
                  (val) {
                if (val != null) setState(() => _selectedCategory = val);
              }),
              const SizedBox(height: 16),
              _buildDropdown("preparation_area".tr, pos.preparationAreas.map((a) => a.name).toList(),
                  pos.preparationAreas.firstWhereOrNull((a) => a.id == _selectedPrepAreaId.value)?.name ?? "",
                  (val) {
                final area = pos.preparationAreas.firstWhereOrNull((a) => a.name == val);
                if (area != null) _selectedPrepAreaId.value = area.id;
              }, hint: "select_area".tr),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader("pricing".tr),
            _buildCard([
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text("has_variants".tr, style: const TextStyle(fontWeight: FontWeight.w600)),
                   Obx(() => Switch(
                    value: _hasVariants.value,
                    onChanged: (val) => _hasVariants.value = val,
                    activeColor: AppColors.primary,
                  )),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const Text("Faol (Sotuvda bor)", style: TextStyle(fontWeight: FontWeight.w600)),
                   Obx(() => Switch(
                    value: _isAvailable.value,
                    onChanged: (val) => _isAvailable.value = val,
                    activeColor: AppColors.primary,
                  )),
                ],
              ),
              Obx(() => _hasVariants.value ? _buildVariantsList() : _buildPriceTextField()),
            ]),
            const SizedBox(height: 24),
            _buildSectionHeader("product_image".tr),
            _buildCard([
              _buildImagePicker(),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            shadowColor: AppColors.primary.withOpacity(0.4),
          ),
          child: Text("save".tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(title,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1, TextInputType? keyboardType, String? prefixText, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            hintText: hint,
            prefixText: prefixText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String current, Function(String?) onChanged,
      {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(current) ? current : null,
              isExpanded: true,
              hint: Text(hint ?? "Select..."),
              items: items.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceTextField() {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildTextField("price".tr, _priceController,
            keyboardType: TextInputType.number, prefixText: "SUM "),
      ],
    );
  }

  Widget _buildVariantsList() {
    return Column(
      children: [
        const Divider(height: 32),
        Obx(() => ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _variants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final variant = _variants[index];
                final nameCtrl = TextEditingController(text: variant.name);
                final priceCtrl = TextEditingController(text: variant.price > 0 ? variant.price.toString() : "");

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: nameCtrl,
                            onChanged: (val) => _updateVariant(index, name: val),
                            decoration: InputDecoration(
                              hintText: "variant_name".tr,
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: priceCtrl,
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _updateVariant(index, price: double.tryParse(val) ?? 0.0),
                            decoration: InputDecoration(
                              hintText: "price".tr,
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _removeVariant(index),
                        )
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text("Faol", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Transform.scale(
                          scale: 0.7,
                          child: Switch(
                            value: variant.isAvailable,
                            onChanged: (val) => _updateVariant(index, isAvailable: val),
                            activeColor: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            )),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: _addVariant,
          icon: const Icon(Icons.add_circle_outline),
          label: Text("add_variant".tr),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.primary.withOpacity(0.3))),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200, style: BorderStyle.none),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CommonImage(
                    imageUrl: _imageController.text,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    color: Colors.black.withOpacity(0.2),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 40),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _imageController,
          onChanged: (val) => setState(() {}),
          decoration: InputDecoration(
            hintText: "yoki URL kiriting...",
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            suffixIcon: IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _pickImage,
            ),
          ),
        ),
      ],
    );
  }
}

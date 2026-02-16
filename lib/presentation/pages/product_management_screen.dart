import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../logic/pos_controller.dart';
import '../../data/models/food_item.dart';
import '../../theme/app_colors.dart';
import 'save_product_screen.dart';
import '../widgets/common_image.dart';

class ProductManagementScreen extends StatelessWidget {
  const ProductManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text("menu_management".tr),
          centerTitle: true,
          bottom: TabBar(
            tabs: [
              Tab(text: "products".tr),
              Tab(text: "categories".tr),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
          ),
        ),
        body: TabBarView(
          children: [
            _buildProductsTab(pos, context),
            _buildCategoriesTab(pos, context),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsTab(POSController pos, BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => Get.to(() => const SaveProductScreen()),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Obx(() {
        if (pos.products.isEmpty) {
          return Center(child: Text("no_products".tr));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pos.products.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = pos.products[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Slidable(
                key: ValueKey(item.id),
                startActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => _confirmDeleteProduct(context, pos, item),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'delete'.tr,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ],
                ),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => Get.to(() => SaveProductScreen(item: item)),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: 'edit'.tr,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ],
                ),
                child: Container(
                  color: Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CommonImage( // Updated
                        imageUrl: item.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${item.category} • \$${item.price.toStringAsFixed(2)}"),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildCategoriesTab(POSController pos, BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context, pos, null),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Obx(() {
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: pos.categories.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final category = pos.categories[index];
            if (category == "All") return const SizedBox.shrink(); // Hide 'All' from editing usually

            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Slidable(
                key: ValueKey(category),
                startActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => _confirmDeleteCategory(context, pos, category),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'delete'.tr,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ],
                ),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => _showCategoryDialog(context, pos, category),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: 'edit'.tr,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ],
                ),
                child: Container(
                  color: Colors.white,
                  child: ListTile(
                    title: Text(category),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  void _confirmDeleteProduct(BuildContext context, POSController pos, FoodItem item) {
    Get.defaultDialog(
      title: "Confirm Delete",
      middleText: "Delete ${item.name}?",
      textConfirm: "Delete",
      textCancel: "Cancel",
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        pos.deleteProduct(item.id);
        Get.back();
      },
    );
  }

  void _showCategoryDialog(BuildContext context, POSController pos, String? category) {
    final controller = TextEditingController(text: category ?? "");
    Get.defaultDialog(
      title: category == null ? "Add Category" : "Edit Category",
      content: TextField(controller: controller, decoration: InputDecoration(labelText: "product_name".tr)), // Using product_name as placeholder or better 'category'
      confirm: ElevatedButton(
        onPressed: () async {
          if (controller.text.isNotEmpty) {
            Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);
            try {
              if (category == null) {
                await pos.addCategory(controller.text);
              } else {
                await pos.updateCategory(category, controller.text);
              }
              Get.back(); // Close loading
              Get.back(); // Close dialog
              Get.snackbar("success".tr, category == null ? "category_added".tr : "category_updated".tr,
                backgroundColor: Colors.green, colorText: Colors.white);
            } catch (e) {
              Get.back(); // Close loading
              Get.snackbar("error".tr, "Save failed: $e", backgroundColor: Colors.red, colorText: Colors.white);
            }
          }
        },
        child: Text("save".tr),
      ),
      cancel: TextButton(onPressed: () => Get.back(), child: Text("cancel".tr)),
    );
  }

  void _confirmDeleteCategory(BuildContext context, POSController pos, String category) {
    Get.defaultDialog(
      title: "delete_category_confirm".tr,
      middleText: "'$category'?",
      textConfirm: "delete".tr,
      textCancel: "cancel".tr,
      confirmTextColor: Colors.white,
      buttonColor: Colors.red,
      onConfirm: () {
        pos.deleteCategory(category);
        Get.back();
      },
    );
  }
}

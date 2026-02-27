import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../logic/pos_controller.dart';
import '../../data/models/food_item.dart';
import '../../theme/app_colors.dart';
import 'save_product_screen.dart';
import '../widgets/common_image.dart';
import '../../theme/responsive.dart';

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
        heroTag: 'product_add_fab',
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
                enabled: Responsive.isMobile(context),
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
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.category,
                              style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (item.hasVariants)
                            Row(
                              children: [
                                const Icon(Icons.sell_outlined, size: 12, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(
                                  "${item.variants.length} variant",
                                  style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            )
                          else
                            Text(
                              "${NumberFormat("#,###", "uz_UZ").format(item.price)} ${pos.currencySymbol}",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    trailing: !Responsive.isMobile(context) 
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => Get.to(() => SaveProductScreen(item: item)),
                              icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                            ),
                            IconButton(
                              onPressed: () => _confirmDeleteProduct(context, pos, item),
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                            ),
                          ],
                        )
                      : null,
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
        heroTag: 'category_add_fab',
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
                enabled: Responsive.isMobile(context),
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
                    trailing: !Responsive.isMobile(context)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => _showCategoryDialog(context, pos, category),
                              icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                            ),
                            IconButton(
                              onPressed: () => _confirmDeleteCategory(context, pos, category),
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                            ),
                          ],
                        )
                      : null,
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
      title: "confirm_delete".tr,
      middleText: "delete_item_confirm".tr,
      textConfirm: "delete".tr,
      textCancel: "cancel".tr,
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
      title: category == null ? "add_category".tr : "edit_category".tr,
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
      title: "confirm_delete".tr,
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

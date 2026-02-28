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
        return ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: pos.products.length,
          onReorder: (oldIndex, newIndex) => pos.reorderProducts(oldIndex, newIndex),
          itemBuilder: (context, index) {
            final item = pos.products[index];
            return Padding(
              key: ValueKey(item.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Slidable(
                  key: ValueKey("slidable_${item.id}"),
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
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.drag_indicator, color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CommonImage(
                              imageUrl: item.imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _showRecipeDialog(context, pos, item),
                            icon: const Icon(Icons.receipt_long_rounded, color: Colors.teal, size: 22),
                            tooltip: "Kalkulatsiya",
                          ),
                          if (!Responsive.isMobile(context)) ...[
                            IconButton(
                              onPressed: () => Get.to(() => SaveProductScreen(item: item)),
                              icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                            ),
                            IconButton(
                              onPressed: () => _confirmDeleteProduct(context, pos, item),
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                            ),
                          ],
                          if (Responsive.isMobile(context))
                            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                        ],
                      ),
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

  void _showRecipeDialog(BuildContext context, POSController pos, FoodItem product) async {
    // Get existing recipe
    final recipeItems = await pos.api.getRecipe(product.id);
    final List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(recipeItems);

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("${product.name} — Kalkulatsiya", style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (items.isEmpty)
                  const Padding(padding: EdgeInsets.all(20), child: Text("Retsept hali belgilanmagan"))
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final it = items[index];
                        return ListTile(
                          title: Text("${it['ingredient']['name']}"),
                          subtitle: Text("${it['quantity']} ${it['ingredient']['unit']}"),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                            onPressed: () {
                              // Delete logic could be added here
                            },
                          ),
                        );
                      },
                    ),
                  ),
                const Divider(),
                ElevatedButton.icon(
                  onPressed: () => _showAddRecipeItemDialog(context, pos, product, (newItem) {
                    setState(() {
                      items.add(newItem);
                    });
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text("Xom-ashyo qo'shish"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text("Yopish")),
          ],
        ),
      ),
    );
  }

  void _showAddRecipeItemDialog(BuildContext context, POSController pos, FoodItem product, Function(Map<String, dynamic>) onAdded) {
    String? selectedIngredientId;
    final qtyController = TextEditingController();

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Xom-ashyo qo'shish"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                value: selectedIngredientId,
                hint: const Text("Xom-ashyo tanlang"),
                items: pos.ingredients.map((ing) => DropdownMenuItem(
                  value: ing['id'].toString(),
                  child: Text("${ing['name']} (${ing['unit']})"),
                )).toList(),
                onChanged: (v) => setState(() => selectedIngredientId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Miqdori"),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text("Bekor qilish")),
            ElevatedButton(
              onPressed: () async {
                if (selectedIngredientId == null || qtyController.text.isEmpty) return;
                try {
                  final res = await pos.api.addRecipeItem({
                    "product_id": product.id,
                    "ingredient_id": selectedIngredientId,
                    "quantity": double.tryParse(qtyController.text) ?? 0,
                  });
                  onAdded(res);
                  Get.back();
                } catch (e) {
                  Get.snackbar("Xatolik", e.toString());
                }
              },
              child: const Text("Qo'shish"),
            ),
          ],
        ),
      ),
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

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
  ProductManagementScreen({super.key});

  final RxList<String> expandedProductIds = <String>[].obs;
  final RxMap<String, TextEditingController> variantNameControllers = <String, TextEditingController>{}.obs;
  final RxMap<String, TextEditingController> variantPriceControllers = <String, TextEditingController>{}.obs;

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

        final List<dynamic> displayItems = [];
        for (var product in pos.products) {
          displayItems.add({'type': 'product', 'data': product});
          if (expandedProductIds.contains(product.id)) {
            for (int i = 0; i < product.variants.length; i++) {
              displayItems.add({'type': 'variant', 'data': product.variants[i], 'parentId': product.id, 'index': i});
            }
            displayItems.add({'type': 'add_variant', 'parentId': product.id});
          }
        }

        return ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: displayItems.length,
          onReorder: (oldIndex, newIndex) {
            // Only allow reordering products, not variants (simplification for mobile)
            final oldItem = displayItems[oldIndex];
            final newItem = displayItems[newIndex > displayItems.length - 1 ? displayItems.length - 1 : newIndex];
            
            if (oldItem['type'] == 'product') {
              // Find actual product index
              int actualOld = pos.products.indexOf(oldItem['data']);
              // This is a bit tricky with nested items, but reorderProducts handles the list
              // For simplicity, we only reorder if both are products or we find the right spot
              pos.reorderProducts(actualOld, newIndex > pos.products.length ? pos.products.length : newIndex);
            }
          },
          itemBuilder: (context, index) {
            final item = displayItems[index];
            final String key = item['type'] == 'product' ? "prod_${item['data'].id}" : 
                               item['type'] == 'variant' ? "var_${item['parentId']}_${item['index']}" :
                               "add_var_${item['parentId']}";

            if (item['type'] == 'product') {
              return _buildProductRow(pos, context, item['data'], key);
            } else if (item['type'] == 'variant') {
              return _buildVariantRow(pos, context, item['data'], item['parentId'], item['index'], key);
            } else {
              return _buildAddVariantRow(pos, context, item['parentId'], key);
            }
          },
        );
      }),
    );
  }

  Widget _buildProductRow(POSController pos, BuildContext context, FoodItem item, String key) {
    bool isExpanded = expandedProductIds.contains(item.id);
    return Padding(
      key: ValueKey(key),
      padding: const EdgeInsets.only(bottom: 8),
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
              ),
            ],
          ),
          child: Container(
            color: Colors.white,
            child: ListTile(
              onTap: () {
                if (isExpanded) {
                  expandedProductIds.remove(item.id);
                } else {
                  expandedProductIds.add(item.id);
                }
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReorderableDragStartListener(
                    index: pos.products.indexOf(item),
                    child: const Icon(Icons.drag_indicator, color: Colors.grey, size: 20),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (isExpanded) {
                        expandedProductIds.remove(item.id);
                      } else {
                        expandedProductIds.add(item.id);
                      }
                    },
                    child: Icon(
                      isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right, 
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CommonImage(
                      imageUrl: item.imageUrl,
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.category,
                      style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (item.hasVariants)
                    Text("${item.variants.length} variant", style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600))
                  else
                    Text(
                      "${NumberFormat("#,###", "uz_UZ").format(item.price)} ${pos.currencySymbol}",
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch.adaptive(
                    value: item.isAvailable,
                    onChanged: (v) => pos.toggleProductAvailability(item),
                    activeColor: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _showMergeDialog(context, pos, item),
                    icon: const Icon(Icons.merge_type, color: Colors.orange, size: 22),
                    tooltip: "Birlashtirish",
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  IconButton(
                    onPressed: () => _showRecipeDialog(context, pos, item),
                    icon: const Icon(Icons.receipt_long_rounded, color: Colors.teal, size: 22),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                  if (!Responsive.isMobile(context))
                    IconButton(
                      onPressed: () => Get.to(() => SaveProductScreen(item: item)),
                      icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 22),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVariantRow(POSController pos, BuildContext context, FoodVariant variant, String parentId, int variantIndex, String key) {
    return Container(
      key: ValueKey(key),
      margin: const EdgeInsets.only(left: 40, bottom: 4, right: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        leading: const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
        title: Text(variant.name, style: const TextStyle(fontSize: 14)),
        subtitle: Text("${NumberFormat("#,###", "uz_UZ").format(variant.price)} ${pos.currencySymbol}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch.adaptive(
              value: variant.isAvailable,
              onChanged: (v) {
                final parent = pos.products.firstWhere((p) => p.id == parentId);
                pos.toggleVariantAvailability(parent, variantIndex);
              },
              activeColor: AppColors.primary,
            ),
            TextButton.icon(
              onPressed: () {
                final parent = pos.products.firstWhere((p) => p.id == parentId);
                pos.extractVariant(parent, variantIndex);
              },
              icon: const Icon(Icons.outbound_outlined, size: 14),
              label: const Text("Alohida qilish", style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddVariantRow(POSController pos, BuildContext context, String parentId, String key) {
    if (!variantNameControllers.containsKey(parentId)) {
      variantNameControllers[parentId] = TextEditingController();
      variantPriceControllers[parentId] = TextEditingController();
    }
    
    return Container(
      key: ValueKey(key),
      margin: const EdgeInsets.only(left: 40, bottom: 12, right: 16),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: variantNameControllers[parentId],
              decoration: const InputDecoration(hintText: "Variant nomi", isDense: true, border: InputBorder.none, hintStyle: TextStyle(fontSize: 12)),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: variantPriceControllers[parentId],
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "Narxi", isDense: true, border: InputBorder.none, hintStyle: TextStyle(fontSize: 12)),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: () {
              final name = variantNameControllers[parentId]?.text ?? "";
              final price = double.tryParse(variantPriceControllers[parentId]?.text ?? "0") ?? 0;
              if (name.isNotEmpty) {
                final parent = pos.products.firstWhere((p) => p.id == parentId);
                pos.addVariantToProduct(parent, name, price);
                variantNameControllers[parentId]?.clear();
                variantPriceControllers[parentId]?.clear();
              }
            },
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 24),
          ),
        ],
      ),
    );
  }

  void _showMergeDialog(BuildContext context, POSController pos, FoodItem source) {
    if (source.hasVariants) {
      Get.snackbar("Xato", "Variantlari bor mahsulotni boshqa mahsulotga birlashtirib bo'lmaydi");
      return;
    }

    Get.dialog(
      AlertDialog(
        title: Text("${source.name} ni qaysi mahsulotga birlashtiramiz?"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: pos.products.length,
            itemBuilder: (context, index) {
              final target = pos.products[index];
              if (target.id == source.id) return const SizedBox.shrink();
              return ListTile(
                title: Text(target.name),
                subtitle: Text(target.category),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CommonImage(imageUrl: target.imageUrl, width: 30, height: 30, fit: BoxFit.cover),
                ),
                onTap: () {
                  Get.back();
                  pos.mergeProducts(source, target);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Bekor qilish")),
        ],
      ),
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

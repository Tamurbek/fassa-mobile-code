import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/food_item.dart';
import '../../theme/app_colors.dart';
import '../../logic/pos_controller.dart';
import 'food_detail_screen.dart';
import 'cart_screen.dart';
import '../widgets/common_image.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    void handleSave() {
      pos.updateExistingOrder(isPaid: false);
      Get.back(); // Return to Orders
      Get.snackbar("success".tr, "ordered".tr, 
        backgroundColor: AppColors.primary, colorText: Colors.white);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Obx(() => Text(pos.editingOrderId.value != null 
          ? "${'editing_order'.tr} #${pos.editingOrderId.value}" 
          : "${pos.currentMode.value.toLowerCase().tr} Terminal")),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (pos.isOrderModified.value) {
              Get.dialog(
                AlertDialog(
                  title: Text(pos.editingOrderId.value != null ? 'cancel_edit'.tr : 'discard_order'.tr),
                  content: Text('unsaved_changes'.tr),
                  actions: [
                    TextButton(onPressed: () => Get.back(), child: Text('keep'.tr)),
                    TextButton(
                      onPressed: () {
                        pos.clearCurrentOrder();
                        Get.back(); // Close dialog
                        Get.back(); // Go back to Orders
                      }, 
                      child: Text(pos.editingOrderId.value != null ? 'cancel'.tr : 'discard'.tr, 
                        style: const TextStyle(color: Colors.red))
                    ),
                  ],
                ),
              );
            } else {
              Get.back();
            }
          },
        ),
        actions: [
          Obx(() => (pos.editingOrderId.value != null && pos.isOrderModified.value) 
            ? IconButton(
                icon: const Icon(Icons.check, color: Colors.green, size: 28),
                onPressed: handleSave,
              )
            : const SizedBox.shrink()),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildOperatorHeader(pos),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategories(pos),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      "select_items".tr,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: Obx(() {
                    final cat = pos.selectedCategory.value;
                    final items = cat == "All" 
                      ? pos.products 
                      : pos.products.where((p) => p.category == cat).toList();
                    return _buildPopularGrid(items);
                  })),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Obx(() {
        if (pos.currentOrder.isEmpty) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => Get.to(() => const CartScreen()),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pos.editingOrderId.value != null 
                      ? "${'update_review'.tr}: \$${pos.total.toStringAsFixed(2)}"
                      : "${'review_bill'.tr}: \$${pos.total.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text("${pos.totalItems} ${'items'.tr}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildOperatorHeader(POSController pos) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${'operator'.tr}: Alisher Z.", style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            Obx(() => pos.currentMode.value == "Dine-in" 
              ? Text("${'table'.tr}: ${pos.selectedTable.value}", style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14))
              : const SizedBox.shrink()),
          ],
        ),
        Obx(() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            pos.currentMode.value.toLowerCase().tr,
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        )),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.cardShadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'search_hint'.tr,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildCategories(POSController pos) {
    return SizedBox(
      height: 45,
      child: Obx(() => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: pos.categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final category = pos.categories[index];
          return Obx(() {
            final isSelected = pos.selectedCategory.value == category;
            return GestureDetector(
              onTap: () => pos.selectedCategory.value = category,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Text(
                    category.tr, // Ensure keys exist or it will just show category name
                    style: TextStyle(color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            );
          });
        },
      )),
    );
  }

  Widget _buildPopularGrid(List<FoodItem> items) {
    if (items.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text("No items in this category")));
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _buildFoodCard(items[index]),
      ),
    );
  }

  Widget _buildFoodCard(FoodItem item) {
    final POSController pos = Get.find<POSController>();

    return GestureDetector(
      onTap: () => Get.to(() => FoodDetailScreen(item: item)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.cardShadow.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CommonImage( // Updated to use CommonImage
                imageUrl: item.imageUrl,
                width: 85,
                height: 85,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1),
                  const SizedBox(height: 4),
                  Text(item.description, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary), maxLines: 1),
                  const SizedBox(height: 8),
                  Text("\$${item.price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ),
            Obx(() {
              final cartItem = pos.currentOrder.firstWhereOrNull((e) => e['item'].id == item.id);
              final int qty = cartItem != null ? cartItem['quantity'] : 0;
              final int itemIndex = pos.currentOrder.indexWhere((e) => e['item'].id == item.id);

              return Row(
                children: [
                  if (qty > 0) ...[
                    GestureDetector(
                      onTap: () => pos.updateQuantity(itemIndex, -1),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.remove, size: 20, color: AppColors.textPrimary),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        qty.toString(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  GestureDetector(
                    onTap: () => pos.addToCart(item),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

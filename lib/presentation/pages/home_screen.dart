import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/food_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/responsive.dart';
import '../../logic/pos_controller.dart';
import 'food_detail_screen.dart';
import 'cart_screen.dart';
import '../widgets/common_image.dart';
import '../widgets/printing_overlay.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    void handleSave() {
      pos.updateExistingOrder(isPaid: false);
      Get.back();
      Get.snackbar("success".tr, "ordered".tr, 
        backgroundColor: AppColors.primary, colorText: Colors.white);
    }

    return Obx(() => Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(pos.editingOrderId.value != null 
              ? "${'editing_order'.tr} #${pos.editingOrderId.value}" 
              : "${pos.currentMode.value.toLowerCase().tr} Terminal"),
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
                            Get.back();
                            Get.back();
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
              if (pos.editingOrderId.value != null && pos.isOrderModified.value) 
                IconButton(
                    icon: const Icon(Icons.check, color: Colors.green, size: 28),
                    onPressed: handleSave,
                  ),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.isMobile(context) ? 24 : 40, 
                    vertical: 8
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       _buildOperatorHeader(pos, context),
                      const SizedBox(height: 16),
                      _buildSearchBar(),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategories(pos, context),
                      const SizedBox(height: 24),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.isMobile(context) ? 24 : 40
                        ),
                        child: Text(
                          "select_items".tr,
                          style: TextStyle(
                            fontSize: Responsive.isMobile(context) ? 20 : 24, 
                            fontWeight: FontWeight.bold, 
                            color: AppColors.textPrimary
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: Builder(builder: (context) {
                        final cat = pos.selectedCategory.value;
                        final items = cat == "All" 
                          ? pos.products 
                          : pos.products.where((p) => p.category == cat).toList();
                        return _buildItemsGrid(items, context);
                      })),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: pos.currentOrder.isEmpty ? null : Container(
            padding: const EdgeInsets.all(16),
            constraints: BoxConstraints(maxWidth: Responsive.isMobile(context) ? double.infinity : 400),
            margin: EdgeInsets.symmetric(
              horizontal: Responsive.isMobile(context) ? 24 : 0
            ),
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
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        ),
        if (pos.isPrinting.value)
          const PrintingOverlay(),
      ],
    ));
  }

  Widget _buildOperatorHeader(POSController pos, BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${'operator'.tr}: ${pos.currentUser.value?['name'] ?? 'Unknown'}", 
              style: TextStyle(
                color: AppColors.textSecondary, 
                fontSize: Responsive.isMobile(context) ? 13 : 15
              )
            ),
            Obx(() => pos.currentMode.value == "Dine-in" 
              ? Text("${'table'.tr}: ${pos.selectedTable.value}", 
                  style: TextStyle(
                    color: AppColors.textPrimary, 
                    fontWeight: FontWeight.bold, 
                    fontSize: Responsive.isMobile(context) ? 14 : 18
                  )
                )
              : const SizedBox.shrink()),
          ],
        ),
        Obx(() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            pos.currentMode.value.toLowerCase().tr,
            style: TextStyle(
              color: AppColors.primary, 
              fontWeight: FontWeight.bold, 
              fontSize: Responsive.isMobile(context) ? 12 : 14
            ),
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

  Widget _buildCategories(POSController pos, BuildContext context) {
    return SizedBox(
      height: 50,
      child: Obx(() => ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: Responsive.isMobile(context) ? 24 : 40),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected ? null : Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Text(
                    category.tr,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textSecondary, 
                      fontWeight: FontWeight.w600, 
                      fontSize: Responsive.isMobile(context) ? 14 : 16
                    ),
                  ),
                ),
              ),
            );
          });
        },
      )),
    );
  }

  Widget _buildItemsGrid(List<FoodItem> items, BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(40.0), child: Text("No items in this category")));
    }

    final int crossAxisCount = Responsive.isMobile(context) ? 1 : (Responsive.isTablet(context) ? 2 : 3);
    final double childAspectRatio = Responsive.isMobile(context) ? 2.8 : 2.5;

    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: Responsive.isMobile(context) ? 24 : 40),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildFoodCard(items[index], context),
      physics: const BouncingScrollPhysics(),
    );
  }

  Widget _buildFoodCard(FoodItem item, BuildContext context) {
    final POSController pos = Get.find<POSController>();
    final bool isMobile = Responsive.isMobile(context);

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
              child: CommonImage(
                imageUrl: item.imageUrl,
                width: isMobile ? 85 : 100,
                height: isMobile ? 85 : 100,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.name, 
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18, 
                      fontWeight: FontWeight.bold
                    ), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 4),
                  Text(item.description, 
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13, 
                      color: AppColors.textSecondary
                    ), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                  const SizedBox(height: 8),
                  Text("\$${item.price.toStringAsFixed(2)}", 
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20, 
                      fontWeight: FontWeight.bold, 
                      color: AppColors.primary
                    )
                  ),
                ],
              ),
            ),
            _buildQuantityControls(item, pos, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControls(FoodItem item, POSController pos, bool isMobile) {
    return Obx(() {
      final cartItem = pos.currentOrder.firstWhereOrNull((e) => e['item'].id == item.id);
      final int qty = cartItem != null ? cartItem['quantity'] : 0;
      final int itemIndex = pos.currentOrder.indexWhere((e) => e['item'].id == item.id);

      return Row(
        mainAxisSize: MainAxisSize.min,
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
                child: Icon(Icons.remove, size: isMobile ? 20 : 22, color: AppColors.textPrimary),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                qty.toString(),
                style: TextStyle(fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.bold),
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
              child: Icon(Icons.add, size: isMobile ? 20 : 22, color: Colors.white),
            ),
          ),
        ],
      );
    });
  }
}


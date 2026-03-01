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
import '../widgets/virtual_keyboard.dart';
import 'package:intl/intl.dart';
import 'main_navigation_screen.dart';
import 'kitchen_display_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    final bool isMobile = Responsive.isMobile(context);

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) pos.clearCurrentOrder();
      },
      child: Obx(() => Stack(
        children: [
        Scaffold(
          backgroundColor: const Color(0xFFF8F9FB),
          body: Row(
            children: [
              // Left Sidebar: Cart (Only on Desktop/Tablet)
              if (!isMobile)
                Container(
                  width: 380,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(right: BorderSide(color: Color(0xFFEDF0F5))),
                  ),
                  child: _buildPOSCartSidebar(pos, context),
                ),
              
              // Main Content
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(pos, context),
                    _buildCategories(pos, context),
                    Expanded(
                      child: Obx(() {
                        final cat = pos.selectedCategory.value;
                        final query = pos.searchQuery.value.toLowerCase();
                        
                        final items = pos.products.where((p) {
                          if (!p.isAvailable) return false;
                          final bool matchCat = cat == "All" || p.category == cat;
                          final bool matchQuery = query.isEmpty || 
                            p.name.toLowerCase().contains(query) ||
                            p.description.toLowerCase().contains(query);
                          return matchCat && matchQuery;
                        }).toList();
                        
                        return Column(
                          children: [
                            Expanded(child: _buildItemsGrid(items, context)),
                            if (pos.showKeyboard.value)
                              VirtualKeyboard(
                                controller: pos.searchController,
                                onEnter: () => pos.showKeyboard.value = false,
                              ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: isMobile && pos.currentOrder.isNotEmpty 
            ? _buildMobileCartButton(pos, context) 
            : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        ),
        if (pos.isPrinting.value) const PrintingOverlay(),
      ],
    )));
  }

  Widget _buildTopBar(POSController pos, BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 24 : 40, 
        MediaQuery.of(context).padding.top + 16, 
        isMobile ? 24 : 40, 
        16
      ),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            GestureDetector(
              onTap: () {
                pos.clearCurrentOrder();
                Get.back();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9500),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF9500).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "back".tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          if (!isMobile) ...[
            Obx(() => Text(
              pos.restaurantName.value.isEmpty ? "FAST FOOD PRO" : pos.restaurantName.value.toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFF9500), letterSpacing: -0.5),
            )),
            const SizedBox(width: 40),
          ],
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Obx(() => TextField(
                controller: pos.searchController,
                focusNode: pos.searchFocusNode, // Added FocusNode
                onChanged: (v) => pos.searchQuery.value = v,
                readOnly: pos.showKeyboard.value, // Added readOnly
                showCursor: true, // Added showCursor
                decoration: InputDecoration(
                  hintText: 'search_hint'.tr,
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (pos.searchQuery.value.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            pos.searchController.clear();
                            pos.searchQuery.value = "";
                          },
                        ),
                      IconButton(
                        icon: Icon(
                          pos.showKeyboard.value ? Icons.keyboard_hide_rounded : Icons.keyboard_rounded,
                          size: 20,
                          color: pos.showKeyboard.value ? const Color(0xFFFF9500) : const Color(0xFF9CA3AF),
                        ),
                        onPressed: () {
                          pos.showKeyboard.value = !pos.showKeyboard.value;
                          if (pos.showKeyboard.value) {
                            pos.searchFocusNode.requestFocus(); // Request focus when keyboard is shown
                          } else {
                            pos.searchFocusNode.unfocus(); // Unfocus when keyboard is hidden
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )),
            ),
          ),
          const SizedBox(width: 16),
          // Offline Indicator
          Obx(() => pos.isOffline.value || pos.pendingOfflineOrders.value > 0 ? 
            _buildTopStatusBadge(
              pos.isOffline.value ? Icons.cloud_off_rounded : Icons.cloud_sync_rounded,
              pos.pendingOfflineOrders.value.toString(),
              pos.isOffline.value ? Colors.red : Colors.orange,
              onTap: () => pos.refreshData() // Refresh tries to sync
            ) : const SizedBox.shrink()),
          const SizedBox(width: 12),
          _buildTopIcon(Icons.notifications_outlined),
          const SizedBox(width: 12),
          _buildTopIcon(Icons.lock_rounded, onTap: () => pos.lockTerminal()),
          const SizedBox(width: 12),
          _buildTopIcon(Icons.refresh_rounded, onTap: () => pos.refreshData()),
          const SizedBox(width: 12),
          if (pos.isAdmin || pos.isCashier)
            _buildTopIcon(Icons.kitchen_rounded, onTap: () => Get.to(() => const KitchenDisplayPage())),
          const SizedBox(width: 12),
          _buildTopIcon(Icons.settings_outlined, onTap: () => Get.toNamed('/settings')),
        ],
      ),
    );
  }

  Widget _buildTopStatusBadge(IconData icon, String label, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopIcon(IconData icon, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: const Color(0xFF1A1A1A), size: 22),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildCategories(POSController pos, BuildContext context) {
    final List<Map<String, dynamic>> catItems = pos.categories.map((cat) {
      IconData icon = Icons.grid_view_rounded;
      final name = cat.toLowerCase();
      if (name.contains('burger')) icon = Icons.lunch_dining_rounded;
      if (name.contains('drink') || name.contains('ichimlik')) icon = Icons.local_drink_rounded;
      if (name.contains('pizza') || name.contains('pitsa')) icon = Icons.local_pizza_rounded;
      if (name.contains('lavash')) icon = Icons.local_fire_department_rounded;
      if (name.contains('salat') || name.contains('salad')) icon = Icons.eco_rounded;
      if (name.contains('desert') || name.contains('dessert')) icon = Icons.cake_rounded;
      
      return {
        "name": cat,
        "label": cat == "All" ? "all".tr : cat,
        "icon": icon
      };
    }).toList();

    return Container(
      height: 56,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: Responsive.isMobile(context) ? 24 : 40),
        scrollDirection: Axis.horizontal,
        itemCount: catItems.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final cat = catItems[index];
          return Obx(() {
            final isSelected = pos.selectedCategory.value == cat['name'] as String;
            return GestureDetector(
              onTap: () => pos.selectedCategory.value = cat['name'] as String,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFF9500) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(cat['icon'] as IconData, size: 18, color: isSelected ? Colors.white : const Color(0xFF1A1A1A)),
                    const SizedBox(width: 8),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          });
        },
      ),
    );
  }

  Widget _buildItemsGrid(List<FoodItem> items, BuildContext context) {
    final bool isMobile = Responsive.isMobile(context);
    return GridView.builder(
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _buildFoodCard(items[index], context),
    );
  }

  Widget _buildFoodCard(FoodItem item, BuildContext context) {
    final POSController pos = Get.find<POSController>();
    final bool isMobile = Responsive.isMobile(context);

    return GestureDetector(
      onTap: () {
        if (item.hasVariants && item.variants.isNotEmpty) {
          _showVariantPicker(context, item, pos);
        } else {
          pos.addToCart(item);
        }
      },
      child: Obx(() {
        final int qty = pos.currentOrder
            .where((e) => (e['item'] as FoodItem).id == item.id && e['isNew'] == true)
            .fold(0, (sum, e) => sum + (e['quantity'] as int));

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CommonImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A1A)), 
                          maxLines: 1, overflow: TextOverflow.ellipsis
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (item.hasVariants && item.variants.isNotEmpty)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Variantlar",
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF0EA5E9))),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text("${NumberFormat("#,###", "uz_UZ").format(item.variants.first.price)}", 
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFFF9500))),
                                            const SizedBox(width: 4),
                                            Text(pos.currencySymbol, style: const TextStyle(fontSize: 9, color: Color(0xFFFF9500), fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    )
                                  else
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("${NumberFormat("#,###", "uz_UZ").format(item.price)}", 
                                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFFFF9500))),
                                        Text(pos.currencySymbol, style: const TextStyle(fontSize: 10, color: Color(0xFFFF9500), fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            if (isMobile && qty > 0)
                              _buildCounterControl(item, qty, pos)
                            else
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: item.hasVariants ? const Color(0xFFE0F2FE) : const Color(0xFFFFF7ED),
                                  borderRadius: BorderRadius.circular(10)
                                ),
                                child: Icon(
                                  item.hasVariants ? Icons.expand_more : Icons.add,
                                  color: item.hasVariants ? const Color(0xFF0EA5E9) : const Color(0xFFFF9500),
                                  size: 18
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (qty > 0)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9500),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9500).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    "$qty",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  void _showVariantPicker(BuildContext context, FoodItem item, POSController pos) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text(item.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            const SizedBox(height: 8),
            Text("Hajmni tanlang:", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: item.variants.where((v) => v.isAvailable).map((variant) => Obx(() {
                    final int qty = pos.currentOrder
                        .where((e) => (e['item'] as FoodItem).id == item.id && 
                                     e['variant']?.id == variant.id && 
                                     e['isNew'] == true)
                        .fold(0, (sum, e) => sum + (e['quantity'] as int));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: qty > 0 ? const Color(0xFFFFF7ED) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: qty > 0 ? const Color(0xFFFF9500).withOpacity(0.5) : const Color(0xFFEDF0F5),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(variant.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text(
                                  "${NumberFormat('#,###', 'uz_UZ').format(variant.price)} ${pos.currencySymbol}",
                                  style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.w900, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          _buildCounterForVariant(item, variant, qty, pos),
                        ],
                      ),
                    );
                  })).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9500),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("Tayyor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterForVariant(FoodItem item, dynamic variant, int qty, POSController pos) {
    if (qty == 0) {
      return GestureDetector(
        onTap: () => pos.addToCart(item, variant: variant),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.add, color: Color(0xFF0EA5E9), size: 22),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => pos.decrementFromCart(item, variant: variant),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.remove, size: 22, color: Color(0xFF1A1A1A)),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 44),
            alignment: Alignment.center,
            child: Text("$qty", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          ),
          GestureDetector(
            onTap: () => pos.addToCart(item, variant: variant),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFF9500), borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.add, size: 22, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterControl(FoodItem item, int qty, POSController pos) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => pos.decrementFromCart(item),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.remove, size: 18, color: Color(0xFF1A1A1A)),
            ),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            alignment: Alignment.center,
            child: Text("$qty", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          ),
          GestureDetector(
            onTap: () => pos.addToCart(item),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFF9500), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPOSCartSidebar(POSController pos, BuildContext context) {
    return Column(
      children: [
        _buildOperatorHeader(pos),
        _buildModeSelector(pos),
        Expanded(
          child: pos.currentOrder.isEmpty
              ? _buildEmptyCartPlaceholder()
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  itemCount: pos.currentOrder.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final cartItem = pos.currentOrder[index];
                    return _buildPOSCartItem(cartItem, index, pos);
                  },
                ),
        ),
        _buildPOSOrderSummary(pos),
      ],
    );
  }

  Widget _buildOperatorHeader(POSController pos) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFFFEDD5),
            child: Icon(Icons.person, color: Color(0xFFFF9500)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("operator".tr, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, fontWeight: FontWeight.bold)),
                Text((pos.currentUser.value?['name'] as String?) ?? "Unknown", 
                  style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
          if (pos.isAdmin || pos.isCashier)
            IconButton(
              icon: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 24),
              onPressed: () {
                Get.dialog(
                  AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text("cancel_order_confirm_title".tr),
                    content: Text("cancel_order_confirm_msg".tr),
                    actions: [
                      TextButton(onPressed: () => Get.back(), child: Text("back".tr)),
                      TextButton(
                        onPressed: () {
                          pos.clearCurrentOrder();
                          Get.back();
                        }, 
                        child: Text("yes_cancel".tr, style: const TextStyle(color: Colors.red))
                      ),
                    ],
                  )
                );
              },
              tooltip: "Bekor",
            ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(POSController pos) {
    final modes = [
      {"id": "Dine-in", "label": "dine_in".tr, "icon": Icons.restaurant},
      {"id": "Takeaway", "label": "takeaway".tr, "icon": Icons.shopping_bag},
      {"id": "Delivery", "label": "delivery".tr, "icon": Icons.delivery_dining},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: modes.map((m) {
          final isSel = pos.currentMode.value == m['id'] as String;
          return Expanded(
            child: GestureDetector(
              onTap: () => pos.setMode(m['id'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSel ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)] : null,
                ),
                child: Column(
                  children: [
                    Icon(m['icon'] as IconData, size: 18, color: isSel ? const Color(0xFFFF9500) : const Color(0xFF9CA3AF)),
                    const SizedBox(height: 4),
                    Text(m['label'] as String, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isSel ? const Color(0xFF1A1A1A) : const Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPOSCartItem(Map<String, dynamic> cartItem, int index, POSController pos) {
    final FoodItem item = cartItem['item'];
    final int quantity = cartItem['quantity'];
    final bool isNew = cartItem['isNew'] == true;
    final int sentQty = cartItem['sentQty'] ?? 0;
    final bool isCancelled = !isNew && quantity == 0;
    final bool isPartialCancelled = !isNew && quantity < sentQty && quantity > 0;

    return Opacity(
      opacity: isCancelled ? 0.5 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isNew 
            ? const Color(0xFFEFF6FF) // Light blue for new
            : (isCancelled ? Colors.grey.shade100 : const Color(0xFFF8F9FB)),
          borderRadius: BorderRadius.circular(20),
          border: isNew ? Border.all(color: Colors.blue.shade100) : null,
        ),
        child: Row(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CommonImage(imageUrl: item.imageUrl, width: 50, height: 50, fit: BoxFit.cover),
                ),
                if (isCancelled)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.hasVariants && cartItem['variant'] != null
                            ? "${item.name} (${cartItem['variant']?.name})"
                            : item.name, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 13,
                            decoration: isCancelled ? TextDecoration.lineThrough : null,
                          )
                        ),
                      ),
                      if (isNew)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(6)),
                          child: const Text("Yangi", style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (isPartialCancelled)
                    Text("${sentQty - quantity} ta bekor qilindi", 
                      style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold))
                  else if (isCancelled)
                    const Text("Bekor qilingan", 
                      style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold))
                  else
                    Text("${NumberFormat("#,###", "uz_UZ").format(cartItem['variant']?.price ?? item.price)} ${pos.currencySymbol}", 
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            _buildVerticalCounter(index, quantity, pos, isCancelled),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalCounter(int index, int qty, POSController pos, bool isCancelled) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(30), 
        border: Border.all(color: const Color(0xFFEDF0F5), width: 1.5)
      ),
      child: Column(
        children: [
          _buildCounterBtn(Icons.add, () => pos.updateQuantity(index, 1)),
          GestureDetector(
            onTap: () => pos.showQuantityDialog(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text("$qty", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isCancelled ? Colors.red : const Color(0xFF1A1A1A))),
            ),
          ),
          _buildCounterBtn(Icons.remove, () => pos.updateQuantity(index, -1)),
        ],
      ),
    );
  }

  Widget _buildCounterBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
      ),
    );
  }

  Widget _buildPOSOrderSummary(POSController pos) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDF0F5))),
      ),
      child: Obx(() {
        final hasDiscount = pos.discountValue.value > 0;
        return Column(
          children: [
            _buildSumRow("subtotal_sum".tr, "${NumberFormat("#,###", "uz_UZ").format(pos.subtotal)} ${pos.currencySymbol}"),
            _buildSumRow(
              pos.currentMode.value == "Dine-in"
                ? "${"service_fee_label".tr} (${pos.serviceFeeDineIn.value.toStringAsFixed(0)}%)"
                : "service_fee_label".tr,
              "${NumberFormat("#,###", "uz_UZ").format(pos.serviceFee)} ${pos.currencySymbol}"
            ),

            // Chegirma satri
            if (hasDiscount) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.discount_rounded, color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          pos.discountType.value == "percent"
                            ? "Chegirma (${pos.discountValue.value.toStringAsFixed(0)}%)"
                            : "Chegirma (belgilangan)",
                          style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "- ${NumberFormat("#,###", "uz_UZ").format(pos.discountAmount)} ${pos.currencySymbol}",
                          style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => pos.resetDiscount(),
                          child: const Icon(Icons.close, color: Colors.red, size: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("total".tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                Text("${NumberFormat("#,###", "uz_UZ").format(pos.total)} ${pos.currencySymbol}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFF9500))),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                // Chegirma tugmasi
                if (pos.isAdmin || pos.isCashier) ...[
                  Expanded(
                    child: _buildActionBtn(
                      Icons.discount_rounded,
                      "Chegirma",
                      hasDiscount ? Colors.green : const Color(0xFF6B7280),
                      () => _showDiscountDialog(pos),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // Kitchen Print
                Expanded(
                  child: _buildActionBtn(
                    Icons.soup_kitchen_rounded,
                    pos.isOrderModified.value ? "Saqlash" : "Oshxona",
                    const Color(0xFF3B82F6),
                    () async {
                      if (!pos.isOrderModified.value) {
                        Get.snackbar("Eslatma", "O'zgarishlar yo'q",
                          backgroundColor: Colors.orange, colorText: Colors.white);
                        return;
                      }
                      bool success = await pos.submitOrder(isPaid: false);
                      if (success) {
                        Get.offAll(() => const MainNavigationScreen());
                      }
                    },
                    tooltip: "kitchen_print_sidebar".tr,
                  ),
                ),
                const SizedBox(width: 8),
                // Receipt Print
                Expanded(
                  child: _buildActionBtn(Icons.receipt_long_rounded, "Hisob", const Color(0xFF64748B), () {
                    pos.printBillAndExit();
                  }, tooltip: "Hisob chekini chiqarish"),
                ),
                // Pay & Finish (Admin/Cashier only)
                if (pos.isAdmin || pos.isCashier) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionBtn(Icons.payments_rounded, "To`lov", const Color(0xFFFF9500), () async {
                      _showPaymentMethodDialog(pos);
                    }, tooltip: "pay_finish_sidebar".tr),
                  ),
                ],
              ],
            ),
          ],
        );
      }),
    );
  }

  void _showPaymentMethodDialog(POSController pos) {
    final hasDiscount = pos.discountValue.value > 0;
    
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("To'lov usulini tanlang", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Jami: ${NumberFormat("#,###", "uz_UZ").format(pos.total)} ${pos.currencySymbol}", 
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (hasDiscount)
              Text(
                "Chegirma: -${NumberFormat("#,###", "uz_UZ").format(pos.discountAmount)} ${pos.currencySymbol}",
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),
            const SizedBox(height: 20),
            
            // Naqd pul
            _paymentMethodCard(
              icon: Icons.money_rounded,
              label: "Naqd pul",
              color: Colors.green,
              onTap: () => _confirmPayment(pos, "Cash"),
            ),
            const SizedBox(height: 12),
            
            // Karta / Terminal
            _paymentMethodCard(
              icon: Icons.credit_card_rounded,
              label: "Karta / Terminal",
              color: Colors.blue,
              onTap: () => _confirmPayment(pos, "Card"),
            ),
            const SizedBox(height: 12),
            
            // Uzto / Payme (Optional custom)
            _paymentMethodCard(
              icon: Icons.qr_code_scanner_rounded,
              label: "Click / Payme",
              color: const Color(0xFF00BFFF),
              onTap: () => _confirmPayment(pos, "Online"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Bekor qilish")),
        ],
      ),
    );
  }

  Widget _paymentMethodCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPayment(POSController pos, String method) async {
    Get.back(); // Close payment method dialog
    
    // Final confirmation (optional, but good for safety)
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("To'lovni tasdiqlash"),
        content: Text("${method == 'Cash' ? 'Naqd pul' : method == 'Card' ? 'Karta' : 'Online'} orqali to'lov qabul qilindi va buyurtma yakunlansinmi?"),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Yo'q")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9500),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Get.back(); // Close confirm dialog
              bool success = await pos.submitOrder(isPaid: true, paymentMethod: method);
              if (success) {
                Get.offAll(() => MainNavigationScreen());
              }
            },
            child: const Text("Ha, yakunlash"),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog(POSController pos) {
    final TextEditingController ctrl = TextEditingController(
      text: pos.discountValue.value > 0 ? pos.discountValue.value.toStringAsFixed(0) : "",
    );
    String localType = pos.discountType.value;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Chegirma qo'shish", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Type selector
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => localType = "percent"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: localType == "percent" ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: localType == "percent" ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)] : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.percent, size: 16, color: localType == "percent" ? const Color(0xFFFF9500) : Colors.grey),
                            const SizedBox(width: 6),
                            Text("Foiz (%)", style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13,
                              color: localType == "percent" ? const Color(0xFF1A1A1A) : Colors.grey,
                            )),
                          ],
                        ),
                      ),
                    )),
                    Expanded(child: GestureDetector(
                      onTap: () => setState(() => localType = "fixed"),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: localType == "fixed" ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: localType == "fixed" ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)] : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.attach_money, size: 16, color: localType == "fixed" ? const Color(0xFFFF9500) : Colors.grey),
                            const SizedBox(width: 6),
                            Text("Miqdor", style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13,
                              color: localType == "fixed" ? const Color(0xFF1A1A1A) : Colors.grey,
                            )),
                          ],
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFF9500)),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: localType == "percent" ? "Masalan: 10" : "Masalan: 5000",
                  suffixText: localType == "percent" ? "%" : pos.currencySymbol,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFF9500), width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Quick percent presets
              if (localType == "percent")
                Wrap(
                  spacing: 8,
                  children: [5, 10, 15, 20, 25, 50].map((p) => GestureDetector(
                    onTap: () => ctrl.text = p.toString(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF9500).withOpacity(0.3)),
                      ),
                      child: Text("$p%", style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  )).toList(),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                pos.resetDiscount();
                Get.back();
              },
              child: const Text("Bekor qilish", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final val = double.tryParse(ctrl.text.replaceAll(",", ".")) ?? 0.0;
                if (val > 0) {
                  pos.discountType.value = localType;
                  pos.discountValue.value = localType == "percent" ? val.clamp(0.0, 100.0) : val;
                }
                Get.back();
              },
              child: const Text("Qo'llash"),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildActionBtn(IconData icon, String label, Color color, VoidCallback onTap, {String? tooltip}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: tooltip ?? label,
          child: Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label, 
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6B7280)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSumRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSidebarBtn(String label, Color color, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildEmptyCartPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
            child: const Icon(Icons.shopping_cart_outlined, size: 40, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 20),
          Text("current_bill_empty".tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 8),
          Text("empty_cart_msg".tr, 
            textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildMobileCartButton(POSController pos, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
      child: InkWell(
        onTap: () => Get.to(() => const CartScreen()),
        child: Row(
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text("${pos.totalItems} ${'items'.tr}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text("${NumberFormat("#,###", "uz_UZ").format(pos.total)} ${pos.currencySymbol}", 
              style: const TextStyle(color: Color(0xFFFF9500), fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}


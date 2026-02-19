import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../theme/app_colors.dart';
import '../../theme/responsive.dart';
import '../../logic/pos_controller.dart';
import '../../data/models/food_item.dart';
import 'home_screen.dart';
import 'table_selection_screen.dart';
import 'cart_screen.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    final List<FoodItem> catalog = pos.products;
    final bool isMobile = Responsive.isMobile(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text("order_management".tr),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.language),
            onPressed: () => _showLanguageSwitcher(context),
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: "active".tr),
              Tab(text: "history".tr),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => pos.allOrders.refresh(),
            ),
            if (!isMobile) const SizedBox(width: 16),
          ],
        ),
        body: TabBarView(
          children: [
            Obx(() {
              final activeOrders = pos.allOrders.where((o) => o['status'] != "Completed").toList();
              return activeOrders.isEmpty
                  ? _buildEmptyState("no_active_orders".tr, "start_new_sale".tr)
                  : _buildOrdersGrid(activeOrders, pos, catalog, context);
            }),
            Obx(() {
              final completedOrders = pos.allOrders.where((o) => o['status'] == "Completed").toList();
              return completedOrders.isEmpty
                  ? _buildEmptyState("no_completed_orders".tr, "history_empty".tr)
                  : _buildOrdersGrid(completedOrders, pos, catalog, context);
            }),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showOrderTypeDialog(context, pos),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildOrdersGrid(List<Map<String, dynamic>> orders, POSController pos, List<FoodItem> catalog, BuildContext context) {
    final int crossAxisCount = Responsive.isMobile(context) ? 1 : (Responsive.isTablet(context) ? 2 : 3);
    final isMobile = Responsive.isMobile(context);

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 24 : 40, 
        12, 
        isMobile ? 24 : 40, 
        100
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isMobile ? 1.4 : 1.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) => _buildSlidableOrderCard(orders[index], pos, catalog, context),
    );
  }

  void _showLanguageSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Sizning tilingiz / Ваш язык / Your Language", 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildLangItem("O'zbekcha", 'uz', 'UZ'),
            _buildLangItem("English", 'en', 'US'),
            _buildLangItem("Русский", 'ru', 'RU'),
          ],
        ),
      ),
    );
  }

  Widget _buildLangItem(String label, String langCode, String countryCode) {
    return ListTile(
      title: Text(label),
      onTap: () {
        final locale = Locale(langCode, countryCode);
        Get.updateLocale(locale);
        GetStorage().write('lang', '${langCode}_$countryCode');
        Get.back();
      },
      trailing: Get.locale?.languageCode == langCode ? const Icon(Icons.check, color: AppColors.primary) : null,
    );
  }

  Widget _buildSlidableOrderCard(Map<String, dynamic> order, POSController pos, List<FoodItem> catalog, BuildContext context) {
    final bool isActive = order['status'] != "Completed";

    return Slidable(
      key: ValueKey(order['id']),
      startActionPane: isActive ? ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              pos.printOrder(order, receiptTitle: "HISOB CHEKI");
              pos.updateOrderStatus(order['id'], "Bill Printed");
              Get.snackbar("success".tr, "print_receipt".tr, 
                backgroundColor: Colors.orange, colorText: Colors.white);
            },
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            icon: Icons.receipt_long,
            borderRadius: BorderRadius.circular(20),
          ),
          if (pos.isAdmin)
            SlidableAction(
              onPressed: (context) {
                pos.loadOrderForEditing(order, catalog);
                Get.to(() => const CartScreen());
              },
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: Icons.payments_outlined,
              borderRadius: BorderRadius.circular(20),
            ),
        ],
      ) : null,
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          if (isActive) _buildEndAction(order['status'], order, pos, catalog),
          if (pos.isAdmin)
            SlidableAction(
              onPressed: (context) => _confirmDelete(order['id'], pos),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              borderRadius: BorderRadius.circular(20),
            ),
        ],
      ),
      child: _buildOrderCardContent(order, pos, catalog, isActive, context),
    );
  }

  Widget _buildOrderCardContent(Map<String, dynamic> order, POSController pos, List<FoodItem> catalog, bool isActive, BuildContext context) {
    final status = order['status'];
    final mode = order['mode'] ?? "Dine-in";
    String modeLabel = mode.toString().toLowerCase() == "dine-in" ? 'dine_in'.tr : (mode.toString().toLowerCase() == "takeaway" ? 'takeaway'.tr : 'delivery'.tr);
    final details = order['details'] as List? ?? [];
    final bool isMobile = Responsive.isMobile(context);

    return InkWell(
      onTap: () {
        if (status != "Bill Printed") {
          pos.loadOrderForEditing(order, catalog);
          Get.to(() => const HomeScreen());
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Order #${order['id']}", 
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 16 : 18),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (isActive) _buildActionIcon(status, order, pos, catalog),
                        ],
                      ),
                      Text(
                        "${order['table']} • $modeLabel • ${order['items']} ${'items'.tr}", 
                        style: TextStyle(color: AppColors.textSecondary, fontSize: isMobile ? 12 : 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${'total'.tr}: \$${order['total'].toStringAsFixed(2)}", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 16 : 18, color: AppColors.primary)
                ),
                Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.withOpacity(0.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndAction(dynamic status, Map<String, dynamic> order, POSController pos, List<FoodItem> catalog) {
    if (status == "Bill Printed") {
       if (pos.isAdmin) {
         return SlidableAction(
           onPressed: (context) => _confirmUnlock(order['id'], pos),
           backgroundColor: Colors.orange,
           foregroundColor: Colors.white,
           icon: Icons.lock_open,
           borderRadius: BorderRadius.circular(20),
         );
       }
       return const SizedBox.shrink(); 
    } else {
       return SlidableAction(
        onPressed: (context) {
          pos.loadOrderForEditing(order, catalog);
          Get.to(() => const HomeScreen());
        },
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        icon: Icons.edit_outlined,
        borderRadius: BorderRadius.circular(20),
      );
    }
  }

  Widget _buildActionIcon(dynamic status, Map<String, dynamic> order, POSController pos, List<FoodItem> catalog) {
    if (status == "Bill Printed") {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.lock, size: 16, color: Colors.orange.withOpacity(pos.isAdmin ? 1.0 : 0.5)),
      );
    } else {
      return GestureDetector(
        onTap: () {
          pos.loadOrderForEditing(order, catalog);
          Get.to(() => const HomeScreen());
        },
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.add, size: 16, color: AppColors.primary),
        ),
      );
    }
  }

  void _confirmUnlock(int orderId, POSController pos) {
    Get.dialog(
      AlertDialog(
        title: Text("unlock_order".tr),
        content: Text("unlock_order_msg".tr),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("cancel".tr)),
          TextButton(
            onPressed: () {
              pos.updateOrderStatus(orderId, "Pending");
              Get.back();
              Get.snackbar("Success", "Order #$orderId unlocked", backgroundColor: Colors.green, colorText: Colors.white);
            }, 
            child: Text("unlock".tr, style: const TextStyle(color: Colors.orange))
          ),
        ],
      ),
    );
  }

  void _confirmDelete(int orderId, POSController pos) {
    Get.dialog(
      AlertDialog(
        title: Text("delete_confirm_title".tr),
        content: Text("delete_confirm_msg".tr),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("cancel".tr)),
          TextButton(
            onPressed: () {
              pos.deleteOrder(orderId);
              Get.back();
              Get.snackbar("Deleted", "Order #$orderId has been removed", backgroundColor: Colors.red, colorText: Colors.white);
            }, 
            child: Text("delete".tr, style: const TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  void _showOrderTypeDialog(BuildContext context, POSController pos) {
    if (pos.isWaiter) {
      pos.clearCurrentOrder(); 
      pos.setMode("Dine-in");
      Get.to(() => const TableSelectionScreen());
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        constraints: BoxConstraints(maxWidth: Responsive.isMobile(context) ? double.infinity : 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("select_order_type".tr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildModeOption(Icons.restaurant, "Dine-in", pos),
                const SizedBox(width: 16),
                _buildModeOption(Icons.shopping_bag, "Takeaway", pos),
                const SizedBox(width: 16),
                _buildModeOption(Icons.delivery_dining, "Delivery", pos),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(IconData icon, String label, POSController pos) {
    return Expanded(
      child: InkWell(
        onTap: () {
          pos.clearCurrentOrder(); 
          pos.setMode(label);
          Get.back(); 
          if (label == "Dine-in") {
            Get.to(() => const TableSelectionScreen());
          } else {
            Get.to(() => const HomeScreen());
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}


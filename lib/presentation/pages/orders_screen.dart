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
    final RxString selectedFilter = "All".obs;

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
            if (!isMobile)
              Obx(() => IconButton(
                icon: Icon(pos.isOrdersTableView.value ? Icons.grid_view_rounded : Icons.view_list_rounded),
                onPressed: () => pos.toggleOrdersViewMode(),
                tooltip: pos.isOrdersTableView.value ? "Switch to Cards" : "Switch to Table",
              )),
            if (!isMobile) const SizedBox(width: 16),
          ],
        ),
        body: Column(
          children: [
            // Filter Bar
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Obx(() => ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildFilterChip("All", "all".tr, selectedFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip("Dine-in", 'dine_in'.tr, selectedFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip("Takeaway", 'takeaway'.tr, selectedFilter),
                  const SizedBox(width: 8),
                  _buildFilterChip("Delivery", 'delivery'.tr, selectedFilter),
                ],
              )),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Obx(() {
                    var filtered = pos.allOrders.where((o) => o['status'] != "Completed").toList();
                    if (selectedFilter.value != "All") {
                      filtered = filtered.where((o) => o['mode'] == selectedFilter.value).toList();
                    } else {
                      filtered = _sortOrders(filtered);
                    }
                    return filtered.isEmpty
                        ? _buildEmptyState("no_active_orders".tr, "start_new_sale".tr)
                        : (pos.isOrdersTableView.value && !isMobile 
                            ? _buildOrdersTable(filtered, pos, catalog, context)
                            : _buildOrdersGrid(filtered, pos, catalog, context));
                  }),
                  Obx(() {
                    var filtered = pos.allOrders.where((o) => o['status'] == "Completed").toList();
                    if (selectedFilter.value != "All") {
                      filtered = filtered.where((o) => o['mode'] == selectedFilter.value).toList();
                    } else {
                      filtered = _sortOrders(filtered);
                    }
                    return filtered.isEmpty
                        ? _buildEmptyState("no_completed_orders".tr, "history_empty".tr)
                        : (pos.isOrdersTableView.value && !isMobile 
                            ? _buildOrdersTable(filtered, pos, catalog, context)
                            : _buildOrdersGrid(filtered, pos, catalog, context));
                  }),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'orders_fab',
          onPressed: () => _showOrderTypeDialog(context, pos),
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _sortOrders(List<Map<String, dynamic>> orders) {
    final Map<String, int> modePriority = {
      "Dine-in": 0,
      "Takeaway": 1,
      "Delivery": 2,
    };
    
    final sorted = List<Map<String, dynamic>>.from(orders);
    sorted.sort((a, b) {
      int pA = modePriority[a['mode']] ?? 99;
      int pB = modePriority[b['mode']] ?? 99;
      return pA.compareTo(pB);
    });
    return sorted;
  }

  Widget _buildOrdersTable(List<Map<String, dynamic>> orders, POSController pos, List<FoodItem> catalog, BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(AppColors.background),
          dividerThickness: 1,
          columns: [
            DataColumn(label: Text('# ID', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('table'.tr, style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('total'.tr, style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: orders.map((order) {
            final String status = order['status'] ?? "Pending";
            final bool isActive = status != "Completed";
            
            return DataRow(cells: [
              DataCell(Text(order['id'].toString().length > 8 ? order['id'].toString().substring(0, 8) : order['id'].toString())),
              DataCell(Text(order['table'] ?? "—")),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(order['mode'] ?? "Dine-in", style: TextStyle(fontSize: 12, color: AppColors.primary)),
              )),
              DataCell(Text("${order['total'].toStringAsFixed(0)} so'm", style: TextStyle(fontWeight: FontWeight.bold))),
              DataCell(_buildStatusBadge(status)),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      if (status != "Bill Printed") {
                        pos.loadOrderForEditing(order, catalog);
                        Get.to(() => const HomeScreen());
                      }
                    },
                  ),
                  if (isActive) 
                    IconButton(
                      icon: Icon(Icons.receipt_long, color: Colors.orange),
                      onPressed: () {
                        pos.printOrder(order, receiptTitle: "HISOB CHEKI");
                        pos.updateOrderStatus(order['id'], "Bill Printed");
                      },
                    ),
                  if (pos.isAdmin)
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(order['id'], pos),
                    ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    if (status == "Completed") color = Colors.green;
    if (status == "Pending") color = Colors.orange;
    if (status == "Bill Printed") color = Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(status.tr, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFilterChip(String value, String label, RxString selectedFilter) {
    final bool isSelected = selectedFilter.value == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) selectedFilter.value = value;
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade200),
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
        childAspectRatio: isMobile ? 2.8 : 2.1,
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
      enabled: Responsive.isMobile(context),
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
    final bool isMobile = Responsive.isMobile(context);

    return Container(
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
              if (!isMobile)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive) ...[
                      _buildCompactIconButton(
                        onPressed: () {
                          pos.printOrder(order, receiptTitle: "HISOB CHEKI");
                          pos.updateOrderStatus(order['id'], "Bill Printed");
                        },
                        icon: Icons.print_rounded,
                        color: Colors.orange,
                        tooltip: "print_receipt".tr,
                      ),
                      _buildCompactIconButton(
                        onPressed: () {
                          pos.loadOrderForEditing(order, catalog);
                          Get.to(() => const HomeScreen());
                        },
                        icon: Icons.edit_rounded,
                        color: Colors.blue,
                        tooltip: "edit".tr,
                      ),
                    ],
                    if (pos.isAdmin)
                      _buildCompactIconButton(
                        onPressed: () => _confirmDelete(order['id'], pos),
                        icon: Icons.delete_outline_rounded,
                        color: Colors.red,
                        tooltip: "delete".tr,
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactIconButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 18),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        padding: EdgeInsets.zero,
        splashRadius: 20,
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
        padding: const EdgeInsets.all(8), // Increased from 4
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(Icons.lock, size: 20, color: Colors.orange.withOpacity(pos.isAdmin ? 1.0 : 0.5)), // Increased from 16
      );
    } else {
      return GestureDetector(
        onTap: () {
          pos.loadOrderForEditing(order, catalog);
          Get.to(() => const HomeScreen());
        },
        child: Container(
          padding: const EdgeInsets.all(8), // Increased from 4
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.add, size: 20, color: AppColors.primary), // Increased from 16
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


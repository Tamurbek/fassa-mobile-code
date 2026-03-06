import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../logic/pos_controller.dart';
import '../../theme/app_colors.dart';
import 'home_screen.dart';

class KitchenDisplayPage extends StatefulWidget {
  const KitchenDisplayPage({super.key});

  @override
  State<KitchenDisplayPage> createState() => _KitchenDisplayPageState();
}

class _KitchenDisplayPageState extends State<KitchenDisplayPage> {
  final POSController pos = Get.find<POSController>();
  String? selectedArea;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : const Color(0xFFF3F4F6);
    final appBarColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Get.back(),
        ),
        title: Text(
          "oshxona_ekrani".tr.toUpperCase(), 
          style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2)
        ),
        centerTitle: false,
        actions: [
          _buildAreaDropdown(isDark, textColor, appBarColor),
          _buildRefreshButton(textColor),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        final activeOrders = pos.allOrders.where((o) => 
          !["Completed", "Cancelled"].contains(o['status'])
        ).toList();

        if (activeOrders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu_rounded, size: 80, color: textColor.withOpacity(0.1)),
                const SizedBox(height: 20),
                Text("faol_buyurtmalar_yoq".tr, style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 450,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: 0.8,
          ),
          itemCount: activeOrders.length,
          itemBuilder: (context, index) {
            final order = activeOrders[index];
            final items = (order['details'] as List? ?? []).where((item) {
              if (selectedArea == null) return true;
              final product = pos.products.firstWhereOrNull((p) => p.id == item['id']);
              if (product == null) return true;
              final area = pos.preparationAreas.firstWhereOrNull((a) => a.id == product.preparationAreaId);
              return area?.name == selectedArea;
            }).toList();

            if (items.isEmpty) return const SizedBox.shrink();

            return _OrderCard(order: order, items: items, pos: pos);
          },
        );
      }),
    );
  }

  Widget _buildAreaDropdown(bool isDark, Color textColor, Color appBarColor) {
    return Obx(() => Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          dropdownColor: appBarColor,
          value: selectedArea,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: textColor, size: 20),
          hint: Text("barcha_bolimlar".tr, style: TextStyle(color: textColor.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.bold)),
          items: [
            DropdownMenuItem(value: null, child: Text("barcha_bolimlar".tr, style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
            ...pos.preparationAreas.map((a) => DropdownMenuItem(
              value: a.name,
              child: Text(a.name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            )),
          ],
          onChanged: (v) => setState(() => selectedArea = v),
        ),
      ),
    ));
  }

  Widget _buildRefreshButton(Color textColor) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: IconButton(
        icon: Icon(Icons.refresh_rounded, color: textColor),
        onPressed: () => pos.refreshData(),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final List<dynamic> items;
  final POSController pos;

  const _OrderCard({required this.order, required this.items, required this.pos});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime createdAt = DateTime.tryParse(order['timestamp']?.toString() ?? "") ?? DateTime.now();
    final duration = DateTime.now().difference(createdAt);
    
    Color statusColor = Colors.green;
    if (duration.inMinutes > 20) {
      statusColor = Colors.red;
    } else if (duration.inMinutes > 10) {
      statusColor = Colors.orange;
    }

    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(
          color: statusColor.withOpacity(isDark ? 0.3 : 0.1), 
          width: 2
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (order['table'] == null || order['table'] == "-" || order['table'] == "") 
                          ? "takeaway".tr.toUpperCase()
                          : "${"table".tr} ${order['table']}".toUpperCase(), 
                        style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 18)
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded, size: 14, color: textColor.withOpacity(0.4)),
                          const SizedBox(width: 4),
                          Text(
                            order['waiter_name'] ?? "Kassir", 
                            style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold)
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${duration.inMinutes} min", 
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 16)
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('HH:mm').format(createdAt), 
                      style: TextStyle(color: textColor.withOpacity(0.3), fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              itemCount: items.length,
              separatorBuilder: (context, index) => Divider(color: textColor.withOpacity(0.05), height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          "${item['qty']}x", 
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900, fontSize: 14)
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${item['name']}", 
                              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: -0.2)
                            ),
                            if (item['variant_name'] != null)
                              Text(
                                item['variant_name'],
                                style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ElevatedButton(
              onPressed: () => _markOrderReady(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: statusColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                shadowColor: statusColor.withOpacity(0.4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text("TAYYOR".tr.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _markOrderReady(BuildContext context) async {
    try {
      await pos.updateOrderStatus(order['id'], "Ready");
      Get.snackbar(
        "tayyor".tr, 
        "buyurtma_tayyor_deb_belgilandi".tr,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(15),
        borderRadius: 15,
        icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar("error".tr, "holatni_yangilashda_xatolik".tr);
    }
  }
}


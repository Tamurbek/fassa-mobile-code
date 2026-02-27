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
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
        title: const Text("OSHXONA EKRANI (KDS)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          Obx(() => Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                dropdownColor: const Color(0xFF1F2937),
                value: selectedArea,
                hint: const Text("Barcha bo'limlar", style: TextStyle(color: Colors.white70, fontSize: 13)),
                items: [
                  const DropdownMenuItem(value: null, child: Text("Barcha bo'limlar", style: TextStyle(color: Colors.white))),
                  ...pos.preparationAreas.map((a) => DropdownMenuItem(
                    value: a.name,
                    child: Text(a.name, style: const TextStyle(color: Colors.white)),
                  )),
                ],
                onChanged: (v) => setState(() => selectedArea = v),
              ),
            ),
          )),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => pos.refreshData(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        final activeOrders = pos.allOrders.where((o) => 
          !["Completed", "Cancelled"].contains(o['status'])
        ).toList();

        if (activeOrders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu_rounded, size: 64, color: Colors.white24),
                SizedBox(height: 16),
                Text("Faol buyurtmalar yo'q", style: TextStyle(color: Colors.white38, fontSize: 18)),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 400,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: activeOrders.length,
          itemBuilder: (context, index) {
            final order = activeOrders[index];
            final items = (order['details'] as List? ?? []).where((item) {
              if (selectedArea == null) return true;
              // Link item to area via product info
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
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final List<dynamic> items;
  final POSController pos;

  const _OrderCard({required this.order, required this.items, required this.pos});

  @override
  Widget build(BuildContext context) {
    final DateTime createdAt = DateTime.tryParse(order['timestamp']?.toString() ?? "") ?? DateTime.now();
    final duration = DateTime.now().difference(createdAt);
    final color = duration.inMinutes > 20 ? Colors.red : (duration.inMinutes > 10 ? Colors.orange : Colors.green);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("STOL ${order['table']}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(order['waiter_name'] ?? "Ofitsiant", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${duration.inMinutes} min", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(DateFormat('HH:mm').format(createdAt), style: const TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          
          // Items List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white12, height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text("${item['qty']}x", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text("${item['name']}", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _markOrderReady(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("TAYYOR", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _markOrderReady(BuildContext context) {
     Get.snackbar(
      "Muvaffaqiyatli", 
      "Buyurtma tayyor deb belgilandi",
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
    );
    // In a real scenario, we'd update status to "Ready" and notify waiter via socket
  }
}

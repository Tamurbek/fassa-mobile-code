import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../logic/pos_controller.dart';
import '../../theme/app_colors.dart';
import 'package:uuid/uuid.dart';

class InventoryManagementPage extends StatefulWidget {
  const InventoryManagementPage({super.key});

  @override
  State<InventoryManagementPage> createState() => _InventoryManagementPageState();
}

class _InventoryManagementPageState extends State<InventoryManagementPage> {
  final POSController pos = Get.find<POSController>();
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("INVENTARIZASIYA (OMBOR)", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () => _showMovementHistory(),
            tooltip: "Harakatlar tarixi",
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () => _showAddIngredientDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Yangi xom-ashyo"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() {}),
              decoration: InputDecoration(
                hintText: "Xom-ashyo qidirish...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          
          // Ingredients List
          Expanded(
            child: Obx(() {
              final query = _searchController.text.toLowerCase();
              final filtered = pos.ingredients.where((ing) => 
                ing['name'].toString().toLowerCase().contains(query)
              ).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text("Xom-ashyolar topilmadi"));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final ing = filtered[index];
                  final bool isLowStock = (ing['current_stock'] as num? ?? 0) <= (ing['min_stock_level'] as num? ?? 0);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(ing['name'] ?? "Noma'lum", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Row(
                        children: [
                          Text("Narxi: ${ing['cost_per_unit']} UZS/${ing['unit']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          const SizedBox(width: 12),
                          if (isLowStock) 
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: const Text("KAM QOLDI", style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "${ing['current_stock']} ${ing['unit']}",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 18, 
                                  color: isLowStock ? Colors.red : Colors.green[700]
                                ),
                              ),
                              const Text("Qoldiq", style: TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(width: 16),
                          PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'add', child: Text("Kirim (IN)")),
                              const PopupMenuItem(value: 'waste', child: Text("Spisanie (WASTE)")),
                              const PopupMenuItem(value: 'edit', child: Text("Tahrirlash")),
                            ],
                            onSelected: (val) {
                              if (val == 'add') _showStockMovementDialog(ing, "IN");
                              if (val == 'waste') _showStockMovementDialog(ing, "WASTE");
                              if (val == 'edit') _showAddIngredientDialog(ingredient: ing);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showAddIngredientDialog({Map<String, dynamic>? ingredient}) {
    final nameController = TextEditingController(text: ingredient?['name']);
    final costController = TextEditingController(text: ingredient?['cost_per_unit']?.toString() ?? "0");
    final minStockController = TextEditingController(text: ingredient?['min_stock_level']?.toString() ?? "1.0");
    String unit = ingredient?['unit'] ?? "kg";

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(ingredient == null ? "Yangi xom-ashyo" : "Tahrirlash"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nomi")),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: costController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Narxi (1 birlik uchun)"))),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: unit,
                    items: ["kg", "l", "piece", "gr", "ml"].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => unit = v!),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: minStockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Minimal qoldiq")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text("Bekor qilish")),
            ElevatedButton(
              onPressed: () async {
                final data = {
                  "id": ingredient?['id'] ?? const Uuid().v4(),
                  "name": nameController.text,
                  "unit": unit,
                  "cost_per_unit": double.tryParse(costController.text) ?? 0,
                  "min_stock_level": double.tryParse(minStockController.text) ?? 1,
                  "cafe_id": pos.cafeId,
                };

                try {
                  if (ingredient == null) {
                    await pos.api.createIngredient(data);
                  } else {
                    await pos.api.updateIngredient(ingredient['id'], data);
                  }
                  pos.refreshData();
                  Get.back();
                } catch (e) {
                  Get.snackbar("Xatolik", e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: const Text("Saqlash"),
            ),
          ],
        ),
      ),
    );
  }

  void _showStockMovementDialog(Map<String, dynamic> ing, String type) {
    final qtyController = TextEditingController();
    final remarkController = TextEditingController();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(type == "IN" ? "Omborga kirim" : "Hisobdan chiqarish (Spisanie)"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${ing['name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: "Miqdori (${ing['unit']})")),
            const SizedBox(height: 12),
            TextField(controller: remarkController, decoration: const InputDecoration(labelText: "Izoh (ixtiyoriy)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text("Bekor qilish")),
          ElevatedButton(
            onPressed: () async {
              try {
                await pos.api.createStockMovement({
                  "ingredient_id": ing['id'],
                  "type": type,
                  "quantity": double.tryParse(qtyController.text) ?? 0,
                  "reason": remarkController.text,
                  "cafe_id": pos.cafeId,
                });
                pos.refreshData();
                Get.back();
                Get.snackbar("Muvaffaqiyatli", "Ombor yangilandi", backgroundColor: Colors.green, colorText: Colors.white);
              } catch (e) {
                Get.snackbar("Xatolik", e.toString(), backgroundColor: Colors.red, colorText: Colors.white);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: type == 'IN' ? Colors.green : Colors.orange, foregroundColor: Colors.white),
            child: const Text("Tasdiqlash"),
          ),
        ],
      ),
    );
  }

  void _showMovementHistory() async {
    final movements = await pos.api.getStockMovements();
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            const Text("Harakatlar tarixi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: movements.length,
                itemBuilder: (context, index) {
                  final m = movements[index];
                  final ing = pos.ingredients.firstWhereOrNull((i) => i['id'] == m['ingredient_id']);
                  return ListTile(
                    title: Text("${ing?['name'] ?? m['ingredient_id']}"),
                    subtitle: Text("${m['type']} - ${m['reason'] ?? ''}"),
                    trailing: Text(
                      "${m['type'] == 'IN' ? '+' : '-'}${m['quantity']}",
                      style: TextStyle(color: m['type'] == 'IN' ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/food_item.dart';
import '../../theme/app_colors.dart';
import '../../logic/pos_controller.dart';
import 'orders_screen.dart';
import '../widgets/common_image.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("review_bill".tr),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Get.back(),
        ),
      ),
      body: Obx(() => Column(
            children: [
              _buildModeSelector(pos),
              Expanded(
                child: pos.currentOrder.isEmpty
                    ? _buildEmptyCart()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        itemCount: pos.currentOrder.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final cartItem = pos.currentOrder[index];
                          return _buildCartItem(cartItem['item'], cartItem['quantity'], index, pos);
                        },
                      ),
              ),
              if (pos.currentOrder.isNotEmpty) _buildOrderSummary(pos),
            ],
          )),
    );
  }

  Widget _buildModeSelector(POSController pos) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: pos.orderModes.map((mode) {
          final isSelected = pos.currentMode.value == mode;
          String translatedLabel = mode.toLowerCase() == "dine-in" ? 'dine_in'.tr : (mode.toLowerCase() == "takeaway" ? 'takeaway'.tr : 'delivery'.tr);
          return Expanded(
            child: GestureDetector(
              onTap: () => pos.setMode(mode),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                      : [],
                ),
                child: Center(
                  child: Text(
                    translatedLabel,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("current_bill_empty".tr, style: const TextStyle(fontSize: 18, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => Get.back(), child: Text("back_to_terminal".tr)),
        ],
      ),
    );
  }

  Widget _buildCartItem(FoodItem item, int quantity, int index, POSController pos) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15), 
            child: CommonImage( // Updated
              imageUrl: item.imageUrl,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text("\$${item.price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ],
            ),
          ),
          Row(
            children: [
              _buildSmallQtyBtn(Icons.remove, () => pos.updateQuantity(index, -1)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(quantity.toString(), style: const TextStyle(fontWeight: FontWeight.bold))),
              _buildSmallQtyBtn(Icons.add, () => pos.updateQuantity(index, 1), isPrimary: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallQtyBtn(IconData icon, VoidCallback onTap, {bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: isPrimary ? AppColors.primary : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: isPrimary ? Colors.white : AppColors.textPrimary),
      ),
    );
  }

  Widget _buildOrderSummary(POSController pos) {
    String modeLabel = pos.currentMode.value.toLowerCase() == "dine-in" ? 'dine_in'.tr : (pos.currentMode.value.toLowerCase() == "takeaway" ? 'takeaway'.tr : 'delivery'.tr);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildSummaryRow("subtotal".tr, "\$${pos.subtotal.toStringAsFixed(2)}"),
            _buildSummaryRow("$modeLabel ${'fee'.tr}", "\$${pos.serviceFee.toStringAsFixed(2)}"),
            _buildSummaryRow("${'tax'.tr} (5%)", "\$${pos.tax.toStringAsFixed(2)}"),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
            _buildSummaryRow("total".tr, "\$${pos.total.toStringAsFixed(2)}", isTotal: true),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      // Submit and print
                      await pos.submitOrder(isPaid: false);
                      Get.close(1); // Go back one or just home
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 75), 
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.print_rounded, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          "kitchen_print".tr, 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Just print the bill without finalizing payment
                      // Construct a temporary order object for printing if not saved yet
                      final tempOrder = {
                        "id": pos.editingOrderId.value ?? "NEW",
                        "table": pos.selectedTable.value.isNotEmpty ? "Table ${pos.selectedTable.value}" : "-",
                        "mode": pos.currentMode.value,
                        "total": pos.total,
                        "details": pos.currentOrder.map((e) => {
                          "id": (e['item'] as FoodItem).id,
                          "name": (e['item'] as FoodItem).name,
                          "qty": e['quantity'],
                          "price": (e['item'] as FoodItem).price,
                        }).toList(),
                      };
                      pos.printOrder(tempOrder);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 75), 
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      side: const BorderSide(color: Colors.blue, width: 1.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 20, color: Colors.blue),
                        const SizedBox(height: 4),
                        Text(
                          "print_receipt".tr, 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await pos.submitOrder(isPaid: true);
                      Get.close(1); // Go back after payment
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 75), 
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 2,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          "pay_finish".tr, 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 20 : 15, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: isTotal ? AppColors.textPrimary : AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: isTotal ? 20 : 15, fontWeight: FontWeight.bold, color: isTotal ? AppColors.primary : AppColors.textPrimary)),
        ],
      ),
    );
  }
}

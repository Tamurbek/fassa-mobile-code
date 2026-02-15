import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/food_item.dart';
import '../../theme/app_colors.dart';
import '../../logic/pos_controller.dart';
import '../widgets/common_image.dart';

class FoodDetailScreen extends StatelessWidget {
  final FoodItem item;
  const FoodDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    var quantity = 1.obs;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Hero(
              tag: 'food-image-${item.id}',
              child: CommonImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildRoundButton(icon: Icons.arrow_back_ios_new, onTap: () => Get.back()),
                  _buildRoundButton(icon: Icons.favorite_border, iconColor: Colors.red, onTap: () {}),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              width: double.infinity,
              decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(36))),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 8),
                              Row(children: [const Icon(Icons.star, color: Colors.amber, size: 20), const SizedBox(width: 4), Text(item.rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
                            ],
                          ),
                        ),
                        Text("\$${item.price.toStringAsFixed(2)}", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text("Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    Text("${item.description}. Premium quality ingredients prepared for our POS terminal.", style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5)),
                    const SizedBox(height: 32),
                    const Text("Quantity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildQuantityButton(icon: Icons.remove, onTap: () { if (quantity.value > 1) quantity.value--; }),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Obx(() => Text(quantity.value.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
                        _buildQuantityButton(icon: Icons.add, onTap: () => quantity.value++, isPrimary: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 24,
            right: 24,
            child: ElevatedButton(
              onPressed: () {
                final pos = Get.find<POSController>();
                for (int i = 0; i < quantity.value; i++) {
                  pos.addToCart(item);
                }
                Get.back();
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 65), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long),
                  const SizedBox(width: 12),
                  const Text("Add to Bill", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Obx(() => Text("\$${(item.price * quantity.value).toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoundButton({required IconData icon, Color? iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]), child: Icon(icon, color: iconColor ?? AppColors.textPrimary, size: 20)),
    );
  }

  Widget _buildQuantityButton({required IconData icon, required VoidCallback onTap, bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isPrimary ? AppColors.primary : AppColors.white, borderRadius: BorderRadius.circular(10), border: isPrimary ? null : Border.all(color: Colors.grey.shade300)), child: Icon(icon, color: isPrimary ? AppColors.white : AppColors.textPrimary, size: 20)),
    );
  }
}

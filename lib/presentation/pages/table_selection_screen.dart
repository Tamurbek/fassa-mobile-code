import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../logic/pos_controller.dart';
import 'home_screen.dart';

class TableSelectionScreen extends StatelessWidget {
  const TableSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();
    
    // Total 12 tables for demonstration
    final List<String> tables = List.generate(12, (index) => (index + 1).toString().padLeft(2, '0'));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Select Table"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                 _StatusIndicator(color: Colors.green, label: "Available"),
                 _StatusIndicator(color: Colors.red, label: "Occupied"),
                 _StatusIndicator(color: AppColors.primary, label: "Selected"),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: tables.length,
              itemBuilder: (context, index) {
                final tableNum = tables[index];
                // Mock: tables 3 and 7 are occupied
                final bool isOccupied = tableNum == "03" || tableNum == "07";
                
                return GestureDetector(
                  onTap: isOccupied ? null : () {
                    pos.setTable(tableNum);
                    Get.to(() => const HomeScreen());
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isOccupied ? Colors.red.withOpacity(0.1) : AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isOccupied ? Colors.red.withOpacity(0.3) : Colors.grey.shade200,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.table_restaurant, 
                          color: isOccupied ? Colors.red : AppColors.primary,
                          size: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "T-$tableNum",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isOccupied ? Colors.red : AppColors.textPrimary,
                          ),
                        ),
                        if (isOccupied)
                          const Text(
                            "In Use",
                            style: TextStyle(fontSize: 10, color: Colors.red),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              "Please select an available table to proceed with the dine-in order.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusIndicator({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

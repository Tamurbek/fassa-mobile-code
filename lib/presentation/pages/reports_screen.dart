import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/responsive.dart';
import '../../logic/pos_controller.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("reports".tr),
        centerTitle: true,
      ),
      body: Obx(() {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final todayOrders = pos.allOrders.where((o) => (o['timestamp'] ?? '').startsWith(today)).toList();
        
        double todayRevenue = todayOrders.fold(0, (sum, o) => sum + (o['total'] as double));
        int orderCount = todayOrders.length;
        double avgBill = orderCount > 0 ? todayRevenue / orderCount : 0.0;
        double totalRevenue = pos.allOrders.fold(0, (sum, o) => sum + (o['total'] as double));

        Map<String, int> itemSales = {};
        Map<String, double> itemRevenue = {};
        
        for (var order in pos.allOrders) {
          final details = order['details'] as List? ?? [];
          for (var item in details) {
            String name = item['name'] ?? 'Unknown';
            int qty = item['qty'] ?? 0;
            double price = item['price'] ?? 0.0;
            
            itemSales[name] = (itemSales[name] ?? 0) + qty;
            itemRevenue[name] = (itemRevenue[name] ?? 0.0) + (qty * price);
          }
        }

        var sortedItems = itemSales.keys.toList()
          ..sort((a, b) => itemSales[b]!.compareTo(itemSales[a]!));
        
        final topSelling = sortedItems.take(5).map((name) => {
          "name": name,
          "sales": itemSales[name].toString(),
          "revenue": "\$${itemRevenue[name]!.toStringAsFixed(2)}"
        }).toList();

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.isMobile(context) ? double.infinity : 1000
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(Responsive.isMobile(context) ? 24 : 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("sales_analytics".tr, style: TextStyle(fontSize: Responsive.isMobile(context) ? 22 : 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildStatsGrid(todayRevenue, orderCount, avgBill, totalRevenue, context),
                  const SizedBox(height: 32),
                  Text("top_selling".tr, style: TextStyle(fontSize: Responsive.isMobile(context) ? 18 : 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildTopSellingList(topSelling, context),
                  const SizedBox(height: 32),
                  _buildSessionAction(context),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStatsGrid(double todayRevenue, int orderCount, double avgBill, double totalRevenue, BuildContext context) {
    final int crossAxisCount = Responsive.isMobile(context) ? 2 : 4;
    
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard("today_revenue".tr, "\$${todayRevenue.toStringAsFixed(2)}", Icons.payments, Colors.green),
        _buildStatCard("order_count".tr, orderCount.toString(), Icons.shopping_cart, Colors.blue),
        _buildStatCard("average_bill".tr, "\$${avgBill.toStringAsFixed(2)}", Icons.analytics, Colors.orange),
        _buildStatCard("total_sales".tr, "\$${totalRevenue.toStringAsFixed(2)}", Icons.show_chart, Colors.purple),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 20),
              const Icon(Icons.trending_up, color: Colors.green, size: 16),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingList(List<Map<String, String>> items, BuildContext context) {
    if (items.isEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text("no_data".tr),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = items[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            title: Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${item['sales']} items sold", style: const TextStyle(fontSize: 12)),
            trailing: Text(item['revenue']!, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          );
        },
      ),
    );
  }

  Widget _buildSessionAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("active_session".tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("Started: ${DateFormat('hh:mm a').format(DateTime.now())}", style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.isMobile(context) ? 16 : 32,
                vertical: 12
              )
            ),
            child: Text("close_register".tr),
          ),
        ],
      ),
    );
  }
}


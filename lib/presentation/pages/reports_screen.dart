import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/app_colors.dart';
import '../../theme/responsive.dart';
import '../../logic/pos_controller.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text("reports".tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Color(0xFF1A1A1A))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E5ED)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF6B7280)),
                const SizedBox(width: 8),
                Text(
                  "${"today".tr}, ${DateFormat('d-MMMM', Get.locale?.toString()).format(DateTime.now())}",
                  style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 24),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E5ED)),
            ),
            child: const Icon(Icons.file_download_outlined, color: Color(0xFF6B7280)),
          ),
        ],
      ),
      body: Obx(() {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final todayOrders = pos.allOrders.where((o) => (o['timestamp'] ?? '').startsWith(today)).toList();
        
        double todayRevenue = todayOrders.fold(0, (sum, o) => sum + (o['total'] as double));
        int orderCount = todayOrders.length;
        double avgBill = orderCount > 0 ? todayRevenue / orderCount : 0.0;
        double totalRevenue = pos.allOrders.fold(0, (sum, o) => sum + (o['total'] as double));

        Map<String, Map<String, dynamic>> itemStats = {};
        
        for (var order in pos.allOrders) {
          final details = order['details'] as List? ?? [];
          for (var item in details) {
            String name = item['name'] ?? 'Unknown';
            int qty = item['qty'] ?? 0;
            double price = item['price'] ?? 0.0;
            
            if (!itemStats.containsKey(name)) {
              itemStats[name] = {
                "name": name,
                "sales": 0,
                "revenue": 0.0,
                "category": "Kategoriya"
              };
              // Try to find category from products list
              final product = pos.products.firstWhereOrNull((p) => p.name == name);
              if (product != null) {
                itemStats[name]!["category"] = product.category;
              }
            }
            
            itemStats[name]!["sales"] = (itemStats[name]!["sales"] as int) + qty;
            itemStats[name]!["revenue"] = (itemStats[name]!["revenue"] as double) + (qty * price);
          }
        }

        var sortedItems = itemStats.values.toList()
          ..sort((a, b) => (b['sales'] as int).compareTo(a['sales'] as int));
        
        final topSelling = sortedItems.take(5).toList();

        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("sales_analytics".tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                        Text("${"last_update".tr}: ${DateFormat('HH:mm').format(DateTime.now())}", style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildStatsRow(todayRevenue, orderCount, avgBill, totalRevenue, context),
                    const SizedBox(height: 40),
                    Text("top_selling".tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 16),
                    _buildTopSellingTable(topSelling),
                  ],
                ),
              ),
            ),
            _buildStickyFooter(context),
          ],
        );
      }),
    );
  }

  Widget _buildStatsRow(double todayRevenue, int orderCount, double avgBill, double totalRevenue, BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = (constraints.maxWidth - (3 * 20)) / 4;
        return Wrap(
          spacing: 20,
          runSpacing: 20,
          children: [
            _buildStatCard("today_revenue".tr, todayRevenue, Get.find<POSController>().currencySymbol, 12.5, Colors.orange, cardWidth),
            _buildStatCard("order_count".tr, orderCount.toDouble(), "items".tr, 5.2, Colors.blue, cardWidth, isInteger: true),
            _buildStatCard("average_bill".tr, avgBill, Get.find<POSController>().currencySymbol, 2.1, Colors.green, cardWidth),
            _buildStatCard("total_sales".tr, totalRevenue, Get.find<POSController>().currencySymbol, 8.4, Colors.red, cardWidth),
          ],
        );
      }
    );
  }

  Widget _buildStatCard(String title, double value, String unit, double percent, Color color, double width, {bool isInteger = false}) {
    final formatter = NumberFormat("#,###", "uz_UZ");
    return Container(
      width: width < 220 ? double.infinity : width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text("$percent%", style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isInteger ? value.toInt().toString() : formatter.format(value),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
          ),
          Text(unit, style: const TextStyle(fontSize: 18, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          SizedBox(
            height: 40,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: 6, minY: 0, maxY: 6,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3), FlSpot(1, 2), FlSpot(2, 4), FlSpot(3, 2.5), FlSpot(4, 5), FlSpot(5, 3.5), FlSpot(6, 4.5),
                    ],
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: color.withOpacity(0.05)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSellingTable(List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE0E5ED)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text("product_name_header".tr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF)))),
                Expanded(flex: 2, child: Text("category_header".tr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF)))),
                Expanded(flex: 2, child: Text("sold_header".tr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF)))),
                Expanded(flex: 2, child: Text("revenue_header".tr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF)))),
                SizedBox(width: 40, child: Text("trend_header".tr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF)))),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE0E5ED)),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFEDF0F5)),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.fastfood_outlined, color: Color(0xFF9CA3AF)),
                          ),
                          const SizedBox(width: 16),
                          Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                    ),
                    Expanded(flex: 2, child: Text(item['category'] as String, style: const TextStyle(color: Color(0xFF6B7280)))),
                    Expanded(flex: 2, child: Text("${item['sales']} ${"piece".tr}", style: const TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text("${NumberFormat("#,###", "uz_UZ").format(item['revenue'])} ${Get.find<POSController>().currencySymbol}", style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(
                      width: 40,
                      child: Icon(Icons.trending_up, color: Colors.green, size: 20),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStickyFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("active_session_header".tr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
              Text("${"last_update".tr}: 08:00 (6s 30m)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("cash_status_header".tr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF), letterSpacing: 0.5)),
              Text("1,840,000 ${Get.find<POSController>().currencySymbol} ${"cash_label".tr}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(width: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.logout_rounded),
            label: Text("close_register".tr, style: const TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9500),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}


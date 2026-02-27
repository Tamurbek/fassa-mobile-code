import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../logic/pos_controller.dart';
import '../../logic/services/report_generator.dart';

class WaiterPerformancePage extends StatefulWidget {
  const WaiterPerformancePage({super.key});

  @override
  State<WaiterPerformancePage> createState() => _WaiterPerformancePageState();
}

class _WaiterPerformancePageState extends State<WaiterPerformancePage> {
  String _period = 'today'; // 'today' | 'week' | 'all'
  bool _exporting = false;

  static const _periodLabels = {
    'today': 'Bugun',
    'week': 'Bu hafta',
    'all': 'Hammasi',
  };

  // ── Helpers ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _filteredOrders(POSController pos) {
    final now = DateTime.now();
    return pos.allOrders.where((o) {
      final ts = o['timestamp'];
      if (ts == null) return false;
      try {
        final dt = DateTime.parse(ts.toString());
        if (_period == 'today') {
          return dt.year == now.year && dt.month == now.month && dt.day == now.day;
        } else if (_period == 'week') {
          final weekAgo = now.subtract(const Duration(days: 7));
          return dt.isAfter(weekAgo);
        }
        return true;
      } catch (_) { return false; }
    }).toList();
  }

  List<Map<String, dynamic>> _buildStats(List<Map<String, dynamic>> orders) {
    final Map<String, Map<String, dynamic>> map = {};
    for (var o in orders) {
      final name = (o['waiter_name'] ?? 'Noma\'lum').toString();
      final total = (o['total'] as num? ?? 0).toDouble();
      if (!map.containsKey(name)) {
        map[name] = {'name': name, 'orders': 0, 'revenue': 0.0};
      }
      map[name]!['orders'] = (map[name]!['orders'] as int) + 1;
      map[name]!['revenue'] = (map[name]!['revenue'] as double) + total;
    }
    final list = map.values.map((w) {
      final int cnt = w['orders'] as int;
      final double rev = w['revenue'] as double;
      return {...w, 'avg_bill': cnt > 0 ? rev / cnt : 0.0};
    }).toList();
    list.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    return list;
  }

  Color _medalColor(int rank) {
    if (rank == 0) return const Color(0xFFFFD700); // gold
    if (rank == 1) return const Color(0xFFC0C0C0); // silver
    if (rank == 2) return const Color(0xFFCD7F32); // bronze
    return const Color(0xFFE5E7EB);
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final pos = Get.find<POSController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Ofitsiantlar unumdorligi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Color(0xFF1A1A1A)),
        ),
        centerTitle: false,
        actions: [
          // Export PDF
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: _exporting
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
              : IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF6B7280)),
                  tooltip: 'PDF sifatida ulashish',
                  onPressed: () => _exportPdf(pos),
                ),
          ),
        ],
      ),

      body: Obx(() {
        final orders = _filteredOrders(pos);
        final stats = _buildStats(orders);
        final currency = pos.currencySymbol;
        final fmt = NumberFormat('#,###', 'uz_UZ');

        final double totalRevenue = stats.fold(0.0, (s, w) => s + (w['revenue'] as double));
        final int totalOrders = orders.length;

        return Column(
          children: [
            // ── Period selector ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: _periodLabels.entries.map((e) {
                    final sel = _period == e.key;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _period = e.key),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? const Color(0xFFFF9500) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            e.value,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: sel ? Colors.white : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // ── Summary bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                children: [
                  _summaryChip(Icons.people_outline, '${stats.length} ta ofitsiant', Colors.blue),
                  const SizedBox(width: 12),
                  _summaryChip(Icons.receipt_long_outlined, '$totalOrders ta buyurtma', Colors.orange),
                  const SizedBox(width: 12),
                  _summaryChip(Icons.attach_money, '${fmt.format(totalRevenue)} $currency', Colors.green),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Waiter list ──────────────────────────────────────────────
            Expanded(
              child: stats.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: stats.length,
                    itemBuilder: (context, i) => _buildWaiterCard(
                      waiter: stats[i],
                      rank: i,
                      currency: currency,
                      maxRevenue: stats.first['revenue'] as double,
                      fmt: fmt,
                    ),
                  ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildWaiterCard({
    required Map<String, dynamic> waiter,
    required int rank,
    required String currency,
    required double maxRevenue,
    required NumberFormat fmt,
  }) {
    final revenue = waiter['revenue'] as double;
    final orders = waiter['orders'] as int;
    final avgBill = waiter['avg_bill'] as double;
    final progress = maxRevenue > 0 ? revenue / maxRevenue : 0.0;
    final medal = _medalColor(rank);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
        border: rank == 0
          ? Border.all(color: const Color(0xFFFFD700).withOpacity(0.5), width: 1.5)
          : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Rank badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: medal.withOpacity(0.15), shape: BoxShape.circle),
                child: Center(
                  child: rank < 3
                    ? Text(['🥇', '🥈', '🥉'][rank], style: const TextStyle(fontSize: 20))
                    : Text('${rank + 1}', style: TextStyle(fontWeight: FontWeight.bold, color: medal, fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),

              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiter['name'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1A1A1A)),
                    ),
                    Text(
                      '$orders ta buyurtma',
                      style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Revenue
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${fmt.format(revenue)} $currency',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFFF9500)),
                  ),
                  Text(
                    "O'rtacha: ${fmt.format(avgBill)} $currency",
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFFF3F4F6),
              valueColor: AlwaysStoppedAnimation<Color>(
                rank == 0 ? const Color(0xFFFFD700) :
                rank == 1 ? const Color(0xFF94A3B8) :
                rank == 2 ? const Color(0xFFCD7F32) :
                const Color(0xFF4318FF),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Stats row
          Row(
            children: [
              _miniStat(Icons.shopping_bag_outlined, '$orders buyurtma', Colors.blue),
              const SizedBox(width: 12),
              _miniStat(Icons.receipt_outlined, '${fmt.format(avgBill)} $currency o\'rtacha', Colors.purple),
              const SizedBox(width: 12),
              _miniStat(Icons.percent, '${(progress * 100).toStringAsFixed(0)}% ulush', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _summaryChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Color(0xFFF3F4F6), shape: BoxShape.circle),
            child: const Icon(Icons.people_outline, size: 40, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 16),
          Text(
            _period == 'today' ? 'Bugun hali buyurtma yo\'q' : 'Buyurtmalar topilmadi',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 8),
          Text(
            'Boshqa davr tanlang',
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf(POSController pos) async {
    setState(() => _exporting = true);
    try {
      final orders = _filteredOrders(pos);
      final periodLabel = _periodLabels[_period] ?? '';
      
      // Try to find Receipt Printer for Direct ESC/POS printing
      final receiptPrinters = pos.printers.where((p) => p.isActive && (p.printReceipts || p.printPayments)).toList();
      
      if (receiptPrinters.isNotEmpty) {
        bool anySuccess = false;
        for (var p in receiptPrinters) {
          final ok = await pos.printerService.printWaiterPerformanceReport(p, orders, periodLabel);
          if (ok) anySuccess = true;
        }
        if (anySuccess) {
          Get.snackbar('Muvaffaqiyat', 'Hisobot printerga yuborildi', 
              backgroundColor: Colors.green, colorText: Colors.white);
          return;
        }
      }

      // Fallback: Generate PDF
      final pdf = await ReportGenerator.generateWaiterPerformanceReport(
        orders: orders,
        cafeName: pos.restaurantName.value.isEmpty ? 'Cafe' : pos.restaurantName.value,
        currency: pos.currencySymbol,
        period: periodLabel,
      );
      await ReportGenerator.printPdf(pdf);
    } catch (e) {
      Get.snackbar('Xato', 'Chop etib bo\'mladi: $e',
        backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      setState(() => _exporting = false);
    }
  }
}

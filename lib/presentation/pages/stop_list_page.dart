import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../logic/pos_controller.dart';
import '../../data/models/food_item.dart';
import '../widgets/common_image.dart';
import 'package:intl/intl.dart';

class StopListPage extends StatefulWidget {
  const StopListPage({super.key});

  @override
  State<StopListPage> createState() => _StopListPageState();
}

class _StopListPageState extends State<StopListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final RxString _query = ''.obs;
  final RxString _selectedCategory = 'Barchasi'.obs;
  final Set<String> _loadingIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final POSController pos = Get.find<POSController>();

    // Access gate — only admin
    if (!pos.isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 80, color: Color(0xFFEF4444)),
              const SizedBox(height: 16),
              const Text("Faqat admin uchun", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Bu bo'limga kirish huquqingiz yo'q", style: TextStyle(color: Color(0xFF9CA3AF))),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF9500), foregroundColor: Colors.white),
                child: const Text("Orqaga"),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 16, 24, 0),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 24),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Stop-list boshqaruvi",
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF1A1A1A))),
                        Obx(() {
                          final stopCount = pos.products.where((p) => !p.isAvailable).length;
                          return Text("$stopCount ta mahsulot to'xtatilgan",
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13));
                        }),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => _query.value = v,
                    decoration: InputDecoration(
                      hintText: "Mahsulot nomini qidiring...",
                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                      suffixIcon: Obx(() => _query.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF9CA3AF)),
                            onPressed: () { _searchController.clear(); _query.value = ''; },
                          )
                        : const SizedBox.shrink()),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Tabs
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFFFF9500),
                  unselectedLabelColor: const Color(0xFF9CA3AF),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  indicatorColor: const Color(0xFFFF9500),
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: "Barcha mahsulotlar"),
                    Tab(text: "Stop-listdagilar"),
                  ],
                ),
              ],
            ),
          ),

          // Category filter
          Obx(() {
            final cats = ['Barchasi', ...pos.categories.where((c) => c != 'All')];
            return Container(
              height: 48,
              color: Colors.white,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = cats[index];
                  final isSel = _selectedCategory.value == cat;
                  return GestureDetector(
                    onTap: () => _selectedCategory.value = cat,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFFFF9500) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(cat,
                        style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13,
                          color: isSel ? Colors.white : const Color(0xFF6B7280),
                        )),
                    ),
                  );
                },
              ),
            );
          }),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllProducts(pos),
                _buildStopListProducts(pos),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllProducts(POSController pos) {
    return Obx(() {
      final q = _query.value.toLowerCase();
      final cat = _selectedCategory.value;
      final items = pos.products.where((p) {
        final matchCat = cat == 'Barchasi' || p.category == cat;
        final matchQ = q.isEmpty || p.name.toLowerCase().contains(q);
        return matchCat && matchQ;
      }).toList();

      if (items.isEmpty) {
        return const Center(child: Text("Mahsulot topilmadi", style: TextStyle(color: Color(0xFF9CA3AF))));
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildProductTile(items[index], pos),
      );
    });
  }

  Widget _buildStopListProducts(POSController pos) {
    return Obx(() {
      final q = _query.value.toLowerCase();
      final cat = _selectedCategory.value;
      final items = pos.products.where((p) {
        if (p.isAvailable) return false;
        final matchCat = cat == 'Barchasi' || p.category == cat;
        final matchQ = q.isEmpty || p.name.toLowerCase().contains(q);
        return matchCat && matchQ;
      }).toList();

      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, size: 80, color: Colors.green.withOpacity(0.5)),
              const SizedBox(height: 16),
              const Text("Hamma taomlar sotuvda! 🎉",
                style: TextStyle(fontSize: 16, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildProductTile(items[index], pos),
      );
    });
  }

  Widget _buildProductTile(FoodItem item, POSController pos) {
    final isLoading = _loadingIds.contains(item.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isAvailable ? const Color(0xFFEDF0F5) : const Color(0xFFEF4444).withOpacity(0.3),
          width: item.isAvailable ? 1 : 1.5,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CommonImage(imageUrl: item.imageUrl, width: 60, height: 60, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          // Name + cat + price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 15,
                    color: item.isAvailable ? const Color(0xFF1A1A1A) : const Color(0xFF9CA3AF),
                    decoration: item.isAvailable ? null : TextDecoration.lineThrough,
                  )),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(6)),
                      child: Text(item.category,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${NumberFormat("#,###", "uz_UZ").format(item.price)} so'm",
                      style: const TextStyle(fontSize: 13, color: Color(0xFFFF9500), fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Toggle button
          GestureDetector(
            onTap: isLoading ? null : () async {
              setState(() => _loadingIds.add(item.id));
              await pos.toggleProductAvailability(item);
              setState(() => _loadingIds.remove(item.id));
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: item.isAvailable
                  ? const Color(0xFFEF4444).withOpacity(0.1)
                  : const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: item.isAvailable ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  width: 1.5,
                ),
              ),
              child: isLoading
                ? SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: item.isAvailable ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.isAvailable ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: item.isAvailable ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.isAvailable ? "To'xtatish" : "Faollashtirish",
                        style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13,
                          color: item.isAvailable ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

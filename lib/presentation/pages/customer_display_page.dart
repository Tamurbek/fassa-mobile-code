import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import '../../theme/app_colors.dart';

class CustomerDisplayPage extends StatefulWidget {
  final Map<String, dynamic> initialData;
  const CustomerDisplayPage({super.key, required this.initialData});

  @override
  State<CustomerDisplayPage> createState() => _CustomerDisplayPageState();
}

class _CustomerDisplayPageState extends State<CustomerDisplayPage> {
  List<dynamic> items = [];
  double total = 0.0;
  String restaurantName = "";
  String currency = "so'm";
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _updateData(widget.initialData);
    
    // Clock timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });

    // Listen for updates from main window
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      if (call.method == 'updateData') {
        final data = jsonDecode(call.arguments);
        _updateData(data);
      }
      return null;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _updateData(Map<String, dynamic> data) {
    setState(() {
      items = data['items'] ?? [];
      total = (data['total'] ?? 0.0).toDouble();
      restaurantName = data['restaurantName'] ?? "Fassa";
      currency = data['currency'] ?? "so'm";
    });
  }

  String _formatPrice(dynamic amount) {
    double value = double.tryParse(amount.toString()) ?? 0.0;
    final formatter = NumberFormat("#,###", "en_US");
    return "${formatter.format(value).replaceAll(',', ' ')} $currency";
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : AppColors.background;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final accentColor = AppColors.primary;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryTextColor = isDark ? Colors.white60 : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: items.isEmpty 
          ? _buildEmptyState(textColor, secondaryTextColor, accentColor, cardColor) 
          : _buildOrderState(isDark, textColor, secondaryTextColor, accentColor, cardColor),
      ),
    );
  }

  Widget _buildOrderState(bool isDark, Color textColor, Color secondaryTextColor, Color accentColor, Color cardColor) {
    return Row(
      key: const ValueKey("order_state"),
      children: [
        // Left Side: Order List
        Expanded(
          flex: 3,
          child: _buildOrderList(textColor, secondaryTextColor, accentColor, cardColor),
        ),
        
        // Right Side: Summary & Total (Only visible when items exist)
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF9FAFB),
              border: Border(left: BorderSide(color: textColor.withOpacity(0.05))),
            ),
            child: Column(
              children: [
                _buildRestaurantHeader(accentColor, textColor),
                const Spacer(),
                _buildTotalCard(accentColor, total),
                const SizedBox(height: 60),
                _buildFooter(secondaryTextColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color textColor, Color secondaryTextColor, Color accentColor, Color cardColor) {
    String timeStr = DateFormat('HH:mm').format(_now);
    String secondsStr = DateFormat(':ss').format(_now);
    String dateStr = DateFormat('EEEE, d MMMM', 'uz_UZ').format(_now);

    return Container(
      key: const ValueKey("empty_state"),
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(40),
      color: cardColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Elegant large clock
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: accentColor, 
                      fontSize: 220, 
                      fontWeight: FontWeight.w900, 
                      height: 1.0, 
                      letterSpacing: -10
                    ),
                  ),
                  Text(
                    secondsStr,
                    style: TextStyle(
                      color: accentColor.withOpacity(0.4), 
                      fontSize: 220, 
                      fontWeight: FontWeight.w900, 
                      height: 1.0,
                      letterSpacing: -10
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              dateStr.toUpperCase(),
              style: TextStyle(color: textColor.withOpacity(0.4), fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: 4),
            ),
            const SizedBox(height: 100),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 25),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: accentColor.withOpacity(0.1)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars_rounded, color: accentColor, size: 36),
                  const SizedBox(width: 20),
                  Text(
                    "Xush kelibsiz! Buyurtmangizni kutamiz",
                    style: TextStyle(color: accentColor, fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList(Color textColor, Color secondaryTextColor, Color accentColor, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(40),
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [accentColor, accentColor.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 25),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Sizning Savatingiz",
                    style: TextStyle(color: textColor, fontSize: 34, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    "${items.length} ta mahsulot",
                    style: TextStyle(color: secondaryTextColor, fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(color: textColor.withOpacity(0.06), height: 40, thickness: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['name'] ?? "",
                            style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.bold),
                          ),
                          if (item['variant'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                item['variant'],
                                style: TextStyle(color: secondaryTextColor, fontSize: 18, fontWeight: FontWeight.w500),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      "${item['quantity']} ×",
                      style: TextStyle(color: secondaryTextColor, fontSize: 24, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 40),
                    Text(
                      _formatPrice((item['price'] ?? 0) * (item['quantity'] ?? 1)),
                      style: TextStyle(color: textColor, fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantHeader(Color accentColor, Color textColor) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: accentColor.withOpacity(0.2), width: 2),
          ),
          child: Center(
            child: Text(
              restaurantName.isNotEmpty ? restaurantName[0].toUpperCase() : "F",
              style: TextStyle(color: accentColor, fontSize: 45, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          restaurantName.toUpperCase(),
          style: TextStyle(color: textColor, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
      ],
    );
  }

  Widget _buildTotalCard(Color accentColor, double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 30),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor, accentColor.withOpacity(0.9)],
        ),
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "UMUMIY SUMMA",
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, letterSpacing: 3, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 15),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatPrice(total),
              style: const TextStyle(color: Colors.white, fontSize: 55, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Color secondaryTextColor) {
    return Column(
      children: [
        Text(
          "Xaridingiz uchun rahmat!",
          textAlign: TextAlign.center,
          style: TextStyle(color: secondaryTextColor, fontSize: 22, fontWeight: FontWeight.w500, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 15),
        Opacity(
          opacity: 0.3,
          child: Image.asset('assets/images/app_icon.png', height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.qr_code_2, size: 40)),
        ),
      ],
    );
  }
}

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ReportGenerator {
  static final NumberFormat _formatter = NumberFormat('#,###', 'uz_UZ');

  // ─── Color Palette ───────────────────────────────────────────────────────
  static const PdfColor _primary    = PdfColor.fromInt(0xFF4318FF);
  static const PdfColor _accent     = PdfColor.fromInt(0xFF00B5D8);
  static const PdfColor _success    = PdfColor.fromInt(0xFF38A169);
  static const PdfColor _warning    = PdfColor.fromInt(0xFFDD6B20);
  static const PdfColor _bg         = PdfColor.fromInt(0xFFF7F8FC);
  static const PdfColor _border     = PdfColor.fromInt(0xFFE2E8F0);
  static const PdfColor _text       = PdfColor.fromInt(0xFF1A202C);
  static const PdfColor _textLight  = PdfColor.fromInt(0xFF718096);
  static const PdfColor _white      = PdfColors.white;

  // ─── Font handling for Unicode support ───
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;

  static Future<pw.ThemeData> _getTheme() async {
    try {
      _regularFont ??= await PdfGoogleFonts.robotoRegular().timeout(const Duration(seconds: 3));
      _boldFont ??= await PdfGoogleFonts.robotoBold().timeout(const Duration(seconds: 3));
    } catch (e) {
      print("Warning: Google fonts could not be loaded, using fallback: $e");
    }
    
    return pw.ThemeData.withFont(
      base: _regularFont,
      bold: _boldFont,
    );
  }

  // ─── Common header widget ────────────────────────────────────────────────
  static pw.Widget _buildHeader({
    required String cafeName,
    required String reportTitle,
    required String reportSubtitle,
    required PdfColor accentColor,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [accentColor, accentColor.shade(0.7)],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
      ),
      padding: const pw.EdgeInsets.all(24),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                cafeName.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 11,
                  color: _white.shade(0.85),
                  letterSpacing: 1.5,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                reportTitle,
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: _white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                reportSubtitle,
                style: pw.TextStyle(fontSize: 11, color: _white.shade(0.8)),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                DateFormat('dd.MM.yyyy').format(DateTime.now()),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: _white,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                DateFormat('HH:mm').format(DateTime.now()),
                style: pw.TextStyle(fontSize: 13, color: _white.shade(0.85)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── KPI card ────────────────────────────────────────────────────────────
  static pw.Widget _buildKpiCard(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 6),
        padding: const pw.EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: pw.BoxDecoration(
          color: color.shade(0.08),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          border: pw.Border.all(color: color.shade(0.3), width: 1),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Container(
              width: 6, height: 6,
              decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              label,
              style: pw.TextStyle(fontSize: 9, color: _textLight),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section heading ─────────────────────────────────────────────────────
  static pw.Widget _buildSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 20, bottom: 10),
      child: pw.Row(
        children: [
          pw.Container(width: 4, height: 16, color: _primary),
          pw.SizedBox(width: 8),
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _text,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Footer ──────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border)),
      ),
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Tizim tomonidan avtomatik yaratildi',
              style: pw.TextStyle(fontSize: 8, color: _textLight)),
          pw.Text('Sahifa ${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _textLight)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  X-REPORT  (shift snapshot — don't close shift)
  // ════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> generateXReport(
    List<Map<String, dynamic>> orders,
    String cafeName,
    String currency,
    String? cashierName,
  ) async {
    return _generateShiftReport(
      orders: orders,
      cafeName: cafeName,
      currency: currency,
      cashierName: cashierName,
      title: 'X-REPORT',
      subtitle: 'Smena holati hisoboti (Yopilmaydi)',
      accentColor: _accent,
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  Z-REPORT  (close of day — used when cashier closes shift)
  // ════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> generateZReport(
    List<Map<String, dynamic>> orders,
    String cafeName,
    String currency,
    String? cashierName,
  ) async {
    return _generateShiftReport(
      orders: orders,
      cafeName: cafeName,
      currency: currency,
      cashierName: cashierName,
      title: 'Z-REPORT',
      subtitle: 'Kun yakuniy hisoboti (Smena yopilishi)',
      accentColor: _warning,
    );
  }

  static Future<pw.Document> _generateShiftReport({
    required List<Map<String, dynamic>> orders,
    required String cafeName,
    required String currency,
    required String? cashierName,
    required String title,
    required String subtitle,
    required PdfColor accentColor,
  }) async {
    final pdf = pw.Document(theme: await _getTheme());

    // ── KPIs ──
    double totalRevenue = 0;
    double dineInRevenue = 0;
    double takeawayRevenue = 0;
    double deliveryRevenue = 0;
    int dineInCount = 0;
    int takeawayCount = 0;
    int deliveryCount = 0;

    Map<String, double> itemRevenue = {};
    Map<String, int> itemQty = {};

    for (var o in orders) {
      final double total = (o['total'] as num).toDouble();
      totalRevenue += total;
      final mode = (o['mode'] ?? '').toString().toLowerCase();
      if (mode.contains('dine')) { dineInRevenue += total; dineInCount++; }
      else if (mode.contains('take')) { takeawayRevenue += total; takeawayCount++; }
      else if (mode.contains('deliv')) { deliveryRevenue += total; deliveryCount++; }

      for (var item in (o['details'] as List? ?? [])) {
        final name = (item['name'] ?? 'Nomalum').toString();
        final qty = (item['qty'] as num).toInt();
        final price = (item['price'] as num).toDouble();
        itemRevenue[name] = (itemRevenue[name] ?? 0) + (price * qty);
        itemQty[name] = (itemQty[name] ?? 0) + qty;
      }
    }

    final avgBill = orders.isEmpty ? 0.0 : totalRevenue / orders.length;
    final sortedItems = itemRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = sortedItems.take(5).toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      footer: _buildFooter,
      build: (context) => [
        _buildHeader(
          cafeName: cafeName,
          reportTitle: title,
          reportSubtitle: subtitle,
          accentColor: accentColor,
        ),
        pw.SizedBox(height: 20),

        // KPI row
        pw.Row(
          children: [
            _buildKpiCard("Jami buyurtmalar", orders.length.toString(), _primary),
            _buildKpiCard("Jami savdo", "${_formatter.format(totalRevenue)} $currency", _success),
            _buildKpiCard("O'rtacha chek", "${_formatter.format(avgBill)} $currency", _accent),
          ],
        ),
        pw.SizedBox(height: 12),

        // Sales by type
        _buildSectionTitle("Buyurtma turlari bo'yicha"),
        pw.Table(
          border: pw.TableBorder.all(color: _border),
          columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(2)},
          children: [
            // Header
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _bg),
              children: [
                _tableCell("Tur", bold: true),
                _tableCell("Buyurtmalar", bold: true, align: pw.TextAlign.center),
                _tableCell("Summa", bold: true, align: pw.TextAlign.right),
              ],
            ),
            _buildTypeRow("Zalda", dineInCount, dineInRevenue, currency),
            _buildTypeRow("Olib ketish", takeawayCount, takeawayRevenue, currency),
            _buildTypeRow("Yetkazib berish", deliveryCount, deliveryRevenue, currency),
            // Total
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _bg),
              children: [
                _tableCell("JAMI", bold: true),
                _tableCell(orders.length.toString(), bold: true, align: pw.TextAlign.center),
                _tableCell("${_formatter.format(totalRevenue)} $currency", bold: true, align: pw.TextAlign.right),
              ],
            ),
          ],
        ),

        // Top items
        if (top5.isNotEmpty) ...[
          _buildSectionTitle("Eng ko'p sotilganlar (Top 5)"),
          pw.Table(
            border: pw.TableBorder.all(color: _border),
            columnWidths: {0: const pw.FixedColumnWidth(28), 1: const pw.FlexColumnWidth(5), 2: const pw.FlexColumnWidth(2), 3: const pw.FlexColumnWidth(3)},
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _bg),
                children: [
                  _tableCell("#", bold: true, align: pw.TextAlign.center),
                  _tableCell("Mahsulot", bold: true),
                  _tableCell("Soni", bold: true, align: pw.TextAlign.center),
                  _tableCell("Savdo", bold: true, align: pw.TextAlign.right),
                ],
              ),
              ...top5.asMap().entries.map((e) => pw.TableRow(children: [
                _tableCell("${e.key + 1}", align: pw.TextAlign.center),
                _tableCell(e.value.key),
                _tableCell("${itemQty[e.value.key] ?? 0}", align: pw.TextAlign.center),
                _tableCell("${_formatter.format(e.value.value)} $currency", align: pw.TextAlign.right),
              ])),
            ],
          ),
        ],

        // Cashier info
        if (cashierName != null) ...[
          _buildSectionTitle("Kassir ma'lumotlari"),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _bg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: _border),
            ),
            child: pw.Row(
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Kassir:", style: pw.TextStyle(fontSize: 10, color: _textLight)),
                    pw.SizedBox(height: 4),
                    pw.Text(cashierName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _text)),
                  ],
                ),
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Hisobot vaqti:", style: pw.TextStyle(fontSize: 10, color: _textLight)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _text),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    ));

    return pdf;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  SALES REPORT  (general)
  // ════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> generateSalesReport({
    required String title,
    required List<Map<String, dynamic>> orders,
    required String cafeName,
    required String currency,
  }) async {
    final pdf = pw.Document(theme: await _getTheme());

    double totalRevenue = orders.fold(0, (s, o) => s + (o['total'] as num).toDouble());
    double avgBill = orders.isEmpty ? 0 : totalRevenue / orders.length;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      footer: _buildFooter,
      build: (context) => [
        _buildHeader(
          cafeName: cafeName,
          reportTitle: 'SAVDO HISOBOTI',
          reportSubtitle: title,
          accentColor: _success,
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          children: [
            _buildKpiCard("Buyurtmalar", orders.length.toString(), _primary),
            _buildKpiCard("Jami savdo", "${_formatter.format(totalRevenue)} $currency", _success),
            _buildKpiCard("O'rtacha chek", "${_formatter.format(avgBill)} $currency", _accent),
          ],
        ),
        _buildSectionTitle("Barcha buyurtmalar"),
        pw.Table(
          border: pw.TableBorder.all(color: _border),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
            5: const pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _bg),
              children: [
                _tableCell("#", bold: true),
                _tableCell("Vaqt", bold: true),
                _tableCell("Stol", bold: true, align: pw.TextAlign.center),
                _tableCell("Ofitsiant", bold: true),
                _tableCell("Status", bold: true),
                _tableCell("Summa", bold: true, align: pw.TextAlign.right),
              ],
            ),
            ...orders.asMap().entries.map((e) {
              final o = e.value;
              String timeStr = "-";
              try {
                if (o['timestamp'] != null) {
                  timeStr = DateFormat('HH:mm').format(DateTime.parse(o['timestamp'].toString()));
                }
              } catch (_) {}
              return pw.TableRow(
                decoration: e.key % 2 == 1 ? const pw.BoxDecoration(color: _bg) : null,
                children: [
                  _tableCell("${e.key + 1}", align: pw.TextAlign.center),
                  _tableCell(timeStr),
                  _tableCell(o['table']?.toString() ?? "-", align: pw.TextAlign.center),
                  _tableCell(o['waiter_name']?.toString() ?? "-"),
                  _tableCell(o['status']?.toString() ?? "-"),
                  _tableCell("${_formatter.format((o['total'] as num).toDouble())} $currency", align: pw.TextAlign.right),
                ],
              );
            }),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _bg),
              children: [
                _tableCell("", bold: true),
                _tableCell("JAMI", bold: true),
                _tableCell("", bold: true),
                _tableCell("", bold: true),
                _tableCell("", bold: true),
                _tableCell("${_formatter.format(totalRevenue)} $currency", bold: true, align: pw.TextAlign.right),
              ],
            ),
          ],
        ),
      ],
    ));

    return pdf;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  CATEGORY SALES REPORT
  // ════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> generateCategoryReport({
    required String title,
    required List<Map<String, dynamic>> orders,
    required String cafeName,
    required String currency,
  }) async {
    final pdf = pw.Document(theme: await _getTheme());

    Map<String, double> catRevenue = {};
    Map<String, int> catQty = {};
    double totalRevenue = 0;

    for (var order in orders) {
      for (var item in (order['details'] as List? ?? [])) {
        final cat = (item['category'] ?? 'Boshqa').toString();
        final qty = (item['qty'] as num).toInt();
        final price = (item['price'] as num).toDouble();
        catRevenue[cat] = (catRevenue[cat] ?? 0) + (price * qty);
        catQty[cat] = (catQty[cat] ?? 0) + qty;
        totalRevenue += price * qty;
      }
    }

    final sorted = catRevenue.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      footer: _buildFooter,
      build: (context) => [
        _buildHeader(
          cafeName: cafeName,
          reportTitle: 'KATEGORIYA SAVDOSI',
          reportSubtitle: title,
          accentColor: PdfColor.fromInt(0xFF805AD5),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          children: [
            _buildKpiCard("Kategoriyalar", catRevenue.length.toString(), _primary),
            _buildKpiCard("Jami savdo", "${_formatter.format(totalRevenue)} $currency", _success),
          ],
        ),
        _buildSectionTitle("Kategoriyalar bo'yicha savdo"),
        pw.Table(
          border: pw.TableBorder.all(color: _border),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(3),
            4: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _bg),
              children: [
                _tableCell("#", bold: true),
                _tableCell("Kategoriya", bold: true),
                _tableCell("Soni", bold: true, align: pw.TextAlign.center),
                _tableCell("Savdo", bold: true, align: pw.TextAlign.right),
                _tableCell("Ulush", bold: true, align: pw.TextAlign.right),
              ],
            ),
            ...sorted.asMap().entries.map((e) {
              final pct = totalRevenue > 0 ? (e.value.value / totalRevenue * 100).toStringAsFixed(1) : "0.0";
              return pw.TableRow(
                decoration: e.key % 2 == 1 ? const pw.BoxDecoration(color: _bg) : null,
                children: [
                  _tableCell("${e.key + 1}", align: pw.TextAlign.center),
                  _tableCell(e.value.key),
                  _tableCell("${catQty[e.value.key] ?? 0}", align: pw.TextAlign.center),
                  _tableCell("${_formatter.format(e.value.value)} $currency", align: pw.TextAlign.right),
                  _tableCell("$pct%", align: pw.TextAlign.right),
                ],
              );
            }),
          ],
        ),
      ],
    ));

    return pdf;
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  static pw.TableRow _buildTypeRow(String label, int count, double revenue, String currency) {
    return pw.TableRow(children: [
      _tableCell(label),
      _tableCell(count.toString(), align: pw.TextAlign.center),
      _tableCell("${_formatter.format(revenue)} $currency", align: pw.TextAlign.right),
    ]);
  }

  static pw.Widget _tableCell(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: bold ? _text : _textLight,
        ),
      ),
    );
  }

  // ─── Share / Print ───────────────────────────────────────────────────────
  static Future<void> sharePdf(pw.Document pdf, String filename) async {
    final bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: filename);
  }

  static Future<void> printPdf(pw.Document pdf) async {
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  // ════════════════════════════════════════════════════════════════════════
  //  WAITER PERFORMANCE REPORT
  // ════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> generateWaiterPerformanceReport({
    required List<Map<String, dynamic>> orders,
    required String cafeName,
    required String currency,
    required String period,
  }) async {
    final pdf = pw.Document(theme: await _getTheme());

    // Build per-waiter stats
    final Map<String, Map<String, dynamic>> map = {};
    for (var o in orders) {
      final name = (o['waiter_name'] ?? "Noma'lum").toString();
      final total = (o['total'] as num? ?? 0).toDouble();
      if (!map.containsKey(name)) {
        map[name] = {'name': name, 'orders': 0, 'revenue': 0.0};
      }
      map[name]!['orders'] = (map[name]!['orders'] as int) + 1;
      map[name]!['revenue'] = (map[name]!['revenue'] as double) + total;
    }

    final stats = map.values.map((w) {
      final int cnt = w['orders'] as int;
      final double rev = w['revenue'] as double;
      return {...w, 'avg_bill': cnt > 0 ? rev / cnt : 0.0};
    }).toList()
      ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

    final double totalRevenue = stats.fold(0.0, (s, w) => s + (w['revenue'] as double));
    final int totalOrders = orders.length;
    final double avgBill = stats.isEmpty ? 0 : totalRevenue / stats.length;

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      footer: _buildFooter,
      build: (context) => [
        _buildHeader(
          cafeName: cafeName,
          reportTitle: 'OFITSIANTLAR UNUMDORLIGI',
          reportSubtitle: 'Davr: $period',
          accentColor: PdfColor.fromInt(0xFF2D3748),
        ),
        pw.SizedBox(height: 20),
        pw.Row(
          children: [
            _buildKpiCard('Ofitsiantlar', '${stats.length} ta', _primary),
            _buildKpiCard('Jami buyurtmalar', '$totalOrders ta', _accent),
            _buildKpiCard('Jami savdo', '${_formatter.format(totalRevenue)} $currency', _success),
            _buildKpiCard("O'rtacha / ofitsiant", '${_formatter.format(avgBill)} $currency', _warning),
          ],
        ),
        _buildSectionTitle("Reyting jadvali"),
        pw.Table(
          border: pw.TableBorder.all(color: _border),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(3),
            4: const pw.FlexColumnWidth(3),
            5: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _bg),
              children: [
                _tableCell('#', bold: true, align: pw.TextAlign.center),
                _tableCell('Ofitsiant', bold: true),
                _tableCell('Buyurtmalar', bold: true, align: pw.TextAlign.center),
                _tableCell('Jami savdo', bold: true, align: pw.TextAlign.right),
                _tableCell("O'rtacha chek", bold: true, align: pw.TextAlign.right),
                _tableCell('Ulush', bold: true, align: pw.TextAlign.right),
              ],
            ),
            ...stats.asMap().entries.map((e) {
              final w = e.value;
              final revenue = w['revenue'] as double;
              final pct = totalRevenue > 0 ? (revenue / totalRevenue * 100).toStringAsFixed(1) : '0.0';
              final medal = e.key == 0 ? '🥇 ' : e.key == 1 ? '🥈 ' : e.key == 2 ? '🥉 ' : '';
              return pw.TableRow(
                decoration: e.key % 2 == 1 ? const pw.BoxDecoration(color: _bg) : null,
                children: [
                  _tableCell('${e.key + 1}', align: pw.TextAlign.center),
                  _tableCell('$medal${w['name']}'),
                  _tableCell('${w['orders']}', align: pw.TextAlign.center),
                  _tableCell('${_formatter.format(revenue)} $currency', align: pw.TextAlign.right),
                  _tableCell('${_formatter.format(w['avg_bill'])} $currency', align: pw.TextAlign.right),
                  _tableCell('$pct%', align: pw.TextAlign.right),
                ],
              );
            }),
          ],
        ),
        // Total row
        pw.Container(
          decoration: const pw.BoxDecoration(color: _bg),
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _tableCell('JAMI', bold: true),
              pw.Spacer(),
              _tableCell('$totalOrders buyurtma  |  ${_formatter.format(totalRevenue)} $currency', bold: true, align: pw.TextAlign.right),
            ],
          ),
        ),
      ],
    ));

    return pdf;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PAYMENT METHOD REPORT
  // ════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> generatePaymentMethodReport({
    required List<Map<String, dynamic>> orders,
    required String cafeName,
    required String currency,
  }) async {
    final pdf = pw.Document(theme: await _getTheme());

    final Map<String, double> revenueByMethod = {
      'Cash': 0.0,
      'Card': 0.0,
      'Online': 0.0,
      'Other': 0.0,
    };
    final Map<String, int> countsByMethod = {
      'Cash': 0,
      'Card': 0,
      'Online': 0,
      'Other': 0,
    };

    double totalRevenue = 0.0;
    int totalPaidOrders = 0;

    for (var o in orders) {
      if (o['is_paid'] != true) continue;
      
      String method = (o['payment_method'] ?? 'Other').toString();
      if (!revenueByMethod.containsKey(method)) method = 'Other';
      
      final total = (o['total'] as num? ?? 0).toDouble();
      revenueByMethod[method] = revenueByMethod[method]! + total;
      countsByMethod[method] = countsByMethod[method]! + 1;
      
      totalRevenue += total;
      totalPaidOrders++;
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      footer: _buildFooter,
      build: (context) => [
        _buildHeader(
          cafeName: cafeName,
          reportTitle: "TO'LOV TURI BO'YICHA HISOBOT",
          reportSubtitle: 'Faqat yakunlangan (to\'langan) buyurtmalar',
          accentColor: _accent,
        ),
        pw.SizedBox(height: 20),
        
        // Summary Cards
        pw.Row(
          children: [
            _buildKpiCard('Jami savdo', '${_formatter.format(totalRevenue)} $currency', _primary),
            _buildKpiCard('Naqd pul', '${_formatter.format(revenueByMethod['Cash'])} $currency', _success),
            _buildKpiCard('Karta / Terminal', '${_formatter.format(revenueByMethod['Card'])} $currency', _accent),
            _buildKpiCard('Online / Boshqa', '${_formatter.format(revenueByMethod['Online']! + revenueByMethod['Other']!)} $currency', _warning),
          ],
        ),
        
        _buildSectionTitle("To'lovlar taqsimoti"),
        pw.Table(
          border: pw.TableBorder.all(color: _border),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _bg),
              children: [
                _tableCell("To'lov turi", bold: true),
                _tableCell("Soni", bold: true, align: pw.TextAlign.center),
                _tableCell("Jamma miqdor", bold: true, align: pw.TextAlign.right),
                _tableCell("Ulush (%)", bold: true, align: pw.TextAlign.right),
              ],
            ),
            ...revenueByMethod.entries.where((e) => e.value > 0 || countsByMethod[e.key]! > 0).map((e) {
              final pct = totalRevenue > 0 ? (e.value / totalRevenue * 100).toStringAsFixed(1) : '0.0';
              final label = e.key == 'Cash' ? 'Naqd pul' :
                            e.key == 'Card' ? 'Karta / Terminal' :
                            e.key == 'Online' ? 'Click / Payme' : 'Boshqa';
              return pw.TableRow(
                children: [
                  _tableCell(label),
                  _tableCell('${countsByMethod[e.key]}', align: pw.TextAlign.center),
                  _tableCell('${_formatter.format(e.value)} $currency', align: pw.TextAlign.right),
                  _tableCell('$pct%', align: pw.TextAlign.right),
                ],
              );
            }),
          ],
        ),
      ],
    ));

    return pdf;
  }

  // ════════════════════════════════════════════════════════════════════════
  //  HOURLY SALES REPORT
  // ════════════════════════════════════════════════════════════════════════
  static Future<pw.Document> generateHourlySalesReport({
    required List<Map<String, dynamic>> orders,
    required String cafeName,
    required String currency,
  }) async {
    final pdf = pw.Document(theme: await _getTheme());

    final Map<int, double> hourlyRevenue = {};
    final Map<int, int> hourlyCount = {};
    for (int i = 0; i < 24; i++) {
      hourlyRevenue[i] = 0.0;
      hourlyCount[i] = 0;
    }

    double totalRevenue = 0.0;
    int maxRevenueHour = -1;
    double maxRevenue = 0.0;

    for (var o in orders) {
      if (o['status'] == 'Cancelled') continue;
      
      try {
        final dt = DateTime.parse(o['timestamp'].toString());
        final hour = dt.hour;
        final total = (o['total'] as num? ?? 0).toDouble();
        
        hourlyRevenue[hour] = hourlyRevenue[hour]! + total;
        hourlyCount[hour] = hourlyCount[hour]! + 1;
        totalRevenue += total;
        
        if (hourlyRevenue[hour]! > maxRevenue) {
          maxRevenue = hourlyRevenue[hour]!;
          maxRevenueHour = hour;
        }
      } catch (_) {}
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      footer: _buildFooter,
      build: (context) => [
        _buildHeader(
          cafeName: cafeName,
          reportTitle: "ENG YAXSHI SOATLAR",
          reportSubtitle: 'Kun davomida savdo unumdorligi tahlili',
          accentColor: _primary,
        ),
        pw.SizedBox(height: 20),
        
        // Summary Cards
        pw.Row(
          children: [
            _buildKpiCard('Jami savdo', '${_formatter.format(totalRevenue)} $currency', _primary),
            _buildKpiCard('Eng yaxshi soat', maxRevenueHour == -1 ? '-' : '$maxRevenueHour:00', _success),
            _buildKpiCard('O\'rtacha soatlik', '${_formatter.format(totalRevenue / 24)} $currency', _accent),
          ],
        ),
        
        _buildSectionTitle("Soatlik savdo grafigi (Vizual)"),
        pw.Container(
          height: 200,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: List.generate(24, (index) {
              final val = hourlyRevenue[index] ?? 0;
              final heightPct = maxRevenue > 0 ? (val / maxRevenue) : 0.0;
              return pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 12,
                    height: (heightPct * 150) + 1, // min 1px
                    decoration: pw.BoxDecoration(
                      color: index == maxRevenueHour ? _success : PdfColor(_primary.red, _primary.green, _primary.blue, 0.6),
                      borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4)),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('$index', style: const pw.TextStyle(fontSize: 8)),
                ],
              );
            }),
          ),
        ),
        
        _buildSectionTitle("Batafsil ma'lumot"),
        pw.Table(
          border: pw.TableBorder.all(color: _border),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _bg),
              children: [
                _tableCell("Vaqt oralig'i", bold: true),
                _tableCell("Buyurtmalar", bold: true, align: pw.TextAlign.center),
                _tableCell("Savdo miqdori", bold: true, align: pw.TextAlign.right),
                _tableCell("Ulush (%)", bold: true, align: pw.TextAlign.right),
              ],
            ),
            ...List.generate(24, (i) {
              final revenue = hourlyRevenue[i] ?? 0;
              if (revenue == 0 && hourlyCount[i] == 0) return null;
              final pct = totalRevenue > 0 ? (revenue / totalRevenue * 100).toStringAsFixed(1) : '0.0';
              return pw.TableRow(
                decoration: i == maxRevenueHour ? pw.BoxDecoration(color: PdfColor(_success.red, _success.green, _success.blue, 0.1)) : null,
                children: [
                  _tableCell("$i:00 - ${i + 1}:00", bold: i == maxRevenueHour),
                  _tableCell("${hourlyCount[i]}", align: pw.TextAlign.center),
                  _tableCell("${_formatter.format(revenue)} $currency", align: pw.TextAlign.right),
                  _tableCell("$pct%", align: pw.TextAlign.right),
                ],
              );
            }).where((row) => row != null).cast<pw.TableRow>(),
          ],
        ),
      ],
    ));

    return pdf;
  }
}

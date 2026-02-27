import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class ReportGenerator {
  static final NumberFormat _formatter = NumberFormat("#,###", "uz_UZ");

  static Future<pw.Document> generateSalesReport(
      String title, List<Map<String, dynamic>> orders, String cafeName, String currency) async {
    final pdf = pw.Document();

    double totalRevenue = 0;
    int totalOrders = orders.length;
    for (var o in orders) {
      totalRevenue += (o['total'] as double);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(cafeName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Center(child: pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryBox("Buyurtmalar", totalOrders.toString()),
                _buildSummaryBox("Jami Savdo", "${_formatter.format(totalRevenue)} $currency"),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Table.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              headers: ['No', 'Vaqt', 'Stol', 'Ofitsiant', 'Status', 'Summa'],
              data: List<List<dynamic>>.generate(
                orders.length,
                (index) {
                  final o = orders[index];
                  return [
                    (index + 1),
                    DateFormat('HH:mm').format(DateTime.parse(o['timestamp'])),
                    o['table'] ?? "-",
                    o['waiter_name'] ?? "-",
                    o['status'] ?? "-",
                    "${_formatter.format(o['total'])} $currency",
                  ];
                },
              ),
            ),
          ];
        },
      ),
    );

    return pdf;
  }

  static pw.Widget _buildSummaryBox(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  static Future<pw.Document> generateCategoryReport(
      String title, List<Map<String, dynamic>> orders, String cafeName, String currency) async {
    final pdf = pw.Document();

    Map<String, double> categories = {};
    for (var order in orders) {
      final details = order['details'] as List? ?? [];
      for (var item in details) {
        String cat = item['category'] ?? 'Boshqa';
        double price = (item['price'] as num).toDouble();
        int qty = (item['qty'] as num).toInt();
        categories[cat] = (categories[cat] ?? 0) + (price * qty);
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(cafeName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                context: context,
                headers: ['Kategoriya', 'Jami Savdo'],
                data: categories.entries.map((e) => [e.key, "${_formatter.format(e.value)} $currency"]).toList(),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

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
}

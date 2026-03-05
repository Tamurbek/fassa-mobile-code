import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/printer_model.dart';
import '../../logic/pos_controller.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class PrinterService {
  static img.Image? _decodeImage(Uint8List bytes) {
    return img.decodeImage(bytes);
  }
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  CapabilityProfile? _cachedProfile;
  Future<CapabilityProfile> _getProfile() async {
    _cachedProfile ??= await CapabilityProfile.load();
    return _cachedProfile!;
  }

  String _formatPrice(dynamic amount) {
    double value = double.tryParse(amount.toString()) ?? 0.0;
    final formatter = NumberFormat("#,###", "en_US");
    return formatter.format(value).replaceAll(',', ' ');
  }

  String _normalizeString(String? text) {
    if (text == null) return "";
    // Replace known Cyrillic characters that look like Latin with their Latin counterparts
    // for better visual consistency if they were accidentally typed.
    // However, the printer error is likely because it doesn't support UTF-8/multi-byte at all.
    // For now, let's just ensure we only send ASCII characters to the printer.
    
    Map<String, String> replacements = {
      'Е': 'E', 'е': 'e',
      'А': 'A', 'а': 'a',
      'В': 'B',
      'С': 'C', 'с': 'c',
      'Н': 'H',
      'К': 'K', 'к': 'k',
      'М': 'M', 'м': 'm',
      'О': 'O', 'о': 'o',
      'Р': 'P', 'р': 'p',
      'Т': 'T',
      'Х': 'X', 'х': 'x',
      'У': 'Y', 'у': 'y',
    };

    String result = text;
    replacements.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    // Strip any remaining non-ASCII characters to prevent printer driver crash
    return result.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  }

  Future<bool> printReceipt(PrinterModel printer, Map<String, dynamic> order, {String? title, bool isKitchenOnly = false}) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;

    try {
      final profile = await _getProfile();
      final generator = Generator(
          printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      
      List<int> bytes = [];
      final posController = Get.find<POSController>();

      // Use either receiptLayout or kitchenReceiptLayout based on the flag
      final layout = isKitchenOnly 
          ? posController.kitchenReceiptLayout.toList() 
          : posController.receiptLayout.toList();

      if (layout.isEmpty) {
        // Simple fallback if no layout is defined
        bytes += generator.text(_normalizeString(posController.restaurantName.value), styles: const PosStyles(align: PosAlign.center, bold: true));
        bytes += generator.hr();
        bytes += generator.text(_normalizeString('ID: ${order['id']}'), styles: const PosStyles(align: PosAlign.center));
        bytes += generator.hr();
        for (var item in (order['details'] as List)) {
          bytes += _row(generator, item['name'], '${item['qty']} x ${_formatPrice(item['price'])}');
        }
        bytes += generator.hr();
        bytes += _row(generator, 'JAMI:', _formatPrice(order['total']), bold: true);
      } else {
        for (var element in layout) {
          if (!(element['enabled'] ?? true)) continue;
          final type = element['type'];

          switch (type) {
            case 'HEADER':
              bytes += generator.text(_normalizeString(posController.restaurantName.value), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
              if (posController.restaurantAddress.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.restaurantAddress.value), styles: const PosStyles(align: PosAlign.center));
              if (posController.restaurantPhone.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.restaurantPhone.value), styles: const PosStyles(align: PosAlign.center));
              break;
            case 'CAFE_LOGO':
              if (posController.showLogo.value && posController.restaurantLogo.value.isNotEmpty) {
                try {
                  final logoUrl = posController.restaurantLogo.value;
                  final response = await http.get(Uri.parse(logoUrl)).timeout(const Duration(seconds: 5));
                  if (response.statusCode == 200) {
                    final image = await compute(_decodeImage, response.bodyBytes);
                    if (image != null) {
                      final maxWidth = printer.paperSize == '58mm' ? 150 : 200;
                      img.Image resized = img.copyResize(image, width: maxWidth);
                      bytes += generator.image(resized);
                    }
                  }
                } catch (e) { print('Logo error: $e'); }
              }
              break;
            case 'ORDER_INFO':
              if (title != null) bytes += generator.text(_normalizeString(title.toUpperCase()), styles: const PosStyles(align: PosAlign.center, bold: true));
              bytes += generator.text(_normalizeString('ID: ${order['id'].toString().substring(0, order['id'].toString().length > 8 ? 8 : order['id'].toString().length)}'), styles: const PosStyles(align: PosAlign.center));
              bytes += generator.text(_normalizeString(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())), styles: const PosStyles(align: PosAlign.center));
              if (order['table'] != null && order['table'] != '-') {
                 bytes += generator.text(_normalizeString('STOL: ${order['table']}'), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
              }
              if (order['waiter_name'] != null && order['waiter_name'].toString().isNotEmpty) {
                 bytes += generator.text(_normalizeString('OFITSIANT: ${order['waiter_name']}'), styles: const PosStyles(align: PosAlign.center));
              }
              break;
            case 'ITEMS_TABLE':
              bytes += generator.hr(ch: '-');
              bytes += generator.row([
                PosColumn(text: _normalizeString('NOMI'), width: 7, styles: const PosStyles(bold: true)),
                PosColumn(text: _normalizeString('SONI'), width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
                PosColumn(text: _normalizeString('NARXI'), width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
              ]);
              bytes += generator.hr(ch: '-');
              final items = order['details'] as List;
              for (var item in items) {
                int qty = int.tryParse(item['qty'].toString()) ?? 0;
                double price = double.tryParse(item['price'].toString()) ?? 0.0;
                bytes += generator.row([
                  PosColumn(text: _normalizeString(item['name']), width: 7),
                  PosColumn(text: _normalizeString(qty.toString()), width: 2, styles: const PosStyles(align: PosAlign.center)),
                  PosColumn(text: _normalizeString(_formatPrice(qty * price)), width: 3, styles: const PosStyles(align: PosAlign.right)),
                ]);
              }
              bytes += generator.hr(ch: '-');
              break;
            case 'TOTAL_BLOCK':
              double subtotal = 0;
              for (var item in (order['details'] as List)) {
                subtotal += (double.tryParse(item['price'].toString()) ?? 0.0) * (int.tryParse(item['qty'].toString()) ?? 0);
              }
              bytes += _row(generator, 'SUMMA:', _formatPrice(subtotal));
              final double discountAmt = (order['discount_amount'] as num?)?.toDouble() ?? 0.0;
              if (discountAmt > 0) bytes += _row(generator, 'CHEGIRMA:', '-${_formatPrice(discountAmt)}', bold: true);
              
              double finalTotal = subtotal - discountAmt;
              bytes += generator.hr(ch: '=');
              bytes += generator.row([
                PosColumn(text: _normalizeString('JAMI:'), width: 5, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
                PosColumn(text: _normalizeString('${_formatPrice(finalTotal)}'), width: 7, styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2)),
              ]);
              bytes += generator.hr(ch: '=');
              break;
            case 'DIVIDER':
              bytes += generator.hr(ch: '-');
              break;
            case 'QR_CODE':
              // Not yet implemented for ESC/POS but placeholder to avoid missing case
              break;
            case 'FOOTER':
              if (posController.receiptFooter.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.receiptFooter.value), styles: const PosStyles(align: PosAlign.center, bold: true));
              if (posController.instagram.value.isNotEmpty) bytes += generator.text(_normalizeString('Insta: @${posController.instagram.value.replaceAll('@', '')}'), styles: const PosStyles(align: PosAlign.center));
              if (posController.telegram.value.isNotEmpty) bytes += generator.text(_normalizeString('TG: t.me/${posController.telegram.value.replaceAll('t.me/', '')}'), styles: const PosStyles(align: PosAlign.center));
              break;
            case 'WIFI_INFO':
               if (posController.wifiSsid.value.isNotEmpty) {
                 bytes += generator.text(_normalizeString('Wi-Fi: ${posController.wifiSsid.value}'), styles: const PosStyles(align: PosAlign.center));
                 bytes += generator.text(_normalizeString('Parol: ${posController.wifiPassword.value}'), styles: const PosStyles(align: PosAlign.center));
               }
               break;
            case 'KITCHEN_TITLE':
              bytes += generator.text(_normalizeString('*** OSHXONA ***'), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
              break;
          }
        }
      }

      bytes += generator.feed(3);
      bytes += generator.cut();
      return await _sendToPrinter(printer, bytes);
    } catch (e) {
      print('Manual layout print failed: $e');
      return false;
    }
  }

  Future<bool> printKitchenTicket(PrinterModel printer, Map<String, dynamic> order, List<dynamic> items, {String? title}) async {
    final orderForKitchen = Map<String, dynamic>.from(order);
    orderForKitchen['details'] = items;
    return await printReceipt(printer, orderForKitchen, title: title, isKitchenOnly: true);
  }

  Future<bool> printCancellationTicket(PrinterModel printer, Map<String, dynamic> order, List<dynamic> items, {String? title}) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty || items.isEmpty) return false;

    try {
      final profile = await _getProfile();
      final generator = Generator(
          printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      
      List<int> bytes = [];

      // Large Header - Red-like warning (Capitalized and Bold)
      bytes += generator.feed(1);
      bytes += generator.text(_normalizeString(title != null ? '!!! $title !!!' : '!!! BEKOR QILINDI !!!'),
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true,
          ));
      bytes += generator.hr(ch: '*');

      // Order & Table Info
      bytes += generator.text(_normalizeString('STOL: ${order['table']}'), 
          styles: const PosStyles(height: PosTextSize.size2, width: PosTextSize.size2, bold: true, align: PosAlign.center));
      bytes += generator.text(_normalizeString('BUYURTMA: #${order['id']}'), 
          styles: const PosStyles(height: PosTextSize.size1, width: PosTextSize.size1, bold: true, align: PosAlign.center));
      
      bytes += generator.feed(1);
      bytes += generator.text(_normalizeString('VAQT: ${DateFormat('HH:mm').format(DateTime.now())}'), styles: const PosStyles(align: PosAlign.center));
      if (order['waiter_name'] != null && order['waiter_name'].toString().isNotEmpty) {
        bytes += generator.text(_normalizeString('AFITSANT: ${order['waiter_name']}'), styles: const PosStyles(align: PosAlign.center, bold: true));
      }
      bytes += generator.hr(ch: '-');

      // Cancelled Items
      for (var item in items) {
        bytes += generator.row([
          PosColumn(text: _normalizeString('${item['qty']} x'), width: 3, styles: const PosStyles(height: PosTextSize.size2, width: PosTextSize.size2, bold: true)),
          PosColumn(text: _normalizeString('${item['name']}'), width: 9, styles: const PosStyles(height: PosTextSize.size2, width: PosTextSize.size1, bold: true)),
        ]);
        bytes += generator.hr(ch: '-');
      }

      bytes += generator.feed(3);
      bytes += generator.cut();

      final socket = await Socket.connect(printer.ipAddress, printer.port,
          timeout: const Duration(seconds: 2));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      
      return true;
    } catch (e) {
      print('Cancellation printing error: $e');
      return false;
    }
  }

  Future<bool> printTestPage(PrinterModel printer) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;

    try {
      final profile = await _getProfile();
      final generator = Generator(
          printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.text('TEST PRINT',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true,
          ));
      bytes += generator.text('Printer: ${printer.name}', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('IP: ${printer.ipAddress}', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text('Port: ${printer.port}', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();
      bytes += generator.text('If you see this, your printer is working correctly.', styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(3);
      bytes += generator.cut();

      final socket = await Socket.connect(printer.ipAddress, printer.port,
          timeout: const Duration(seconds: 2));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      print('Test print error: $e');
      return false;
    }
  }

  // ─── Direct ESC/POS Report Printing ───────────────────────────────────────

  Future<bool> printXorZReport(PrinterModel printer, List<Map<String, dynamic>> orders, {required String title, String? cashierName}) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;
    try {
      final profile = await _getProfile();
      final generator = Generator(printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];
      final posController = Get.find<POSController>();
      final String currency = posController.currencySymbol;

      bytes += generator.text(_normalizeString(posController.restaurantName.value.toUpperCase()), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
      bytes += generator.text(_normalizeString('*** $title ***'), styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text(_normalizeString(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())), styles: const PosStyles(align: PosAlign.center));
      if (cashierName != null) bytes += generator.text(_normalizeString('KASSIR: $cashierName'), styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();

      double totalRevenue = 0;
      double dineInRevenue = 0, takeawayRevenue = 0, deliveryRevenue = 0;
      int dineInCount = 0, takeawayCount = 0, deliveryCount = 0;

      for (var o in orders) {
        final double total = (o['total'] as num).toDouble();
        totalRevenue += total;
        final mode = (o['mode'] ?? '').toString().toLowerCase();
        if (mode.contains('dine')) { dineInRevenue += total; dineInCount++; }
        else if (mode.contains('take')) { takeawayRevenue += total; takeawayCount++; }
        else if (mode.contains('deliv')) { deliveryRevenue += total; deliveryCount++; }
      }

      bytes += generator.row([
        PosColumn(text: _normalizeString('JAMI BUYURTMALAR:'), width: 8),
        PosColumn(text: _normalizeString('${orders.length}'), width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
      bytes += generator.row([
        PosColumn(text: _normalizeString('JAMI SAVDO:'), width: 6),
        PosColumn(text: _normalizeString('${_formatPrice(totalRevenue)} $currency'), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.hr();

      bytes += generator.text(_normalizeString('SAVDO TURLARI BO\'YICHA'), styles: const PosStyles(bold: true));
      if (dineInCount > 0) bytes += _row(generator, 'ZALDA ($dineInCount)', _formatPrice(dineInRevenue));
      if (takeawayCount > 0) bytes += _row(generator, 'OLIB KETISH ($takeawayCount)', _formatPrice(takeawayRevenue));
      if (deliveryCount > 0) bytes += _row(generator, 'YETKAZIB BERISH ($deliveryCount)', _formatPrice(deliveryRevenue));
      
      bytes += generator.feed(3);
      bytes += generator.cut();
      return await _sendToPrinter(printer, bytes);
    } catch (e) { return false; }
  }

  Future<bool> printCategoryReport(PrinterModel printer, List<Map<String, dynamic>> orders, String title) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;
    try {
      final profile = await _getProfile();
      final generator = Generator(printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];
      final posController = Get.find<POSController>();
      final String currency = posController.currencySymbol;

      bytes += generator.text(_normalizeString('KATEGORIYA HISOBOTI'), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size1, width: PosTextSize.size1));
      bytes += generator.text(_normalizeString(title), styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();

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
      for (var e in sorted) {
        bytes += generator.text(_normalizeString(e.key.toUpperCase()), styles: const PosStyles(bold: true));
        bytes += _row(generator, '  Soni: ${catQty[e.key]}', '${_formatPrice(e.value)} $currency');
      }

      bytes += generator.hr();
      bytes += _row(generator, 'JAMI:', _formatPrice(totalRevenue), bold: true);
      bytes += generator.feed(3);
      bytes += generator.cut();
      return await _sendToPrinter(printer, bytes);
    } catch (e) { return false; }
  }

  Future<bool> printPaymentMethodReport(PrinterModel printer, List<Map<String, dynamic>> orders, String title) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;
    try {
      final profile = await _getProfile();
      final generator = Generator(printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];
      final posController = Get.find<POSController>();

      bytes += generator.text(_normalizeString('TO\'LOV TURLARI'), styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.hr();

      final Map<String, double> methods = {'Cash': 0.0, 'Card': 0.0, 'Click': 0.0, 'Payme': 0.0, 'Other': 0.0};
      double total = 0;

      for (var o in orders) {
        final m = o['payment_method']?.toString() ?? 'Other';
        final val = (o['total'] as num).toDouble();
        methods[m] = (methods[m] ?? 0) + val;
        total += val;
      }

      methods.forEach((key, value) {
        if (value > 0) bytes += _row(generator, key.toUpperCase(), _formatPrice(value));
      });

      bytes += generator.hr();
      bytes += _row(generator, 'JAMI:', _formatPrice(total), bold: true);
      bytes += generator.feed(3);
      bytes += generator.cut();
      return await _sendToPrinter(printer, bytes);
    } catch (e) { return false; }
  }

  Future<bool> printHourlySalesReport(PrinterModel printer, List<Map<String, dynamic>> orders, String title) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;
    try {
      final profile = await _getProfile();
      final generator = Generator(printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.text(_normalizeString('SOATBAY SAVDO'), styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.hr();

      final Map<int, double> hourly = {};
      for (var o in orders) {
        final dt = DateTime.tryParse(o['timestamp'] ?? '');
        if (dt != null) hourly[dt.hour] = (hourly[dt.hour] ?? 0) + (o['total'] as num).toDouble();
      }

      for (int i = 0; i < 24; i++) {
        if (hourly.containsKey(i)) {
          bytes += _row(generator, '$i:00 - ${i + 1}:00', _formatPrice(hourly[i]));
        }
      }

      bytes += generator.feed(3);
      bytes += generator.cut();
      return await _sendToPrinter(printer, bytes);
    } catch (e) { return false; }
  }

  Future<bool> printSalesReport(PrinterModel printer, List<Map<String, dynamic>> orders, String title) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;
    try {
      final profile = await _getProfile();
      final generator = Generator(printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.text(_normalizeString('SAVDO HISOBOTI'), styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text(_normalizeString(title), styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();

      Map<String, int> qty = {};
      Map<String, double> revenue = {};
      for (var o in orders) {
        for (var item in (o['details'] as List? ?? [])) {
          final n = item['name']?.toString() ?? 'Nomalum';
          qty[n] = (qty[n] ?? 0) + (item['qty'] as num).toInt();
          revenue[n] = (revenue[n] ?? 0) + ((item['price'] as num).toDouble() * (item['qty'] as num).toInt());
        }
      }

      final sorted = qty.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (var e in sorted) {
        bytes += generator.text(_normalizeString(e.key.toUpperCase()));
        bytes += _row(generator, '  ${e.value} ta', _formatPrice(revenue[e.key]));
      }

      bytes += generator.feed(3);
      bytes += generator.cut();
      return await _sendToPrinter(printer, bytes);
    } catch (e) { return false; }
  }

  Future<bool> printWaiterPerformanceReport(PrinterModel printer, List<Map<String, dynamic>> orders, String period) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;
    try {
      final profile = await _getProfile();
      final generator = Generator(printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.text(_normalizeString('OFITSIANTLAR UNUMDORLIGI'), styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text(_normalizeString('Davr: $period'), styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();

      final Map<String, Map<String, dynamic>> map = {};
      for (var o in orders) {
        final name = (o['waiter_name'] ?? 'Nomaylum').toString();
        final total = (o['total'] as num? ?? 0).toDouble();
        if (!map.containsKey(name)) {
          map[name] = {'name': name, 'orders': 0, 'revenue': 0.0};
        }
        map[name]!['orders'] = (map[name]!['orders'] as int) + 1;
        map[name]!['revenue'] = (map[name]!['revenue'] as double) + total;
      }

      final list = map.values.toList();
      list.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

      for (var w in list) {
        bytes += generator.text(_normalizeString(w['name'].toString().toUpperCase()), styles: const PosStyles(bold: true));
        bytes += _row(generator, '  ${w['orders']} buyurtma', _formatPrice(w['revenue']));
      }

      bytes += generator.feed(3);
      bytes += generator.cut();
      return await _sendToPrinter(printer, bytes);
    } catch (e) { return false; }
  }

  List<int> _row(Generator g, String left, String right, {bool bold = false}) {
    return g.row([
      PosColumn(text: _normalizeString(left), width: 7, styles: PosStyles(bold: bold)),
      PosColumn(text: _normalizeString(right), width: 5, styles: PosStyles(align: PosAlign.right, bold: bold)),
    ]);
  }

  Future<bool> _sendToPrinter(PrinterModel printer, List<int> bytes) async {
    try {
      final socket = await Socket.connect(printer.ipAddress, printer.port, timeout: const Duration(seconds: 2));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) { return false; }
  }

  Future<bool> printPdfAsImage(PrinterModel printer, Uint8List pdfBytes) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;

    try {
      final profile = await _getProfile();
      final generator = Generator(
          printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      
      List<int> bytes = [];
      
      // Render PDF to images (page by page, though reports are usually 1 page)
      await for (var page in Printing.raster(pdfBytes, pages: null, dpi: 200)) {
        final bitmap = await page.toImage(); 
        final byteData = await bitmap.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) continue;
        
        final image = img.decodeImage(byteData.buffer.asUint8List());
        if (image != null) {
          // Adjust width for thermal printer
          final maxWidth = printer.paperSize == '58mm' ? 384 : 512;
          img.Image resized = image;
          if (image.width > maxWidth) {
             resized = img.copyResize(image, width: maxWidth);
          }
          
          bytes += generator.image(resized);
        }
      }
      
      bytes += generator.feed(3);
      bytes += generator.cut();

      final socket = await Socket.connect(printer.ipAddress, printer.port,
          timeout: const Duration(seconds: 10));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      print('PDF thermal print error: $e');
      return false;
    }
  }
}

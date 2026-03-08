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
    
    // Comprehensive Cyrillic to Latin transliteration for printers without Cyrillic support
    Map<String, String> replacements = {
      'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'Yo', 'Ж': 'Zh', 
      'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M', 'Н': 'N', 'О': 'O', 
      'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U', 'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts', 
      'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Sch', 'Ъ': '', 'Ы': 'Y', 'Ь': '', 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo', 'ж': 'zh', 
      'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o', 
      'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts', 
      'ч': 'ch', 'ш': 'sh', 'щ': 'sch', 'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
      'Ў': 'O\'', 'ў': 'o\'', 'Қ': 'Q', 'қ': 'q', 'Ғ': 'G\'', 'ғ': 'g\'', 'Ҳ': 'H', 'ҳ': 'h',
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
        bytes += generator.text(_normalizeString(posController.restaurantName.value), styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
        if (posController.restaurantAddress.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.restaurantAddress.value), styles: const PosStyles(align: PosAlign.center));
        bytes += generator.hr();
        bytes += generator.text(_normalizeString(title ?? 'BUYURTMA'), styles: const PosStyles(align: PosAlign.center, bold: true));
        bytes += generator.text(_normalizeString('ID: ${order['id']}'), styles: const PosStyles(align: PosAlign.center));
        bytes += generator.text(_normalizeString(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())), styles: const PosStyles(align: PosAlign.center));
        if (order['table'] != null && order['table'] != '-') bytes += generator.text(_normalizeString('STOL: ${order['table']}'), styles: const PosStyles(align: PosAlign.center, bold: true));
        bytes += generator.hr();
        
        final items = (order['details'] as List);
        for (var item in items) {
          int qty = int.tryParse(item['qty'].toString()) ?? 0;
          double price = double.tryParse(item['price'].toString()) ?? 0.0;
          double lineTotal = qty * price;
          
          bytes += generator.text(_normalizeString(item['name']), styles: PosStyles(bold: true, height: isKitchenOnly ? PosTextSize.size2 : PosTextSize.size1));
          
          if (isKitchenOnly) {
             bytes += generator.text(_normalizeString('SONI: $qty ta'), styles: const PosStyles(bold: true, height: PosTextSize.size2));
          } else {
            bytes += generator.row([
              PosColumn(text: _normalizeString('  $qty x ${_formatPrice(price)}'), width: 7, styles: const PosStyles(fontType: PosFontType.fontB)),
              PosColumn(text: _normalizeString(_formatPrice(lineTotal)), width: 5, styles: const PosStyles(align: PosAlign.right)),
            ]);
          }
        }
        bytes += generator.hr();
        
        if (!isKitchenOnly) {
          // Use the same logic as TOTAL_BLOCK for the fallback
          double subtotal = 0;
          for (var item in items) {
            subtotal += (double.tryParse(item['price'].toString()) ?? 0.0) * (int.tryParse(item['qty'].toString()) ?? 0);
          }

          bytes += _row(generator, 'SUMMA:', _formatPrice(subtotal));

          double feePercent = 0.0;
          double feeFixed = 0.0;
          final String mode = (order['mode'] ?? "Dine-in").toString().toLowerCase();
          if (mode.contains("dine")) feePercent = (order['service_fee_dine_in'] as num?)?.toDouble() ?? 10.0;
          else if (mode.contains("takeaway")) feeFixed = (order['service_fee_takeaway'] as num?)?.toDouble() ?? 0.0;
          else if (mode.contains("delivery")) feeFixed = (order['service_fee_delivery'] as num?)?.toDouble() ?? 0.0;

          double feeAmt = feeFixed;
          if (feePercent > 0) {
            feeAmt = subtotal * (feePercent / 100);
            bytes += _row(generator, 'XIZMAT (${feePercent.toInt()}%):', _formatPrice(feeAmt));
          } else if (feeFixed > 0) {
            bytes += _row(generator, 'XIZMAT:', _formatPrice(feeAmt));
          }

          final double discountAmt = (order['discount_amount'] as num?)?.toDouble() ?? 0.0;
          if (discountAmt > 0) bytes += _row(generator, 'CHEGIRMA:', '-${_formatPrice(discountAmt)}', styles: const PosStyles(bold: true));

          double finalTotal = subtotal + feeAmt - discountAmt;
          if (finalTotal < 0) finalTotal = 0;
          
          bytes += generator.hr(ch: '=');
          bytes += generator.row([
            PosColumn(text: _normalizeString('JAMI:'), width: 5, styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
            PosColumn(text: _normalizeString(_formatPrice(finalTotal)), width: 7, styles: const PosStyles(align: PosAlign.right, bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
          ]);
          bytes += generator.hr(ch: '=');
        }
      } else {
        for (int i = 0; i < layout.length; i++) {
          var element = layout[i];
          if (!(element['enabled'] ?? true)) continue;

          final width = element['width'] ?? 100;
          
          if (width == 50 && i + 1 < layout.length) {
            int nextEnabledIdx = -1;
            for (int j = i + 1; j < layout.length; j++) {
              if (layout[j]['enabled'] ?? true) {
                nextEnabledIdx = j;
                break;
              }
            }

            if (nextEnabledIdx != -1 && layout[nextEnabledIdx]['width'] == 50) {
              var elLeft = element;
              var elRight = layout[nextEnabledIdx];
              
              bytes += _printSideBySide(generator, elLeft, elRight, order, posController);
              
              i = nextEnabledIdx;
              continue;
            }
          }

          bytes += await _printElement(generator, element, order, posController, printer, title, isKitchenOnly);
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

  PosStyles _getStyles(Map<String, dynamic> element, {bool defaultBold = false, PosAlign defaultAlign = PosAlign.center, PosTextSize defaultSize = PosTextSize.size1}) {
    final props = element['props'] ?? {};
    
    PosAlign align = defaultAlign;
    if (props['align'] == 'LEFT') align = PosAlign.left;
    else if (props['align'] == 'CENTER') align = PosAlign.center;
    else if (props['align'] == 'RIGHT') align = PosAlign.right;

    bool bold = props['bold'] ?? defaultBold;
    
    PosTextSize size = defaultSize;
    if (props['size'] == 'LARGE') size = PosTextSize.size2;
    else if (props['size'] == 'XLARGE') size = PosTextSize.size3;
    else if (props['size'] == 'NORMAL') size = PosTextSize.size1;

    PosFontType font = PosFontType.fontA;
    if (props['font'] == 'B') font = PosFontType.fontB;

    return PosStyles(
      align: align,
      bold: bold,
      height: size,
      width: size,
      fontType: font,
    );
  }

  Future<List<int>> _printElement(Generator generator, Map<String, dynamic> element, Map<String, dynamic> order, POSController posController, PrinterModel printer, String? title, bool isKitchenOnly) async {
    List<int> bytes = [];
    final type = element['type'];
    final styles = _getStyles(element);

    switch (type) {
      case 'HEADER':
      case 'STORE_NAME':
        bytes += generator.text(_normalizeString(posController.restaurantName.value), styles: _getStyles(element, defaultBold: true, defaultSize: PosTextSize.size2));
        if (posController.restaurantAddress.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.restaurantAddress.value), styles: _getStyles(element));
        if (posController.restaurantPhone.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.restaurantPhone.value), styles: _getStyles(element));
        break;
      case 'LOGO':
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
                bytes += generator.image(resized, align: styles.align);
              }
            }
          } catch (e) { print('Logo error: $e'); }
        }
        break;
      case 'STORE_ADDRESS':
        if (posController.restaurantAddress.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.restaurantAddress.value), styles: styles);
        break;
      case 'STORE_PHONE':
        if (posController.restaurantPhone.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.restaurantPhone.value), styles: styles);
        break;
      case 'ORDER_INFO':
        if (title != null) bytes += generator.text(_normalizeString(title.toUpperCase()), styles: _getStyles(element, defaultBold: true));
        bytes += generator.text(_normalizeString('ID: ${order['id'].toString().substring(0, order['id'].toString().length > 8 ? 8 : order['id'].toString().length)}'), styles: styles);
        bytes += generator.text(_normalizeString(DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())), styles: styles);
        if (order['table'] != null && order['table'] != '-') {
           bytes += generator.text(_normalizeString('STOL: ${order['table']}'), styles: _getStyles(element, defaultBold: true, defaultSize: PosTextSize.size2));
        }
        if (order['waiter_name'] != null && order['waiter_name'].toString().isNotEmpty) {
           bytes += generator.text(_normalizeString('OFITSIANT: ${order['waiter_name']}'), styles: styles);
        }
        break;
      case 'ITEMS_TABLE':
        bytes += generator.hr(ch: '-');
        final items = order['details'] as List;
        for (var item in items) {
          int qty = int.tryParse(item['qty'].toString()) ?? 0;
          double price = double.tryParse(item['price'].toString()) ?? 0.0;
          double lineTotal = qty * price;
          
          // Print Name (Full width, bold)
          bytes += generator.text(_normalizeString(item['name']), 
              styles: styles.copyWith(bold: true, fontType: PosFontType.fontA, height: isKitchenOnly ? PosTextSize.size2 : PosTextSize.size1));
          
          if (isKitchenOnly) {
            // Kitchen: Only Quantity (Large)
            bytes += generator.text(_normalizeString('SONI: $qty ta'), 
                styles: styles.copyWith(bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
          } else {
            // Bill: Quantity x Price and Total
            bytes += generator.row([
              PosColumn(
                  text: _normalizeString('  $qty x ${_formatPrice(price)}'), 
                  width: 7, 
                  styles: styles.copyWith(fontType: PosFontType.fontB)),
              PosColumn(
                  text: _normalizeString(_formatPrice(lineTotal)), 
                  width: 5, 
                  styles: styles.copyWith(align: PosAlign.right, fontType: PosFontType.fontA)),
            ]);
          }
        }
        bytes += generator.hr(ch: '-');
        break;
      case 'TOTAL_BLOCK':
        if (isKitchenOnly) break; // Don't show totals in kitchen
        double subtotal = 0;
        final items = (order['details'] as List);
        for (var item in items) {
          subtotal += (double.tryParse(item['price'].toString()) ?? 0.0) * (int.tryParse(item['qty'].toString()) ?? 0);
        }
        
        bytes += _row(generator, 'SUMMA:', _formatPrice(subtotal), styles: styles);
        
        // Calculate Service Fee
        double feePercent = 0.0;
        double feeFixed = 0.0;
        final String mode = (order['mode'] ?? "Dine-in").toString().toLowerCase();
        
        if (mode.contains("dine")) {
          feePercent = (order['service_fee_dine_in'] as num?)?.toDouble() ?? 10.0;
        } else if (mode.contains("takeaway")) {
          feeFixed = (order['service_fee_takeaway'] as num?)?.toDouble() ?? 0.0;
        } else if (mode.contains("delivery")) {
          feeFixed = (order['service_fee_delivery'] as num?)?.toDouble() ?? 0.0;
        }
 
        double feeAmt = feeFixed;
        if (feePercent > 0) {
          feeAmt = subtotal * (feePercent / 100);
          bytes += _row(generator, 'XIZMAT (${feePercent.toInt()}%):', _formatPrice(feeAmt), styles: styles);
        } else if (feeFixed > 0) {
          bytes += _row(generator, 'XIZMAT:', _formatPrice(feeAmt), styles: styles);
        }
 
        final double discountAmt = (order['discount_amount'] as num?)?.toDouble() ?? 0.0;
        if (discountAmt > 0) {
          bytes += _row(generator, 'CHEGIRMA:', '-${_formatPrice(discountAmt)}', styles: styles.copyWith(bold: true));
        }
        
        double finalTotal = subtotal + feeAmt - discountAmt;
        if (finalTotal < 0) finalTotal = 0;
 
        bytes += generator.hr(ch: '=');
        bytes += generator.row([
          PosColumn(text: _normalizeString('JAMI:'), width: 5, styles: styles.copyWith(bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
          PosColumn(text: _normalizeString('${_formatPrice(finalTotal)}'), width: 7, styles: styles.copyWith(bold: true, align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2)),
        ]);
        bytes += generator.hr(ch: '=');
        break;
      case 'DIVIDER':
        bytes += generator.hr(ch: '-');
        break;
      case 'SPACER':
        bytes += generator.feed(1);
        break;
      case 'INSTAGRAM_QR':
        String instaLink = posController.instagramLink.value;
        if (instaLink.isEmpty && posController.instagram.value.isNotEmpty) {
           instaLink = "https://instagram.com/${posController.instagram.value.replaceAll('@', '')}";
        }
        if (instaLink.isNotEmpty) {
          bytes += generator.text(_normalizeString('INSTAGRAM'), styles: styles.copyWith(bold: true));
          bytes += generator.qrcode(instaLink, size: _getQRSize(element['props']?['size']), align: styles.align);
        }
        break;
      case 'TELEGRAM_QR':
        String tgLink = posController.telegramLink.value;
        if (tgLink.isEmpty && posController.telegram.value.isNotEmpty) {
           tgLink = "https://t.me/${posController.telegram.value.replaceAll('t.me/', '')}";
        }
        if (tgLink.isNotEmpty) {
          bytes += generator.text(_normalizeString('TELEGRAM'), styles: styles.copyWith(bold: true));
          bytes += generator.qrcode(tgLink, size: _getQRSize(element['props']?['size']), align: styles.align);
        }
        break;
      case 'FOOTER':
        if (posController.receiptFooter.value.isNotEmpty) bytes += generator.text(_normalizeString(posController.receiptFooter.value), styles: styles.copyWith(bold: true));
        if (posController.instagram.value.isNotEmpty) bytes += generator.text(_normalizeString('Insta: @${posController.instagram.value.replaceAll('@', '')}'), styles: styles);
        if (posController.telegram.value.isNotEmpty) bytes += generator.text(_normalizeString('TG: t.me/${posController.telegram.value.replaceAll('t.me/', '')}'), styles: styles);
        break;
      case 'WIFI_INFO':
         if (posController.wifiSsid.value.isNotEmpty) {
           bytes += generator.text(_normalizeString('Wi-Fi: ${posController.wifiSsid.value}'), styles: styles);
           bytes += generator.text(_normalizeString('Parol: ${posController.wifiPassword.value}'), styles: styles);
         }
         break;
      case 'KITCHEN_TITLE':
        bytes += generator.text(_normalizeString(element['props']?['title'] ?? '*** OSHXONA ***'), styles: _getStyles(element, defaultBold: true, defaultSize: PosTextSize.size2));
        break;
    }
    return bytes;
  }

  QRSize _getQRSize(String? size) {
    if (size == 'LARGE') return QRSize.size5;
    if (size == 'XLARGE') return QRSize.size6;
    return QRSize.size4;
  }

  List<int> _row(Generator g, String left, String right, {PosStyles? styles}) {
    final s = styles ?? const PosStyles();
    return g.row([
      PosColumn(text: _normalizeString(left), width: 7, styles: s),
      PosColumn(text: _normalizeString(right), width: 5, styles: s.copyWith(align: PosAlign.right)),
    ]);
  }

  List<int> _printSideBySide(Generator generator, Map<String, dynamic> elL, Map<String, dynamic> elR, Map<String, dynamic> order, POSController posController) {
    String getLabel(Map<String, dynamic> el) {
      if (el['type'] == 'INSTAGRAM_QR') return 'INSTAGRAM';
      if (el['type'] == 'TELEGRAM_QR') return 'TELEGRAM';
      if (el['type'] == 'WIFI_INFO') return 'WI-FI';
      return el['label'] ?? "";
    }

    final stylesL = _getStyles(elL);
    final stylesR = _getStyles(elR);

    List<int> bytes = [];
    bytes += generator.row([
      PosColumn(text: _normalizeString(getLabel(elL)), width: 6, styles: stylesL.copyWith(align: PosAlign.center, bold: true)),
      PosColumn(text: _normalizeString(getLabel(elR)), width: 6, styles: stylesR.copyWith(align: PosAlign.center, bold: true)),
    ]);
    
    return bytes;
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
        bytes += generator.text(_normalizeString(item['name']), styles: const PosStyles(bold: true, height: PosTextSize.size2));
        bytes += generator.text(_normalizeString('BEKOR: ${item['qty']} ta'), styles: const PosStyles(bold: true, height: PosTextSize.size2));
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
      bytes += _row(generator, 'JAMI:', _formatPrice(totalRevenue), styles: const PosStyles(bold: true));
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
      bytes += _row(generator, 'JAMI:', _formatPrice(total), styles: const PosStyles(bold: true));
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

  Future<bool> _sendToPrinter(PrinterModel printer, List<int> bytes) async {
    try {
      final socket = await Socket.connect(printer.ipAddress, printer.port, timeout: const Duration(seconds: 5));
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

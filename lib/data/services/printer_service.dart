import 'dart:io';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/printer_model.dart';
import '../../logic/pos_controller.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  Future<bool> printReceipt(PrinterModel printer, Map<String, dynamic> order) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(
          printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      
      List<int> bytes = [];

      final posController = Get.find<POSController>();

      // Header - Restaurant Identity
      bytes += generator.text(posController.restaurantName.value,
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true,
          ));
      
      if (posController.restaurantAddress.value.isNotEmpty) {
        bytes += generator.text(posController.restaurantAddress.value,
            styles: const PosStyles(align: PosAlign.center));
      }
      if (posController.restaurantPhone.value.isNotEmpty) {
        bytes += generator.text(posController.restaurantPhone.value,
            styles: const PosStyles(align: PosAlign.center));
      }
      bytes += generator.feed(1);
      bytes += generator.text('*** TO\'LOV CHEKI ***', styles: const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.hr();

      // Order Metadata
      bytes += generator.text('Buyurtma: #${order['id']}', styles: const PosStyles(bold: true));
      bytes += generator.text('Sana: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}');
      
      String modeName = "Zalda";
      if (order['mode'] == "Takeaway") modeName = "Olib ketish";
      else if (order['mode'] == "Delivery") modeName = "Yetkazib berish";
      
      bytes += generator.text('Turi: $modeName');
      if (order['table'] != null && order['table'] != '-') {
        bytes += generator.text('Stol: ${order['table']}', styles: const PosStyles(bold: true));
      }
      bytes += generator.hr();

      // Items Table Header
      bytes += generator.row([
        PosColumn(text: 'Nomi', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Soni', width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
        PosColumn(text: 'Narxi', width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.hr(ch: '-');

      // Items Calculation and Printing
      final items = order['details'] as List;
      double itemsSubtotal = 0;
      for (var item in items) {
        double price = double.tryParse(item['price'].toString()) ?? 0.0;
        int qty = int.tryParse(item['qty'].toString()) ?? 0;
        double lineTotal = price * qty;
        itemsSubtotal += lineTotal;

        bytes += generator.row([
          PosColumn(text: item['name'], width: 6),
          PosColumn(text: qty.toString(), width: 2, styles: const PosStyles(align: PosAlign.center)),
          PosColumn(text: lineTotal.toStringAsFixed(0), width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      bytes += generator.hr();

      // Totals
      // Calculate breakdown based on the same logic as frontend
      double serviceFee = 0;
      if (order['mode'] == "Dine-in") {
        serviceFee = itemsSubtotal * 0.10;
      } else if (order['mode'] == "Delivery") {
        serviceFee = 3.00; // Use simple logic for now or get from order
      }
      
      double tax = itemsSubtotal * 0.05;
      double finalTotal = itemsSubtotal + serviceFee + tax;

      bytes += generator.row([
        PosColumn(text: 'Subtotal:', width: 8),
        PosColumn(text: '${itemsSubtotal.toStringAsFixed(0)} sum', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);

      if (serviceFee > 0) {
        bytes += generator.row([
          PosColumn(text: 'Xizmat haqi:', width: 8),
          PosColumn(text: '${serviceFee.toStringAsFixed(0)} sum', width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.row([
        PosColumn(text: 'Soliq (5%):', width: 8),
        PosColumn(text: '${tax.toStringAsFixed(0)} sum', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.hr(ch: '=');
      bytes += generator.row([
        PosColumn(text: 'JAMI:', width: 6, styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size1)),
        PosColumn(text: '${finalTotal.toStringAsFixed(0)} sum', width: 6, styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size1)),
      ]);
      bytes += generator.hr(ch: '=');

      // Footer
      bytes += generator.feed(1);
      bytes += generator.text('Xaridingiz uchun rahmat!', styles: const PosStyles(align: PosAlign.center, italic: true));
      bytes += generator.text('Yana keling!', styles: const PosStyles(align: PosAlign.center));
      
      bytes += generator.feed(3);
      bytes += generator.cut();

      // Send to printer
      final socket = await Socket.connect(printer.ipAddress, printer.port,
          timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      
      return true;
    } catch (e) {
      print('Printing error: $e');
      return false;
    }
  }

  Future<bool> printKitchenTicket(PrinterModel printer, Map<String, dynamic> order, List<dynamic> items) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty || items.isEmpty) return false;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(
          printer.paperSize == '58mm' ? PaperSize.mm58 : PaperSize.mm80, profile);
      
      List<int> bytes = [];

      // Large Header
      bytes += generator.text('KITCHEN TICKET',
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true,
          ));
      
      bytes += generator.hr();
      bytes += generator.text('Order ID: #${order['id']}', styles: const PosStyles(height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
      bytes += generator.text('Table: ${order['table']}', styles: const PosStyles(height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
      bytes += generator.text('Time: ${DateFormat('HH:mm').format(DateTime.now())}');
      bytes += generator.hr();

      // Items
      for (var item in items) {
        bytes += generator.text('${item['qty']} x ${item['name']}', 
            styles: const PosStyles(height: PosTextSize.size2, width: PosTextSize.size2, bold: true));
        if (item['note'] != null && item['note'].toString().isNotEmpty) {
          bytes += generator.text(' NOTE: ${item['note']}');
        }
        bytes += generator.feed(1);
      }

      bytes += generator.hr();
      bytes += generator.feed(2);
      bytes += generator.cut();

      final socket = await Socket.connect(printer.ipAddress, printer.port,
          timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      
      return true;
    } catch (e) {
      print('Kitchen printing error: $e');
      return false;
    }
  }

  Future<bool> printTestPage(PrinterModel printer) async {
    if (printer.ipAddress == null || printer.ipAddress!.isEmpty) return false;

    try {
      final profile = await CapabilityProfile.load();
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
          timeout: const Duration(seconds: 5));
      socket.add(bytes);
      await socket.flush();
      await socket.close();
      return true;
    } catch (e) {
      print('Test print error: $e');
      return false;
    }
  }
}

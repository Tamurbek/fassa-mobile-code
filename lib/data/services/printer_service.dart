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

      // Header
      bytes += generator.text(Get.find<POSController>().restaurantName.value,
          styles: const PosStyles(
            align: PosAlign.center,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
            bold: true,
          ));
      
      bytes += generator.text(Get.find<POSController>().restaurantAddress.value,
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(Get.find<POSController>().restaurantPhone.value,
          styles: const PosStyles(align: PosAlign.center));
      bytes += generator.hr();

      // Order Info
      bytes += generator.text('Order ID: ${order['id']}',
          styles: const PosStyles(bold: true));
      bytes += generator.text('Date: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}');
      bytes += generator.text('Mode: ${order['mode']}');
      if (order['table'] != null && order['table'] != '-') {
        bytes += generator.text('Table: ${order['table']}');
      }
      bytes += generator.hr();

      // Items Header
      bytes += generator.row([
        PosColumn(text: 'Item', width: 7, styles: const PosStyles(bold: true)),
        PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
        PosColumn(text: 'Total', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);
      bytes += generator.hr(ch: '-');

      // Items
      final items = order['details'] as List;
      for (var item in items) {
        bytes += generator.row([
          PosColumn(text: item['name'], width: 7),
          PosColumn(text: item['qty'].toString(), width: 2, styles: const PosStyles(align: PosAlign.center)),
          PosColumn(text: (item['price'] * item['qty']).toStringAsFixed(0), width: 3, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      bytes += generator.hr();

      // Totals
      bytes += generator.row([
        PosColumn(text: 'Total Amount:', width: 8, styles: const PosStyles(bold: true)),
        PosColumn(text: order['total'].toStringAsFixed(0), width: 4, styles: const PosStyles(bold: true, align: PosAlign.right)),
      ]);

      bytes += generator.feed(2);
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
          bytes += generator.text(' NOTE: ${item['note']}', styles: const PosStyles(italic: true));
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

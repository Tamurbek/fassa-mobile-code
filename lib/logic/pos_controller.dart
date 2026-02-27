import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:io';
import '../data/models/food_item.dart';
import 'package:dio/dio.dart';
import '../data/models/printer_model.dart';
import '../data/models/preparation_area_model.dart';
import 'controller_parts/pos_controller_state.dart';
import 'controller_parts/user_auth_mixin.dart';
import 'controller_parts/data_sync_mixin.dart';
import 'controller_parts/order_mixin.dart';
import 'controller_parts/printer_mixin.dart';
import 'controller_parts/product_mixin.dart';
import 'controller_parts/staff_mixin.dart';
import 'controller_parts/table_mixin.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../presentation/pages/main_navigation_screen.dart';
import '../data/services/offline_service.dart';

class POSController extends POSControllerState with 
    UserAuthMixin, 
    DataSyncMixin, 
    OrderMixin, 
    PrinterMixin, 
    ProductMixin, 
    StaffMixin,
    TableMixin {

  final Map<String, DateTime> _processedPrintIds = {};

  @override
  void onInit() {
    super.onInit();
    _loadLocalData();
    fetchBackendData();
    _setupSocketListenersDetailed();
    updateService.checkForUpdate();
    startSubscriptionCheck();
    initLocationTracking();
  }

  @override
  void onClose() {
    searchController.dispose();
    searchFocusNode.dispose();
    subscriptionTimer?.cancel();
    locationTimer?.cancel();
    super.onClose();
  }

  void _loadLocalData() {
    var storedAllOrders = storage.read('all_orders');
    if (storedAllOrders != null) {
      allOrders.assignAll(List<Map<String, dynamic>>.from(storedAllOrders));
    }

    deviceRole.value = storage.read('device_role');
    waiterCafeId.value = storage.read('waiter_cafe_id');
    currentUser.value = storage.read('user');
    currentTerminal.value = storage.read('terminal');
    pinCode.value = storage.read('pin_code');

    var storedProducts = storage.read('products');
    if (storedProducts != null) {
      products.assignAll(List<Map<String, dynamic>>.from(storedProducts)
          .map((e) => FoodItem.fromJson(e)).toList());
    }

    var storedCategories = storage.read('categories_objects');
    if (storedCategories != null) {
      categoriesObjects.assignAll(List<Map<String, dynamic>>.from(storedCategories));
      categories.assignAll(["All", ...categoriesObjects.map((c) => c['name'].toString())]);
    }

    var storedPrepAreas = storage.read('preparation_areas');
    if (storedPrepAreas != null) {
      preparationAreas.assignAll(List<Map<String, dynamic>>.from(storedPrepAreas)
          .map((e) => PreparationAreaModel.fromJson(e)).toList());
    }

    var storedPrinters = storage.read('printers');
    if (storedPrinters != null) {
      printers.assignAll(List<Map<String, dynamic>>.from(storedPrinters)
          .map((e) => PrinterModel.fromJson(e)).toList());
    }

    var storedLocs = storage.read('table_positions');
    if (storedLocs != null) {
      try {
        Map<String, Map<String, double>> parsedLocs = {};
        (storedLocs as Map).forEach((key, value) {
          if (value is Map) {
            Map<String, double> coords = {};
            value.forEach((k, v) {
              coords[k.toString()] = (v as num).toDouble();
            });
            parsedLocs[key.toString()] = coords;
          }
        });
        tablePositions.assignAll(parsedLocs);
      } catch (e) {
        print("Error parsing table_positions: $e");
      }
    }

    var storedPrinted = storage.read('printed_kitchen_items');
    if (storedPrinted != null) {
      try {
        Map<String, Map<String, int>> parsed = {};
        (storedPrinted as Map).forEach((orderId, items) {
          if (items is Map) {
            Map<String, int> itemMap = {};
            items.forEach((pId, qty) {
              itemMap[pId.toString()] = (qty as num).toInt();
            });
            parsed[orderId.toString()] = itemMap;
          }
        });
        printedKitchenQuantities.assignAll(parsed);
      } catch (e) { print("Error parsing printed_kitchen_items: $e"); }
    }

    // Load Printer Settings
    printerPaperSize.value = storage.read('printer_paper_size') ?? "80mm";
    autoPrintReceipt.value = storage.read('auto_print_receipt') ?? false;
    enableKitchenPrint.value = storage.read('enable_kitchen_print') ?? true;
    enableBillPrint.value = storage.read('enable_bill_print') ?? true;
    enablePaymentPrint.value = storage.read('enable_payment_print') ?? true;

    // Load Cafe Settings (Offline/First-load)
    restaurantName.value = storage.read('restaurant_name') ?? "";
    restaurantAddress.value = storage.read('restaurant_address') ?? "";
    restaurantPhone.value = storage.read('restaurant_phone') ?? "";
    currency.value = storage.read('currency') ?? "UZS";
    serviceFeeDineIn.value = (storage.read('service_fee_dine_in') as num?)?.toDouble() ?? 10.0;
    serviceFeeTakeaway.value = (storage.read('service_fee_takeaway') as num?)?.toDouble() ?? 0.0;
    serviceFeeDelivery.value = (storage.read('service_fee_delivery') as num?)?.toDouble() ?? 3000.0;
    receiptHeader.value = storage.read('receipt_header') ?? "";
    receiptFooter.value = storage.read('receipt_footer') ?? "Xaridingiz uchun rahmat!";
    showLogo.value = storage.read('show_logo') ?? true;

    if (currentUser.value != null) {
      socket.setCafeId(cafeId);
    }
  }

  void _setupSocketListenersDetailed() {
    setupSocketListeners();
    
    socket.onNewOrder((data) {
      int index = allOrders.indexWhere((o) => o['id'].toString() == data['id'].toString());
      if (index == -1) {
        final normalized = normalizeOrder(data);
        allOrders.insert(0, normalized);
        allOrders.refresh();
        saveAllOrders();

        if (isAdmin || isCashier) {
          final orderId = data['id']?.toString();
          if (orderId != null) {
            final now = DateTime.now();
            if (_processedPrintIds.containsKey(orderId) && 
                now.difference(_processedPrintIds[orderId]!).inSeconds < 10) {
              return;
            }
            _processedPrintIds[orderId] = now;
          }
          printLocally(normalized, isKitchenOnly: true);
        }
      }
    });

    socket.onPrintRequest((data) async {
      if (isAdmin || isCashier) {
        final orderId = data['order']?['id']?.toString();
        if (orderId != null) {
          final now = DateTime.now();
          if (_processedPrintIds.containsKey(orderId) && 
              now.difference(_processedPrintIds[orderId]!).inSeconds < 10) {
            return;
          }
          _processedPrintIds[orderId] = now;
        }

        final Map<String, dynamic> order = Map<String, dynamic>.from(data['order']);
        if (data['sender'] != null) order['waiter_name'] = data['sender'];
        final bool isKitchenOnly = data['isKitchenOnly'] == true;
        final bool skipCancellation = data['skipCancellation'] == true;
        
        await printLocally(order, isKitchenOnly: isKitchenOnly, receiptTitle: data['receiptTitle'], skipCancellation: skipCancellation);
        
        // If it was a persistent job from DB, acknowledge it
        if (data['job_id'] != null) {
          socket.emitPrintAck(data['job_id']);
        }
      }
    });

    socket.onWaiterCall((data) async {
      if (currentUser.value?['id']?.toString() == data['waiter_id'].toString()) {
        _playAlertSound();
        
        // Vibrate if supported
        if (await Vibration.hasVibrator() ?? false) {
          Vibration.vibrate(duration: 2000, amplitude: 255);
        }

        Get.snackbar("Chaqiruv!", "${data['sender_name']} sizni chaqirmoqda", 
          backgroundColor: Colors.red.withOpacity(0.9), 
          colorText: Colors.white, 
          duration: const Duration(seconds: 5),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    });
    
    socket.onShiftClosed((data) {
      if (isWaiter && isShiftBroadcastEnabled.value) {
        final bool isOnTerminal = currentTerminal.value != null;

        Get.snackbar(
          "Smena yopildi",
          isOnTerminal
              ? "Kassir smenani yopdi. PIN kod bilan qayta kiring."
              : "Kassir smenani yopdi. Iltimos, terminalga borib qayta kiring.",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );

        Future.delayed(const Duration(seconds: 3), () {
          if (isOnTerminal) {
            // POS terminal → Staff selection (PIN bilan qayta kirish mumkin)
            lockTerminal();
          } else {
            // Ofitsiantning o'z telefoni → to'liq logout
            // U terminalga borib PIN ko'rib kirishi kerak
            logout(forced: true);
          }
        });
      }
    });

    socket.onTestPrint((data) async {
      final String? printerId = data['printer_id']?.toString();
      if (printerId == null) return;

      // Find the printer in local list
      final printer = printers.firstWhereOrNull((p) => p.id == printerId);
      if (printer == null) {
        print('Test print: printer $printerId not found locally');
        return;
      }

      Get.snackbar(
        "Test Chop Etish",
        "${printer.name} printeriga test sahifasi yuborilmoqda...",
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      final success = await printerService.printTestPage(printer);

      Get.snackbar(
        success ? "✅ Muvaffaqiyatli" : "❌ Xatolik",
        success ? "${printer.name} test sahifasi chop etildi" : "${printer.name} ga ulanib bo'lmadi",
        backgroundColor: success ? Colors.green : Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    });
  }

  Future<void> _playAlertSound() async {
    try {
      await audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3'));
    } catch (e) {
      print("Error playing alert sound: $e");
    }
  }

  Future<bool> submitOrder({bool isPaid = false, String? paymentMethod}) async {
    if (currentOrder.isEmpty) return false;
    bool isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (!isWithinGeofence.value && isWaiter && !isDesktop) return false;

    if (editingOrderId.value != null) return await updateExistingOrder(isPaid: isPaid, paymentMethod: paymentMethod);

    final orderData = {
      "table_number": currentMode.value == "Dine-in" ? selectedTable.value : null,
      "type": currentMode.value.toUpperCase().replaceAll("-", "_"),
      "is_paid": isPaid,
      "waiter_name": selectedWaiter.value ?? currentUser.value?['name'],
      "payment_method": paymentMethod,
      "cafe_id": cafeId,
      // Discount
      if (discountValue.value > 0) ...{
        "discount_type": discountType.value,
        "discount_value": discountValue.value,
        "discount_amount": discountAmount,
      },
      "items": () {
        final Map<String, Map<String, dynamic>> grouped = {};
        for (var e in currentOrder) {
          final FoodItem item = e['item'] as FoodItem;
          final FoodVariant? variant = e['variant'] as FoodVariant?;
          final String id = item.id.toString();
          final String? variantId = variant?.id;
          final String groupKey = variantId != null ? "${id}_$variantId" : id;
          final int qty = e['quantity'] as int;
          if (qty <= 0) continue;

          if (grouped.containsKey(groupKey)) {
            grouped[groupKey]!['quantity'] += qty;
          } else {
            grouped[groupKey] = {
              "product_id": id,
              "variant_id": variantId,
              "variant_name": variant?.name,
              "quantity": qty,
              "price": variant?.price ?? item.price
            };
          }
        }
        return grouped.values.toList();
      }(),
    };

    try {
      final newOrder = await api.createOrder(orderData);
      isOffline.value = false;
      final normalized = normalizeOrder(newOrder);
      
      // Check if already added by socket to prevent duplicates
      int index = allOrders.indexWhere((o) => o['id'].toString() == normalized['id'].toString());
      if (index == -1) {
        allOrders.insert(0, normalized);
      } else {
        allOrders[index] = normalized;
      }
      
      final orderId = normalized['id']?.toString();
      if (orderId != null) {
        _processedPrintIds[orderId] = DateTime.now();
      }

      await printOrder(normalized, isKitchenOnly: !isPaid, 
          receiptTitle: isPaid ? "TO'LOV CHEKI" : "HISOB CHEKI");

      // ── Try sync queue ──
      OfflineService().syncQueue().then((_) {
        pendingOfflineOrders.value = OfflineService().queueCount;
      });

      clearCurrentOrder();
      saveAllOrders();
      return true;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.sendTimeout || 
          e.type == DioExceptionType.receiveTimeout || 
          e.type == DioExceptionType.connectionError) {
        
        isOffline.value = true;
        await OfflineService().queueOrder(orderData);
        pendingOfflineOrders.value = OfflineService().queueCount;
        
        Get.snackbar(
          "Oflayn rejim", 
          "Internet yo'q. Buyurtma lokal xotiraga saqlandi va internet ulanganda yuboriladi.",
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
        
        clearCurrentOrder();
        return true; 
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateExistingOrder({bool isPaid = false, String? paymentMethod}) async {
    if (editingOrderId.value == null) return false;
    bool isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    if (!isWithinGeofence.value && isWaiter && !isDesktop) return false;
    
    try {
      final newStatus = isPaid ? "Completed" : "Preparing";
      // ... (existing code for grouped and consolidatedList)
      
      // I need to make sure I don't break the existing logic.
      // Let's just update the API call part.
      List<Map<String, dynamic>> consolidatedList = [];
      List<Map<String, dynamic>> cancelledItems = [];
      final Map<String, Map<String, dynamic>> grouped = {};
      final Map<String, int> totalSentQty = {};

      for (var e in currentOrder) {
        final item = e['item'] as FoodItem;
        final FoodVariant? variant = e['variant'] as FoodVariant?;
        final String id = item.id.toString();
        final String? variantId = variant?.id;
        final String groupKey = variantId != null ? "${id}_$variantId" : id;
        final int qty = e['quantity'];
        final int sentQty = e['sentQty'] ?? 0;

        totalSentQty[groupKey] = (totalSentQty[groupKey] ?? 0) + sentQty;

        if (qty > 0) {
          if (grouped.containsKey(groupKey)) {
            grouped[groupKey]!['qty'] += qty;
            grouped[groupKey]!['quantity'] += qty;
          } else {
            grouped[groupKey] = {
              "id": id,
              "product_id": id,
              "variant_id": variantId,
              "variant_name": variant?.name,
              "name": variant != null ? "${item.name} (${variant.name})" : item.name,
              "qty": qty,
              "quantity": qty,
              "price": variant?.price ?? item.price,
            };
          }
        }
      }

      consolidatedList = grouped.values.toList();

      // track cancellations for receipt display
      totalSentQty.forEach((id, sentQty) {
        final int currentQty = grouped[id]?['qty'] ?? 0;
        if (currentQty < sentQty) {
          final item = currentOrder.firstWhere((e) => (e['item'] as FoodItem).id.toString() == id)['item'] as FoodItem;
          cancelledItems.add({
            "id": id,
            "name": item.name,
            "qty": sentQty - currentQty,
          });
        }
      });

      int index = allOrders.indexWhere((o) => o['id'] == editingOrderId.value);
      bool wasBillPrinted = false;
      if (index != -1) {
        wasBillPrinted = allOrders[index]['status'] == "Bill Printed";
      }

      await api.updateOrderStatus(editingOrderId.value!, newStatus);
      await api.updateOrder(editingOrderId.value!, {
        "status": newStatus,
        "payment_method": paymentMethod,
        if (discountValue.value > 0) ...{
          "discount_type": discountType.value,
          "discount_value": discountValue.value,
          "discount_amount": discountAmount,
        },
        "items": consolidatedList.map((i) => { 
          "product_id": i["product_id"], 
          "variant_id": i["variant_id"],
          "quantity": i["qty"], 
          "price": i["price"] 
        }).toList()
      });
      
      if (index != -1) {
        final orderToPrint = Map<String, dynamic>.from(allOrders[index]);
        orderToPrint['items'] = totalItems;
        orderToPrint['total'] = total;
        orderToPrint['status'] = newStatus;
        orderToPrint['mode'] = currentMode.value;
        orderToPrint['table'] = currentMode.value == "Dine-in" ? selectedTable.value : "-";
        orderToPrint['details'] = consolidatedList;
        orderToPrint['cancelled_items'] = cancelledItems; // Pass to printer
        
        // Update allOrders with new details
        allOrders[index] = orderToPrint;

      
      final orderId = editingOrderId.value?.toString();
      if (orderId != null) {
        _processedPrintIds[orderId] = DateTime.now();
      }

      await printOrder(orderToPrint, isKitchenOnly: !isPaid, 
          skipCancellation: wasBillPrinted && !isPaid,
          receiptTitle: isPaid ? "TO'LOV CHEKI" : "HISOB CHEKI");

        allOrders.refresh();
        clearCurrentOrder();
        saveAllOrders();
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  Future<void> printBillAndExit() async {
    if (editingOrderId.value == null) {
      Get.snackbar("Eslatma", "Siz hali buyurtmani saqlamadingiz. Avval 'Saqlash' tugmasini bosing.", 
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (isOrderModified.value) {
      Get.snackbar("Eslatma", "Buyurtmada o'zgarishlar bor. Avval 'Saqlash' tugmasini bosing.", 
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    try {
      // 1. Update status to BILL_PRINTED
      await api.updateOrderStatus(editingOrderId.value!, "BILL_PRINTED");
      
      // 2. Prepare order data
      final index = allOrders.indexWhere((o) => o['id'] == editingOrderId.value);
      Map<String, dynamic> orderToPrint;
      
      if (index != -1) {
        orderToPrint = Map<String, dynamic>.from(allOrders[index]);
        orderToPrint['status'] = "Bill Printed";
        allOrders[index] = orderToPrint;
        allOrders.refresh();
        saveAllOrders();
      } else {
        orderToPrint = {
          "id": editingOrderId.value,
          "table": selectedTable.value.isNotEmpty ? selectedTable.value : "-",
          "mode": currentMode.value,
          "total": total,
          "waiter_name": currentUser.value?['name'],
          "details": currentOrder.map((e) => {
            "id": (e['item'] as FoodItem).id,
            "name": (e['item'] as FoodItem).name,
            "qty": e['quantity'],
            "price": (e['item'] as FoodItem).price,
          }).toList(),
        };
      }

      // 3. Print
      await printOrder(orderToPrint, receiptTitle: "HISOB CHEKI");

      // 4. Exit if waiter
      if (isWaiter) {
        clearCurrentOrder(); // Clear local state
        Get.offAll(() => MainNavigationScreen());
      }
    } catch (e) {
      Get.snackbar("Xatolik", "Hisob chiqarishda xato: $e", 
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void setMode(String mode) => currentMode.value = mode;
  void setTable(String table) {
    if (selectedTable.value.isNotEmpty) socket.emitTableUnlock(selectedTable.value);
    selectedTable.value = table;
    if (table.isNotEmpty) socket.emitTableLock(table, currentUser.value?['name'] ?? "User");
  }
  void toggleEditMode() => isEditMode.value = !isEditMode.value;
  void setDeviceRole(String? role) { deviceRole.value = role; storage.write('device_role', role); }
  void setWaiterCafeId(String? cafeId) { waiterCafeId.value = cafeId; storage.write('waiter_cafe_id', cafeId); }
}

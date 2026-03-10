import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/food_item.dart';
import 'pos_controller_state.dart';
import '../../presentation/widgets/virtual_keyboard.dart';

mixin OrderMixin on POSControllerState {
  double get subtotal => currentOrder.fold(0, (sum, item) {
    final foodItem = item['item'] as FoodItem;
    final variant = item['variant'] as FoodVariant?;
    final price = variant?.price ?? foodItem.price;
    return sum + (price * (item['quantity'] as int));
  });
  int get totalItems => currentOrder.fold(0, (sum, item) => sum + (item['quantity'] as int));
  bool get hasNewItems => currentOrder.any((item) => item['isNew'] == true && (item['quantity'] as int) > 0);
  bool get hasChanges => isOrderModified.value;

  double get serviceFee {
    if (currentMode.value == "Dine-in") {
      return subtotal * (serviceFeeDineIn.value / 100);
    } else if (currentMode.value == "Takeaway") {
      return serviceFeeTakeaway.value;
    } else if (currentMode.value == "Delivery") {
      return serviceFeeDelivery.value;
    }
    return 0.0;
  }

  /// Chegirma miqdori (hisoblangan)
  double get discountAmount {
    if (discountValue.value <= 0) return 0.0;
    if (discountType.value == "percent") {
      return (subtotal + serviceFee) * (discountValue.value / 100);
    }
    return discountValue.value.clamp(0.0, subtotal + serviceFee);
  }

  double get total => (subtotal + serviceFee - discountAmount).clamp(0.0, double.infinity);

  void resetDiscount() {
    discountValue.value = 0.0;
    discountType.value = "percent";
  }

  void addToCart(FoodItem item, {FoodVariant? variant}) {
    // Prevent adding parent items if they have variants
    if ((item.hasVariants || item.variants.isNotEmpty) && variant == null) {
      return;
    }

    int index = currentOrder.indexWhere((e) => 
      e['item'].id == item.id && 
      e['variant']?.id == variant?.id &&
      e['isNew'] == true
    );
    
    if (index != -1) {
      currentOrder[index]['quantity']++;
    } else {
      currentOrder.add({
        'item': item, 
        'variant': variant,
        'quantity': 1, 
        'isNew': true,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
    currentOrder.refresh();
    checkIfModified();
  }

  void decrementFromCart(FoodItem item, {FoodVariant? variant}) {
    int index = currentOrder.indexWhere((e) => 
      e['item'].id == item.id && 
      e['variant']?.id == variant?.id &&
      e['isNew'] == true
    );
    if (index != -1) {
      if (currentOrder[index]['quantity'] > 1) {
        currentOrder[index]['quantity']--;
      } else {
        if (currentOrder[index]['isNew'] == false) {
          if (isWaiter) {
            Get.snackbar("Cheklov", "Ofitsiant yuborilgan mahsulotni o'chira olmaydi", 
              backgroundColor: Colors.orange, colorText: Colors.white);
            return;
          }
          currentOrder[index]['quantity'] = 0;
        } else {
          currentOrder.removeAt(index);
        }
      }
      currentOrder.refresh();
      checkIfModified();
    }
  }

  void removeFromCart(int index) {
    if (currentOrder[index]['isNew'] == false) {
      if (isWaiter) {
        Get.snackbar("Cheklov", "Ofitsiant yuborilgan mahsulotni o'chira olmaydi", 
          backgroundColor: Colors.orange, colorText: Colors.white);
        return;
      }
      currentOrder[index]['quantity'] = 0;
    } else {
      currentOrder.removeAt(index);
    }
    currentOrder.refresh();
    checkIfModified();
  }

  void updateQuantity(int index, int delta) {
    int currentQty = currentOrder[index]['quantity'];
    int newQty = currentQty + delta;
    
    // Waiter restriction: cannot decrease sent items
    if (isWaiter && currentOrder[index]['isNew'] == false && delta < 0) {
      Get.snackbar("Cheklov", "Ofitsiant yuborilgan mahsulotni kamaytira olmaydi", 
        backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (newQty > 0) {
      currentOrder[index]['quantity'] = newQty;
    } else {
      if (currentOrder[index]['isNew'] == false) {
        currentOrder[index]['quantity'] = 0;
      } else {
        currentOrder.removeAt(index);
      }
    }
    currentOrder.refresh();
    checkIfModified();
  }

  void setAbsoluteQuantity(int index, int quantity) {
    int currentQty = currentOrder[index]['quantity'];
    
    // Waiter restriction: cannot decrease sent items
    if (isWaiter && currentOrder[index]['isNew'] == false && quantity < currentQty) {
      Get.snackbar("Cheklov", "Ofitsiant yuborilgan mahsulotni kamaytira olmaydi", 
        backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    if (quantity > 0) {
      currentOrder[index]['quantity'] = quantity;
    } else {
      if (currentOrder[index]['isNew'] == false) {
        currentOrder[index]['quantity'] = 0;
      } else {
        currentOrder.removeAt(index);
      }
    }
    currentOrder.refresh();
    checkIfModified();
  }

  void checkIfModified() {
    if (editingOrderId.value == null) {
      isOrderModified.value = currentOrder.isNotEmpty;
      return;
    }
    final currentJson = currentOrder.map((e) => {
      "id": (e['item'] as FoodItem).id,
      "variant_id": (e['variant'] as FoodVariant?)?.id,
      "qty": e['quantity'],
    }).toList().toString();
    isOrderModified.value = currentJson != originalOrderJson;
  }

  Future<void> updateOrderStatus(dynamic orderId, String status) async {
    if (isOnline.value) {
      try {
        await api.updateOrderStatus(orderId, status);
      } catch (e) {
        print("Online status update failed: $e");
        addToSyncQueue('UPDATE_STATUS', {'id': orderId, 'status': status});
      }
    } else {
      addToSyncQueue('UPDATE_STATUS', {'id': orderId, 'status': status});
    }

    int index = allOrders.indexWhere((o) => o['id'] == orderId);
    if (index != -1) {
      allOrders[index]['status'] = status.toString().replaceAll("_", " ").split(" ").map((s) => s.toLowerCase().capitalizeFirst).join(" ");
      allOrders.refresh();
      saveAllOrders();
    }
  }

  void deleteOrder(dynamic orderId) {
    allOrders.removeWhere((o) => o['id'] == orderId);
    printedKitchenQuantities.remove(orderId.toString());
    storage.write('printed_kitchen_items', Map.from(printedKitchenQuantities));
    allOrders.refresh();
    saveAllOrders();
  }

  Future<void> changeOrderTable(dynamic orderId, String tableKey) async {
    try {
      final String? tableUuid = tableBackendIds[tableKey];
      // Extract the clean number from "Area-Number" format
      final parts = tableKey.split("-");
      final String tableNum = parts.length >= 2 ? parts.sublist(1).join("-") : tableKey;

      await api.updateOrder(orderId, {
        "table_id": tableUuid,
        "table_number": tableNum,
      });
      int index = allOrders.indexWhere((o) => o['id'] == orderId);
      if (index != -1) {
        allOrders[index]['table'] = tableKey;
        allOrders[index]['table_id'] = tableUuid;
        allOrders.refresh();
        saveAllOrders();
      }
      Get.snackbar("Stol o'zgartirildi", "Buyurtma $tableKey-stolga o'tkazildi", 
        backgroundColor: Colors.green, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      print("Error updating table: $e");
      Get.snackbar("Xato", "Stolni o'zgartirishda xatolik yuz berdi", 
        backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> changeOrderWaiter(dynamic orderId, String newWaiterId, String newWaiterName) async {
    try {
      await api.updateOrder(orderId, {
        "waiter_id": newWaiterId,
        "waiter_name": newWaiterName,
      });
      int index = allOrders.indexWhere((o) => o['id'] == orderId);
      if (index != -1) {
        allOrders[index]['waiter_id'] = newWaiterId;
        allOrders[index]['waiter_name'] = newWaiterName;
        allOrders.refresh();
        saveAllOrders();
      }
      Get.snackbar("Afitsant o'zgartirildi", "Buyurtma $newWaiterName-ga o'tkazildi", 
        backgroundColor: Colors.blue, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      print("Error updating waiter: $e");
      Get.snackbar("Xato", "Afitsantni o'zgartirishda xatolik yuz berdi", 
        backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  void showQuantityDialog(int index) {
    final TextEditingController controller = TextEditingController(
      text: currentOrder[index]['quantity'].toString()
    );
    final focusNode = FocusNode();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(currentOrder[index]['item'].name, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              autofocus: true,
              readOnly: showKeyboard.value,
              showCursor: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: "Miqdori",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (showKeyboard.value) ...[
              const SizedBox(height: 20),
              VirtualKeyboard(
                controller: controller,
                type: VirtualKeyboardType.numeric,
                onEnter: () {
                  int? val = int.tryParse(controller.text);
                  if (val != null) {
                    setAbsoluteQuantity(index, val);
                    Get.back();
                  }
                },
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            }, 
            child: const Text("Bekor qilish")
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9500),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              int? val = int.tryParse(controller.text);
              if (val != null) {
                setAbsoluteQuantity(index, val);
                Get.back();
              }
            },
            child: const Text("Saqlash"),
          ),
        ],
      ),
    ).then((_) => focusNode.dispose());
  }

  void syncCartToDisplay() {
    final cartData = {
      'items': currentOrder.where((item) {
        final foodItem = item['item'] as FoodItem;
        final variant = item['variant'] as FoodVariant?;
        // Filter out parent items that have variants but no variant is selected
        return !((foodItem.hasVariants || foodItem.variants.isNotEmpty) && variant == null);
      }).map((item) {
        final foodItem = item['item'] as FoodItem;
        final variant = item['variant'] as FoodVariant?;
        final price = variant?.price ?? foodItem.price;
        return {
          'id': foodItem.id.toString(),
          'name': variant != null ? "${foodItem.name} (${variant.name})" : foodItem.name,
          'quantity': item['quantity'],
          'price': price,
        };
      }).toList(),
      'total': total,
    };
    socket.emitCartUpdate(cartData);
  }

  void clearCurrentOrder() {
    if (selectedTable.value.isNotEmpty) {
      socket.emitTableUnlock(selectedTable.value);
    }
    currentOrder.clear();
    selectedTable.value = "";
    editingOrderId.value = null;
    isOrderModified.value = false;
    discountValue.value = 0.0;
    discountType.value = "percent";
    socket.emitCartClear();
  }

  void loadOrderForEditing(Map<String, dynamic> order, List<FoodItem> catalog) {
    editingOrderId.value = order['id']?.toString();
    currentMode.value = order['mode'] ?? "Dine-in";
    final String tableVal = (order['table'] ?? "").toString();
    if (tableVal != "-" && tableVal.isNotEmpty) {
      selectedTable.value = tableVal.replaceFirst("Table ", "");
      socket.emitTableLock(selectedTable.value, currentUser.value?['name'] ?? "User");
    } else {
      selectedTable.value = "";
    }

    currentOrder.clear();
    final details = order['details'] as List? ?? [];
    for (var d in details) {
      final item = catalog.firstWhereOrNull((f) => f.id.toString() == d['id'].toString() || f.name == d['name']);
      if (item != null) {
        FoodVariant? variant;
        if (d['variant_id'] != null && item.hasVariants) {
          variant = item.variants.firstWhereOrNull((v) => v.id.toString() == d['variant_id'].toString());
        }

        // Skip parent items if they have variants but no variant was found/specified
        if ((item.hasVariants || item.variants.isNotEmpty) && variant == null) {
          continue;
        }
        
        currentOrder.add({
          'item': item, 
          'variant': variant,
          'quantity': (d['qty'] as num?)?.toInt() ?? 0,
          'sentQty': (d['qty'] as num?)?.toInt() ?? 0,
          'isNew': false,
          'timestamp': d['timestamp'] ?? order['timestamp'],
        });
      }
    }
    
    originalOrderJson = currentOrder.map((e) => {
      "id": (e['item'] as FoodItem).id,
      "variant_id": (e['variant'] as FoodVariant?)?.id,
      "qty": e['quantity'],
    }).toList().toString();
    
    isOrderModified.value = false;
    syncCartToDisplay();
    
    discountType.value = order['discount_type'] ?? "percent";
    discountValue.value = (order['discount_value'] as num?)?.toDouble() ?? 0.0;

    // Sync printed quantities for kitchen
    final String orderIdStr = order['id']?.toString() ?? "0";
    if (!printedKitchenQuantities.containsKey(orderIdStr)) {
      final Map<String, int> printedMap = {};
      for (var d in details) {
        printedMap[d['id']?.toString() ?? ""] = (d['qty'] as num?)?.toInt() ?? 0;
      }
      printedKitchenQuantities[orderIdStr] = printedMap;
      storage.write('printed_kitchen_items', Map.from(printedKitchenQuantities));
    }
  }
}

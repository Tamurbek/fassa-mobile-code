import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../data/models/food_item.dart';
import '../data/models/printer_model.dart';
import '../data/models/preparation_area_model.dart';
import '../data/services/api_service.dart';
import '../data/services/socket_service.dart';
import '../data/services/printer_service.dart';
import '../data/services/update_service.dart';
import '../theme/app_colors.dart';

class POSController extends GetxController {
  final _storage = GetStorage();
  final _api = ApiService();
  final _socket = SocketService();
  final _printer = PrinterService();
  final _update = UpdateService();
  
  var currentOrder = <Map<String, dynamic>>[].obs;
  var allOrders = <Map<String, dynamic>>[].obs;
  var currentUser = Rxn<Map<String, dynamic>>();
  var currentTerminal = Rxn<Map<String, dynamic>>();
  var pinCode = RxnString();
  var isPinAuthenticated = false.obs;
  var isPrinting = false.obs;
  var deviceRole = RxnString(); // "ADMIN", "CASHIER", "WAITER"
  var waiterCafeId = RxnString(); // Used only for WAITER role
  var printedKitchenQuantities = <String, Map<String, int>>{}.obs; // "orderId": {"productId": qty}
  
  // Order modes, current selection, table, and editing state
  final List<String> orderModes = ["Dine-in", "Takeaway", "Delivery"];
  var currentMode = "Dine-in".obs;
  
  // Product Catalog
  var products = <FoodItem>[].obs;
  var categories = <String>["All"].obs;
  var categoriesObjects = <Map<String, dynamic>>[].obs;
  var preparationAreas = <PreparationAreaModel>[].obs;
  var printers = <PrinterModel>[].obs;
  var selectedCategory = "All".obs;
  var users = <Map<String, dynamic>>[].obs;

  var selectedTable = "".obs;
  var lockedTables = <String, String>{}.obs; // {"tableId": "userName"}
  var editingOrderId = RxnInt(); // Track if we are editing an existing order
  String _originalOrderJson = ""; // To check if any changes were made
  var isOrderModified = false.obs;
  
  // Settings
  var printerPaperSize = "80mm".obs;
  var autoPrintReceipt = false.obs;
  var restaurantName = "".obs;
  var restaurantAddress = "".obs;
  var restaurantPhone = "".obs;
  var restaurantLogo = "".obs;
  var currency = "UZS".obs;
  String get currencySymbol => currency.value == 'USD' ? '\$' : "so'm";
  var serviceFeeDineIn = 10.0.obs;
  var serviceFeeTakeaway = 0.0.obs;
  var serviceFeeDelivery = 3000.0.obs;
  
  // Receipt Settings
  var receiptStyle = "STANDARD".obs;
  var receiptHeader = "".obs;
  var receiptFooter = "Xaridingiz uchun rahmat!".obs;
  var showLogo = true.obs;
  var showWaiter = true.obs;
  var showWifi = false.obs;
  var wifiSsid = "".obs;
  var wifiPassword = "".obs;
  var instagram = "".obs;
  var telegram = "".obs;
  var allowWaiterMobileOrders = true.obs;

  // Printing Toggles
  var enableKitchenPrint = true.obs;
  var enableBillPrint = true.obs;
  var enablePaymentPrint = true.obs;

  var isOrdersTableView = false.obs;

  var tableAreas = <String>[].obs;
  var tablesByArea = <String, List<String>>{}.obs;

  var tableAreaBackendIds = <String, String>{}; // "Zal": "area_uuid"
  var tableAreaDetails = <String, Map<String, dynamic>>{}.obs; // "Zal": {"width_m": 12.0, "height_m": 8.0}
  var selectedWaiter = RxnString(); // Track selected waiter for order assignment (Cashier/Admin)

  var tablePositions = <String, Map<String, double>>{}.obs; // "Location-TableId": {"x": 100.0, "y": 200.0}
  var tableProperties = <String, Map<String, dynamic>>{}.obs; // width, height, shape
  var tableBackendIds = <String, String>{}; // "Location-TableId": "backend_uuid"
  var isEditMode = false.obs;

  // Subscription
  var subscriptionDaysLeft = RxnInt();    // null = VIP (cheksiz)
  var isSubscriptionExpired = false.obs;
  var isVip = false.obs;
  var subscriptionEndDate = RxnString();  // ISO string or null
  Timer? _subscriptionTimer;
  Timer? _locationTimer;
  var isWithinGeofence = true.obs;

  // Role helpers
  bool get isAdmin => currentUser.value?['role'] == "CAFE_ADMIN" || currentUser.value?['role'] == "SYSTEM_ADMIN";
  bool get isWaiter => currentUser.value?['role'] == "WAITER";
  bool get isCashier => currentUser.value?['role'] == "CASHIER";

  String get cafeId {
    final userCafeId = currentUser.value?['cafe_id'];
    if (userCafeId != null) return userCafeId.toString();
    
    final terminalCafeId = currentTerminal.value?['cafe_id'];
    if (terminalCafeId != null) return terminalCafeId.toString();
    
    return waiterCafeId.value ?? "";
  }

  @override
  void onInit() {
    super.onInit();
    _loadLocalData();
    _fetchBackendData();
    _setupSocketListeners();
    _update.checkForUpdate();
    _startSubscriptionCheck();
    _initLocationTracking();
  }

  @override
  void onClose() {
    _subscriptionTimer?.cancel();
    _locationTimer?.cancel();
    super.onClose();
  }

  void _startSubscriptionCheck() {
    if (currentUser.value != null) {
      checkSubscription();
    }
    _subscriptionTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (currentUser.value != null) {
        checkSubscription(showWarning: false);
      }
    });
  }

  void _initLocationTracking() async {
    if (currentUser.value == null) {
      if (Platform.isAndroid || Platform.isIOS) {
        FlutterBackgroundService().invoke("stopService");
      }
      _locationTimer?.cancel();
      return;
    }

    // Check permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      // 1. One immediate location update
      _sendLocationUpdate();

      // 2. Continuous tracking
      if (Platform.isAndroid || Platform.isIOS) {
        final service = FlutterBackgroundService();
        final isRunning = await service.isRunning();
        if (!isRunning) {
          service.startService();
        }
      } else {
        // macOS/Windows fallback using Timer
        _locationTimer?.cancel();
        _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          _sendLocationUpdate();
        });
      }
    }
  }

  Future<void> _sendLocationUpdate() async {
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        // Fallback for simulators where location might hang or fail
        print("Geolocator failed, using fallback location: $e");
        position = Position(
          longitude: 69.2401, latitude: 41.2995, 
          timestamp: DateTime.now(), accuracy: 0.0, 
          altitude: 0.0, altitudeAccuracy: 0.0, heading: 0.0, headingAccuracy: 0.0, speed: 0.0, speedAccuracy: 0.0
        );
      }

      final response = await _api.updateLocation(position.latitude, position.longitude);
      if (response['status'] == 'warning') {
        isWithinGeofence.value = false;
        Get.snackbar("Eslatma", response['message'] ?? 'Hududdan tashqaridasiz.', backgroundColor: Colors.orange, colorText: Colors.white);
      } else {
        isWithinGeofence.value = true;
      }
    } catch (e) {
      print("Direct location update error: $e");
    }
  }

  void stopLocationTracking() {
    if (Platform.isAndroid || Platform.isIOS) {
      FlutterBackgroundService().invoke("stopService");
    }
    _locationTimer?.cancel();
  }

  Future<void> checkSubscription({bool showWarning = true}) async {
    if (currentUser.value == null) return;
    try {
      final status = await _api.getSubscriptionStatus();
      final bool vip = status['is_vip'] == true;
      final bool expired = status['is_expired'] == true;
      final bool active = status['is_active'] != false; // null bo'lsa faol deb hisoblaymiz
      final dynamic daysLeft = status['days_left'];
      final String? endDate = status['end_date'];

      isVip.value = vip;
      isSubscriptionExpired.value = expired || !active;
      subscriptionDaysLeft.value = vip ? null : (daysLeft as int?);
      subscriptionEndDate.value = endDate;

      if (expired || !active) {
        _forceLogoutDueToExpiry(reason: !active ? 'Kafe nofaol holatda' : 'Obuna tugadi');
        return;
      }

      if (!vip && showWarning && daysLeft != null) {
        final int days = daysLeft as int;
        if (days <= 3 && days > 0) {
          Get.snackbar(
            'Obuna tugayapti!',
            'Obuna muddati ' + days.toString() + ' kun ichida tugaydi. Iltimos, muddatni uzaytiring.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 8),
            snackPosition: SnackPosition.TOP,
            icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
            margin: const EdgeInsets.all(12),
          );
        }
      }
    } catch (e) {
      print('Subscription check error: ' + e.toString());
    }
  }

  void _forceLogoutDueToExpiry({String reason = 'Obuna tugadi'}) {
    if (Get.isDialogOpen == true) return;
    isSubscriptionExpired.value = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.dialog(
        PopScope(
          canPop: false,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.red, size: 28),
                const SizedBox(width: 8),
                Text(reason,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              reason == 'Obuna tugadi' 
                ? 'Kafengizning obuna muddati tugadi.\n\nTizimdan chiqib, administrator bilan bog\'laning.'
                : 'Kafengiz vaqtincha nofaol qilindi.\n\nTizimdan chiqib, administrator bilan bog\'laning.',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            actions: [
              ElevatedButton.icon(
                onPressed: () {
                  Get.back();
                  logout();
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Chiqish'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        barrierDismissible: false,
      );
    });
  }


  void _loadLocalData() {
    var storedAllOrders = _storage.read('all_orders');
    if (storedAllOrders != null) {
      allOrders.assignAll(List<Map<String, dynamic>>.from(storedAllOrders));
    }

    deviceRole.value = _storage.read('device_role');
    waiterCafeId.value = _storage.read('waiter_cafe_id');
    currentUser.value = _storage.read('user');
    currentTerminal.value = _storage.read('terminal');
    pinCode.value = _storage.read('pin_code');

    var storedProducts = _storage.read('products');
    if (storedProducts != null) {
      products.assignAll((storedProducts as List).map((e) => FoodItem.fromJson(e)).toList());
    }

    var storedCategories = _storage.read('categories');
    if (storedCategories != null) {
      categories.assignAll(List<String>.from(storedCategories));
    }

    var storedCategoriesObjects = _storage.read('categories_objects');
    if (storedCategoriesObjects != null) {
      categoriesObjects.assignAll(List<Map<String, dynamic>>.from(storedCategoriesObjects));
    }

    var storedPrepAreas = _storage.read('preparation_areas');
    if (storedPrepAreas != null) {
      preparationAreas.assignAll((storedPrepAreas as List).map((e) => PreparationAreaModel.fromJson(e)).toList());
    }

    var storedPrinters = _storage.read('printers');
    if (storedPrinters != null) {
      printers.assignAll((storedPrinters as List).map((e) => PrinterModel.fromJson(e)).toList());
    }

    printerPaperSize.value = _storage.read('printer_paper_size') ?? "80mm";
    autoPrintReceipt.value = _storage.read('auto_print_receipt') ?? false;
    restaurantName.value = _storage.read('restaurant_name') ?? "";
    restaurantAddress.value = _storage.read('restaurant_address') ?? "";
    restaurantPhone.value = _storage.read('restaurant_phone') ?? "";
    restaurantLogo.value = _storage.read('restaurant_logo') ?? "";
    currency.value = _storage.read('currency') ?? "UZS";
    serviceFeeDineIn.value = _storage.read('service_fee_dine_in') ?? 0.0;
    serviceFeeTakeaway.value = _storage.read('service_fee_takeaway') ?? 0.0;
    serviceFeeDelivery.value = _storage.read('service_fee_delivery') ?? 0.0;
    
    receiptStyle.value = _storage.read('receipt_style') ?? "STANDARD";
    receiptHeader.value = _storage.read('receipt_header') ?? "";
    receiptFooter.value = _storage.read('receipt_footer') ?? "Xaridingiz uchun rahmat!";
    showLogo.value = _storage.read('show_logo') ?? true;
    showWaiter.value = _storage.read('show_waiter') ?? true;
    showWifi.value = _storage.read('show_wifi') ?? false;
    wifiSsid.value = _storage.read('wifi_ssid') ?? "";
    wifiPassword.value = _storage.read('wifi_password') ?? "";
    instagram.value = _storage.read('instagram') ?? "";
    telegram.value = _storage.read('telegram') ?? "";
    allowWaiterMobileOrders.value = _storage.read('allow_waiter_mobile_orders') ?? true;
    
    enableKitchenPrint.value = _storage.read('enable_kitchen_print') ?? true;
    enableBillPrint.value = _storage.read('enable_bill_print') ?? true;
    enablePaymentPrint.value = _storage.read('enable_payment_print') ?? true;
    isOrdersTableView.value = _storage.read('is_orders_table_view') ?? false;

    var storedUser = _storage.read('user');
    if (storedUser != null) {
      currentUser.value = Map<String, dynamic>.from(storedUser);
      _socket.setCafeId(cafeId);
    }

    var storedWaiters = _storage.read('all_users');
    if (storedWaiters != null) {
      users.assignAll(List<Map<String, dynamic>>.from(storedWaiters));
    }

    pinCode.value = _storage.read('pin_code');

    var storedPrinted = _storage.read('printed_kitchen_items');
    if (storedPrinted != null) {
      try {
        final Map<String, dynamic> decoded = Map<String, dynamic>.from(storedPrinted);
        printedKitchenQuantities.assignAll(decoded.map(
          (key, value) => MapEntry(key, Map<String, int>.from(value))
        ));
      } catch (e) {
        print("Error loading printed kitchen items: $e");
      }
    }

    var storedTablePositions = _storage.read('table_positions');
    if (storedTablePositions != null) {
      try {
        final Map<String, dynamic> decoded = Map<String, dynamic>.from(storedTablePositions);
        tablePositions.assignAll(decoded.map(
          (key, value) => MapEntry(key, Map<String, double>.from(value))
        ));
      } catch (e) {
        print("Error loading table positions: $e");
      }
    }

    var storedTableProperties = _storage.read('table_properties');
    if (storedTableProperties != null) {
      try {
        final Map<String, dynamic> decoded = Map<String, dynamic>.from(storedTableProperties);
        tableProperties.assignAll(decoded.map(
          (key, value) => MapEntry(key, Map<String, dynamic>.from(value))
        ));
      } catch (e) {
        print("Error loading table properties: $e");
      }
    }
  }

  void updateTablePosition(String tableId, double x, double y) {
    tablePositions[tableId] = {"x": x, "y": y};
    _storage.write('table_positions', Map.from(tablePositions));
  }

  void setEnableKitchenPrint(bool value) {
    enableKitchenPrint.value = value;
    _storage.write('enable_kitchen_print', value);
  }

  void setEnableBillPrint(bool value) {
    enableBillPrint.value = value;
    _storage.write('enable_bill_print', value);
  }

  void setEnablePaymentPrint(bool value) {
    enablePaymentPrint.value = value;
    _storage.write('enable_payment_print', value);
  }

  void toggleOrdersViewMode() {
    isOrdersTableView.value = !isOrdersTableView.value;
    _storage.write('is_orders_table_view', isOrdersTableView.value);
  }

  Future<void> syncTablePositionWithBackend(String tableId) async {
    final pos = tablePositions[tableId];
    final backendId = tableBackendIds[tableId];
    if (pos == null || backendId == null) return;

    try {
      await _api.updateTablePosition(backendId, {
        "x": pos['x'],
        "y": pos['y']
      });
    } catch (e) {
      print("Error syncing table position to backend: $e");
    }
  }

  void setPinCode(String code) {
    pinCode.value = code;
    _storage.write('pin_code', code);
  }

  void authenticatePin(bool status) {
    isPinAuthenticated.value = status;
  }

  Future<void> updateCafeInfo({
    String? name,
    String? address,
    String? phone,
    String? logo,
    double? serviceFeeDineInVal,
    double? serviceFeeTakeawayVal,
    double? serviceFeeDeliveryVal,
    String? receiptStyleVal,
    String? receiptHeaderVal,
    String? receiptFooterVal,
    bool? showLogoVal,
    bool? showWaiterVal,
    bool? showWifiVal,
    String? wifiSsidVal,
    String? wifiPasswordVal,
    String? instagramVal,
    String? telegramVal,
  }) async {
    try {
      final Map<String, dynamic> updateData = {};
      if (name != null) updateData['name'] = name;
      if (address != null) updateData['address'] = address;
      if (phone != null) updateData['phone'] = phone;
      if (logo != null) updateData['logo'] = logo;
      if (serviceFeeDineInVal != null) updateData['service_fee_dine_in'] = serviceFeeDineInVal;
      if (serviceFeeTakeawayVal != null) updateData['service_fee_takeaway'] = serviceFeeTakeawayVal;
      if (serviceFeeDeliveryVal != null) updateData['service_fee_delivery'] = serviceFeeDeliveryVal;
      if (receiptStyleVal != null) updateData['receipt_style'] = receiptStyleVal;
      if (receiptHeaderVal != null) updateData['receipt_header'] = receiptHeaderVal;
      if (receiptFooterVal != null) updateData['receipt_footer'] = receiptFooterVal;
      if (showLogoVal != null) updateData['show_logo'] = showLogoVal;
      if (showWaiterVal != null) updateData['show_waiter'] = showWaiterVal;
      if (showWifiVal != null) updateData['show_wifi'] = showWifiVal;
      if (wifiSsidVal != null) updateData['wifi_ssid'] = wifiSsidVal;
      if (wifiPasswordVal != null) updateData['wifi_password'] = wifiPasswordVal;
      if (instagramVal != null) updateData['instagram'] = instagramVal;
      if (telegramVal != null) updateData['telegram'] = telegramVal;
      // Note: allow_waiter_mobile_orders might be added here too, if needed

      if (updateData.isEmpty) return;

      final updatedCafe = await _api.updateCafe(cafeId, updateData);
      
      // Update local observables
      if (name != null) restaurantName.value = updatedCafe['name'];
      if (address != null) restaurantAddress.value = updatedCafe['address'];
      if (phone != null) restaurantPhone.value = updatedCafe['phone'];
      if (logo != null) restaurantLogo.value = updatedCafe['logo'];
      if (serviceFeeDineInVal != null) serviceFeeDineIn.value = (updatedCafe['service_fee_dine_in'] as num).toDouble();
      if (serviceFeeTakeawayVal != null) serviceFeeTakeaway.value = (updatedCafe['service_fee_takeaway'] as num).toDouble();
      if (serviceFeeDeliveryVal != null) serviceFeeDelivery.value = (updatedCafe['service_fee_delivery'] as num).toDouble();

      if (receiptStyleVal != null) receiptStyle.value = updatedCafe['receipt_style'] ?? "STANDARD";
      if (receiptHeaderVal != null) receiptHeader.value = updatedCafe['receipt_header'] ?? "";
      if (receiptFooterVal != null) receiptFooter.value = updatedCafe['receipt_footer'] ?? "Xaridingiz uchun rahmat!";
      if (showLogoVal != null) showLogo.value = updatedCafe['show_logo'] ?? true;
      if (showWaiterVal != null) showWaiter.value = updatedCafe['show_waiter'] ?? true;
      if (showWifiVal != null) showWifi.value = updatedCafe['show_wifi'] ?? false;
      if (wifiSsidVal != null) wifiSsid.value = updatedCafe['wifi_ssid'] ?? "";
      if (wifiPasswordVal != null) wifiPassword.value = updatedCafe['wifi_password'] ?? "";
      if (instagramVal != null) instagram.value = updatedCafe['instagram'] ?? "";
      if (telegramVal != null) telegram.value = updatedCafe['telegram'] ?? "";
      
      // Save to local storage
      if (name != null) _storage.write('restaurant_name', restaurantName.value);
      if (address != null) _storage.write('restaurant_address', restaurantAddress.value);
      if (phone != null) _storage.write('restaurant_phone', restaurantPhone.value);
      if (logo != null) _storage.write('restaurant_logo', restaurantLogo.value);
      if (serviceFeeDineInVal != null) _storage.write('service_fee_dine_in', serviceFeeDineIn.value);
      if (serviceFeeTakeawayVal != null) _storage.write('service_fee_takeaway', serviceFeeTakeaway.value);
      if (serviceFeeDeliveryVal != null) _storage.write('service_fee_delivery', serviceFeeDelivery.value);
      
      _storage.write('receipt_style', receiptStyle.value);
      _storage.write('receipt_header', receiptHeader.value);
      _storage.write('receipt_footer', receiptFooter.value);
      _storage.write('show_logo', showLogo.value);
      _storage.write('show_waiter', showWaiter.value);
      _storage.write('show_wifi', showWifi.value);
      _storage.write('wifi_ssid', wifiSsid.value);
      _storage.write('wifi_password', wifiPassword.value);
      _storage.write('instagram', instagram.value);
      _storage.write('telegram', telegram.value);

      Get.snackbar("Muvaffaqiyatli", "Sozlamalar saqlandi", 
        backgroundColor: Colors.green, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      print("Error updating cafe info: $e");
      Get.snackbar("Xato", "Sozlamalarni saqlashda xatolik yuz berdi", 
        backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<bool> switchUserWithPin(String userId, String pin) async {
    try {
      final data = await _api.loginWithPin(userId, pin, deviceId: "POS_Terminal", deviceName: "POS");
      currentUser.value = data['user'];
      _storage.write('user', data['user']);
      
      // Resync data with new user properties
      await _fetchBackendData();
      return true;
    } catch (e) {
      Get.snackbar("Xato", "Nato'g'ri PIN yoki server xatosi.", backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  Future<String?> getStaffQRToken(String userId) async {
    try {
      final data = await _api.getQRToken(userId);
      return data['qr_token'];
    } catch (e) {
      print("Error getting QR token: $e");
      return null;
    }
  }

  Future<bool> loginWithQR(String qrToken) async {
    try {
      String deviceId = "mobile_${DateTime.now().millisecondsSinceEpoch}";
      if (Platform.isAndroid || Platform.isIOS) {
         // Optionally get real device id
      }
      
      final data = await _api.loginWithQR(qrToken, deviceId: deviceId, deviceName: Platform.operatingSystem);
      currentUser.value = data['user'];
      _storage.write('user', data['user']);
      _storage.write('access_token', data['access_token']);
      
      _socket.setCafeId(cafeId);
      await _fetchBackendData();
      return true;
    } catch (e) {
      print("QR Login Error: $e");
      return false;
    }
  }

  Future<void> refreshData({bool showMessage = true}) async {
    try {
      await _fetchBackendData();
      if (showMessage) {
        Get.snackbar(
          "Yangilandi", 
          "Ma'lumotlar muvaffaqiyatli yangilandi",
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      print("Refresh error: $e");
    }
  }

  Future<void> _fetchBackendData() async {
    if (currentUser.value == null) return;
    
    // Fetch Cafe Info (including service fees)
    try {
      final cafe = await _api.getCafe(cafeId);
      restaurantName.value = cafe['name'] ?? "";
      restaurantAddress.value = cafe['address'] ?? "";
      restaurantPhone.value = cafe['phone'] ?? "";
      restaurantLogo.value = cafe['logo'] ?? "";
      currency.value = cafe['currency'] ?? "UZS";
      serviceFeeDineIn.value = (cafe['service_fee_dine_in'] ?? 10.0).toDouble();
      serviceFeeTakeaway.value = (cafe['service_fee_takeaway'] ?? 0.0).toDouble();
      serviceFeeDelivery.value = (cafe['service_fee_delivery'] ?? 3000.0).toDouble();
      
      receiptStyle.value = cafe['receipt_style'] ?? "STANDARD";
      receiptHeader.value = cafe['receipt_header'] ?? "";
      receiptFooter.value = cafe['receipt_footer'] ?? "Xaridingiz uchun rahmat!";
      showLogo.value = cafe['show_logo'] ?? true;
      showWaiter.value = cafe['show_waiter'] ?? true;
      showWifi.value = cafe['show_wifi'] ?? false;
      wifiSsid.value = cafe['wifi_ssid'] ?? "";
      wifiPassword.value = cafe['wifi_password'] ?? "";
      instagram.value = cafe['instagram'] ?? "";
      telegram.value = cafe['telegram'] ?? "";
      allowWaiterMobileOrders.value = cafe['allow_waiter_mobile_orders'] ?? true;
      
      _storage.write('restaurant_name', restaurantName.value);
      _storage.write('restaurant_address', restaurantAddress.value);
      _storage.write('restaurant_phone', restaurantPhone.value);
      _storage.write('restaurant_logo', restaurantLogo.value);
      _storage.write('currency', currency.value);
      _storage.write('service_fee_dine_in', serviceFeeDineIn.value);
      _storage.write('service_fee_takeaway', serviceFeeTakeaway.value);
      _storage.write('service_fee_delivery', serviceFeeDelivery.value);
      
      _storage.write('receipt_style', receiptStyle.value);
      _storage.write('receipt_header', receiptHeader.value);
      _storage.write('receipt_footer', receiptFooter.value);
      _storage.write('show_logo', showLogo.value);
      _storage.write('show_waiter', showWaiter.value);
      _storage.write('show_wifi', showWifi.value);
      _storage.write('wifi_ssid', wifiSsid.value);
      _storage.write('wifi_password', wifiPassword.value);
      _storage.write('instagram', instagram.value);
      _storage.write('telegram', telegram.value);
      _storage.write('allow_waiter_mobile_orders', allowWaiterMobileOrders.value);
    } catch (e) {
      print("Error fetching cafe info: $e");
    }
    
    // Fetch Categories
    try {
      final backendCategories = await _api.getCategories();
      categoriesObjects.assignAll(List<Map<String, dynamic>>.from(backendCategories));
      categories.assignAll(["All", ...backendCategories.map((c) => c['name'].toString())]);
      _storage.write('categories_objects', categoriesObjects.toList());
      saveCategories();
    } catch (e) {
      print("Error fetching categories: $e");
    }

    // Fetch Products
    try {
      final backendProducts = await _api.getProducts();
      print("Fetched ${backendProducts.length} products from backend");
      
      List<FoodItem> parsedProducts = [];
      for (var p in backendProducts) {
        try {
          parsedProducts.add(FoodItem.fromJson(p));
        } catch (e) {
          print("Skipping product due to parse error: $e");
        }
      }
      
      products.assignAll(parsedProducts);
      print("Successfully parsed ${products.length} products: ${products.map((e) => e.name).join(', ')}");
      saveProducts();
    } catch (e) {
      print("Error fetching products: $e");
    }

    // Fetch Preparation Areas
    try {
      final backendPrepAreas = await _api.getPreparationAreas();
      preparationAreas.assignAll(backendPrepAreas.map((a) => PreparationAreaModel.fromJson(a)).toList());
      savePreparationAreas();
    } catch (e) {
      print("Error fetching preparation areas: $e");
    }

    // Fetch Printers
    try {
      final backendPrinters = await _api.getPrinters();
      printers.assignAll(backendPrinters.map((p) => PrinterModel.fromJson(p)).toList());
      savePrinters();
    } catch (e) {
      print("Error fetching printers: $e");
    }

    // Fetch Orders
    try {
      final backendOrders = await _api.getOrders();
      allOrders.assignAll(backendOrders.map((o) => _normalizeOrder(o)).toList());
      saveAllOrders();
    } catch (e) {
      print("Error fetching orders: $e");
    }

    // Fetch Tables & Floor Plan
    try {
      final backendAreas = await _api.getTableAreas();
      if (backendAreas.isNotEmpty) {
        tableAreas.assignAll(backendAreas.map((a) => a['name'].toString()).toList());
        for (var a in backendAreas) {
          final String name = a['name'].toString();
          tableAreaBackendIds[name] = a['id'].toString();
          tableAreaDetails[name] = {
            "width_m": (a['width_m'] as num?)?.toDouble() ?? 10.0,
            "height_m": (a['height_m'] as num?)?.toDouble() ?? 10.0,
          };
        }
      }

      final backendTables = await _api.getTables();
      if (backendTables.isNotEmpty || backendAreas.isNotEmpty) {
        Map<String, List<String>> tba = {};
        for (var area in tableAreas) {
           tba[area] = [];
        }

        for (var t in backendTables) {
          final String loc = t['area'] ?? t['location'] ?? "Zal"; 
          final String tableNum = t['number'] != null ? t['number'].toString() : "01";
          final String tableId = "$loc-$tableNum";

          if (!tba.containsKey(loc)) {
            tba[loc] = [];
            if (!tableAreas.contains(loc)) tableAreas.add(loc);
          }
          tba[loc]!.add(tableNum);
          
          tableBackendIds[tableId] = t['id'].toString();
          
          if (t['x'] != null && t['y'] != null) {
            tablePositions[tableId] = {
              "x": (t['x'] as num).toDouble(),
              "y": (t['y'] as num).toDouble()
            };
          }
          
          tableProperties[tableId] = {
            "width": (t['width'] as num?)?.toDouble() ?? 80.0,
            "height": (t['height'] as num?)?.toDouble() ?? 80.0,
            "shape": t['shape']?.toString() ?? "square",
          };
        }
        
        // Ensure all areas are present in tba
        for (var a in tableAreas) {
            if (!tba.containsKey(a)) tba[a] = [];
        }

        // Sort table numbers if they represent numbers natively
        tba.forEach((key, value) {
          value.sort((a, b) {
             int numA = int.tryParse(a) ?? 0;
             int numB = int.tryParse(b) ?? 0;
             if (numA != 0 && numB != 0) return numA.compareTo(numB);
             return a.compareTo(b);
          });
        });

        tablesByArea.assignAll(tba);
        _storage.write('table_positions', Map.from(tablePositions));
        _storage.write('table_properties', Map.from(tableProperties));
      }
    } catch (e) {
      print("Error fetching tables: $e");
    }

    // Fetch Users (Waiters)
    if (isAdmin || isCashier) {
      try {
        final backendUsers = await _api.getUsers();
        users.assignAll(List<Map<String, dynamic>>.from(backendUsers));
        _storage.write('all_users', users.toList());
      } catch (e) {
        print("Error fetching users: $e");
      }
    }
  }

  Map<String, dynamic> _normalizeOrder(Map<String, dynamic> o) {
    // Convert backend structure to frontend structure
    // Handle both camelCase (from Websocket) and snake_case (from REST API)
    final tableNum = o['tableNumber'] ?? o['table_number'];
    final totalAmt = o['totalAmount'] ?? o['total_amount'];
    final typeStr = o['type'] ?? 'DINE_IN';
    final statusStr = o['status'] ?? 'PENDING';
    final timestamp = o['createdAt'] ?? o['created_at'];

    return {
      "id": o['id'],
      "table": tableNum != null ? tableNum.toString() : "-",
      "mode": typeStr.toString().toLowerCase().replaceAll("_", "-").capitalizeFirst,
      "items": (o['items'] as List?)?.fold(0, (sum, item) => sum + ((item['quantity'] ?? item['qty'] ?? 0) as int)) ?? 0,
      "total": double.tryParse(totalAmt.toString()) ?? 0.0,
      "status": statusStr.toString().replaceAll("_", " ").split(" ").map((s) => s.toLowerCase().capitalizeFirst).join(" "),
      "waiter_name": o['waiter_name'],
      "timestamp": timestamp,
      "details": (o['items'] as List? ?? []).map((i) => {
        "id": i['productId'] ?? i['product_id'],
        "name": i['product'] != null ? i['product']['name'] : "Unknown",
        "qty": i['quantity'] ?? i['qty'],
        "price": double.tryParse((i['price'] ?? 0).toString()) ?? 0.0,
      }).toList(),
    };
  }

  void _setupSocketListeners() {
    _socket.onNewOrder((data) {
      print("Socket: New order received: ${data['id']}");
      // Add new order to list if it's not already there
      int index = allOrders.indexWhere((o) => o['id'] == data['id']);
      if (index == -1) {
        final normalized = _normalizeOrder(data);
        allOrders.insert(0, normalized);
        allOrders.refresh();
        saveAllOrders();

        // Auto-print for Admin/Cashier devices if it's a new order
        if (deviceRole.value == "ADMIN" || deviceRole.value == "CASHIER" || isAdmin || isCashier) {
          print("Socket: Auto-printing new order for Admin/Cashier...");
          _printLocally(normalized, isKitchenOnly: true); // New orders always start with Kitchen Print
        }
      }
    });

    _socket.onOrderStatusUpdated((data) {
      int index = allOrders.indexWhere((o) => o['id'] == data['orderId']);
      if (index != -1) {
        allOrders[index]['status'] = data['status'].toString().toLowerCase().capitalizeFirst;
        allOrders.refresh();
        saveAllOrders();
      }
    });

    _socket.onPrintRequest((data) {
      // Only Admin or Cashier devices should process print requests from other devices
      if (deviceRole.value == "ADMIN" || deviceRole.value == "CASHIER" || isAdmin || isCashier) {
        print("Remote print request received: ${data['receiptTitle']}");
        final Map<String, dynamic> order = Map<String, dynamic>.from(data['order']);
        if (data['sender'] != null && data['sender'].toString().isNotEmpty) {
          order['waiter_name'] = data['sender'];
        }
        final bool isKitchenOnly = (data['isKitchenOnly'] == true || data['isKitchenOnly'].toString() == 'true' || data['isKitchenOnly'] == 1);
        final String? receiptTitle = data['receiptTitle'];
        
        // Print locally on this device
        _printLocally(order, isKitchenOnly: isKitchenOnly, receiptTitle: receiptTitle);
      }
    });

    _socket.onTableLockStatus((data) {
      final String tableId = data['tableId'].toString();
      final String? userName = data['user']; // null means unlocked
      
      if (userName != null) {
        lockedTables[tableId] = userName;
      } else {
        lockedTables.remove(tableId);
      }
      lockedTables.refresh();
    });
  }

  double get subtotal => currentOrder.fold(0, (sum, item) => sum + (item['item'].price * item['quantity']));
  int get totalItems => currentOrder.fold(0, (sum, item) => sum + (item['quantity'] as int));
  bool get hasNewItems => currentOrder.any((item) => item['isNew'] == true && (item['quantity'] as int) > 0);

  // Service fee calculation based on mode
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

  double get tax => 0.0;

  double get total => subtotal + serviceFee;

  void setMode(String mode) {
    currentMode.value = mode;
    if (mode != "Dine-in") selectedTable.value = "";
  }

  void setTable(String table) {
    if (selectedTable.value.isNotEmpty) {
      _socket.emitTableUnlock(selectedTable.value);
    }
    selectedTable.value = table;
    if (table.isNotEmpty) {
      _socket.emitTableLock(table, currentUser.value?['name'] ?? "User");
    }
  }

  void toggleEditMode() {
    isEditMode.value = !isEditMode.value;
  }

  void addToCart(FoodItem item) {
    // Check if we already have a 'New' line for this item
    int index = currentOrder.indexWhere((element) => 
      element['item'].id == item.id && (element['isNew'] == true)
    );

    if (index != -1) {
      currentOrder[index]['quantity']++;
    } else {
      currentOrder.add({
        'item': item, 
        'quantity': 1,
        'isNew': true,
        'sentQty': 0,
      });
    }
    currentOrder.refresh();
    _checkIfModified();
  }

  void decrementFromCart(FoodItem item) {
    // Check if we have a 'New' line for this item
    int index = currentOrder.indexWhere((element) => 
      element['item'].id == item.id && (element['isNew'] == true)
    );

    if (index != -1) {
      if (currentOrder[index]['quantity'] > 1) {
        currentOrder[index]['quantity']--;
      } else {
        currentOrder.removeAt(index);
      }
      currentOrder.refresh();
      _checkIfModified();
    }
  }

  void setDeviceRole(String? role) {
    deviceRole.value = role;
    if (role == null) {
      _storage.remove('device_role');
    } else {
      _storage.write('device_role', role);
    }
  }

  void setWaiterCafeId(String? cafeId) {
    waiterCafeId.value = cafeId;
    if (cafeId == null) {
      _storage.remove('waiter_cafe_id');
    } else {
      _storage.write('waiter_cafe_id', cafeId);
    }
  }

  void removeFromCart(int index) {
    currentOrder.removeAt(index);
    _checkIfModified();
  }

  void updateQuantity(int index, int delta) {
    final item = currentOrder[index];
    final bool isNew = item['isNew'] == true;
    final int sentQty = item['sentQty'] ?? 0;

    if (delta > 0) {
      if (!isNew) {
        // If it's a sent item and we increase, redirect to addToCart to create/update separate New line
        addToCart(item['item']);
        return;
      }
      item['quantity']++;
    } else {
      item['quantity']--;
      if (isNew && item['quantity'] <= 0) {
        currentOrder.removeAt(index);
      } else if (!isNew && item['quantity'] < 0) {
        item['quantity'] = 0; // Don't remove sent items, just mark as cancelled (qty 0)
      }
    }
    currentOrder.refresh();
    _checkIfModified();
  }

  void setAbsoluteQuantity(int index, int quantity) {
    if (quantity <= 0) {
      currentOrder.removeAt(index);
    } else {
      currentOrder[index]['quantity'] = quantity;
      currentOrder.refresh();
    }
    _checkIfModified();
  }

  void showQuantityDialog(int index) {
    final int currentQty = currentOrder[index]['quantity'];
    final TextEditingController controller = TextEditingController(text: currentQty.toString());
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("quantity".tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("cancel".tr)),
          ElevatedButton(
            onPressed: () {
              final int? newQty = int.tryParse(controller.text);
              if (newQty != null) {
                setAbsoluteQuantity(index, newQty);
              }
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("ok".tr),
          ),
        ],
      ),
    );
  }

  void _checkIfModified() {
    if (editingOrderId.value == null) {
      isOrderModified.value = currentOrder.isNotEmpty;
      return;
    }
    
    // Simple JSON comparison to check for changes
    final currentJson = currentOrder.map((e) => {
      "id": (e['item'] as FoodItem).id,
      "qty": e['quantity'],
    }).toList().toString();
    
    isOrderModified.value = currentJson != _originalOrderJson;
  }

  void setCurrentUser(Map<String, dynamic>? user) {
    currentUser.value = user;
    if (user != null) {
      _storage.write('user', user);
      _socket.setCafeId(cafeId);
      _fetchBackendData(); // Sync data immediately after login
    } else {
      _storage.remove('user');
    }
  }

  void setCurrentTerminal(Map<String, dynamic>? terminal) {
    currentTerminal.value = terminal;
    if (terminal != null) {
      _storage.write('terminal', terminal);
    } else {
      _storage.remove('terminal');
    }
  }

  void logout({bool forced = false}) {
    stopLocationTracking();
    setCurrentUser(null);
    pinCode.value = null;
    _storage.remove('pin_code');
    
    bool wasTerminal = currentTerminal.value != null;
    if (wasTerminal) {
      _api.restoreTerminalToken();
    } else {
      _api.setToken(null);
    }
    isPinAuthenticated.value = false;
    
    currentOrder.clear();
    // In terminal mode we might want to keep some data, but logout usually implies clearing
    // but we MUST clear sensitive user data
    
    if (forced) {
       allOrders.clear();
       products.clear();
       categories.assignAll(["All"]);
       categoriesObjects.clear();
       preparationAreas.clear();
       printers.clear();
       users.clear();
       lockedTables.clear();
    }

    _storage.remove('products');
    _storage.remove('categories');
    _storage.remove('categories_objects');
    _storage.remove('preparation_areas');
    _storage.remove('printers');
    _storage.remove('all_users');
    _storage.remove('printed_kitchen_items');
    _storage.remove('table_positions');
    _storage.remove('table_properties');

    if (deviceRole.value == null) {
      Get.offAllNamed('/role-selection');
    } else if (wasTerminal) {
      Get.offAllNamed('/staff-selection');
    } else {
      Get.offAllNamed('/login');
    }
    if (forced) {
       Get.snackbar(
         "Tizimdan chiqildi", 
         "Hisobingizga boshqa qurilmadan kirildi",
         backgroundColor: Colors.red,
         colorText: Colors.white,
         snackPosition: SnackPosition.TOP,
         duration: const Duration(seconds: 5)
       );
    }
  }

  void lockTerminal() {
    logout(forced: false);
  }

  Future<bool> submitOrder({bool isPaid = false}) async {
    if (currentOrder.isEmpty) return false;

    // --- Geofencing Check ---
    if (!isWithinGeofence.value && currentUser.value?['role'] == "WAITER") {
      Get.snackbar(
        "Diqqat", 
        "Siz ish joyidan tashqaridasiz. Buyurtma olish uchun belgilangan hududga qayting.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5)
      );
      return false;
    }

    if (editingOrderId.value != null) {
      return await updateExistingOrder(isPaid: isPaid);
    }

    final orderData = {
      "tableNumber": currentMode.value == "Dine-in" ? selectedTable.value : null,
      "type": currentMode.value.toUpperCase().replaceAll("-", "_"),
      "items": currentOrder.map((e) => {
        "productId": (e['item'] as FoodItem).id,
        "qty": e['quantity'],
        "price": (e['item'] as FoodItem).price,
      }).toList(),
    };

    try {
      final newOrder = await _api.createOrder({
        "table_number": orderData["tableNumber"],
        "type": orderData["type"],
        "is_paid": isPaid,
        "waiter_name": selectedWaiter.value ?? currentUser.value?['name'],
        "cafe_id": cafeId,
        "items": (orderData["items"] as List).map((i) => {
          "product_id": i["productId"],
          "quantity": i["qty"],
          "price": i["price"]
        }).toList(),
      });
      
      final normalizedOrder = _normalizeOrder(newOrder);
    
      // Check for duplicates (e.g. if socket already added it)
      int existingIndex = allOrders.indexWhere((o) => o['id'] == normalizedOrder['id']);
      if (existingIndex == -1) {
        allOrders.insert(0, normalizedOrder);
      } else {
        // If it exists, update it just in case some normalization/data is better from Direct API
        allOrders[existingIndex] = normalizedOrder;
      }
      
      // Print order (Kitchen or Receipt)
      await printOrder(normalizedOrder, 
        isKitchenOnly: !isPaid, 
        receiptTitle: isPaid ? "TO'LOV CHEKI" : "HISOB CHEKI"
      );

      clearCurrentOrder();
      saveAllOrders();
      Get.snackbar("success".tr, isPaid ? "payment_completed".tr : "sent_to_kitchen".tr,
          backgroundColor: Colors.green, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return true;
    } catch (e) {
      print("Error creating order: $e");
      Get.snackbar("Error", "Could not save order to server", 
        backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  void loadOrderForEditing(Map<String, dynamic> order, List<FoodItem> catalog) {
    editingOrderId.value = order['id'];
    currentMode.value = order['mode'] ?? "Dine-in";
    
    // Extract table number if exists
    final String tableVal = (order['table'] ?? "").toString();
    if (tableVal != "-" && tableVal.isNotEmpty) {
      selectedTable.value = tableVal.replaceFirst("Table ", "");
      _socket.emitTableLock(selectedTable.value, currentUser.value?['name'] ?? "User");
    } else {
      selectedTable.value = "";
    }

    currentOrder.clear();
    final details = order['details'] as List? ?? [];
    for (var d in details) {
      final item = catalog.firstWhereOrNull((f) => f.id == d['id'] || f.name == d['name']);
      if (item != null) {
        currentOrder.add({
          'item': item, 
          'quantity': d['qty'],
          'sentQty': d['qty'],
          'isNew': false,
          'createdAt': d['created_at'],
        });
      }
    }
    
    // Store original state for change tracking
    _originalOrderJson = currentOrder.map((e) => {
      "id": (e['item'] as FoodItem).id,
      "qty": e['quantity'],
    }).toList().toString();
    isOrderModified.value = false;
  }

  Future<bool> updateExistingOrder({bool isPaid = false}) async {
    if (editingOrderId.value == null) return false;

    // --- Geofencing Check ---
    if (!isWithinGeofence.value && currentUser.value?['role'] == "WAITER") {
      Get.snackbar(
        "Diqqat", 
        "Siz ish joyidan tashqaridasiz. Buyurtmani tahrirlash uchun belgilangan hududga qayting.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5)
      );
      return false;
    }
    
    try {
      // 1. Update status and items on backend
      final newStatus = isPaid ? "Completed" : "Preparing";
      
      // Group items for backend and receipts
      Map<dynamic, Map<String, dynamic>> aggregated = {};
      for (var e in currentOrder) {
        final item = e['item'] as FoodItem;
        final id = item.id;
        if (aggregated.containsKey(id)) {
          aggregated[id]!['qty'] += e['quantity'];
        } else {
          aggregated[id] = {
            "id": id,
            "product_id": id, // For backend
            "name": item.name,
            "qty": e['quantity'],
            "quantity": e['quantity'], // For backend
            "price": item.price,
          };
        }
      }
      
      // Filter out items that are completely cancelled (qty 0) if it's not a kitchen update
      // Actually, for kitchen update we need the 0 to detect cancellation.
      final consolidatedList = aggregated.values.toList();

      await _api.updateOrderStatus(editingOrderId.value!, newStatus);
      try {
        await _api.updateOrder(editingOrderId.value!, {
          "items": consolidatedList.map((i) => {
            "product_id": i["id"],
            "quantity": i["qty"],
            "price": i["price"]
          }).toList()
        });
      } catch (e) {
        print("Backend item update failed (may be expected if route missing): $e");
      }
      
      // 2. Update local state
      int index = allOrders.indexWhere((o) => o['id'] == editingOrderId.value);
      if (index != -1) {
        allOrders[index]['items'] = totalItems;
        allOrders[index]['total'] = total;
        allOrders[index]['status'] = newStatus;
        allOrders[index]['mode'] = currentMode.value;
        allOrders[index]['table'] = currentMode.value == "Dine-in" ? selectedTable.value : "-";
        
        // Save aggregated details for receipts and history
        allOrders[index]['details'] = consolidatedList;
        
        // 3. Print if it's a kitchen update
        await printOrder(allOrders[index], 
          isKitchenOnly: !isPaid, 
          receiptTitle: isPaid ? "TO'LOV CHEKI" : "HISOB CHEKI"
        );

        allOrders.refresh();
        clearCurrentOrder();
        saveAllOrders();
        Get.snackbar("success".tr, isPaid ? "payment_completed".tr : "sent_to_kitchen".tr,
            backgroundColor: Colors.green, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
        return true;
      }
      return false;
    } catch (e) {
      print("Error updating existing order: $e");
      Get.snackbar("Error", "Could not update order on server", 
        backgroundColor: Colors.red, colorText: Colors.white);
      return false;
    }
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    try {
      await _api.updateOrderStatus(orderId, status);
      int index = allOrders.indexWhere((o) => o['id'] == orderId);
      if (index != -1) {
        allOrders[index]['status'] = status;
        allOrders.refresh();
        saveAllOrders();
      }
    } catch (e) {
      print("Error updating status: $e");
    }
  }

  Future<void> changeOrderTable(int orderId, String newTableId) async {
    try {
      await _api.updateOrder(orderId, {"table_number": newTableId});
      int index = allOrders.indexWhere((o) => o['id'] == orderId);
      if (index != -1) {
        allOrders[index]['table'] = newTableId;
        allOrders.refresh();
        saveAllOrders();
      }
      Get.snackbar("Stol o'zgartirildi", "Buyurtma $newTableId-stolga o'tkazildi", 
        backgroundColor: Colors.green, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      print("Error updating table: $e");
      Get.snackbar("Xato", "Stolni o'zgartirishda xatolik yuz berdi", 
        backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
    }
  }

  void showWaiterSelectionDialog(String tableId, Function onSelected) {
    if (users.isEmpty) {
      onSelected();
      return;
    }

    final waiters = users.where((u) => u['role'] == "WAITER").toList();
    if (waiters.isEmpty) {
      onSelected();
      return;
    }

    bool didSelect = false;

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Afitsantni tanlang", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: waiters.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final w = waiters[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(w['name']?[0] ?? "W", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
                title: Text(w['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  selectedWaiter.value = w['name'];
                  didSelect = true;
                  Get.back();
                  onSelected();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              selectedWaiter.value = null; // Default to current user
              didSelect = true;
              Get.back();
              onSelected();
            },
            child: const Text("O'zimga biriktirish"),
          ),
        ],
      ),
    ).then((_) {
      if (!didSelect) {
        clearCurrentOrder();
      }
    });
  }

  void deleteOrder(int orderId) {
    allOrders.removeWhere((o) => o['id'] == orderId);
    printedKitchenQuantities.remove(orderId.toString());
    _storage.write('printed_kitchen_items', Map.from(printedKitchenQuantities));
    allOrders.refresh();
    saveAllOrders();
  }

  Future<void> updateAreaDimensions(String areaName, double width, double height) async {
    final String? areaId = tableAreaBackendIds[areaName];
    if (areaId == null) return;

    try {
      await _api.updateTableArea(areaId, {
        "name": areaName,
        "width_m": width,
        "height_m": height,
      });
      tableAreaDetails[areaName] = {
        "width_m": width,
        "height_m": height,
      };
      tableAreaDetails.refresh();
    } catch (e) {
      print("Error updating area dimensions: $e");
      Get.snackbar("Xatolik", "Hudud o'lchamlarini saqlashda xatolik yuz berdi",
          backgroundColor: Colors.red, colorText: Colors.white);
    }
  }

  void clearCurrentOrder() {
    if (selectedTable.value.isNotEmpty) {
      _socket.emitTableUnlock(selectedTable.value);
    }
    currentOrder.clear();
    selectedTable.value = "";
    editingOrderId.value = null; // Clear editing state
  }

  void saveAllOrders() {
    _storage.write('all_orders', allOrders.toList());
  }

  void saveProducts() {
    _storage.write('products', products.map((e) => e.toJson()).toList());
  }

  void saveCategories() {
    _storage.write('categories', categories.toList());
  }

  Future<void> addProduct(FoodItem item) async {
    try {
      final json = item.toJson();
      json['cafe_id'] = cafeId;
      
      // Map imageUrl to image for backend
      json['image'] = item.imageUrl;
      
      // Find category ID
      final cat = categoriesObjects.firstWhereOrNull((c) => c['name'] == item.category);
      if (cat != null) {
        json['category_id'] = cat['id'];
      }

      final newItem = await _api.createProduct(json);
      products.add(FoodItem.fromJson(newItem));
      saveProducts();
    } catch (e) {
      print("Error adding product: $e");
    }
  }

  Future<void> updateProduct(FoodItem item) async {
    try {
      final json = item.toJson();
      json.remove('id'); // ID in URL
      json['cafe_id'] = cafeId;
      
      // Map imageUrl to image for backend
      json['image'] = item.imageUrl;
      
      final cat = categoriesObjects.firstWhereOrNull((c) => c['name'] == item.category);
      if (cat != null) {
        json['category_id'] = cat['id'];
      }

      final updatedItem = await _api.updateProduct(item.id, json);
      int index = products.indexWhere((p) => p.id == item.id);
      if (index != -1) {
        products[index] = FoodItem.fromJson(updatedItem);
        saveProducts();
      }
    } catch (e) {
      print("Error updating product: $e");
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _api.deleteProduct(id);
      products.removeWhere((p) => p.id == id);
      saveProducts();
    } catch (e) {
      print("Error deleting product: $e");
    }
  }

  Future<void> addCategory(String category) async {
    if (categories.contains(category)) return;
    try {
      final newCat = await _api.createCategory({
        "name": category,
        "cafe_id": cafeId,
        "sort_order": categories.length
      });
      categoriesObjects.add(newCat);
      categories.add(newCat['name']);
      _storage.write('categories_objects', categoriesObjects.toList());
      saveCategories();
    } catch (e) {
      print("Error adding category: $e");
    }
  }
  
  Future<void> updateCategory(String oldName, String newName) async {
    final catObj = categoriesObjects.firstWhereOrNull((c) => c['name'] == oldName);
    if (catObj == null) return;

    try {
      final updatedCat = await _api.updateCategory(catObj['id'], {
        "name": newName,
      });
      
      int objIndex = categoriesObjects.indexWhere((c) => c['id'] == catObj['id']);
      if (objIndex != -1) categoriesObjects[objIndex] = updatedCat;

      int nameIndex = categories.indexOf(oldName);
      if (nameIndex != -1) categories[nameIndex] = newName;

      _storage.write('categories_objects', categoriesObjects.toList());
      saveCategories();

      // Update products locally
      for (int i = 0; i < products.length; i++) {
        if (products[i].category == oldName) {
          products[i] = FoodItem.fromJson({
            ...products[i].toJson(),
            'category': newName,
          });
        }
      }
      products.refresh();
      saveProducts();
    } catch (e) {
      print("Error updating category: $e");
    }
  }

  Future<void> deleteCategory(String category) async {
    if (category == "All") return;
    final catObj = categoriesObjects.firstWhereOrNull((c) => c['name'] == category);
    if (catObj == null) return;

    try {
      await _api.deleteCategory(catObj['id']);
      categoriesObjects.removeWhere((c) => c['id'] == catObj['id']);
      categories.remove(category);
      _storage.write('categories_objects', categoriesObjects.toList());
      saveCategories();
    } catch (e) {
      print("Error deleting category: $e");
    }
  }

  Future<void> addPreparationArea(PreparationAreaModel area) async {
    try {
      final json = area.toJson();
      json['cafe_id'] = cafeId;
      final newArea = await _api.createPreparationArea(json);
      preparationAreas.add(PreparationAreaModel.fromJson(newArea));
      savePreparationAreas();
    } catch (e) {
      print("Error adding preparation area: $e");
    }
  }

  void savePreparationAreas() {
    _storage.write('preparation_areas', preparationAreas.map((e) => e.toJson()).toList());
  }

  Future<void> updatePreparationArea(PreparationAreaModel area) async {
    try {
      final json = area.toJson();
      json.remove('id');
      final updatedArea = await _api.updatePreparationArea(area.id, json);
      int index = preparationAreas.indexWhere((a) => a.id == area.id);
      if (index != -1) {
        preparationAreas[index] = PreparationAreaModel.fromJson(updatedArea);
        savePreparationAreas();
      }
    } catch (e) {
      print("Error updating preparation area: $e");
    }
  }

  Future<void> deletePreparationArea(String id) async {
    try {
      await _api.deletePreparationArea(id);
      preparationAreas.removeWhere((a) => a.id == id);
      savePreparationAreas();
    } catch (e) {
      print("Error deleting preparation area: $e");
    }
  }

  void savePrinters() {
    _storage.write('printers', printers.map((e) => e.toJson()).toList());
  }

  Future<void> addPrinter(PrinterModel printer) async {
    try {
      final json = printer.toJson();
      json['cafe_id'] = cafeId;
      final newPrinter = await _api.createPrinter(json);
      printers.add(PrinterModel.fromJson(newPrinter));
      savePrinters();
    } catch (e) {
      print("Error adding printer: $e");
    }
  }

  Future<void> updatePrinter(PrinterModel printer) async {
    try {
      final json = printer.toJson();
      json.remove('id');
      final updatedPrinter = await _api.updatePrinter(printer.id, json);
      int index = printers.indexWhere((p) => p.id == printer.id);
      if (index != -1) {
        printers[index] = PrinterModel.fromJson(updatedPrinter);
        savePrinters();
      }
    } catch (e) {
      print("Error updating printer: $e");
    }
  }

  Future<void> deletePrinter(String id) async {
    try {
      await _api.deletePrinter(id);
      printers.removeWhere((p) => p.id == id);
      savePrinters();
    } catch (e) {
      print("Error deleting printer: $e");
    }
  }

  Future<void> printOrder(Map<String, dynamic> order, {bool isKitchenOnly = false, String? receiptTitle}) async {
    // --- Geofencing Check for Printers ---
    if (!isWithinGeofence.value && currentUser.value?['role'] == "WAITER") {
      Get.snackbar(
        "Diqqat", 
        "Siz ish joyidan tashqaridasiz. Chop etish uchun belgilangan hududga qayting.",
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 5)
      );
      return;
    }

    if (!order.containsKey('waiter_name')) {
      final name = currentUser.value?['name'];
      if (name != null && name.isNotEmpty) {
        order['waiter_name'] = name;
      }
    }

    // If it's a Waiter device, send the print request to the Admin/Cashier device via Socket
    if (deviceRole.value == "WAITER" || isWaiter) {
      print("Sending print request to central printer via Socket...");
      _socket.emitPrintRequest({
        'order': order,
        'isKitchenOnly': isKitchenOnly,
        'receiptTitle': receiptTitle,
        'sender': currentUser.value?['name'] ?? "Waiter",
      });
      
      Get.snackbar(
        "Chop etish yuborildi", 
        "Buyurtma kassaga chop etish uchun yuborildi",
        backgroundColor: Colors.blue, 
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM
      );
      return;
    }

    // If it's an Admin/Cashier device, print locally
    await _printLocally(order, isKitchenOnly: isKitchenOnly, receiptTitle: receiptTitle);
  }

  Future<void> _printLocally(Map<String, dynamic> order, {bool isKitchenOnly = false, String? receiptTitle}) async {
    isPrinting.value = true;
    List<String> successPrinters = [];
    List<String> failedPrinters = [];
    List<String> filteredPrinters = [];
    
    final details = order['details'] as List? ?? [];
    final activePrinters = printers.where((p) => p.isActive).toList();
    
    if (activePrinters.isEmpty) {
      Get.snackbar("Printer Warning", "No active printers configured", 
        backgroundColor: Colors.orange, colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM);
      isPrinting.value = false;
      return;
    }

    for (var printer in activePrinters) {
      try {
        bool success = false;
        
        // --- 1. RECEIPT / PAYMENT PRINTER LOGIC ---
        // Determine if this printer should handle the current receipt type
        bool shouldPrintCurrentReceipt = false;
        if (receiptTitle == "HISOB CHEKI" && printer.printReceipts) {
          shouldPrintCurrentReceipt = true;
        } else if (receiptTitle == null && !isKitchenOnly && printer.printPayments) {
          // Default behavior for final payment receipt
          shouldPrintCurrentReceipt = true;
        } else if (receiptTitle != null && receiptTitle != "HISOB CHEKI" && printer.printPayments) {
          // Any other title is usually a final receipt form
          shouldPrintCurrentReceipt = true;
        }

        // --- Filter by Table Area if specified ---
        if (shouldPrintCurrentReceipt && printer.tableAreaNames.isNotEmpty) {
          final String orderTableId = (order['table'] ?? "").toString();
          final String orderAreaName = orderTableId.contains("-") ? orderTableId.split("-")[0] : "";
          if (!printer.tableAreaNames.contains(orderAreaName)) {
            print("Skipping printer ${printer.name} as it is not assigned to area $orderAreaName");
            shouldPrintCurrentReceipt = false;
          }
        }

        if (shouldPrintCurrentReceipt && !isKitchenOnly) {
          if ((receiptTitle == "HISOB CHEKI" && !enableBillPrint.value) || 
              (receiptTitle != "HISOB CHEKI" && !enablePaymentPrint.value)) {
            print("Printing for $receiptTitle is disabled");
          } else {
            print("Printing receipt/bill to: ${printer.name}");
            
            // Add service fees to the order map for the printer to use
            final orderForPrinting = Map<String, dynamic>.from(order);
            orderForPrinting['service_fee_dine_in'] = serviceFeeDineIn.value;
            orderForPrinting['service_fee_takeaway'] = serviceFeeTakeaway.value;
            orderForPrinting['service_fee_delivery'] = serviceFeeDelivery.value;
            
            success = await _printer.printReceipt(printer, orderForPrinting, title: receiptTitle);
            if (success) successPrinters.add(printer.name);
            else failedPrinters.add(printer.name);
          }
        }

        // --- 2. KITCHEN PRINTER LOGIC ---
        // Kitchen printers handle items based on preparationAreaIds
        if (printer.preparationAreaIds.isNotEmpty && (isKitchenOnly || receiptTitle == null)) {
          if (!enableKitchenPrint.value) {
            print("Kitchen printing is disabled");
          } else {
            print("Processing Kitchen printer: ${printer.name} (Areas: ${printer.preparationAreaIds.join(',')})");
            final orderIdStr = order['id']?.toString() ?? "0";
            final previouslyPrintedRaw = printedKitchenQuantities[orderIdStr];
            final Map<String, int> previouslyPrinted = previouslyPrintedRaw != null 
                ? Map<String, int>.from(previouslyPrintedRaw) : {};
            
            List<dynamic> addedItems = [];
            List<dynamic> cancelledItems = [];

            // Identify items belonging to ANY of this printer's assigned areas
            final areaItems = details.where((d) {
              final itemId = d['id']?.toString().trim();
              if (itemId == null) return false;
              final product = products.firstWhereOrNull((p) => p.id.toString().trim() == itemId);
              if (product == null || product.preparationAreaId == null) return false;
              
              final String prodAreaId = product.preparationAreaId.toString().trim();
              return printer.preparationAreaIds.any((id) => id.trim() == prodAreaId);
            }).toList();

            if (areaItems.isNotEmpty || previouslyPrinted.isNotEmpty) {
              // Diff Logic
              for (var item in areaItems) {
                final String pId = item['id'].toString();
                final int currentQty = int.tryParse(item['qty'].toString()) ?? 0;
                final int prevQty = previouslyPrinted[pId] ?? 0;

                if (currentQty > prevQty) {
                  addedItems.add({...item, 'qty': currentQty - prevQty});
                }
              }

              if (previouslyPrinted.isNotEmpty) {
                 previouslyPrinted.forEach((pId, prevQty) {
                    final product = products.firstWhereOrNull((p) => p.id.toString().trim() == pId.trim());
                    if (product != null && product.preparationAreaId != null) {
                      final String prodAreaId = product.preparationAreaId.toString().trim();
                      bool isMyArea = printer.preparationAreaIds.any((id) => id.trim() == prodAreaId);
                      
                      if (isMyArea) {
                        final currentItem = areaItems.firstWhereOrNull((i) => i['id'].toString() == pId);
                        final int currentQty = currentItem != null ? (int.tryParse(currentItem['qty'].toString()) ?? 0) : 0;
                        if (currentQty < prevQty) {
                          cancelledItems.add({'id': pId, 'name': product?.name ?? "Unknown", 'qty': prevQty - currentQty});
                        }
                      }
                    }
                 });
              }

              // Print Tickets
              bool jobPrinted = false;
              if (addedItems.isNotEmpty) {
                 success = await _printer.printKitchenTicket(printer, order, addedItems);
                 if (success) {
                   successPrinters.add("${printer.name} (Yangilar)");
                   jobPrinted = true;
                 } else failedPrinters.add(printer.name);
              }

              if (cancelledItems.isNotEmpty) {
                 success = await _printer.printCancellationTicket(printer, order, cancelledItems);
                 if (success) {
                   successPrinters.add("${printer.name} (Bekor)");
                   jobPrinted = true;
                 } else failedPrinters.add("${printer.name} (Bekor xatosi)");
              }

              if (jobPrinted) {
                final currentPrintedMap = Map<String, int>.from(printedKitchenQuantities[orderIdStr] ?? {});
                for (var item in areaItems) {
                  currentPrintedMap[item['id'].toString()] = int.tryParse(item['qty'].toString()) ?? 0;
                }
                printedKitchenQuantities[orderIdStr] = currentPrintedMap;
                _storage.write('printed_kitchen_items', Map.from(printedKitchenQuantities));
              }

              if (addedItems.isEmpty && cancelledItems.isEmpty) {
                if (!shouldPrintCurrentReceipt) filteredPrinters.add(printer.name);
              }
            }
          }
        }
      } catch (e) {
        print("Error processing printer ${printer.name}: $e");
        failedPrinters.add(printer.name);
      }
    }
    
    isPrinting.value = false;

    if (failedPrinters.isNotEmpty) {
      String msg = "Failed: ${failedPrinters.join(', ')}";
      if (successPrinters.isNotEmpty) {
        msg += "\nSuccess: ${successPrinters.join(', ')}";
      }
      Get.snackbar("Printer Error", msg, 
        backgroundColor: Colors.red, colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
    } else if (successPrinters.isNotEmpty) {
      Get.snackbar("Printer", "Printed successfully on: ${successPrinters.join(', ')}", 
        backgroundColor: Colors.green, colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
    } else if (filteredPrinters.isNotEmpty) {
      Get.snackbar("Printer Info", "No matching items for: ${filteredPrinters.join(', ')}", 
        backgroundColor: Colors.blueGrey, colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> testPrinter(PrinterModel printer) async {
    await _printer.printTestPage(printer);
  }

  // User/Waiter Management
  Future<void> addUser(Map<String, dynamic> userData) async {
    try {
      final newUser = await _api.createUser(userData);
      users.add(newUser);
      _storage.write('all_users', users.toList());
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateUserProfile(String id, Map<String, dynamic> userData) async {
    try {
      final updatedUser = await _api.updateUser(id, userData);
      int index = users.indexWhere((u) => u['id'] == id);
      if (index != -1) {
        users[index] = updatedUser;
        users.refresh();
        _storage.write('all_users', users.toList());
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _api.deleteUser(id);
      users.removeWhere((u) => u['id'] == id);
      _storage.write('all_users', users.toList());
    } catch (e) {
      rethrow;
    }
  }
}

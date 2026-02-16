import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../data/models/food_item.dart';
import '../data/models/printer_model.dart';
import '../data/models/preparation_area_model.dart';
import '../data/services/api_service.dart';
import '../data/services/socket_service.dart';
import '../data/services/printer_service.dart';
import '../theme/app_colors.dart';

class POSController extends GetxController {
  final _storage = GetStorage();
  final _api = ApiService();
  final _socket = SocketService();
  final _printer = PrinterService();
  
  var currentOrder = <Map<String, dynamic>>[].obs;
  var allOrders = <Map<String, dynamic>>[].obs;
  var currentUser = Rxn<Map<String, dynamic>>();
  var pinCode = RxnString();
  var isPinAuthenticated = false.obs;
  var isPrinting = false.obs;
  
  // Order modes, current selection, table, and editing state
  final List<String> orderModes = ["Dine-in", "Takeaway", "Delivery"];
  var currentMode = "Dine-in".obs;
  
  // Product Catalog
  var products = <FoodItem>[].obs;
  var categories = <String>["All"].obs;
  var preparationAreas = <PreparationAreaModel>[].obs;
  var printers = <PrinterModel>[].obs;
  var selectedCategory = "All".obs;

  var selectedTable = "".obs;
  var editingOrderId = RxnInt(); // Track if we are editing an existing order
  String _originalOrderJson = ""; // To check if any changes were made
  var isOrderModified = false.obs;
  
  // Settings
  var printerPaperSize = "80mm".obs;
  var autoPrintReceipt = false.obs;
  var restaurantName = "".obs;
  var restaurantAddress = "".obs;
  var restaurantPhone = "".obs;

  @override
  void onInit() {
    super.onInit();
    _loadLocalData();
    _fetchBackendData();
    _setupSocketListeners();
  }

  void _loadLocalData() {
    var storedAllOrders = _storage.read('all_orders');
    if (storedAllOrders != null) {
      allOrders.assignAll(List<Map<String, dynamic>>.from(storedAllOrders));
    }

    var storedProducts = _storage.read('products');
    if (storedProducts != null) {
      products.assignAll((storedProducts as List).map((e) => FoodItem.fromJson(e)).toList());
    }

    var storedCategories = _storage.read('categories');
    if (storedCategories != null) {
      categories.assignAll(List<String>.from(storedCategories));
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
    restaurantName.value = _storage.read('restaurant_name') ?? "Fast Food Pro";
    restaurantAddress.value = _storage.read('restaurant_address') ?? "Tashkent, Uzbekistan";
    restaurantPhone.value = _storage.read('restaurant_phone') ?? "+998 90 123 45 67";

    var storedUser = _storage.read('user');
    if (storedUser != null) {
      currentUser.value = Map<String, dynamic>.from(storedUser);
    }

    pinCode.value = _storage.read('pin_code');
  }

  void setPinCode(String code) {
    pinCode.value = code;
    _storage.write('pin_code', code);
  }

  void authenticatePin(bool status) {
    isPinAuthenticated.value = status;
  }

  Future<void> _fetchBackendData() async {
    try {
      // Fetch Categories
      final backendCategories = await _api.getCategories();
      if (backendCategories.isNotEmpty) {
        categories.assignAll(["All", ...backendCategories.map((c) => c['name'].toString())]);
        saveCategories();
      }

      // Fetch Products
      final backendProducts = await _api.getProducts();
      if (backendProducts.isNotEmpty) {
        products.assignAll(backendProducts.map((p) => FoodItem.fromJson(p)).toList());
        saveProducts();
      }

      // Fetch Preparation Areas
      final backendPrepAreas = await _api.getPreparationAreas();
      if (backendPrepAreas.isNotEmpty) {
        preparationAreas.assignAll(backendPrepAreas.map((a) => PreparationAreaModel.fromJson(a)).toList());
        savePreparationAreas();
      }

      // Fetch Printers
      final backendPrinters = await _api.getPrinters();
      if (backendPrinters.isNotEmpty) {
        printers.assignAll(backendPrinters.map((p) => PrinterModel.fromJson(p)).toList());
        savePrinters();
      }

      // Fetch Orders
      final backendOrders = await _api.getOrders();
      if (backendOrders.isNotEmpty) {
        allOrders.assignAll(backendOrders.map((o) => _normalizeOrder(o)).toList());
        saveAllOrders();
      }
    } catch (e) {
      print("Error fetching backend data: $e");
    }
  }

  Map<String, dynamic> _normalizeOrder(Map<String, dynamic> o) {
    // Convert backend structure to frontend structure
    return {
      "id": o['id'],
      "table": o['tableNumber'] != null ? o['tableNumber'] : "-",
      "mode": o['type'].toString().toLowerCase().replaceAll("_", "-").capitalizeFirst,
      "items": (o['items'] as List).fold(0, (sum, item) => sum + (item['quantity'] as int)),
      "total": double.tryParse(o['totalAmount'].toString()) ?? 0.0,
      "status": o['status'].toString().replaceAll("_", " ").split(" ").map((s) => s.toLowerCase().capitalizeFirst).join(" "),
      "timestamp": o['createdAt'],
      "details": (o['items'] as List).map((i) => {
        "id": i['productId'],
        "name": i['product'] != null ? i['product']['name'] : "Unknown",
        "qty": i['quantity'],
        "price": double.tryParse(i['price'].toString()) ?? 0.0,
      }).toList(),
    };
  }

  void _setupSocketListeners() {
    _socket.onNewOrder((data) {
      // Add new order to list if it's not already there
      int index = allOrders.indexWhere((o) => o['id'] == data['id']);
      if (index == -1) {
        allOrders.insert(0, _normalizeOrder(data));
        allOrders.refresh();
        saveAllOrders();
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
  }

  double get subtotal => currentOrder.fold(0, (sum, item) => sum + (item['item'].price * item['quantity']));
  int get totalItems => currentOrder.fold(0, (sum, item) => sum + (item['quantity'] as int));

  // Service fee calculation based on mode
  double get serviceFee {
    if (currentMode.value == "Dine-in") {
      return subtotal * 0.10; // 10% Service for Dine-in
    } else if (currentMode.value == "Delivery") {
      return 3.00; // $3.00 flat fee for Delivery
    }
    return 0.0; // Free for Takeaway
  }

  double get tax => subtotal * 0.05; // 5% flat tax

  double get total => subtotal + serviceFee + tax;

  void setMode(String mode) {
    currentMode.value = mode;
    if (mode != "Dine-in") selectedTable.value = "";
  }

  void setTable(String table) {
    selectedTable.value = table;
  }

  void addToCart(FoodItem item) {
    int index = currentOrder.indexWhere((element) => element['item'].id == item.id);
    if (index != -1) {
      currentOrder[index]['quantity']++;
      currentOrder.refresh();
    } else {
      currentOrder.add({'item': item, 'quantity': 1});
    }
    _checkIfModified();
  }

  void removeFromCart(int index) {
    currentOrder.removeAt(index);
    _checkIfModified();
  }

  void updateQuantity(int index, int delta) {
    currentOrder[index]['quantity'] += delta;
    if (currentOrder[index]['quantity'] <= 0) {
      currentOrder.removeAt(index);
    } else {
      currentOrder.refresh();
    }
    _checkIfModified();
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
    } else {
      _storage.remove('user');
    }
  }

  void logout() {
    setCurrentUser(null);
    _api.setToken(null);
    Get.offAllNamed('/login'); // We should define routes in main.dart
  }

  Future<void> submitOrder({bool isPaid = false}) async {
    if (currentOrder.isEmpty) return;

    if (editingOrderId.value != null) {
      updateExistingOrder(isPaid: isPaid);
      return;
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
        "tableNumber": orderData["tableNumber"],
        "type": orderData["type"],
        "isPaid": isPaid,
        "items": (orderData["items"] as List).map((i) => {
          "productId": i["productId"],
          "quantity": i["qty"],
          "price": i["price"]
        }).toList(),
      });
      
      final normalizedOrder = _normalizeOrder(newOrder);
      allOrders.insert(0, normalizedOrder);
      
      // Print order (Kitchen or Receipt)
      await printOrder(normalizedOrder);

      clearCurrentOrder();
      saveAllOrders();
    } catch (e) {
      print("Error creating order: $e");
    }
  }

  void loadOrderForEditing(Map<String, dynamic> order, List<FoodItem> catalog) {
    editingOrderId.value = order['id'];
    currentMode.value = order['mode'] ?? "Dine-in";
    
    // Extract table number if exists
    String tableLabel = order['table'] ?? "";
    if (tableLabel.contains("Table ")) {
      selectedTable.value = tableLabel.replaceFirst("Table ", "");
    } else {
      selectedTable.value = "";
    }

    currentOrder.clear();
    final details = order['details'] as List? ?? [];
    for (var d in details) {
      final item = catalog.firstWhereOrNull((f) => f.id == d['id'] || f.name == d['name']);
      if (item != null) {
        currentOrder.add({'item': item, 'quantity': d['qty']});
      }
    }
    
    // Store original state for change tracking
    _originalOrderJson = currentOrder.map((e) => {
      "id": (e['item'] as FoodItem).id,
      "qty": e['quantity'],
    }).toList().toString();
    isOrderModified.value = false;
  }

  Future<void> updateExistingOrder({bool isPaid = false}) async {
    if (editingOrderId.value == null) return;
    
    try {
      // 1. Update status on backend
      final newStatus = isPaid ? "Completed" : "Preparing";
      await updateOrderStatus(editingOrderId.value!, newStatus);
      
      // 2. Update local state
      int index = allOrders.indexWhere((o) => o['id'] == editingOrderId.value);
      if (index != -1) {
        allOrders[index]['items'] = totalItems;
        allOrders[index]['total'] = total;
        allOrders[index]['status'] = newStatus;
        allOrders[index]['mode'] = currentMode.value;
        allOrders[index]['table'] = currentMode.value == "Dine-in" ? "Table ${selectedTable.value}" : "-";
        allOrders[index]['details'] = currentOrder.map((e) => {
          "id": (e['item'] as FoodItem).id,
          "name": (e['item'] as FoodItem).name,
          "qty": e['quantity'],
          "price": (e['item'] as FoodItem).price,
        }).toList();
        
        // 3. Print if it's a kitchen update
        await printOrder(allOrders[index]);

        allOrders.refresh();
        clearCurrentOrder();
        saveAllOrders();
      }
    } catch (e) {
      print("Error updating existing order: $e");
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

  void deleteOrder(int orderId) {
    allOrders.removeWhere((o) => o['id'] == orderId);
    allOrders.refresh();
    saveAllOrders();
  }

  void clearCurrentOrder() {
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

  void addProduct(FoodItem item) {
    products.add(item);
    saveProducts();
  }

  void updateProduct(FoodItem item) {
    int index = products.indexWhere((p) => p.id == item.id);
    if (index != -1) {
      products[index] = item;
      saveProducts();
    }
  }

  void deleteProduct(String id) {
    products.removeWhere((p) => p.id == id);
    saveProducts();
  }

  void addCategory(String category) {
    if (!categories.contains(category)) {
      categories.add(category);
      saveCategories();
    }
  }
  
  void updateCategory(String oldName, String newName) {
    if (!categories.contains(oldName)) return;
    int index = categories.indexOf(oldName);
    categories[index] = newName;
    saveCategories();

    // Update products
    for (int i = 0; i < products.length; i++) {
      if (products[i].category == oldName) {
        products[i] = FoodItem(
          id: products[i].id,
          name: products[i].name,
          description: products[i].description,
          price: products[i].price,
          imageUrl: products[i].imageUrl,
          category: newName,
          rating: products[i].rating,
          timeEstimate: products[i].timeEstimate,
        );
      }
    }
    products.refresh();
    saveProducts();
  }

  void deleteCategory(String category) {
    if (category != "All") {
      categories.remove(category);
      saveCategories();
    }
  }

  void addPreparationArea(PreparationAreaModel area) {
    preparationAreas.add(area);
    savePreparationAreas();
  }

  void savePreparationAreas() {
    _storage.write('preparation_areas', preparationAreas.map((e) => e.toJson()).toList());
  }

  void updatePreparationArea(PreparationAreaModel area) {
    int index = preparationAreas.indexWhere((a) => a.id == area.id);
    if (index != -1) {
      preparationAreas[index] = area;
      savePreparationAreas();
    }
  }

  void deletePreparationArea(String id) {
    preparationAreas.removeWhere((a) => a.id == id);
    savePreparationAreas();
  }

  void savePrinters() {
    _storage.write('printers', printers.map((e) => e.toJson()).toList());
  }

  void addPrinter(PrinterModel printer) {
    printers.add(printer);
    savePrinters();
  }

  void updatePrinter(PrinterModel printer) {
    int index = printers.indexWhere((p) => p.id == printer.id);
    if (index != -1) {
      printers[index] = printer;
      savePrinters();
    }
  }

  void deletePrinter(String id) {
    printers.removeWhere((p) => p.id == id);
    savePrinters();
  }

  Future<void> printOrder(Map<String, dynamic> order) async {
    isPrinting.value = true;
    bool anySuccess = false;
    
    final details = order['details'] as List? ?? [];
    
    for (var printer in printers) {
      if (!printer.isActive) continue;

      if (printer.preparationAreaId == null) {
        // Receipt Printer - Full Ticket
        final success = await _printer.printReceipt(printer, order);
        if (success) anySuccess = true;
      } else {
        // Kitchen Printer - Filtered items
        // We need to match items with printer's preparationAreaId
        final filteredItems = details.where((d) {
          // Robust ID matching: convert both to string and trim
          final product = products.firstWhereOrNull((p) => p.id.toString().trim() == d['id'].toString().trim());
          return product?.preparationAreaId != null && product?.preparationAreaId == printer.preparationAreaId;
        }).toList();

        if (filteredItems.isNotEmpty) {
          final success = await _printer.printKitchenTicket(printer, order, filteredItems);
          if (success) anySuccess = true;
        }
      }
    }
    
    isPrinting.value = false;
    if (anySuccess) {
      Get.snackbar("Printer", "Print job sent successfully", 
        backgroundColor: AppColors.primary.withOpacity(0.8), colorText: AppColors.white,
        snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
    } else if (printers.any((p) => p.isActive)) {
      Get.snackbar("Printer Error", "Could not connect to printers", 
        backgroundColor: Get.theme.colorScheme.error, colorText: AppColors.white,
        snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> testPrinter(PrinterModel printer) async {
    await _printer.printTestPage(printer);
  }
}

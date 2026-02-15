import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../data/models/food_item.dart';
import '../data/models/printer_model.dart';
import '../data/services/api_service.dart';
import '../data/services/socket_service.dart';

class POSController extends GetxController {
  final _storage = GetStorage();
  final _api = ApiService();
  final _socket = SocketService();
  
  var currentOrder = <Map<String, dynamic>>[].obs;
  var allOrders = <Map<String, dynamic>>[].obs;
  
  // Order modes, current selection, table, and editing state
  final List<String> orderModes = ["Dine-in", "Takeaway", "Delivery"];
  var currentMode = "Dine-in".obs;
  
  // Product Catalog
  var products = <FoodItem>[].obs;
  var categories = <String>["All", "Burger", "Pizza", "Drinks", "Chicken", "Salad", "Dessert"].obs;
  var preparationAreas = <String>["Kitchen", "Bar"].obs;
  var printers = <PrinterModel>[].obs;
  var selectedCategory = "All".obs;

  var selectedTable = "".obs;
  var editingOrderId = RxnInt(); // Track if we are editing an existing order
  String _originalOrderJson = ""; // To check if any changes were made
  var isOrderModified = false.obs;
  
  // Settings
  var printerPaperSize = "80mm".obs;
  var autoPrintReceipt = false.obs;
  var restaurantName = "Fast Food Pro".obs;
  var restaurantAddress = "Tashkent, Uzbekistan".obs;
  var restaurantPhone = "+998 90 123 45 67".obs;

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
      preparationAreas.assignAll(List<String>.from(storedPrepAreas));
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

      // Fetch Orders
      final backendOrders = await _api.getOrders();
      if (backendOrders.isNotEmpty) {
        allOrders.assignAll(List<Map<String, dynamic>>.from(backendOrders));
        saveAllOrders();
      }
    } catch (e) {
      print("Error fetching backend data: $e");
    }
  }

  void _setupSocketListeners() {
    _socket.onNewOrder((data) {
      // Add new order to list if it's not already there
      int index = allOrders.indexWhere((o) => o['id'] == data['id']);
      if (index == -1) {
        allOrders.insert(0, data);
        allOrders.refresh();
        saveAllOrders();
      }
    });

    _socket.onOrderStatusUpdated((data) {
      int index = allOrders.indexWhere((o) => o['id'] == data['orderId']);
      if (index != -1) {
        allOrders[index]['status'] = data['status'];
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
        "items": (orderData["items"] as List).map((i) => {
          "productId": i["productId"],
          "quantity": i["qty"],
          "price": i["price"]
        }).toList(),
      });
      
      allOrders.insert(0, newOrder);
      clearCurrentOrder();
      saveAllOrders();
    } catch (e) {
      print("Error creating order: $e");
      // Fallback for offline (optional)
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

  void updateExistingOrder({bool isPaid = false}) {
    int index = allOrders.indexWhere((o) => o['id'] == editingOrderId.value);
    if (index != -1) {
      allOrders[index]['items'] = totalItems;
      allOrders[index]['total'] = total;
      allOrders[index]['status'] = isPaid ? "Completed" : "Preparing";
      allOrders[index]['mode'] = currentMode.value;
      allOrders[index]['table'] = currentMode.value == "Dine-in" ? "Table ${selectedTable.value}" : "-";
      allOrders[index]['details'] = currentOrder.map((e) => {
        "id": (e['item'] as FoodItem).id,
        "name": (e['item'] as FoodItem).name,
        "qty": e['quantity'],
        "price": (e['item'] as FoodItem).price,
      }).toList();
      
      allOrders.refresh();
      clearCurrentOrder();
      saveAllOrders();
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

  void savePreparationAreas() {
    _storage.write('preparation_areas', preparationAreas.toList());
  }

  void addPreparationArea(String area) {
    if (!preparationAreas.contains(area)) {
      preparationAreas.add(area);
      savePreparationAreas();
    }
  }

  void updatePreparationArea(String oldName, String newName) {
    if (!preparationAreas.contains(oldName)) return;
    int index = preparationAreas.indexOf(oldName);
    preparationAreas[index] = newName;
    savePreparationAreas();

    // Update products
    for (int i = 0; i < products.length; i++) {
      if (products[i].preparationArea == oldName) {
        products[i] = FoodItem(
          id: products[i].id,
          name: products[i].name,
          description: products[i].description,
          price: products[i].price,
          imageUrl: products[i].imageUrl,
          category: products[i].category,
          rating: products[i].rating,
          timeEstimate: products[i].timeEstimate,
          preparationArea: newName,
        );
      }
    }
    products.refresh();
    saveProducts();

    // Update printers
    for (int i = 0; i < printers.length; i++) {
      var printer = printers[i];
      if (printer.assignedAreas.contains(oldName)) {
        var newAreas = List<String>.from(printer.assignedAreas);
        newAreas[newAreas.indexOf(oldName)] = newName;
        printers[i] = PrinterModel(
          id: printer.id,
          name: printer.name,
          ipAddress: printer.ipAddress,
          port: printer.port,
          assignedAreas: newAreas,
          isDefault: printer.isDefault,
        );
      }
    }
    printers.refresh();
    savePrinters();
  }

  void deletePreparationArea(String area) {
    preparationAreas.remove(area);
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
      printers[index] = PrinterModel(
        id: printer.id,
        name: printer.name,
        ipAddress: printer.ipAddress,
        port: printer.port,
        assignedAreas: printer.assignedAreas,
        isDefault: printer.isDefault,
      );
      savePrinters();
    }
  }

  void deletePrinter(String id) {
    printers.removeWhere((p) => p.id == id);
    savePrinters();
  }
}

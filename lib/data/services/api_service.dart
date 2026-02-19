import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';

class ApiService {
  static final String baseUrl = 'https://cafe-backend-code-production.up.railway.app'; 
  
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  final GetStorage _storage = GetStorage();
  String? _token;

  ApiService._internal() {
    _token = _storage.read('access_token');
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
    ));
  }

  void setToken(String? token) {
    _token = token;
    _storage.write('access_token', token);
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      _token = response.data['access_token'];
      _storage.write('access_token', _token);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/auth/register', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Categories
  Future<List<dynamic>> getCategories() async {
    try {
      final response = await _dio.get('/categories');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/categories/', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCategory(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/categories/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _dio.delete('/categories/$id');
    } catch (e) {
      rethrow;
    }
  }

  // Products
  Future<List<dynamic>> getProducts() async {
    try {
      final response = await _dio.get('/products');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/products/', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/products/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await _dio.delete('/products/$id');
    } catch (e) {
      rethrow;
    }
  }

  // Orders
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> orderData) async {
    try {
      final response = await _dio.post('/orders', data: orderData);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getOrders() async {
    try {
      final response = await _dio.get('/orders');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    try {
      final backendStatus = status.toUpperCase().replaceAll(" ", "_");
      await _dio.patch('/orders/$orderId/status', data: {'status': backendStatus});
    } catch (e) {
      rethrow;
    }
  }

  Future<String> uploadImage(String filePath) async {
    try {
      String fileName = filePath.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dio.post('/uploads/', data: formData);
      return response.data['url'];
    } catch (e) {
      rethrow;
    }
  }

  // Preparation Areas
  Future<List<dynamic>> getPreparationAreas() async {
    try {
      final response = await _dio.get('/preparation-areas');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPreparationArea(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/preparation-areas', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updatePreparationArea(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/preparation-areas/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePreparationArea(String id) async {
    try {
      await _dio.delete('/preparation-areas/$id');
    } catch (e) {
      rethrow;
    }
  }

  // Printers
  Future<List<dynamic>> getPrinters() async {
    try {
      final response = await _dio.get('/printers');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createPrinter(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/printers', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updatePrinter(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/printers/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePrinter(String id) async {
    try {
      await _dio.delete('/printers/$id');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final response = await _dio.get('/cafes/subscription-status');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCafe(String id) async {
    try {
      final response = await _dio.get('/cafes/$id');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCafe(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/cafes/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getLatestVersion() async {
    try {
      final response = await _dio.get('/system/version');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Users
  Future<List<dynamic>> getUsers() async {
    try {
      final response = await _dio.get('/users/');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/users/', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/users/$id', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _dio.delete('/users/$id');
    } catch (e) {
      rethrow;
    }
  }
}

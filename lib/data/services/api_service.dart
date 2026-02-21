import 'package:dio/dio.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get/get.dart' as g;
import '../../logic/pos_controller.dart' as logic;

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;
  final GetStorage _storage = GetStorage();
  String? _token;

  ApiService._internal() {
    final String baseUrl = _storage.read('api_url') ?? 'https://cafe-backend-code-production.up.railway.app';
    
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));

    _token = _storage.read('access_token');
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        if (e.response?.statusCode == 401) {
          final detail = e.response?.data?['detail'];
          if (detail == "Qurilma o'zgargani sababli tizimdan chiqdingiz") {
             try {
                g.Get.find<logic.POSController>().logout(forced: true);
             } catch (_) {}
          }
        }
        return handler.next(e);
      }
    ));
  }

  void setBaseUrl(String url) {
    // Basic validation
    if (!url.startsWith('http')) {
      url = 'https://$url';
    }
    _storage.write('api_url', url);
    _dio.options.baseUrl = url;
    print("API Base URL set to: $url");
  }

  String get currentBaseUrl => _dio.options.baseUrl;

  void setToken(String? token) {
    _token = token;
    _storage.write('access_token', token);
  }

  void restoreTerminalToken() {
    _token = _storage.read('terminal_token');
    _storage.write('access_token', _token);
  }

  void clearTerminalToken() {
    _storage.remove('terminal_token');
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password, {String? deviceId, String? deviceName}) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
        'device_id': deviceId,
        'device_name': deviceName,
      });
      _token = response.data['access_token'];
      _storage.write('access_token', _token);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loginTerminal(String username, String password) async {
    try {
      final response = await _dio.post('/auth/terminal/login', data: {
        'username': username,
        'password': password,
      });
      _token = response.data['access_token'];
      _storage.write('access_token', _token);
      _storage.write('terminal_token', _token); 
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> loginWithPin(String userId, String pinCode, {String? deviceId, String? deviceName}) async {
    try {
      final response = await _dio.post('/auth/login/pin', data: {
        'user_id': userId,
        'pin_code': pinCode,
        'device_id': deviceId,
        'device_name': deviceName,
      });
      _token = response.data['access_token'];
      _storage.write('access_token', _token);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getTerminalStaff() async {
    try {
      final response = await _dio.get('/auth/terminal/staff');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getStaffPublic(String cafeId) async {
    try {
      final response = await _dio.get('/auth/staff-public/$cafeId');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateLocation(double lat, double lng) async {
    try {
      final response = await _dio.post('/auth/location', data: {
        'lat': lat,
        'lng': lng,
      });
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

  // Products
  Future<List<dynamic>> getProducts() async {
    try {
      final response = await _dio.get('/products');
      return response.data;
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

  Future<Map<String, dynamic>> updateOrder(int orderId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/orders/$orderId', data: data);
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

  // Printers
  Future<List<dynamic>> getPrinters() async {
    try {
      final response = await _dio.get('/printers');
      return response.data;
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

  // Tables & Floor Plan
  Future<List<dynamic>> getTableAreas() async {
    try {
      final response = await _dio.get('/table-areas');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getTables() async {
    try {
      final response = await _dio.get('/tables');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Users
  Future<List<dynamic>> getUsers() async {
    try {
      final response = await _dio.get('/users');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}

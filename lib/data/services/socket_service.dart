import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_service.dart';

class SocketService {
  late IO.Socket socket;
  
  // Singleton
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal() {
    _initSocket();
  }

  void _initSocket() {
    socket = IO.io(ApiService.baseUrl, 
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .setQuery({'client': 'mobile'})
        .enableAutoConnect()
        .build()
    );

    socket.onConnect((_) {
      print('WebSocket connected: ${socket.id}');
    });

    socket.onDisconnect((_) {
      print('WebSocket disconnected');
    });

    socket.onConnectError((err) => print('Connection Error: $err'));
  }

  void onNewOrder(Function(dynamic) callback) {
    socket.on('newOrder', (data) => callback(data));
  }

  void onOrderStatusUpdated(Function(dynamic) callback) {
    socket.on('orderStatusUpdated', (data) => callback(data));
  }

  void disconnect() {
    socket.disconnect();
  }
}

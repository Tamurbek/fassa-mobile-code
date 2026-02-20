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

  void emitPrintRequest(Map<String, dynamic> data) {
    socket.emit('printRequest', data);
  }

  void onPrintRequest(Function(dynamic) callback) {
    socket.on('printRequest', (data) => callback(data));
  }

  void emitTableLock(String tableId, String userName) {
    socket.emit('tableLock', {'tableId': tableId, 'user': userName});
  }

  void emitTableUnlock(String tableId) {
    socket.emit('tableUnlock', {'tableId': tableId});
  }

  void onTableLockStatus(Function(dynamic) callback) {
    socket.on('tableLockStatus', (data) => callback(data));
  }

  void disconnect() {
    socket.disconnect();
  }
}

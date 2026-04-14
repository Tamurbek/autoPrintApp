
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/settings.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  
  final Function(String) onLog;
  final Function() onNewJob;
  final Function(bool)? onStatusChange;

  WebSocketService({required this.onLog, required this.onNewJob, this.onStatusChange});

  void connect(AppSettings settings) {
    if (_isConnected) return;
    
    try {
      final uri = Uri.parse(settings.apiUrl);
      
      // Ensure we don't have double paths if apiUrl already has a part of API path
      String path = uri.path;
      if (path.contains('/api/external')) {
        path = path.substring(0, path.indexOf('/api/external'));
      }
      if (path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      
      final wsUri = uri.replace(
        scheme: uri.scheme == 'https' ? 'wss' : 'ws',
        path: '$path/ws/external/printers',
        queryParameters: {'apiKey': settings.apiKey},
      );
      
      final wsUrl = wsUri.toString();
      onLog("WebSocket-ga ulanish: $wsUrl");
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      onStatusChange?.call(true);
      
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          _isConnected = false;
          onStatusChange?.call(false);
          onLog("WebSocket aloqasi uzildi.");
          _retryConnection(settings);
        },
        onError: (error) {
          _isConnected = false;
          onStatusChange?.call(false);
          onLog("WebSocket xatosi: $error");
          _retryConnection(settings);
        },
      );
    } catch (e) {
      _isConnected = false;
      onStatusChange?.call(false);
      onLog("WebSocket ulanishda xatolik: $e");
      _retryConnection(settings);
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      if (data['action'] == 'new_job' || data['type'] == 'new_job') {
        onNewJob();
      }
    } catch (e) {
      // If it's not JSON, maybe it's just a string command
      if (message == 'new_job') {
        onNewJob();
      }
    }
  }

  void _retryConnection(AppSettings settings) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) connect(settings);
    });
  }

  void disconnect() {
    _isConnected = false;
    onStatusChange?.call(false);
    _reconnectTimer?.cancel();
    _channel?.sink.close();
  }
}

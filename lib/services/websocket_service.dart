
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/settings.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _retryCount = 0;
  
  final Function(String) onLog;
  final Function() onNewJob;
  final Function(bool)? onStatusChange;

  WebSocketService({required this.onLog, required this.onNewJob, this.onStatusChange});

  void connect(AppSettings settings) {
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

    // If already connected to the SAME URL, do nothing
    if (_isConnected && _channel != null) {
      // We don't have a direct way to see the current channel's URL easily with web_socket_channel
      // but we can track the last used URL.
      return; 
    }

    // Force disconnect if attempting to connect to a different URL or re-establishing
    if (_channel != null) {
      disconnect();
    }
    
    try {
      onLog("WebSocket-ga ulanish: $wsUrl");
      
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.ready.timeout(const Duration(seconds: 20)).then((_) {
        _isConnected = true;
        _retryCount = 0;
        onStatusChange?.call(true);
      }).catchError((error) {
        _handleWsError(error, settings);
      });

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () => _handleWsDone(settings),
        onError: (error) => _handleWsError(error, settings),
        cancelOnError: true,
      );
    } catch (e) {
      _handleWsError(e, settings);
    }
  }

  void _handleWsDone(AppSettings settings) {
    if (!_isConnected) return;
    _isConnected = false;
    onStatusChange?.call(false);
    onLog("WebSocket aloqasi uzildi.");
    _retryConnection(settings);
  }

  void _handleWsError(dynamic error, AppSettings settings) {
    if (_isConnected || _reconnectTimer == null || !_reconnectTimer!.isActive) {
       _isConnected = false;
       onStatusChange?.call(false);
       onLog("WebSocket xatosi: $error");
       _retryConnection(settings);
    }
  }

  void _handleMessage(dynamic message) {
    onLog("WebSocket xabari: $message");
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
    if (_isConnected) return;
    _reconnectTimer?.cancel();
    
    _retryCount++;
    final delay = (5 * _retryCount).clamp(5, 60); // 5s, 10s, 15s... max 60s
    
    onLog("WebSocket qayta ulanishga urinish ($delay sek kutmoqda)...");
    
    _reconnectTimer = Timer(Duration(seconds: delay), () {
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

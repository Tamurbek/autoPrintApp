
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

  WebSocketService({required this.onLog, required this.onNewJob});

  void connect(AppSettings settings) {
    if (_isConnected) return;
    
    final baseUrl = settings.apiUrl.replaceFirst('http', 'ws');
    final wsUrl = "$baseUrl/ws/external/printers?apiKey=${settings.apiKey}";
    
    onLog("WebSocket-ga ulanish: $wsUrl");
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      
      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          _isConnected = false;
          onLog("WebSocket aloqasi uzildi.");
          _retryConnection(settings);
        },
        onError: (error) {
          _isConnected = false;
          onLog("WebSocket xatosi: $error");
          _retryConnection(settings);
        },
      );
    } catch (e) {
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
    _reconnectTimer?.cancel();
    _channel?.sink.close();
  }
}

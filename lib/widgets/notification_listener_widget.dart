import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class NotificationListenerWidget extends StatefulWidget {
  final Widget child;
  
  const NotificationListenerWidget({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<NotificationListenerWidget> createState() => _NotificationListenerWidgetState();
}

class _NotificationListenerWidgetState extends State<NotificationListenerWidget> {
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  bool _isInitialized = false;
  
  @override
  void initState() {
    super.initState();
    // Delay initialization until the widget is properly mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }
  
  Future<void> _initializeNotifications() async {
    if (_isInitialized) return;
    
    try {
      await _notificationService.initialize();
      
      // Listen for notifications with error handling
      _notificationService.notificationStream.listen((notification) {
        if (mounted) {
          try {
            _showNotification(notification);
          } catch (e) {
            debugPrint('Error showing notification: $e');
          }
        }
      }, onError: (error) {
        debugPrint('Error in notification stream: $error');
      });
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }
  
  void _showNotification(Map<String, dynamic> notification) {
    if (!mounted) return;
    
    final action = notification['action'] as String? ?? 'UNKNOWN';
    final status = notification['status'] as String? ?? 'UNKNOWN';
    final message = notification['message'] as String? ?? 'Notifikasi baru';
    final idTool = notification['idTool'] as String? ?? '';
    
    // Tentukan warna berdasarkan status
    Color backgroundColor;
    IconData iconData;
    
    if (status == 'SUCCESS') {
      backgroundColor = Colors.green.shade700;
      iconData = Icons.check_circle;
    } else if (status == 'WARNING') {
      backgroundColor = Colors.orange.shade700;
      iconData = Icons.warning;
    } else if (status == 'ERROR') {
      backgroundColor = Colors.red.shade700;
      iconData = Icons.error;
    } else {
      backgroundColor = Colors.blue.shade700;
      iconData = Icons.notifications;
    }
    
    // Tampilkan snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              iconData,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'TUTUP',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
    
    // Jika ini adalah notifikasi approval, tampilkan dialog
    if (action == 'PREPARE_APPROVED' || action == 'RETURN_APPROVED') {
      _showApprovalDialog(notification);
    }
  }
  
  void _showApprovalDialog(Map<String, dynamic> notification) {
    if (!mounted) return;
    
    final action = notification['action'] as String? ?? 'UNKNOWN';
    final message = notification['message'] as String? ?? 'Notifikasi baru';
    final idTool = notification['idTool'] as String? ?? '';
    final fromUser = notification['fromUser'] as String? ?? 'UNKNOWN';
    
    // Tampilkan dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green.shade700,
            ),
            const SizedBox(width: 8),
            Text(
              action == 'PREPARE_APPROVED' ? 'Prepare Disetujui' : 'Return Disetujui',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Text(
              'ID Tool: $idTool',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text('Disetujui oleh: $fromUser'),
            Text('Waktu: ${DateTime.now().toString()}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
} 
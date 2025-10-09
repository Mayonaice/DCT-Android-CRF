import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationService {
  // Singleton instance
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  
  // Keys for SharedPreferences
  static const String _notificationsKey = 'crf_notifications';
  
  // Stream controllers untuk notifikasi
  final _notificationStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream => _notificationStreamController.stream;
  
  // Timer untuk polling notifikasi
  Timer? _pollingTimer;
  bool _isInitialized = false;
  
  // Inisialisasi service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Ensure notifications list exists
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_notificationsKey)) {
        await prefs.setString(_notificationsKey, '[]');
      }
      
      // Start polling for notifications every 5 seconds
      _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkForNotifications());
      
      _isInitialized = true;
      debugPrint('NotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
      rethrow;
    }
  }
  
  // Dispose resources
  void dispose() {
    _pollingTimer?.cancel();
    _notificationStreamController.close();
    _isInitialized = false;
  }
  
  // Kirim notifikasi
  Future<bool> sendNotification({
    required String idTool,
    required String action,
    required String status,
    required String message,
    required String fromUser,
    required String toUser,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get existing notifications
      List<dynamic> existingNotifications;
      try {
        existingNotifications = json.decode(prefs.getString(_notificationsKey) ?? '[]') as List<dynamic>;
      } catch (e) {
        debugPrint('Error parsing notifications: $e');
        existingNotifications = [];
      }
      
      // Create new notification
      final Map<String, dynamic> notification = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'idTool': idTool,
        'action': action,
        'status': status,
        'message': message,
        'fromUser': fromUser,
        'toUser': toUser,
        'timestamp': DateTime.now().toIso8601String(),
        'isRead': false,
        'additionalData': additionalData,
      };
      
      // Add to list
      existingNotifications.add(notification);
      
      // Save back to SharedPreferences
      await prefs.setString(_notificationsKey, json.encode(existingNotifications));
      
      debugPrint('Notification sent: ${notification['message']}');
      return true;
    } catch (e) {
      debugPrint('Error sending notification: $e');
      return false;
    }
  }
  
  // Cek notifikasi baru untuk user tertentu
  Future<void> _checkForNotifications() async {
    if (!_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get current user ID from prefs
      final userData = prefs.getString('user_data');
      if (userData == null || userData.isEmpty) {
        return;
      }
      
      Map<String, dynamic> user;
      try {
        user = json.decode(userData) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error parsing user data: $e');
        return;
      }
      
      final currentUserId = user['nik'] ?? user['userID'] ?? '';
      
      if (currentUserId.isEmpty) {
        return;
      }
      
      // Get notifications
      List<dynamic> notifications;
      try {
        notifications = json.decode(prefs.getString(_notificationsKey) ?? '[]') as List<dynamic>;
      } catch (e) {
        debugPrint('Error parsing notifications: $e');
        return;
      }
      
      // Filter unread notifications for current user
      final unreadNotifications = notifications.where((notification) {
        return notification['toUser'] == currentUserId && 
               notification['isRead'] == false;
      }).toList();
      
      // Emit notifications to stream
      for (var notification in unreadNotifications) {
        _notificationStreamController.add(notification);
        
        // Mark as read
        notification['isRead'] = true;
      }
      
      // Save updated notifications
      if (unreadNotifications.isNotEmpty) {
        await prefs.setString(_notificationsKey, json.encode(notifications));
      }
    } catch (e) {
      debugPrint('Error checking notifications: $e');
    }
  }
  
  // Mendapatkan semua notifikasi untuk user tertentu
  Future<List<Map<String, dynamic>>> getNotificationsForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get notifications
      List<dynamic> notifications;
      try {
        notifications = json.decode(prefs.getString(_notificationsKey) ?? '[]') as List<dynamic>;
      } catch (e) {
        debugPrint('Error parsing notifications: $e');
        return [];
      }
      
      // Filter notifications for user
      return notifications
          .where((notification) => notification['toUser'] == userId)
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      return [];
    }
  }
  
  // Hapus semua notifikasi
  Future<bool> clearAllNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notificationsKey, '[]');
      return true;
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
      return false;
    }
  }
} 
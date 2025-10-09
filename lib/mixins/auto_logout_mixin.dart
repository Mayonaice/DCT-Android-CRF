import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

/// Mixin untuk menangani auto-logout ketika token expired
/// Dapat digunakan oleh semua screen yang membutuhkan token validation
mixin AutoLogoutMixin<T extends StatefulWidget> on State<T> {
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();
  
  /// Check token expiry sebelum melakukan API call
  /// Returns true jika token valid, false jika expired (dan sudah logout)
  Future<bool> checkTokenBeforeApiCall() async {
    try {
      final isValid = await _apiService.checkTokenExpiryAndLogout();
      if (!isValid && mounted) {
        // Token expired, user sudah di-logout oleh checkTokenExpiryAndLogout
        // Navigate ke login screen
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (Route<dynamic> route) => false,
        );
        return false;
      }
      return isValid;
    } catch (e) {
      debugPrint('Error in checkTokenBeforeApiCall: $e');
      // Jika ada error, asumsikan token invalid dan logout
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (Route<dynamic> route) => false,
        );
      }
      return false;
    }
  }
  
  /// Wrapper untuk API calls yang otomatis check token expiry
  /// Usage: await safeApiCall(() => apiService.getData())
  Future<T?> safeApiCall<T>(Future<T> Function() apiCall) async {
    final isTokenValid = await checkTokenBeforeApiCall();
    if (!isTokenValid) {
      return null;
    }
    
    try {
      return await apiCall();
    } catch (e) {
      // Check jika error adalah session expired
      if (e.toString().contains('Session expired') || 
          e.toString().contains('Unauthorized') ||
          e.toString().contains('401')) {
        debugPrint('🚨 Session expired during API call: $e');
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
            (Route<dynamic> route) => false,
          );
        }
        return null;
      }
      rethrow;
    }
  }
  
  /// Check token expiry secara periodik (untuk long-running screens)
  /// Call ini di initState() untuk screen yang perlu periodic check
  void startPeriodicTokenCheck({Duration interval = const Duration(minutes: 5)}) {
    Timer.periodic(interval, (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final isValid = await checkTokenBeforeApiCall();
      if (!isValid) {
        timer.cancel();
      }
    });
  }
}
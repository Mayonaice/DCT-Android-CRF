import 'package:flutter/material.dart';

// Colors
class AppColors {
  static const Color primaryGreen = Color(0xFF17766C);
  static const Color primaryBlue = Color(0xFF0056A4);
  static const Color secondaryBlue = Color(0xFF0056A4);
  static const Color lightBlue = Color(0xFF7CBFEA);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color grey = Color(0xFFF5F5F5);
  static const Color textGrey = Color(0xFF666666);
}

// Text Styles
class AppTextStyles {
  static const TextStyle heading = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.black,
  );
  
  static const TextStyle subheading = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.black,
  );
  
  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: AppColors.black,
  );
  
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );
}

// Assets
class AppAssets {
  static const String logo = 'assets/images/logo.png';
  static const String loginBackground = 'assets/images/login_background.png';
  static const String userIcon = 'assets/images/user_icon.png';
}

// Routes
class AppRoutes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/home';
} 
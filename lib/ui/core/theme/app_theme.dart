import 'package:flutter/material.dart';

/// Bảng màu và cấu hình giao diện Material 3 của ứng dụng, lấy cảm hứng từ Todoist.
class AppTheme {
  // Màu đỏ cam chủ đạo đặc trưng của Todoist
  static const Color primaryColor = Color(0xFFE44332);

  // Màu đỏ đậm dùng để cảnh báo các task đã bị quá hạn (Overdue)
  static const Color overdueColor = Color(0xFFD1453B);

  // Màu xanh lá dùng cho hành động hoàn thành (Complete) khi vuốt ngang
  static const Color completeColor = Color(0xFF2E7D32);

  /// Cấu hình giao diện Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFFAFAFA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Color(0xFF202020),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Colors.white,
      ),
    );
  }

  /// Cấu hình giao diện Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF252525),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

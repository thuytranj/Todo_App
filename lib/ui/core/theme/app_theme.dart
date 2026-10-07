import 'package:flutter/material.dart';

/// Bảng màu và cấu hình giao diện Material 3 của ứng dụng, lấy cảm hứng từ Todoist.
class AppTheme {
  // Màu đỏ cam chủ đạo đặc trưng của Todoist
  static const Color primaryColor = Color(0xFFE44332);

  // Màu đỏ đậm dùng để cảnh báo các task đã bị quá hạn (Overdue)
  static const Color overdueColor = Color(0xFFD1453B);

  // Màu xanh lá dùng cho hành động hoàn thành (Complete) khi vuốt ngang
  static const Color completeColor = Color(0xFF2E7D32);

  // Màu vàng/hổ phách dùng cho hiệu ứng nhắc nhở công việc (Reminder Highlight)
  static const Color reminderColor = Color(0xFFF59E0B);

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
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0.0),
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        hintStyle: WidgetStatePropertyAll(TextStyle(color: Colors.grey.shade500)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: const BorderSide(color: Color(0xFFE5E7EB), width: 1.0),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF202020),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: const Color(0xFFFF6B6B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
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
        surface: const Color(0xFF1E1E1E),
      ),
      scaffoldBackgroundColor: const Color(0xFF1E1E1E),
      dividerColor: const Color(0xFF333333),
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
      cardTheme: const CardThemeData(
        elevation: 0,
        color: Color(0xFF242424),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF242424),
        surfaceTintColor: Colors.transparent,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0.0),
        backgroundColor: const WidgetStatePropertyAll(Color(0xFF242424)),
        hintStyle: WidgetStatePropertyAll(TextStyle(color: Colors.grey.shade400)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            side: const BorderSide(color: Color(0xFF383838), width: 1.0),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2C2C2C),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: const Color(0xFFFF8A80),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.0),
          side: const BorderSide(color: Color(0xFF444444), width: 0.8),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Banner cảnh báo hiển thị trên đầu màn hình chính khi quyền thông báo bị từ chối.
/// Cung cấp nút bấm để mở trang Cài đặt hệ thống thông qua callback [onOpenSettings].
class PermissionBanner extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const PermissionBanner({
    super.key,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF2E2200) : const Color(0xFFFFF3CD);
    final borderColor =
        isDark ? const Color(0xFF543E00) : const Color(0xFFFFEEBA);
    final contentColor =
        isDark ? const Color(0xFFFFD54F) : const Color(0xFF856404);
    final buttonBg =
        isDark ? const Color(0xFFFFC107) : const Color(0xFF856404);
    final buttonTextColor = isDark ? const Color(0xFF212121) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor, // Màu nền dịu thích ứng theo theme
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: contentColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Notifications are disabled. You will not receive reminders.',
              style: TextStyle(
                color: contentColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onOpenSettings,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 36),
              backgroundColor: buttonBg,
              foregroundColor: buttonTextColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Settings',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD), // Màu vàng cam cảnh báo dịu
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFEEBA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            color: Color(0xFF856404),
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Notifications are disabled. You will not receive reminders.',
              style: TextStyle(
                color: Color(0xFF856404),
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
              backgroundColor: const Color(0xFF856404),
              foregroundColor: Colors.white,
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

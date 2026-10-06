import 'package:flutter/material.dart';
import 'package:todo_app/ui/core/theme/app_theme.dart';

/// Banner hướng dẫn cử chỉ và thao tác nhanh khi người dùng mới vào ứng dụng:
/// - Hướng dẫn vuốt phải để Hoàn thành / Mở lại.
/// - Hướng dẫn vuốt trái để Xóa nhanh.
/// - Nhắc người dùng có thể nhấn trực tiếp biểu tượng thùng rác để xóa.
/// - Tự động thích ứng cả Light Mode và Dark Mode.
/// - Hỗ trợ nút "Đã hiểu" và nút "X" để đóng và lưu trạng thái vào Storage.
class SwipeTutorialBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const SwipeTutorialBanner({
    super.key,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor =
        isDark ? const Color(0xFF1B2430) : const Color(0xFFEFF6FF);
    final borderColor =
        isDark ? const Color(0xFF2C3E50) : const Color(0xFFBFDBFE);
    final titleColor =
        isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);
    final bodyColor =
        isDark ? Colors.grey.shade300 : const Color(0xFF1E293B);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề & Nút đóng nhanh
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quick Tips & Gestures',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
              ),
              InkWell(
                key: const Key('tutorial_close_button'),
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Mục 1: Vuốt phải
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.swipe_right_rounded,
                color: AppTheme.completeColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12.5, color: bodyColor),
                    children: const [
                      TextSpan(
                        text: 'Swipe right ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: 'to mark a task as completed or reopen it.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Mục 2: Vuốt trái hoặc chạm thùng rác để xóa
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.swipe_left_rounded,
                color: Colors.red.shade600,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 12.5, color: bodyColor),
                    children: const [
                      TextSpan(
                        text: 'Swipe left ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: 'or tap the ',
                      ),
                      TextSpan(
                        text: 'trash icon',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: ' on any task to delete.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Nút "Got it"
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('tutorial_got_it_button'),
              onPressed: onDismiss,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                minimumSize: const Size(0, 32),
                backgroundColor:
                    isDark ? const Color(0xFF2563EB) : const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

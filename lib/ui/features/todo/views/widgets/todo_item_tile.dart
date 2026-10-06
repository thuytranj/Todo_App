import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo_app/domain/logic/todo_logic.dart';
import 'package:todo_app/domain/models/todo.dart';
import 'package:todo_app/ui/core/theme/app_theme.dart';

/// Widget hiển thị một mục công việc trong danh sách (phong cách Todoist):
/// - Tương thích hoàn hảo cho cả Light Mode và Dark Mode.
/// - Nút bấm tròn check hoàn thành.
/// - Nhãn hạn chót với cảnh báo đỏ khi quá hạn ([isOverdue]).
/// - Vuốt sang phải (LTR): Hoàn thành task (nền xanh lá).
/// - Vuốt sang trái (RTL): Xóa task (nền đỏ).
/// - Hiệu ứng làm nổi bật (Highlight Animation) khi người dùng chạm vào thông báo nhắc nhở.
class TodoItemTile extends StatelessWidget {
  final Todo todo;
  final DateTime now;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool isHighlighted;

  const TodoItemTile({
    super.key,
    required this.todo,
    required this.now,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overdue = isOverdue(todo, now);

    // Màu sắc thích ứng hoàn hảo giữa Light Mode và Dark Mode
    final Color tileColor;
    final Border border;

    if (isHighlighted) {
      // Highlight màu đỏ Todoist khi người dùng mở từ thông báo nhắc nhở
      tileColor = isDark ? const Color(0xFF3E2421) : const Color(0xFFFDECEB);
      border = const Border(
        bottom: BorderSide(color: AppTheme.primaryColor, width: 1.5),
        left: BorderSide(color: AppTheme.primaryColor, width: 4.0),
      );
    } else if (todo.isCompleted) {
      // Highlight xanh lá dịu cho task đã hoàn thành theo yêu cầu người dùng
      tileColor = isDark ? const Color(0xFF142918) : const Color(0xFFE8F5E9);
      border = Border(
        bottom: BorderSide(
          color: isDark ? const Color(0xFF1E3D24) : const Color(0xFFC8E6C9),
          width: 1.0,
        ),
        left: BorderSide(
          color: isDark ? const Color(0xFF4CAF50) : AppTheme.completeColor,
          width: 4.0,
        ),
      );
    } else if (overdue) {
      // Highlight tone màu đỏ cảnh báo cho task quá hạn (tương tự như complete)
      tileColor = isDark ? const Color(0xFF2E1515) : const Color(0xFFFFF0EF);
      border = Border(
        bottom: BorderSide(
          color: isDark ? const Color(0xFF4A1E1E) : const Color(0xFFFFCDD2),
          width: 1.0,
        ),
        left: BorderSide(
          color: isDark ? const Color(0xFFEF5350) : AppTheme.overdueColor,
          width: 4.0,
        ),
      );
    } else {
      tileColor = isDark ? const Color(0xFF242424) : Colors.white;
      border = Border(
        bottom: BorderSide(
          color: isDark ? const Color(0xFF333333) : Colors.grey.shade200,
          width: 0.8,
        ),
      );
    }

    final Color titleColor;
    if (todo.isCompleted) {
      titleColor = isDark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32);
    } else if (overdue) {
      titleColor = isDark ? const Color(0xFFFF8A80) : AppTheme.overdueColor;
    } else {
      titleColor = isDark ? Colors.white : const Color(0xFF202020);
    }

    final descColor = todo.isCompleted
        ? (isDark ? Colors.green.shade900.withAlpha(200) : Colors.green.shade700)
        : (overdue
            ? (isDark ? const Color(0xFFE57373) : const Color(0xFFC62828))
            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600));

    final badgeColor = overdue && !todo.isCompleted
        ? AppTheme.overdueColor
        : (isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700);

    return Dismissible(
      key: ValueKey(todo.id),
      // Vuốt từ trái sang phải (LTR) -> Hoàn thành / Hoàn tác task
      background: Container(
        color: todo.isCompleted
            ? Colors.blueGrey.shade700
            : AppTheme.completeColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: [
            Icon(
              todo.isCompleted ? Icons.replay : Icons.check_circle_outline,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              todo.isCompleted ? 'Reopen' : 'Complete',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      // Vuốt từ phải sang trái (RTL) -> Xóa task
      secondaryBackground: Container(
        color: Colors.red.shade700,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white, size: 28),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggle();
          // Vì task đã hoàn thành vẫn hiển thị trên danh sách nên không loại bỏ widget khỏi Dismissible
          return false;
        } else {
          onDelete();
          return true;
        }
      },
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: tileColor,
            border: border,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nút checkbox tròn phong cách Todoist (đạt chuẩn tap target >= 48dp)
              IconButton(
                onPressed: onToggle,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: EdgeInsets.zero,
                icon: Icon(
                  todo.isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: todo.isCompleted
                      ? (isDark ? const Color(0xFF4CAF50) : AppTheme.completeColor)
                      : (overdue
                          ? AppTheme.overdueColor
                          : (isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade500)),
                  size: 22,
                ),
              ),
              const SizedBox(width: 8),
              // Nội dung công việc
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      todo.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: titleColor,
                        decoration: todo.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (todo.description != null &&
                        todo.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        todo.description!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: descColor,
                        ),
                      ),
                    ],
                    if (todo.dueDate != null ||
                        isHighlighted ||
                        todo.isCompleted) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (todo.dueDate != null)
                            _buildDueDateBadge(context, overdue, badgeColor),
                          if (overdue && !todo.isCompleted)
                            _buildOverdueBadge(context, isDark),
                          if (todo.isCompleted)
                            _buildCompletedBadge(context, isDark),
                          if (isHighlighted)
                            _buildHighlightedBadge(context),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Nút xóa trực tiếp trên mỗi mục công việc (giúp thao tác dễ dàng mà không phụ thuộc hoàn toàn vào vuốt)
              IconButton(
                key: ValueKey('todo_delete_button_${todo.id}'),
                onPressed: onDelete,
                tooltip: 'Delete task',
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Xây dựng huy hiệu Completed màu xanh lá
  Widget _buildCompletedBadge(BuildContext context, bool isDark) {
    final greenColor =
        isDark ? const Color(0xFF4CAF50) : AppTheme.completeColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: greenColor.withAlpha(isDark ? 45 : 25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: greenColor,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 12,
            color: greenColor,
          ),
          const SizedBox(width: 4),
          Text(
            'Completed',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: greenColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Xây dựng huy hiệu Overdue màu đỏ cảnh báo cho task quá hạn
  Widget _buildOverdueBadge(BuildContext context, bool isDark) {
    final redColor = isDark ? const Color(0xFFEF5350) : AppTheme.overdueColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: redColor.withAlpha(isDark ? 45 : 25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: redColor,
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 12,
            color: redColor,
          ),
          const SizedBox(width: 4),
          Text(
            'Overdue',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: redColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Xây dựng huy hiệu Reminded màu đỏ khi click từ notification
  Widget _buildHighlightedBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withAlpha(35),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppTheme.primaryColor,
          width: 0.8,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_active,
            size: 12,
            color: AppTheme.primaryColor,
          ),
          SizedBox(width: 4),
          Text(
            'Reminded',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Xây dựng nhãn hiển thị ngày giờ deadline
  Widget _buildDueDateBadge(
    BuildContext context,
    bool overdue,
    Color badgeColor,
  ) {
    final due = todo.dueDate!;

    String dateStr;
    if (todo.hasTime) {
      dateStr = DateFormat('MMM d, h:mm a').format(due);
    } else {
      dateStr = DateFormat('MMM d').format(due);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          overdue ? Icons.warning_amber_rounded : Icons.calendar_today_outlined,
          size: 13,
          color: badgeColor,
        ),
        const SizedBox(width: 4),
        Text(
          dateStr,
          style: TextStyle(
            fontSize: 12,
            fontWeight: overdue ? FontWeight.bold : FontWeight.w500,
            color: badgeColor,
          ),
        ),
      ],
    );
  }
}

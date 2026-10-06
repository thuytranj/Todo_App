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
    final baseTileColor = isDark ? const Color(0xFF242424) : Colors.white;
    final highlightTileColor =
        isDark ? const Color(0xFF3E2421) : const Color(0xFFFDECEB);
    final tileColor = isHighlighted ? highlightTileColor : baseTileColor;

    final borderColor = isHighlighted
        ? AppTheme.primaryColor
        : (isDark ? const Color(0xFF333333) : Colors.grey.shade200);

    final titleColor = todo.isCompleted
        ? (isDark ? Colors.grey.shade600 : Colors.grey)
        : (isDark ? Colors.white : const Color(0xFF202020));

    final descColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    final badgeColor = overdue
        ? AppTheme.overdueColor
        : (isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700);

    return Dismissible(
      key: ValueKey(todo.id),
      // Vuốt từ trái sang phải (LTR) -> Hoàn thành task
      background: Container(
        color: AppTheme.completeColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text(
              'Complete',
              style: TextStyle(
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
          return true;
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
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: isHighlighted ? 1.5 : 0.8,
              ),
              left: isHighlighted
                  ? const BorderSide(color: AppTheme.primaryColor, width: 4.0)
                  : BorderSide.none,
            ),
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
                      ? AppTheme.completeColor
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
                    if (todo.dueDate != null || isHighlighted) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          if (todo.dueDate != null)
                            _buildDueDateBadge(context, overdue, badgeColor),
                          if (isHighlighted)
                            Container(
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
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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

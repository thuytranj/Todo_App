import 'dart:math' as math;
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
/// - Hiệu ứng làm nổi bật khi nhắc nhở: Fade/Glow + Scale nhẹ chạy 3 giây rồi dừng hoàn toàn.
class TodoItemTile extends StatefulWidget {
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
  State<TodoItemTile> createState() => _TodoItemTileState();
}

class _TodoItemTileState extends State<TodoItemTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _highlightController;

  @override
  void initState() {
    super.initState();
    // Bộ điều khiển hiệu ứng làm nổi bật (chạy chính xác 3 giây rồi dừng hoàn toàn)
    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Khi hoàn tất chu kỳ 3 giây, tự động reset controller để giải phóng ticker
    _highlightController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _highlightController.reset();
      }
    });

    if (widget.isHighlighted) {
      _startHighlightAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant TodoItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted) {
      // Bắt đầu hoặc khởi động lại hiệu ứng khi nhận được cờ highlight
      if (!oldWidget.isHighlighted || !_highlightController.isAnimating) {
        _startHighlightAnimation();
      }
    } else if (!widget.isHighlighted && oldWidget.isHighlighted) {
      _stopHighlightAnimation();
    }
  }

  void _startHighlightAnimation() {
    _highlightController.forward(from: 0.0);
  }

  void _stopHighlightAnimation() {
    _highlightController.stop();
    _highlightController.reset();
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overdue = isOverdue(widget.todo, widget.now);

    // 1. Xác định màu sắc cơ sở (Base Colors) dựa trên trạng thái của task
    final Color baseTileColor;
    final BorderSide baseLeftBorder;
    final BorderSide baseBottomBorder;

    if (widget.todo.isCompleted) {
      // Highlight xanh lá dịu cho task đã hoàn thành
      baseTileColor = isDark ? const Color(0xFF142918) : const Color(0xFFE8F5E9);
      baseLeftBorder = BorderSide(
        color: isDark ? const Color(0xFF4CAF50) : AppTheme.completeColor,
        width: 4.0,
      );
      baseBottomBorder = BorderSide(
        color: isDark ? const Color(0xFF1E3D24) : const Color(0xFFC8E6C9),
        width: 1.0,
      );
    } else if (overdue) {
      // Highlight tone màu đỏ cảnh báo cho task quá hạn
      baseTileColor = isDark ? const Color(0xFF2E1515) : const Color(0xFFFFF0EF);
      baseLeftBorder = BorderSide(
        color: isDark ? const Color(0xFFEF5350) : AppTheme.overdueColor,
        width: 4.0,
      );
      baseBottomBorder = BorderSide(
        color: isDark ? const Color(0xFF4A1E1E) : const Color(0xFFFFCDD2),
        width: 1.0,
      );
    } else {
      baseTileColor = isDark ? const Color(0xFF242424) : Colors.white;
      baseLeftBorder = BorderSide.none;
      baseBottomBorder = BorderSide(
        color: isDark ? const Color(0xFF333333) : Colors.grey.shade200,
        width: 0.8,
      );
    }

    // Màu chữ tiêu đề tương thích Light/Dark
    final Color titleColor;
    if (widget.todo.isCompleted) {
      titleColor = isDark ? const Color(0xFFA5D6A7) : const Color(0xFF2E7D32);
    } else if (overdue) {
      titleColor = isDark ? const Color(0xFFFF8A80) : AppTheme.overdueColor;
    } else {
      titleColor = isDark ? Colors.white : const Color(0xFF202020);
    }

    // Màu chữ mô tả
    final descColor = widget.todo.isCompleted
        ? (isDark ? Colors.green.shade900.withAlpha(200) : Colors.green.shade700)
        : (overdue
            ? (isDark ? const Color(0xFFE57373) : const Color(0xFFC62828))
            : (isDark ? Colors.grey.shade400 : Colors.grey.shade600));

    final badgeColor = overdue && !widget.todo.isCompleted
        ? AppTheme.overdueColor
        : (isDark ? Colors.blueGrey.shade200 : Colors.blueGrey.shade700);

    return Dismissible(
      key: ValueKey(widget.todo.id),
      // Vuốt từ trái sang phải (LTR) -> Hoàn thành / Hoàn tác task
      background: Container(
        color: widget.todo.isCompleted
            ? Colors.blueGrey.shade700
            : AppTheme.completeColor,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: [
            Icon(
              widget.todo.isCompleted ? Icons.replay : Icons.check_circle_outline,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              widget.todo.isCompleted ? 'Reopen' : 'Complete',
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
          widget.onToggle();
          // Vì task đã hoàn thành vẫn hiển thị trên danh sách nên không loại bỏ widget khỏi Dismissible
          return false;
        } else {
          widget.onDelete();
          return true;
        }
      },
      child: AnimatedBuilder(
        animation: _highlightController,
        builder: (context, child) {
          final progress = _highlightController.value;

          // Tạo 3 chu kỳ nhịp thở Fade/Glow + Scale nhẹ mượt mà trong 3 giây
          final rawPulse = math.sin(progress * 3 * math.pi);
          final pulseFactor = widget.isHighlighted
              ? (rawPulse * rawPulse) * (1.0 - 0.2 * progress)
              : 0.0;

          // 1. Scale nhẹ: dao động tinh tế từ 1.0 đến 1.025 (2.5%)
          final scale = 1.0 + (0.025 * pulseFactor);

          // 2. Glow (Hào quang phát sáng đỏ dịu xung quanh tile)
          final List<BoxShadow> glowShadows;
          if (widget.isHighlighted && pulseFactor > 0.01) {
            final glowColor =
                isDark ? const Color(0xFFFF5252) : AppTheme.primaryColor;
            glowShadows = [
              BoxShadow(
                color: glowColor.withAlpha((pulseFactor * (isDark ? 80 : 50)).round()),
                blurRadius: 10.0 * pulseFactor,
                spreadRadius: 1.5 * pulseFactor,
              ),
              BoxShadow(
                color: glowColor.withAlpha((pulseFactor * (isDark ? 130 : 85)).round()),
                blurRadius: 18.0 * pulseFactor,
                spreadRadius: 3.5 * pulseFactor,
              ),
            ];
          } else {
            glowShadows = const [];
          }

          // 3. Fade màu nền & đường viền chuyển động nhịp nhàng
          final Color currentTileColor;
          final Border border;

          if (widget.isHighlighted) {
            final highlightPeakColor =
                isDark ? const Color(0xFF3E2421) : const Color(0xFFFDECEB);
            currentTileColor = Color.lerp(
              baseTileColor,
              highlightPeakColor,
              0.35 + (0.65 * pulseFactor),
            )!;

            final highlightBorderColor =
                isDark ? const Color(0xFFFF5252) : AppTheme.primaryColor;
            border = Border(
              bottom: BorderSide(
                color: Color.lerp(
                  baseBottomBorder.color,
                  highlightBorderColor,
                  0.5 + (0.5 * pulseFactor),
                )!,
                width: 1.0 + (0.5 * pulseFactor),
              ),
              left: BorderSide(
                color: highlightBorderColor,
                width: 4.0,
              ),
            );
          } else {
            currentTileColor = baseTileColor;
            border = Border(
              bottom: baseBottomBorder,
              left: baseLeftBorder,
            );
          }

          return Transform.scale(
            scale: scale,
            alignment: Alignment.center,
            child: InkWell(
              onTap: widget.onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: currentTileColor,
                  border: border,
                  boxShadow: glowShadows,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nút checkbox tròn phong cách Todoist (đạt chuẩn tap target >= 48dp)
                    IconButton(
                      onPressed: widget.onToggle,
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        widget.todo.isCompleted
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: widget.todo.isCompleted
                            ? (isDark
                                ? const Color(0xFF4CAF50)
                                : AppTheme.completeColor)
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
                            widget.todo.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: titleColor,
                              decoration: widget.todo.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (widget.todo.description != null &&
                              widget.todo.description!.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.todo.description!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: descColor,
                              ),
                            ),
                          ],
                          if (widget.todo.dueDate != null ||
                              widget.isHighlighted ||
                              widget.todo.isCompleted) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                if (widget.todo.dueDate != null)
                                  _buildDueDateBadge(
                                      context, overdue, badgeColor),
                                if (overdue && !widget.todo.isCompleted)
                                  _buildOverdueBadge(context, isDark),
                                if (widget.todo.isCompleted)
                                  _buildCompletedBadge(context, isDark),
                                if (widget.isHighlighted)
                                  _buildHighlightedBadge(context),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Nút xóa trực tiếp trên mỗi mục công việc (giúp thao tác dễ dàng mà không phụ thuộc hoàn toàn vào vuốt)
                    IconButton(
                      key: ValueKey('todo_delete_button_${widget.todo.id}'),
                      onPressed: widget.onDelete,
                      tooltip: 'Delete task',
                      constraints:
                          const BoxConstraints(minWidth: 40, minHeight: 40),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 20,
                        color:
                            isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
    final due = widget.todo.dueDate!;

    String dateStr;
    if (widget.todo.hasTime) {
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

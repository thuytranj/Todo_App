import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:todo_app/domain/models/todo.dart';
import 'package:todo_app/domain/models/todo_draft.dart';
import 'package:todo_app/domain/models/todo_filter.dart';
import 'package:todo_app/ui/core/theme/app_theme.dart';
import 'package:todo_app/ui/core/widgets/empty_state.dart';
import 'package:todo_app/ui/core/widgets/permission_banner.dart';
import 'package:todo_app/ui/core/widgets/swipe_tutorial_banner.dart';
import 'package:todo_app/ui/features/todo/view_models/todo_view_model.dart';
import 'package:todo_app/ui/features/todo/views/widgets/add_todo_sheet.dart';
import 'package:todo_app/ui/features/todo/views/widgets/todo_item_tile.dart';

/// Màn hình chính của ứng dụng Todo (Home Screen):
/// - Tích hợp toàn diện giao diện theo phong cách Todoist kết hợp Material 3.
/// - Cung cấp thanh tìm kiếm thời gian thực (SearchBar) hỗ trợ xóa nhanh từ khóa.
/// - Hiển thị banner cảnh báo quyền thông báo khi quyền bị vô hiệu hóa.
/// - Hệ thống bộ lọc 3 tab: Today, Upcoming, All với số lượng badge độc lập với tìm kiếm.
/// - Danh sách công việc dạng cuộn mượt mà kèm hỗ trợ hoàn thành/xóa qua vuốt hoặc nút bấm.
/// - Nút bấm nổi (FloatingActionButton) mở BottomSheet thêm mới công việc.
/// - Xử lý thông báo SnackBar kèm nút hoàn tác (Undo) an toàn, tránh chồng chéo thông báo.
class HomeScreen extends StatefulWidget {
  final TodoViewModel viewModel;

  const HomeScreen({
    super.key,
    required this.viewModel,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int? _lastHighlightedTaskId;

  @override
  void initState() {
    super.initState();
    // Đồng bộ từ khóa tìm kiếm khi người dùng nhập trên SearchBar
    _searchController.addListener(() {
      widget.viewModel.setQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Tự động cuộn danh sách đến vị trí task đang được làm nổi bật khi mở từ thông báo
  void _checkAndScrollToHighlighted(List<Todo> visibleTasks) {
    final highlightedId = widget.viewModel.highlightedTaskId;
    if (highlightedId != null && highlightedId != _lastHighlightedTaskId) {
      _lastHighlightedTaskId = highlightedId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final index = visibleTasks.indexWhere((t) => t.id == highlightedId);
        if (index != -1 && _scrollController.position.maxScrollExtent > 0) {
          final targetOffset = (index * 82.0)
              .clamp(0.0, _scrollController.position.maxScrollExtent);
          if (targetOffset != _scrollController.offset) {
            _scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          }
        }
      });
    } else if (highlightedId == null) {
      _lastHighlightedTaskId = null;
    }
  }

  /// Mở modal BottomSheet để thêm mới hoặc chỉnh sửa công việc:
  /// - Nếu truyền [todoToEdit]: chuyển sang chế độ chỉnh sửa task đã có.
  /// - Nếu không truyền: chuyển sang chế độ thêm mới task.
  Future<void> _openAddOrEditSheet(BuildContext context, [Todo? todoToEdit]) async {
    final draft = await showModalBottomSheet<TodoDraft>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AddTodoSheet(
        initialTodo: todoToEdit,
        now: widget.viewModel.now,
      ),
    );

    // Người dùng bấm Save và trả về bản phác thảo hợp lệ
    if (draft != null) {
      if (todoToEdit != null) {
        await widget.viewModel.editTodo(todoToEdit.id, draft);
      } else {
        await widget.viewModel.addTodo(draft);
      }
    }
  }

  /// Đảo trạng thái hoàn thành công việc và hiển thị SnackBar kèm nút hoàn tác (Undo)
  void _toggleTask(BuildContext context, Todo task) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (task.isCompleted) {
      widget.viewModel.undoComplete(task.id);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Task marked as active'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              widget.viewModel.completeTodo(task.id);
            },
          ),
        ),
      );
    } else {
      widget.viewModel.completeTodo(task.id);
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Task marked as completed'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              widget.viewModel.undoComplete(task.id);
            },
          ),
        ),
      );
    }
  }

  /// Xóa công việc và hiển thị SnackBar kèm nút hoàn tác (Undo)
  void _deleteTask(BuildContext context, Todo task) {
    widget.viewModel.deleteTodo(task.id);

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Task deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            widget.viewModel.undoDelete(task);
          },
        ),
      ),
    );
  }

  /// Xây dựng giao diện hiển thị trạng thái rỗng (EmptyState) tùy theo ngữ cảnh lọc / tìm kiếm
  Widget _buildEmptyState() {
    if (widget.viewModel.searchQuery.trim().isNotEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matching tasks',
        message: 'Try searching with different keywords',
      );
    }

    switch (widget.viewModel.currentFilter) {
      case TodoFilter.today:
        return const EmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'No tasks for today',
          message: 'Enjoy your free time!',
        );
      case TodoFilter.upcoming:
        return const EmptyState(
          icon: Icons.event_available_rounded,
          title: 'No upcoming tasks',
          message: 'No tasks scheduled ahead',
        );
      case TodoFilter.all:
        return const EmptyState(
          icon: Icons.task_alt_rounded,
          title: 'No tasks yet',
          message: 'Tap the + button to create a task',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        // Khi ViewModel đang tải dữ liệu lúc khởi động
        if (widget.viewModel.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final visibleTasks = widget.viewModel.visibleTasks;
        // Kiểm tra và tự động cuộn đến task được click từ notification
        _checkAndScrollToHighlighted(visibleTasks);

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Todo List',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            elevation: 0,
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Banner cảnh báo quyền thông báo (nếu bị người dùng từ chối)
                if (!widget.viewModel.hasNotificationPermission)
                  PermissionBanner(
                    onOpenSettings: () {
                      openAppSettings();
                    },
                  ),

                // Thanh tìm kiếm tác vụ thời gian thực
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search tasks...',
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        ),
                    ],
                    elevation: const WidgetStatePropertyAll(1.0),
                  ),
                ),

                // Bộ chọn tab phân loại (Today, Upcoming, All)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 6.0,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<TodoFilter>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment<TodoFilter>(
                          value: TodoFilter.today,
                          label: Text(
                            'Today (${widget.viewModel.todayTasksCount})',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        ButtonSegment<TodoFilter>(
                          value: TodoFilter.upcoming,
                          label: Text(
                            'Upcoming (${widget.viewModel.upcomingTasksCount})',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        ButtonSegment<TodoFilter>(
                          value: TodoFilter.all,
                          label: Text(
                            'All (${widget.viewModel.allTasksCount})',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                      selected: {widget.viewModel.currentFilter},
                      onSelectionChanged: (newSelection) {
                        widget.viewModel.setFilter(newSelection.first);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Banner hướng dẫn thao tác vuốt nhanh cho người dùng mới
                if (widget.viewModel.showSwipeTutorial)
                  SwipeTutorialBanner(
                    onDismiss: widget.viewModel.dismissSwipeTutorial,
                  ),

                // Danh sách công việc hoặc trạng thái rỗng
                Expanded(
                  child: visibleTasks.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            16.0,
                            8.0,
                            16.0,
                            88.0,
                          ),
                          itemCount: visibleTasks.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10.0),
                          itemBuilder: (context, index) {
                            final task = visibleTasks[index];
                            return TodoItemTile(
                              key: ValueKey(task.id),
                              todo: task,
                              now: widget.viewModel.now,
                              isHighlighted:
                                  widget.viewModel.highlightedTaskId == task.id,
                              onToggle: () => _toggleTask(context, task),
                              onTap: () => _openAddOrEditSheet(context, task),
                              onDelete: () => _deleteTask(context, task),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openAddOrEditSheet(context),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            tooltip: 'Add Task',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

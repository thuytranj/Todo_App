// ignore_for_file: prefer_initializing_formals
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:todo_app/data/services/notification_service.dart';
import 'package:todo_app/data/services/storage_service.dart';
import 'package:todo_app/domain/logic/todo_logic.dart';
import 'package:todo_app/domain/models/todo.dart';
import 'package:todo_app/domain/models/todo_draft.dart';
import 'package:todo_app/domain/models/todo_filter.dart';

/// ViewModel chịu trách nhiệm quản lý trạng thái, điều phối nghiệp vụ và kết nối
/// giữa tầng UI với các dịch vụ Storage & Notification.
///
/// Tuân thủ nguyên tắc Clean MVVM:
/// - Kế thừa [ChangeNotifier] thuần của Flutter SDK.
/// - Không giữ [BuildContext] (các thao tác SnackBar/Dialog thuộc về View layer).
/// - Quản lý hàng đợi bất đồng bộ [_enqueue] để chống xung đột ghi đè.
class TodoViewModel extends ChangeNotifier {
  final StorageService _storageService;
  final NotificationService _notificationService;
  final DateTime Function() _clock;

  List<Todo> _todos = [];
  TodoFilter _currentFilter = TodoFilter.today;
  String _searchQuery = '';
  bool _hasNotificationPermission = true;
  bool _isLoading = true;
  bool _hasSeenSwipeTutorial = false;
  int? _highlightedTaskId;
  Timer? _highlightTimer;

  /// Lưu trữ lỗi cuối cùng nếu xảy ra trong hàng đợi bất đồng bộ
  Object? lastError;

  /// Hàng đợi tuần tự xử lý các thao tác bất đồng bộ (Storage + Notification)
  Future<void> _writeQueue = Future.value();

  final bool _enableTicker;
  Timer? _tickerTimer;
  AppLifecycleListener? _lifecycleListener;

  TodoViewModel({
    required StorageService storageService,
    required NotificationService notificationService,
    DateTime Function()? clock,
    bool enableTicker = true,
  })  : _storageService = storageService,
        _notificationService = notificationService,
        _clock = clock ?? DateTime.now,
        _enableTicker = enableTicker;

  // --- GETTERS ---

  /// Toàn bộ danh sách task (bất biến)
  List<Todo> get allTasks => List.unmodifiable(_todos);

  /// Danh sách task đang được hiển thị theo tab lọc hiện tại và từ khóa tìm kiếm
  List<Todo> get visibleTasks =>
      visibleTodos(_todos, _currentFilter, _searchQuery, _clock());

  /// Bộ lọc tab đang chọn (All, Today, Upcoming)
  TodoFilter get currentFilter => _currentFilter;

  /// Từ khóa tìm kiếm hiện tại
  String get searchQuery => _searchQuery;

  /// ID của công việc đang được làm nổi bật (khi người dùng chạm vào thông báo nhắc nhở)
  int? get highlightedTaskId => _highlightedTaskId;

  /// Trạng thái cấp quyền thông báo của ứng dụng
  bool get hasNotificationPermission => _hasNotificationPermission;

  /// Trạng thái đang tải dữ liệu lúc khởi động
  bool get isLoading => _isLoading;

  /// Hiển thị banner hướng dẫn cử chỉ vuốt nếu người dùng chưa từng tắt hoặc trải nghiệm
  bool get showSwipeTutorial => !_hasSeenSwipeTutorial;

  /// Số lượng task active của từng tab (cố định, không bị ảnh hưởng bởi search query)
  int get allTasksCount => countForFilter(_todos, TodoFilter.all, _clock());
  int get todayTasksCount => countForFilter(_todos, TodoFilter.today, _clock());
  int get upcomingTasksCount =>
      countForFilter(_todos, TodoFilter.upcoming, _clock());

  /// Hàm cung cấp mốc thời gian hiện tại (phục vụ deterministic testing)
  DateTime Function() get clock => _clock;

  /// Mốc thời gian hiện tại từ nguồn thời gian đồng hồ
  DateTime get now => _clock();

  // --- INITIALIZATION ---

  /// Khởi tạo ViewModel khi app mở lên:
  /// 1. Tải danh sách tasks từ local storage.
  /// 2. Tự động dọn dẹp các task đã hoàn thành quá 30 ngày.
  /// 3. Kiểm tra trạng thái cấp quyền thông báo.
  /// 4. Yêu cầu quyền thông báo chung nếu là lần đầu tiên mở ứng dụng.
  /// 5. Đặt lại lịch hẹn thông báo cho tất cả active tasks (chống spam với allowLate: false).
  /// 6. Bật bộ đếm 60s và listener vòng đời để cập nhật ngày giờ thời gian thực.
  Future<void> initialize() async {
    _isLoading = true;
    _writeQueue = Future.value();
    notifyListeners();

    // 1. Đọc dữ liệu từ Storage
    _todos = await _storageService.loadTodos();

    // 2. Dọn dẹp task hoàn thành cũ hơn 30 ngày
    final cutoff = _clock().subtract(const Duration(days: 30));
    _todos.removeWhere((t) => t.isCompleted && t.createdAt.isBefore(cutoff));
    await _storageService.saveTodos(_todos);

    // 3. Khởi tạo dịch vụ thông báo
    await _notificationService.initialize();
    _hasNotificationPermission =
        await _notificationService.checkPermissionStatus();

    // 4. Xin quyền thông báo chung ở lần khởi động đầu tiên
    final hasRequested =
        await _storageService.getHasRequestedNotificationPermission();
    if (!hasRequested) {
      await _notificationService.requestGeneralPermissions();
      await _storageService.setHasRequestedNotificationPermission(true);
      _hasNotificationPermission =
          await _notificationService.checkPermissionStatus();
    }

    // 5. Đặt lại lịch thông báo cho các task active (chống spam lúc mở app)
    final activeTodos = _todos.where((t) => !t.isCompleted).toList();
    await _notificationService.rescheduleAll(activeTodos, _clock());

    // 6. Đọc cờ trạng thái hướng dẫn thao tác vuốt
    _hasSeenSwipeTutorial =
        await _storageService.getHasSeenSwipeTutorial();

    _isLoading = false;
    notifyListeners();

    // 6. Bật Timer 60s để tự động cập nhật nhãn ngày tương đối và badge quá hạn (nếu được bật)
    if (_enableTicker) {
      _tickerTimer?.cancel();
      _tickerTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        notifyListeners();
      });
    }

    // 7. Lắng nghe sự kiện app quay lại foreground từ background
    _lifecycleListener?.dispose();
    _lifecycleListener = AppLifecycleListener(
      onResume: () async {
        _hasNotificationPermission =
            await _notificationService.checkPermissionStatus();
        notifyListeners();
      },
    );
  }

  // --- ACTIONS & BUSINESS LOGIC ---

  /// Đổi tab bộ lọc (All, Today, Upcoming)
  void setFilter(TodoFilter filter) {
    if (_currentFilter != filter) {
      _currentFilter = filter;
      notifyListeners();
    }
  }

  /// Cập nhật từ khóa tìm kiếm
  void setQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      notifyListeners();
    }
  }

  /// Thêm công việc mới từ [TodoDraft]:
  /// - Cấp phát ID mới an toàn qua [nextId].
  /// - Nếu task có giờ lần đầu, xin quyền exact alarm.
  /// - Ghi vào Storage trước, sau đó lên lịch thông báo trong hàng đợi bền bỉ.
  Future<void> addTodo(TodoDraft draft) async {
    final newId = nextId(_todos);
    final newTodo = Todo(
      id: newId,
      title: draft.title,
      description: draft.description,
      dueDate: draft.dueDate,
      hasTime: draft.hasTime,
      createdAt: _clock(),
    );

    _todos.add(newTodo);
    notifyListeners();

    if (draft.hasTime) {
      await _notificationService.requestExactAlarmPermission();
    }

    await _enqueue(() async {
      await _storageService.saveTodos(_todos);

      final reminder = reminderTimeFor(newTodo, _clock(), allowLate: true);
      if (reminder != null) {
        await _notificationService.scheduleNotification(
          id: newTodo.id,
          title: newTodo.title,
          body: reminderBody(newTodo),
          scheduledDate: reminder,
        );
      }
    });
  }

  /// Chỉnh sửa công việc:
  /// - Cập nhật thông tin task trong bộ nhớ.
  /// - Hủy thông báo cũ và lên lại lịch thông báo mới.
  Future<void> editTodo(int id, TodoDraft draft) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final existing = _todos[index];
    final updated = existing.copyWith(
      title: draft.title,
      description: draft.description,
      clearDescription: draft.description == null,
      dueDate: draft.dueDate,
      clearDueDate: draft.dueDate == null,
      hasTime: draft.hasTime,
    );

    _todos[index] = updated;
    notifyListeners();

    if (draft.hasTime) {
      await _notificationService.requestExactAlarmPermission();
    }

    await _enqueue(() async {
      await _storageService.saveTodos(_todos);

      if (updated.isCompleted) {
        await _notificationService.cancelNotification(updated.id);
      } else {
        final reminder = reminderTimeFor(updated, _clock(), allowLate: true);
        if (reminder != null) {
          await _notificationService.scheduleNotification(
            id: updated.id,
            title: updated.title,
            body: reminderBody(updated),
            scheduledDate: reminder,
          );
        } else {
          await _notificationService.cancelNotification(updated.id);
        }
      }
    });
  }

  /// Đánh dấu hoàn thành công việc (soft-delete):
  /// - Ẩn khỏi danh sách active.
  /// - Hủy thông báo của task đó.
  Future<void> completeTodo(int id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;

    _todos[index] = _todos[index].copyWith(isCompleted: true);
    notifyListeners();

    await _enqueue(() async {
      await _storageService.saveTodos(_todos);
      await _notificationService.cancelNotification(id);
    });
  }

  /// Hoàn tác hoàn thành công việc (Undo Complete):
  /// - Đặt lại trạng thái `isCompleted = false`.
  /// - Lên lại lịch thông báo (sử dụng allowLate: false vì người dùng đã biết về task).
  Future<void> undoComplete(int id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final restored = _todos[index].copyWith(isCompleted: false);
    _todos[index] = restored;
    notifyListeners();

    await _enqueue(() async {
      await _storageService.saveTodos(_todos);

      final reminder = reminderTimeFor(restored, _clock(), allowLate: false);
      if (reminder != null) {
        await _notificationService.scheduleNotification(
          id: restored.id,
          title: restored.title,
          body: reminderBody(restored),
          scheduledDate: reminder,
        );
      }
    });
  }

  /// Đảo trạng thái hoàn thành của công việc:
  /// - Nếu đang hoàn thành: hoàn tác (Undo Complete).
  /// - Nếu chưa hoàn thành: đánh dấu hoàn thành (Complete).
  Future<void> toggleTodo(int id) async {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;
    if (_todos[index].isCompleted) {
      await undoComplete(id);
    } else {
      await completeTodo(id);
    }
  }

  /// Đánh dấu người dùng đã xem và đóng hướng dẫn thao tác vuốt
  Future<void> dismissSwipeTutorial() async {
    if (_hasSeenSwipeTutorial) return;
    _hasSeenSwipeTutorial = true;
    notifyListeners();
    await _storageService.setHasSeenSwipeTutorial(true);
  }

  /// Xóa hẳn một công việc khỏi danh sách:
  /// - Hủy thông báo tương ứng.
  Future<void> deleteTodo(int id) async {
    _todos.removeWhere((t) => t.id == id);
    notifyListeners();

    await _enqueue(() async {
      await _storageService.saveTodos(_todos);
      await _notificationService.cancelNotification(id);
    });
  }

  /// Hoàn tác xóa công việc (Undo Delete):
  /// - Kiểm tra nếu ID của task cũ đã bị một task mới tạo chiếm mất $\rightarrow$ tự động cấp ID mới qua [nextId].
  /// - Khôi phục task và lên lại lịch thông báo.
  Future<void> undoDelete(Todo deletedTodo) async {
    var restored = deletedTodo;
    if (_todos.any((t) => t.id == deletedTodo.id)) {
      // Đụng độ ID -> cấp ID mới
      restored = deletedTodo.copyWith(id: nextId(_todos));
    }

    _todos.add(restored);
    notifyListeners();

    await _enqueue(() async {
      await _storageService.saveTodos(_todos);

      if (!restored.isCompleted) {
        final reminder = reminderTimeFor(restored, _clock(), allowLate: false);
        if (reminder != null) {
          await _notificationService.scheduleNotification(
            id: restored.id,
            title: restored.title,
            body: reminderBody(restored),
            scheduledDate: reminder,
          );
        }
      }
    });
  }

  /// Xử lý sự kiện người dùng chạm vào thông báo nhắc nhở trên thiết bị:
  /// 1. Tìm công việc tương ứng theo [id].
  /// 2. Xóa bộ lọc tìm kiếm ([_searchQuery = '']) để đảm bảo task hiển thị trên danh sách.
  /// 3. Tự động chuyển tab ([_currentFilter]) về đúng tab chứa task (Today, Upcoming hoặc All).
  /// 4. Đánh dấu [highlightedTaskId] và kích hoạt hiệu ứng thị giác (pulse & border).
  /// 5. Đặt bộ đếm 3 giây tự động tắt hiệu ứng làm nổi bật một cách mượt mà.
  void handleNotificationTap(int id) {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final targetTask = _todos[index];

    // Xóa từ khóa tìm kiếm để task không bị ẩn
    _searchQuery = '';

    // Tự động chuyển đến tab phù hợp với thời hạn của task
    if (targetTask.dueDate != null) {
      if (isDueTodayOrOverdue(targetTask.dueDate!, _clock())) {
        _currentFilter = TodoFilter.today;
      } else if (isDueUpcoming(targetTask.dueDate!, _clock())) {
        _currentFilter = TodoFilter.upcoming;
      } else {
        _currentFilter = TodoFilter.all;
      }
    } else {
      _currentFilter = TodoFilter.all;
    }

    _highlightedTaskId = id;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      _highlightedTaskId = null;
      notifyListeners();
    });

    notifyListeners();
  }

  /// Cơ chế hàng đợi tuần tự có bọc bắt lỗi (Resilient Queue):
  /// Đảm bảo nếu một thao tác ném lỗi thì các thao tác sau vẫn tiếp tục được thực thi bình thường.
  Future<void> _enqueue(Future<void> Function() job) {
    _writeQueue = _writeQueue.then((_) => job()).catchError((Object e) {
      lastError = e;
    });
    return _writeQueue;
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _highlightTimer?.cancel();
    _lifecycleListener?.dispose();
    super.dispose();
  }
}

import 'package:todo_app/data/services/notification_service.dart';
import 'package:todo_app/data/services/storage_service.dart';
import 'package:todo_app/domain/models/todo.dart';

/// Fake implementation của [StorageService] phục vụ kiểm thử đơn vị độc lập trên bộ nhớ RAM.
class FakeStorageService implements StorageService {
  List<Todo> todos;
  bool hasRequestedPermission;
  bool shouldThrowOnSave;

  FakeStorageService({
    List<Todo>? initialTodos,
    this.hasRequestedPermission = false,
    this.shouldThrowOnSave = false,
  }) : todos = List.of(initialTodos ?? []);

  @override
  Future<List<Todo>> loadTodos() async {
    return List.of(todos);
  }

  @override
  Future<void> saveTodos(List<Todo> newTodos) async {
    if (shouldThrowOnSave) {
      throw Exception('Fake storage save exception');
    }
    todos = List.of(newTodos);
  }

  @override
  Future<bool> getHasRequestedNotificationPermission() async {
    return hasRequestedPermission;
  }

  @override
  Future<void> setHasRequestedNotificationPermission(bool value) async {
    hasRequestedPermission = value;
  }
}

/// Fake implementation của [NotificationService] ghi nhận các lệnh gọi đặt lịch và hủy lịch.
class FakeNotificationService implements NotificationService {
  bool isInitialized = false;
  bool permissionStatus = true;
  bool generalPermissionRequested = false;
  bool exactAlarmPermissionRequested = false;
  bool shouldThrowOnSchedule = false;

  final Map<int, DateTime> scheduledNotifications = {};
  final List<int> cancelledNotificationIds = [];
  bool allCancelled = false;
  List<Todo>? lastRescheduledTodos;

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<bool> checkPermissionStatus() async {
    return permissionStatus;
  }

  @override
  Future<bool> requestGeneralPermissions() async {
    generalPermissionRequested = true;
    return permissionStatus;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    exactAlarmPermissionRequested = true;
    return permissionStatus;
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (shouldThrowOnSchedule) {
      throw Exception('Fake notification schedule exception');
    }
    scheduledNotifications[id] = scheduledDate;
  }

  @override
  Future<void> cancelNotification(int id) async {
    scheduledNotifications.remove(id);
    cancelledNotificationIds.add(id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    scheduledNotifications.clear();
    allCancelled = true;
  }

  @override
  Future<void> rescheduleAll(List<Todo> todos, DateTime now) async {
    lastRescheduledTodos = List.of(todos);
  }
}

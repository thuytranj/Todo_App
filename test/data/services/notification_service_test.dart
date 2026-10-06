import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/data/services/notification_service.dart';
import 'package:todo_app/domain/models/todo.dart';

/// Lớp kiểm thử giả lập để kiểm tra logic của NotificationService
class TestableNotificationService implements NotificationService {
  @override
  void Function(int todoId)? onNotificationTapped;

  final List<String> callLogs = [];
  final Map<int, DateTime> scheduled = {};
  bool permission = true;

  @override
  Future<void> initialize() async {
    callLogs.add('initialize');
  }

  @override
  Future<bool> checkPermissionStatus() async {
    callLogs.add('checkPermissionStatus');
    return permission;
  }

  @override
  Future<bool> requestGeneralPermissions() async {
    callLogs.add('requestGeneralPermissions');
    return permission;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    callLogs.add('requestExactAlarmPermission');
    return permission;
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Luôn hủy lịch cũ trước khi đặt lịch mới
    await cancelNotification(id);
    callLogs.add('scheduleNotification:$id');
    scheduled[id] = scheduledDate;
  }

  @override
  Future<void> cancelNotification(int id) async {
    callLogs.add('cancelNotification:$id');
    scheduled.remove(id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    callLogs.add('cancelAllNotifications');
    scheduled.clear();
  }

  @override
  Future<void> rescheduleAll(List<Todo> todos, DateTime now) async {
    // Dọn dẹp toàn bộ thông báo mồ côi trước
    await cancelAllNotifications();

    // Giả lập đặt lịch lại cho các task hợp lệ
    for (final todo in todos) {
      if (todo.hasTime && todo.dueDate != null && !todo.isCompleted) {
        if (todo.dueDate!.isAfter(now)) {
          await scheduleNotification(
            id: todo.id,
            title: todo.title,
            body: todo.description ?? 'Your task is due in 10 minutes.',
            scheduledDate: todo.dueDate!.subtract(const Duration(minutes: 10)),
          );
        }
      }
    }
  }
}

void main() {
  group('NotificationService Contract Tests', () {
    late TestableNotificationService service;
    final now = DateTime(2026, 10, 6, 10, 0);

    setUp(() {
      service = TestableNotificationService();
    });

    test('scheduleNotification luôn gọi cancelNotification trước khi lên lịch mới', () async {
      await service.scheduleNotification(
        id: 1,
        title: 'Task 1',
        body: 'Body',
        scheduledDate: now.add(const Duration(minutes: 20)),
      );

      expect(service.callLogs, contains('cancelNotification:1'));
      expect(service.callLogs, contains('scheduleNotification:1'));
      expect(service.scheduled[1], now.add(const Duration(minutes: 20)));
    });

    test('rescheduleAll gọi cancelAllNotifications trước để dọn dẹp thông báo mồ côi', () async {
      final todos = [
        Todo(
          id: 1,
          title: 'T1',
          dueDate: now.add(const Duration(minutes: 30)),
          hasTime: true,
          createdAt: now,
        ),
        Todo(
          id: 2,
          title: 'T2',
          dueDate: now.add(const Duration(minutes: 40)),
          hasTime: true,
          createdAt: now,
        ),
      ];

      await service.rescheduleAll(todos, now);

      expect(service.callLogs.first, 'cancelAllNotifications');
      expect(service.scheduled.length, 2);
    });

    test('cancelNotification loại bỏ ID khỏi danh sách đặt lịch', () async {
      await service.scheduleNotification(
        id: 10,
        title: 'T10',
        body: 'Body',
        scheduledDate: now.add(const Duration(hours: 1)),
      );
      expect(service.scheduled.containsKey(10), isTrue);

      await service.cancelNotification(10);
      expect(service.scheduled.containsKey(10), isFalse);
    });
  });
}

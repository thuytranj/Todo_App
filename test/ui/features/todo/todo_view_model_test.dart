import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/domain/models/todo.dart';
import 'package:todo_app/domain/models/todo_draft.dart';
import 'package:todo_app/domain/models/todo_filter.dart';
import 'package:todo_app/ui/features/todo/view_models/todo_view_model.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('TodoViewModel Tests', () {
    late FakeStorageService storage;
    late FakeNotificationService notification;
    late DateTime currentTime;

    DateTime clock() => currentTime;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      currentTime = DateTime(2026, 10, 6, 10, 0);
      storage = FakeStorageService();
      notification = FakeNotificationService();
    });

    test('initialize: đọc storage, xin quyền lần đầu, purge task > 30 ngày, rescheduleAll', () async {
      final oldCompletedDate = currentTime.subtract(const Duration(days: 35));
      final recentCompletedDate = currentTime.subtract(const Duration(days: 10));

      storage.todos = [
        Todo(id: 1, title: 'Old Done', isCompleted: true, createdAt: oldCompletedDate),
        Todo(id: 2, title: 'Recent Done', isCompleted: true, createdAt: recentCompletedDate),
        Todo(id: 3, title: 'Active Task', createdAt: currentTime),
      ];

      final viewModel = TodoViewModel(
        storageService: storage,
        notificationService: notification,
        clock: clock,
      );

      await viewModel.initialize();

      // 1. Task cũ hơn 30 ngày bị dọn dẹp
      expect(viewModel.allTasks.any((t) => t.id == 1), isFalse);
      expect(viewModel.allTasks.any((t) => t.id == 2), isTrue);
      expect(viewModel.allTasks.any((t) => t.id == 3), isTrue);

      // 2. Lần đầu mở app: xin quyền thông báo chung và lưu cờ
      expect(notification.generalPermissionRequested, isTrue);
      expect(await storage.getHasRequestedNotificationPermission(), isTrue);

      // 3. rescheduleAll được gọi
      expect(notification.lastRescheduledTodos, isNotNull);
      viewModel.dispose();
    });

    test('addTodo: lưu vào storage trước, lên lịch thông báo, cấp ID tăng dần', () async {
      final viewModel = TodoViewModel(
        storageService: storage,
        notificationService: notification,
        clock: clock,
      );
      await viewModel.initialize();

      final draft = TodoDraft(
        title: 'New Todo',
        dueDate: currentTime.add(const Duration(hours: 1)),
        hasTime: true,
      );

      await viewModel.addTodo(draft);

      expect(viewModel.allTasks.length, 1);
      final created = viewModel.allTasks.first;
      expect(created.id, 1);
      expect(created.title, 'New Todo');
      expect(created.hasTime, isTrue);

      // Storage được cập nhật
      expect(storage.todos.length, 1);
      // Quyền exact alarm được yêu cầu khi lưu task có giờ lần đầu
      expect(notification.exactAlarmPermissionRequested, isTrue);
      // Notification được đặt
      expect(notification.scheduledNotifications.containsKey(1), isTrue);
      viewModel.dispose();
    });

    test('completeTodo & undoComplete: hủy và phục hồi thông báo khớp trạng thái', () async {
      final viewModel = TodoViewModel(
        storageService: storage,
        notificationService: notification,
        clock: clock,
      );
      await viewModel.initialize();

      await viewModel.addTodo(TodoDraft(
        title: 'Task to Complete',
        dueDate: currentTime.add(const Duration(minutes: 40)),
        hasTime: true,
      ));

      expect(notification.scheduledNotifications.containsKey(1), isTrue);

      // Hoàn thành task: vẫn hiện trên danh sách nhưng đánh dấu isCompleted=true
      await viewModel.completeTodo(1);
      expect(viewModel.visibleTasks.length, 1);
      expect(viewModel.visibleTasks.first.isCompleted, isTrue);
      expect(viewModel.todayTasksCount, 0); // Số lượng active tasks giảm về 0
      expect(notification.cancelledNotificationIds, contains(1));

      // Hoàn tác hoàn thành (Undo)
      await viewModel.undoComplete(1);
      expect(viewModel.visibleTasks.length, 1);
      expect(viewModel.visibleTasks.first.isCompleted, isFalse);
      expect(viewModel.todayTasksCount, 1);
      expect(notification.scheduledNotifications.containsKey(1), isTrue);
      viewModel.dispose();
    });

    test('deleteTodo & undoDelete: giải quyết xung đột ID khi có task mới tạo cùng lúc', () async {
      final viewModel = TodoViewModel(
        storageService: storage,
        notificationService: notification,
        clock: clock,
      );
      await viewModel.initialize();

      await viewModel.addTodo(TodoDraft(title: 'Task 1')); // ID = 1
      final deletedTask = viewModel.allTasks.first;

      // Xóa Task 1
      await viewModel.deleteTodo(1);
      expect(viewModel.allTasks, isEmpty);

      // Thêm task mới trong lúc SnackBar Undo còn hiện -> task mới nhận ID 1
      await viewModel.addTodo(TodoDraft(title: 'New Task Taking ID 1'));
      expect(viewModel.allTasks.first.id, 1);

      // Bấm Hoàn tác cho deletedTask -> phát hiện ID 1 đã bị chiếm, cấp ID mới là 2
      await viewModel.undoDelete(deletedTask);
      expect(viewModel.allTasks.length, 2);
      expect(viewModel.allTasks.map((t) => t.id), containsAll([1, 2]));
      viewModel.dispose();
    });

    test('Hàng đợi bền bỉ (_enqueue): lỗi ở một job không làm nghẽn các job kế tiếp', () async {
      final viewModel = TodoViewModel(
        storageService: storage,
        notificationService: notification,
        clock: clock,
      );
      await viewModel.initialize();

      // Giả lập lỗi ở Storage
      storage.shouldThrowOnSave = true;
      await viewModel.addTodo(TodoDraft(title: 'Fail Task'));

      // Khôi phục Storage bình thường
      storage.shouldThrowOnSave = false;
      await viewModel.addTodo(TodoDraft(title: 'Success Task'));

      // Job thứ 2 vẫn chạy và lưu thành công
      expect(viewModel.allTasks.length, 2);
      expect(storage.todos.length, 2);
      viewModel.dispose();
    });

    test('Lọc tab và tìm kiếm cập nhật visibleTasks', () async {
      final viewModel = TodoViewModel(
        storageService: storage,
        notificationService: notification,
        clock: clock,
      );
      await viewModel.initialize();

      await viewModel.addTodo(TodoDraft(
        title: 'Today Task',
        dueDate: currentTime,
        hasTime: false,
      ));
      await viewModel.addTodo(TodoDraft(
        title: 'Upcoming Task',
        dueDate: currentTime.add(const Duration(days: 2)),
        hasTime: false,
      ));

      // Mặc định ở Today
      viewModel.setFilter(TodoFilter.today);
      expect(viewModel.visibleTasks.length, 1);
      expect(viewModel.visibleTasks.first.title, 'Today Task');

      // Chuyển sang Upcoming
      viewModel.setFilter(TodoFilter.upcoming);
      expect(viewModel.visibleTasks.length, 1);
      expect(viewModel.visibleTasks.first.title, 'Upcoming Task');

      // Tìm kiếm trong tab Upcoming
      viewModel.setQuery('today');
      expect(viewModel.visibleTasks, isEmpty);

      viewModel.setQuery('upcoming');
      expect(viewModel.visibleTasks.length, 1);
      viewModel.dispose();
    });

    test('Ticker 60s gọi notifyListeners trong fakeAsync', () {
      fakeAsync((async) {
        final viewModel = TodoViewModel(
          storageService: storage,
          notificationService: notification,
          clock: clock,
        );

        // Khởi tạo viewModel để khởi chạy Timer 60s
        viewModel.initialize();
        async.flushMicrotasks();

        var notifyCount = 0;
        viewModel.addListener(() => notifyCount++);

        // Tiến tới 60s
        async.elapse(const Duration(seconds: 60));
        expect(notifyCount, greaterThanOrEqualTo(1));

        viewModel.dispose();
      });
    });

    test('handleNotificationTap chuyển đúng filter, xóa query, đặt highlight và tự xóa sau 3s', () {
      fakeAsync((async) {
        final upcomingTask = Todo(
          id: 42,
          title: 'Doctor Appointment',
          dueDate: currentTime.add(const Duration(days: 3)),
          hasTime: true,
          createdAt: currentTime,
        );

        final customStorage = FakeStorageService(initialTodos: [upcomingTask]);
        final viewModel = TodoViewModel(
          storageService: customStorage,
          notificationService: notification,
          clock: clock,
        );

        viewModel.initialize();
        async.flushMicrotasks();

        // Giả lập người dùng đang ở tab Today và đang gõ search query
        viewModel.setFilter(TodoFilter.today);
        viewModel.setQuery('random query');
        expect(viewModel.currentFilter, TodoFilter.today);
        expect(viewModel.searchQuery, 'random query');

        // Khi người dùng bấm vào thông báo của task ID 42
        viewModel.handleNotificationTap(42);

        // Đảm bảo đã chuyển sang tab Upcoming, search query bị xóa và ID được highlight
        expect(viewModel.currentFilter, TodoFilter.upcoming);
        expect(viewModel.searchQuery, isEmpty);
        expect(viewModel.highlightedTaskId, 42);

        // Sau 3 giây, highlight tự động được xóa về null
        async.elapse(const Duration(seconds: 3));
        expect(viewModel.highlightedTaskId, isNull);

        viewModel.dispose();
      });
    });

    test('toggleTodo đảo trạng thái hoàn thành giữa complete và undoComplete', () async {
      final task = Todo(
        id: 1,
        title: 'Task 1',
        createdAt: currentTime,
        isCompleted: false,
      );
      final customStorage = FakeStorageService(initialTodos: [task]);
      final viewModel = TodoViewModel(
        storageService: customStorage,
        notificationService: notification,
        clock: clock,
      );

      await viewModel.initialize();
      expect(viewModel.allTasks.first.isCompleted, isFalse);

      // Đảo lần 1: từ false -> true
      await viewModel.toggleTodo(1);
      expect(viewModel.allTasks.first.isCompleted, isTrue);

      // Đảo lần 2: từ true -> false
      await viewModel.toggleTodo(1);
      expect(viewModel.allTasks.first.isCompleted, isFalse);

      viewModel.dispose();
    });

    test('showSwipeTutorial hiển thị lần đầu và ẩn vĩnh viễn khi dismissSwipeTutorial', () async {
      final customStorage = FakeStorageService(hasSeenSwipeTutorial: false);
      final viewModel = TodoViewModel(
        storageService: customStorage,
        notificationService: notification,
        clock: clock,
      );

      await viewModel.initialize();
      expect(viewModel.showSwipeTutorial, isTrue);

      await viewModel.dismissSwipeTutorial();
      expect(viewModel.showSwipeTutorial, isFalse);
      expect(await customStorage.getHasSeenSwipeTutorial(), isTrue);

      viewModel.dispose();
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/domain/logic/todo_logic.dart';
import 'package:todo_app/domain/models/todo.dart';
import 'package:todo_app/domain/models/todo_filter.dart';

void main() {
  group('nextId Tests', () {
    test('Danh sách rỗng trả về ID là 1', () {
      expect(nextId([]), 1);
    });

    test('Danh sách có phần tử trả về max(ID) + 1 ngay cả khi ID không liên tục', () {
      final now = DateTime(2026, 10, 6);
      final todos = [
        Todo(id: 1, title: 'T1', createdAt: now),
        Todo(id: 5, title: 'T5', createdAt: now),
        Todo(id: 3, title: 'T3', createdAt: now),
      ];
      expect(nextId(todos), 6);
    });
  });

  group('isOverdue Tests', () {
    final now = DateTime(2026, 10, 6, 14, 0); // 14:00 ngày 06/10/2026

    test('Task đã hoàn thành hoặc không có hạn chót không bao giờ quá hạn', () {
      final completedTodo = Todo(
        id: 1,
        title: 'Done task',
        dueDate: now.subtract(const Duration(days: 1)),
        isCompleted: true,
        createdAt: now,
      );
      final datelessTodo = Todo(id: 2, title: 'Dateless', createdAt: now);

      expect(isOverdue(completedTodo, now), isFalse);
      expect(isOverdue(datelessTodo, now), isFalse);
    });

    test('Task chỉ có ngày (hasTime=false): chỉ quá hạn khi ngày đã trôi qua', () {
      // 1. Task có hạn hôm nay (06/10/2026) -> không quá hạn kể cả khi kiểm tra lúc 14:00
      final todayDateOnly = Todo(
        id: 1,
        title: 'Today Date-only',
        dueDate: DateTime(2026, 10, 6, 0, 0),
        hasTime: false,
        createdAt: now,
      );
      expect(isOverdue(todayDateOnly, now), isFalse);

      // 2. Task có hạn hôm qua (05/10/2026) -> quá hạn
      final yesterdayDateOnly = Todo(
        id: 2,
        title: 'Yesterday Date-only',
        dueDate: DateTime(2026, 10, 5, 0, 0),
        hasTime: false,
        createdAt: now,
      );
      expect(isOverdue(yesterdayDateOnly, now), isTrue);

      // 3. Task có hạn ngày mai (07/10/2026) -> không quá hạn
      final tomorrowDateOnly = Todo(
        id: 3,
        title: 'Tomorrow Date-only',
        dueDate: DateTime(2026, 10, 7, 0, 0),
        hasTime: false,
        createdAt: now,
      );
      expect(isOverdue(tomorrowDateOnly, now), isFalse);
    });

    test('Task có giờ cụ thể (hasTime=true): quá hạn ngay khi qua mốc thời gian', () {
      // Đúng mốc now -> không quá hạn
      final exactlyNow = Todo(
        id: 1,
        title: 'Exact Now',
        dueDate: now,
        hasTime: true,
        createdAt: now,
      );
      expect(isOverdue(exactlyNow, now), isFalse);

      // Trước now 1 giây -> quá hạn
      final oneSecondAgo = Todo(
        id: 2,
        title: 'Past',
        dueDate: now.subtract(const Duration(seconds: 1)),
        hasTime: true,
        createdAt: now,
      );
      expect(isOverdue(oneSecondAgo, now), isTrue);

      // Sau now 1 phút -> không quá hạn
      final future = Todo(
        id: 3,
        title: 'Future',
        dueDate: now.add(const Duration(minutes: 1)),
        hasTime: true,
        createdAt: now,
      );
      expect(isOverdue(future, now), isFalse);
    });
  });

  group('reminderTimeFor Tests', () {
    final now = DateTime(2026, 10, 6, 10, 0); // 10:00

    test('Trả về null cho task không có giờ, không có hạn, hoặc đã hoàn thành', () {
      final dateless = Todo(id: 1, title: 'No date', createdAt: now);
      final dateOnly = Todo(
        id: 2,
        title: 'Date only',
        dueDate: now.add(const Duration(hours: 1)),
        hasTime: false,
        createdAt: now,
      );
      final completed = Todo(
        id: 3,
        title: 'Completed',
        dueDate: now.add(const Duration(hours: 1)),
        hasTime: true,
        isCompleted: true,
        createdAt: now,
      );

      expect(reminderTimeFor(dateless, now), isNull);
      expect(reminderTimeFor(dateOnly, now), isNull);
      expect(reminderTimeFor(completed, now), isNull);
    });

    test('Trả về null nếu hạn chót <= now', () {
      final exactlyNow = Todo(
        id: 1,
        title: 'Exact now',
        dueDate: now,
        hasTime: true,
        createdAt: now,
      );
      final past = Todo(
        id: 2,
        title: 'Past',
        dueDate: now.subtract(const Duration(minutes: 5)),
        hasTime: true,
        createdAt: now,
      );

      expect(reminderTimeFor(exactlyNow, now), isNull);
      expect(reminderTimeFor(past, now), isNull);
    });

    test('Hạn chót còn > 10 phút: trả về đúng dueDate - 10 phút', () {
      // Hạn chót lúc 10:30 (còn 30 phút nữa)
      final dueIn30m = Todo(
        id: 1,
        title: 'Task 10:30',
        dueDate: now.add(const Duration(minutes: 30)),
        hasTime: true,
        createdAt: now,
      );

      final reminder = reminderTimeFor(dueIn30m, now);
      expect(reminder, now.add(const Duration(minutes: 20))); // 10:20
    });

    test('Hạn chót còn < 10 phút nhưng > 5s: xử lý cờ allowLate', () {
      // Hạn chót lúc 10:07 (còn 7 phút nữa)
      final dueIn7m = Todo(
        id: 1,
        title: 'Task in 7 mins',
        dueDate: now.add(const Duration(minutes: 7)),
        hasTime: true,
        createdAt: now,
      );

      // Khi người dùng tạo/sửa task (allowLate: true) -> nhắc sau 5s
      final lateReminder = reminderTimeFor(dueIn7m, now, allowLate: true);
      expect(lateReminder, now.add(const Duration(seconds: 5)));

      // Khi mở app rescheduleAll (allowLate: false) -> null (chống spam)
      final noLateReminder = reminderTimeFor(dueIn7m, now, allowLate: false);
      expect(noLateReminder, isNull);
    });

    test('Hạn chót còn <= 5 giây: không bao giờ nhắc sau giờ hạn', () {
      // Hạn chót còn 3 giây
      final dueIn3s = Todo(
        id: 1,
        title: 'Task in 3s',
        dueDate: now.add(const Duration(seconds: 3)),
        hasTime: true,
        createdAt: now,
      );

      // Kể cả allowLate=true cũng phải trả về null vì 5s > 3s
      expect(reminderTimeFor(dueIn3s, now, allowLate: true), isNull);
    });

    test('Hỗ trợ tham số leadTime tùy biến (ví dụ 1 phút phục vụ test)', () {
      final dueIn5m = Todo(
        id: 1,
        title: 'Test 1m lead',
        dueDate: now.add(const Duration(minutes: 5)),
        hasTime: true,
        createdAt: now,
      );

      final reminder = reminderTimeFor(
        dueIn5m,
        now,
        leadTime: const Duration(minutes: 1),
      );
      expect(reminder, now.add(const Duration(minutes: 4)));
    });
  });

  group('visibleTodos & countForFilter Tests', () {
    final now = DateTime(2026, 10, 6, 10, 0); // Hôm nay là 06/10/2026
    final startOfToday = DateTime(2026, 10, 6, 0, 0);
    final endOfToday = DateTime(2026, 10, 6, 23, 59, 59);
    final tomorrow = DateTime(2026, 10, 7, 0, 0);
    final yesterday = DateTime(2026, 10, 5, 15, 0);

    final overdueTask = Todo(
      id: 1,
      title: 'Overdue Task',
      description: 'Important',
      dueDate: yesterday,
      hasTime: true,
      createdAt: now.subtract(const Duration(days: 2)),
    );
    final todayStartTask = Todo(
      id: 2,
      title: 'Morning Meeting',
      dueDate: startOfToday,
      hasTime: true,
      createdAt: now.subtract(const Duration(days: 1)),
    );
    final todayEndTask = Todo(
      id: 3,
      title: 'Night Review',
      dueDate: endOfToday,
      hasTime: true,
      createdAt: now,
    );
    final upcomingTask = Todo(
      id: 4,
      title: 'Tomorrow Project',
      dueDate: tomorrow,
      hasTime: true,
      createdAt: now,
    );
    final datelessTask = Todo(
      id: 5,
      title: 'Read Books',
      description: 'No deadline',
      createdAt: now,
    );
    final completedTask = Todo(
      id: 6,
      title: 'Done Yesterday',
      dueDate: yesterday,
      isCompleted: true,
      createdAt: now,
    );

    final allSampleTodos = [
      overdueTask,
      todayStartTask,
      todayEndTask,
      upcomingTask,
      datelessTask,
      completedTask,
    ];

    test('Lọc tab Today: gom đúng task hôm nay VÀ task quá hạn từ ngày trước (Todoist standard)', () {
      final list = visibleTodos(allSampleTodos, TodoFilter.today, '', now);
      expect(list.map((t) => t.id), [1, 2, 3]); // overdueTask, todayStart, todayEnd
    });

    test('Lọc tab Upcoming: chỉ gom các task bắt đầu từ ngày mai trở đi', () {
      final list = visibleTodos(allSampleTodos, TodoFilter.upcoming, '', now);
      expect(list.map((t) => t.id), [4]); // upcomingTask
    });

    test('Lọc tab All: gom toàn bộ task active bao gồm cả task không có ngày', () {
      final list = visibleTodos(allSampleTodos, TodoFilter.all, '', now);
      expect(list.map((t) => t.id), [1, 2, 3, 4, 5]);
    });

    test('Không bao giờ hiển thị task đã hoàn thành ở bất kỳ tab nào', () {
      for (final filter in TodoFilter.values) {
        final list = visibleTodos(allSampleTodos, filter, '', now);
        expect(list.any((t) => t.id == 6), isFalse);
      }
    });

    test('Tìm kiếm theo query không phân biệt hoa thường trên title và description', () {
      // Tìm theo title
      final searchTitle = visibleTodos(allSampleTodos, TodoFilter.all, 'meeting', now);
      expect(searchTitle.map((t) => t.id), [2]);

      // Tìm theo description
      final searchDesc = visibleTodos(allSampleTodos, TodoFilter.all, 'important', now);
      expect(searchDesc.map((t) => t.id), [1]);

      // Tìm trong tab Today
      final searchToday = visibleTodos(allSampleTodos, TodoFilter.today, 'project', now);
      expect(searchToday, isEmpty); // Task 4 nằm ở Upcoming, không xuất hiện ở Today
    });

    test('Sắp xếp ổn định (Stable Sort): có hạn trước, hạn sớm nhất trước, theo createdAt rồi id', () {
      final sameDue1 = Todo(
        id: 10,
        title: 'Same 1',
        dueDate: tomorrow,
        createdAt: DateTime(2026, 10, 6, 8, 0),
      );
      final sameDue2 = Todo(
        id: 11,
        title: 'Same 2',
        dueDate: tomorrow,
        createdAt: DateTime(2026, 10, 6, 8, 0),
      );
      final sameDueEarlierCreated = Todo(
        id: 12,
        title: 'Same Earlier Created',
        dueDate: tomorrow,
        createdAt: DateTime(2026, 10, 6, 7, 0),
      );

      final list = visibleTodos(
        [sameDue2, sameDue1, sameDueEarlierCreated],
        TodoFilter.upcoming,
        '',
        now,
      );
      expect(list.map((t) => t.id), [12, 10, 11]);

      // Kiểm tra nhánh a.dueDate == null và b.dueDate != null (task không hạn xếp sau task có hạn)
      final dateless = Todo(id: 20, title: 'No Date', createdAt: now);
      final dated = Todo(id: 21, title: 'Has Date', dueDate: tomorrow, createdAt: now);
      final sortedMixed = visibleTodos([dateless, dated], TodoFilter.all, '', now);
      expect(sortedMixed.map((t) => t.id), [21, 20]);
    });

    test('countForFilter phản ánh tổng số task active của tab, không bị ảnh hưởng bởi search query', () {
      expect(countForFilter(allSampleTodos, TodoFilter.today, now), 3);
      expect(countForFilter(allSampleTodos, TodoFilter.upcoming, now), 1);
      expect(countForFilter(allSampleTodos, TodoFilter.all, now), 5);
    });
  });

  group('selectRemindersToSchedule & reminderBody Tests', () {
    final now = DateTime(2026, 10, 6, 10, 0);

    test('selectRemindersToSchedule sắp xếp theo thời điểm nhắc và giới hạn 64 items', () {
      final todos = List.generate(70, (index) {
        return Todo(
          id: index + 1,
          title: 'Task $index',
          dueDate: now.add(Duration(minutes: 20 + index)),
          hasTime: true,
          createdAt: now,
        );
      });

      final selected = selectRemindersToSchedule(todos, now, limit: 64);
      expect(selected.length, 64);
      expect(selected.first.id, 1);
      expect(selected.last.id, 64);
    });

    test('reminderBody trả về mô tả nếu có, hoặc câu nhắc mặc định nếu description rỗng', () {
      final withDesc = Todo(
        id: 1,
        title: 'Title',
        description: 'Take passport',
        createdAt: now,
      );
      final withoutDesc = Todo(id: 2, title: 'Title', createdAt: now);
      final emptyDesc = Todo(id: 3, title: 'Title', description: '   ', createdAt: now);

      expect(reminderBody(withDesc), 'Take passport');
      expect(reminderBody(withoutDesc), 'Your task is due in 10 minutes.');
      expect(reminderBody(emptyDesc), 'Your task is due in 10 minutes.');
    });
  });
}

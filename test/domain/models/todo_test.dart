import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/domain/models/todo.dart';
import 'package:todo_app/domain/models/todo_draft.dart';
import 'package:todo_app/domain/models/todo_filter.dart';

void main() {
  group('TodoDraft Tests', () {
    test('Tạo TodoDraft hợp lệ thành công', () {
      final now = DateTime(2026, 10, 6, 10, 0);
      final draft = TodoDraft(
        title: 'Draft Task',
        description: 'Notes',
        dueDate: now,
        hasTime: true,
      );

      expect(draft.title, 'Draft Task');
      expect(draft.description, 'Notes');
      expect(draft.dueDate, now);
      expect(draft.hasTime, isTrue);
    });

    test('TodoDraft ném AssertionError khi hasTime=true nhưng dueDate=null', () {
      expect(
        () => TodoDraft(title: 'Bad Draft', hasTime: true),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('Todo Entity Tests', () {
    final fixedTime = DateTime(2026, 10, 6, 12, 30);
    final createdTime = DateTime(2026, 10, 6, 8, 0);

    test('Khởi tạo Todo hợp lệ với đầy đủ tham số', () {
      final todo = Todo(
        id: 1,
        title: 'Buy groceries',
        description: 'Milk, Eggs',
        dueDate: fixedTime,
        hasTime: true,
        isCompleted: false,
        createdAt: createdTime,
      );

      expect(todo.id, 1);
      expect(todo.title, 'Buy groceries');
      expect(todo.description, 'Milk, Eggs');
      expect(todo.dueDate, fixedTime);
      expect(todo.hasTime, isTrue);
      expect(todo.isCompleted, isFalse);
      expect(todo.createdAt, createdTime);
    });

    test('Ném AssertionError khi hasTime=true nhưng dueDate=null', () {
      expect(
        () => Todo(
          id: 2,
          title: 'Invalid Todo',
          hasTime: true,
          dueDate: null,
          createdAt: createdTime,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith cho phép cập nhật thông tin và hỗ trợ xóa cờ nullable', () {
      final todo = Todo(
        id: 1,
        title: 'Original Title',
        description: 'Original Description',
        dueDate: fixedTime,
        hasTime: true,
        createdAt: createdTime,
      );

      // 1. Cập nhật title thông thường
      final updatedTitle = todo.copyWith(title: 'New Title');
      expect(updatedTitle.title, 'New Title');
      expect(updatedTitle.description, 'Original Description');

      // 2. Xóa dueDate bằng cờ clearDueDate: true (tự động đưa hasTime về false)
      final clearedDate = todo.copyWith(clearDueDate: true);
      expect(clearedDate.dueDate, isNull);
      expect(clearedDate.hasTime, isFalse);

      // 3. Xóa description bằng cờ clearDescription: true
      final clearedDesc = todo.copyWith(clearDescription: true);
      expect(clearedDesc.description, isNull);

      // 4. Cập nhật id khi xử lý xung đột id
      final updatedId = todo.copyWith(id: 99);
      expect(updatedId.id, 99);
    });

    test('toJson chuyển đổi Todo thành Map đúng định dạng ISO8601', () {
      final todo = Todo(
        id: 10,
        title: 'Task 10',
        description: 'Details',
        dueDate: fixedTime,
        hasTime: true,
        isCompleted: true,
        createdAt: createdTime,
      );

      final json = todo.toJson();
      expect(json['id'], 10);
      expect(json['title'], 'Task 10');
      expect(json['description'], 'Details');
      expect(json['dueDate'], fixedTime.toIso8601String());
      expect(json['hasTime'], isTrue);
      expect(json['isCompleted'], isTrue);
      expect(json['createdAt'], createdTime.toIso8601String());
    });

    test('fromJson giải mã Map JSON hợp lệ', () {
      final map = {
        'id': 5,
        'title': 'Read book',
        'description': 'Chapter 1',
        'dueDate': fixedTime.toIso8601String(),
        'hasTime': true,
        'isCompleted': false,
        'createdAt': createdTime.toIso8601String(),
      };

      final todo = Todo.fromJson(map);
      expect(todo.id, 5);
      expect(todo.title, 'Read book');
      expect(todo.description, 'Chapter 1');
      expect(todo.dueDate, fixedTime);
      expect(todo.hasTime, isTrue);
      expect(todo.isCompleted, isFalse);
      expect(todo.createdAt, createdTime);
    });

    test('fromJson ném FormatException khi id không hợp lệ hoặc <= 0', () {
      // id null
      expect(() => Todo.fromJson({'title': 'Task'}), throwsA(isA<FormatException>()));
      // id <= 0
      expect(() => Todo.fromJson({'id': 0, 'title': 'Task'}), throwsA(isA<FormatException>()));
      expect(() => Todo.fromJson({'id': -5, 'title': 'Task'}), throwsA(isA<FormatException>()));
      // id là chuỗi không parse được số
      expect(() => Todo.fromJson({'id': 'abc', 'title': 'Task'}), throwsA(isA<FormatException>()));
    });

    test('fromJson ném FormatException khi title rỗng hoặc chỉ có khoảng trắng', () {
      expect(() => Todo.fromJson({'id': 1, 'title': ''}), throwsA(isA<FormatException>()));
      expect(() => Todo.fromJson({'id': 1, 'title': '   '}), throwsA(isA<FormatException>()));
      expect(() => Todo.fromJson({'id': 1}), throwsA(isA<FormatException>()));
    });

    test('fromJson ép bất biến: hasTime chỉ true khi dueDate != null', () {
      final json = {
        'id': 1,
        'title': 'Task without date',
        'dueDate': null,
        'hasTime': true, // Dữ liệu xấu
      };

      final todo = Todo.fromJson(json);
      expect(todo.hasTime, isFalse, reason: 'hasTime phải bị ép về false nếu không có dueDate');
    });

    test('fromJson rơi về epoch an toàn khi createdAt bị lỗi chuỗi', () {
      final json = {
        'id': 1,
        'title': 'Corrupted created date',
        'createdAt': 'not_a_date',
      };

      final todo = Todo.fromJson(json);
      expect(todo.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('TodoFilter Enum Tests', () {
    test('TodoFilter chứa đúng 3 giá trị All, Today, Upcoming', () {
      expect(TodoFilter.values, containsAll([
        TodoFilter.all,
        TodoFilter.today,
        TodoFilter.upcoming,
      ]));
    });
  });
}

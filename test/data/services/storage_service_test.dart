import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/data/services/storage_service.dart';
import 'package:todo_app/domain/models/todo.dart';

void main() {
  group('SharedPrefsStorageService Tests', () {
    late SharedPrefsStorageService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = SharedPrefsStorageService();
    });

    test('loadTodos trả về danh sách rỗng khi chưa có dữ liệu trong storage', () async {
      final todos = await service.loadTodos();
      expect(todos, isEmpty);
    });

    test('Lưu và đọc danh sách Todo thành công (round-trip)', () async {
      final now = DateTime(2026, 10, 6, 12, 0);
      final originalList = [
        Todo(id: 1, title: 'Task 1', createdAt: now),
        Todo(
          id: 2,
          title: 'Task 2',
          description: 'Desc 2',
          dueDate: now.add(const Duration(hours: 1)),
          hasTime: true,
          createdAt: now,
        ),
      ];

      await service.saveTodos(originalList);
      final loadedList = await service.loadTodos();

      expect(loadedList.length, 2);
      expect(loadedList[0].id, 1);
      expect(loadedList[0].title, 'Task 1');
      expect(loadedList[1].id, 2);
      expect(loadedList[1].title, 'Task 2');
      expect(loadedList[1].hasTime, isTrue);
    });

    test('Bỏ qua bản ghi hỏng và sao lưu chuỗi gốc sang key todo_items_v1_corrupt', () async {
      final prefs = await SharedPreferences.getInstance();
      final corruptRawJson = jsonEncode([
        {'id': 1, 'title': 'Valid Task 1', 'createdAt': '2026-10-06T10:00:00.000'},
        {'id': -99, 'title': 'Bad ID Task'}, // Lỗi ID <= 0
        {'id': 2, 'title': 'Valid Task 2', 'createdAt': '2026-10-06T10:00:00.000'},
      ]);

      await prefs.setString('todo_items_v1', corruptRawJson);

      final loadedList = await service.loadTodos();

      // Giữ lại 2 bản ghi hợp lệ
      expect(loadedList.length, 2);
      expect(loadedList.map((t) => t.id), [1, 2]);

      // Kiểm tra chuỗi gốc đã được sao lưu sang key corrupt
      final backedUp = prefs.getString('todo_items_v1_corrupt');
      expect(backedUp, corruptRawJson);
    });

    test('JSON không phải là List (ví dụ Object {}) -> sao lưu sang corrupt và trả về []', () async {
      final prefs = await SharedPreferences.getInstance();
      const nonListJson = '{"some_key": "some_value"}';

      await prefs.setString('todo_items_v1', nonListJson);

      final loadedList = await service.loadTodos();
      expect(loadedList, isEmpty);

      final backedUp = prefs.getString('todo_items_v1_corrupt');
      expect(backedUp, nonListJson);
    });

    test('JSON hỏng cú pháp (FormatException) -> sao lưu sang corrupt và trả về []', () async {
      final prefs = await SharedPreferences.getInstance();
      const brokenJson = '{broken json string';

      await prefs.setString('todo_items_v1', brokenJson);

      final loadedList = await service.loadTodos();
      expect(loadedList, isEmpty);

      final backedUp = prefs.getString('todo_items_v1_corrupt');
      expect(backedUp, brokenJson);
    });

    test('Đọc và ghi cờ đã yêu cầu quyền thông báo (hasRequestedNotificationPermission)', () async {
      // Mặc định là false
      expect(await service.getHasRequestedNotificationPermission(), isFalse);

      // Đặt thành true
      await service.setHasRequestedNotificationPermission(true);
      expect(await service.getHasRequestedNotificationPermission(), isTrue);
    });
  });
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/domain/models/todo.dart';

/// Giao diện trừu tượng cho dịch vụ lưu trữ dữ liệu cục bộ của ứng dụng Todo.
/// Cho phép dễ dàng thay thế bằng Fake/Mock trong các bài kiểm thử tự động.
abstract class StorageService {
  /// Đọc và giải mã danh sách công việc từ bộ nhớ.
  Future<List<Todo>> loadTodos();

  /// Tuần tự hóa và lưu danh sách công việc xuống bộ nhớ.
  Future<void> saveTodos(List<Todo> todos);

  /// Kiểm tra xem ứng dụng đã từng yêu cầu quyền thông báo lần đầu hay chưa.
  Future<bool> getHasRequestedNotificationPermission();

  /// Cập nhật cờ đánh dấu đã yêu cầu quyền thông báo.
  Future<void> setHasRequestedNotificationPermission(bool value);
}

/// Triển khai [StorageService] sử dụng [SharedPreferences] với cơ chế bảo toàn dữ liệu:
/// - Key lưu trữ chính: `todo_items_v1`
/// - Key lưu trữ bản sao lưu khi phát hiện dữ liệu lỗi: `todo_items_v1_corrupt`
class SharedPrefsStorageService implements StorageService {
  static const String _todosKey = 'todo_items_v1';
  static const String _corruptKey = 'todo_items_v1_corrupt';
  static const String _permissionKey = 'has_requested_notification_permission_v1';

  final Future<SharedPreferences> Function() _prefsFactory;

  SharedPrefsStorageService({
    Future<SharedPreferences> Function()? prefsFactory,
  }) : _prefsFactory = prefsFactory ?? SharedPreferences.getInstance;

  @override
  Future<List<Todo>> loadTodos() async {
    final prefs = await _prefsFactory();
    final rawJson = prefs.getString(_todosKey);

    // Nếu chưa có dữ liệu trong storage -> trả về danh sách rỗng
    if (rawJson == null || rawJson.trim().isEmpty) {
      return [];
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(rawJson);
    } catch (_) {
      // Chuỗi JSON bị hỏng cú pháp hoàn toàn -> sao lưu chuỗi gốc để cứu dữ liệu và trả về []
      await prefs.setString(_corruptKey, rawJson);
      return [];
    }

    // Nếu JSON hợp lệ nhưng không phải là một danh sách (ví dụ là Map {} hoặc số)
    if (decoded is! List) {
      await prefs.setString(_corruptKey, rawJson);
      return [];
    }

    final validTodos = <Todo>[];
    var hasCorruptedRecords = false;

    // Duyệt qua từng bản ghi độc lập để tránh việc 1 bản ghi lỗi làm mất cả danh sách
    for (final item in decoded) {
      try {
        if (item is Map<String, dynamic>) {
          validTodos.add(Todo.fromJson(item));
        } else if (item is Map) {
          validTodos.add(Todo.fromJson(Map<String, dynamic>.from(item)));
        } else {
          hasCorruptedRecords = true;
        }
      } catch (_) {
        // Bỏ qua bản ghi bị lỗi này
        hasCorruptedRecords = true;
      }
    }

    // Nếu có bất kỳ bản ghi nào bị lỗi và bỏ qua, lập tức sao lưu chuỗi JSON gốc
    // trước khi người dùng thực hiện lưu mới (ghi đè)
    if (hasCorruptedRecords) {
      await prefs.setString(_corruptKey, rawJson);
    }

    return validTodos;
  }

  @override
  Future<void> saveTodos(List<Todo> todos) async {
    final prefs = await _prefsFactory();
    final jsonList = todos.map((t) => t.toJson()).toList();
    final encoded = jsonEncode(jsonList);
    await prefs.setString(_todosKey, encoded);
  }

  @override
  Future<bool> getHasRequestedNotificationPermission() async {
    final prefs = await _prefsFactory();
    return prefs.getBool(_permissionKey) ?? false;
  }

  @override
  Future<void> setHasRequestedNotificationPermission(bool value) async {
    final prefs = await _prefsFactory();
    await prefs.setBool(_permissionKey, value);
  }
}

import 'dart:math';

import 'package:todo_app/domain/models/todo.dart';
import 'package:todo_app/domain/models/todo_filter.dart';

/// Cấp phát ID số nguyên dương tiếp theo cho task mới.
/// - Nếu danh sách rỗng: trả về 1.
/// - Nếu không rỗng: tìm max(id) hiện có và cộng thêm 1.
int nextId(List<Todo> todos) {
  if (todos.isEmpty) return 1;
  return todos.map((t) => t.id).reduce(max) + 1;
}

/// Kiểm tra một task có bị coi là quá hạn (Overdue) so với mốc thời gian [now] hay không.
///
/// Quy tắc:
/// 1. Task đã hoàn thành ([todo.isCompleted] = true) hoặc không có hạn chót: luôn trả về `false`.
/// 2. Task có giờ cụ thể ([todo.hasTime] = true): quá hạn nếu `dueDate < now`.
/// 3. Task chỉ có ngày ([todo.hasTime] = false): so sánh theo ngày lịch (bỏ qua phần giờ phút).
///    Task chỉ quá hạn khi ngày của deadline nhỏ hơn ngày hôm nay (`dueDay.isBefore(today)`).
///    Điều này giúp task có hạn ngày hôm nay không bị báo đỏ nhầm vào buổi sáng.
bool isOverdue(Todo todo, DateTime now) {
  final due = todo.dueDate;
  if (due == null || todo.isCompleted) return false;

  if (todo.hasTime) {
    return due.isBefore(now);
  } else {
    final dueDay = DateTime(due.year, due.month, due.day);
    final today = DateTime(now.year, now.month, now.day);
    return dueDay.isBefore(today);
  }
}

/// Tính toán thời điểm cần kích hoạt thông báo nhắc nhở cho [todo].
///
/// Tham số:
/// - [todo]: Task cần tính toán.
/// - [now]: Mốc thời gian hiện tại.
/// - [allowLate]:
///   - `true`: Khi người dùng vừa tạo hoặc sửa task. Nếu hạn chót còn dưới [leadTime] (ví dụ dưới 10 phút),
///     hàm sẽ trả về `now + 5 giây` để nhắc ngay (miễn là không vượt quá giờ hạn chót).
///   - `false`: Dùng cho `rescheduleAll` lúc khởi động app. Không bao giờ bắn nhắc muộn,
///     tránh tình trạng spam thông báo mỗi lần người dùng mở ứng dụng.
/// - [leadTime]: Khoảng thời gian thông báo trước hạn chót (mặc định 10 phút).
DateTime? reminderTimeFor(
  Todo todo,
  DateTime now, {
  bool allowLate = false,
  Duration leadTime = const Duration(minutes: 10),
}) {
  final due = todo.dueDate;
  // 1. Không đặt thông báo nếu: không có ngày, không có giờ cụ thể, hoặc task đã hoàn thành
  if (due == null || !todo.hasTime || todo.isCompleted) return null;

  // 2. Nếu hạn chót đã qua hoặc trùng đúng mốc hiện tại -> bỏ qua
  if (!due.isAfter(now)) return null;

  final reminder = due.subtract(leadTime);

  // 3. Nếu mốc nhắc (dueDate - leadTime) vẫn còn ở tương lai -> đặt lịch đúng mốc đó
  if (reminder.isAfter(now)) return reminder;

  // 4. Nếu đã qua mốc nhắc nhưng chưa đến giờ hạn:
  // - Nếu allowLate = false (rescheduleAll khi mở app): không nhắc muộn để chống spam
  if (!allowLate) return null;

  // - Nếu allowLate = true (vừa tạo/sửa task): nhắc sau 5 giây,
  // nhưng đảm bảo mốc 5 giây này không bị vượt quá giờ hạn chót
  final soon = now.add(const Duration(seconds: 5));
  return soon.isBefore(due) ? soon : null;
}

/// Kiểm tra xem một thời điểm [due] có thuộc tab Today (hôm nay hoặc quá hạn từ trước) hay không.
bool isDueTodayOrOverdue(DateTime due, DateTime now) {
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
  return due.isBefore(startOfTomorrow);
}

/// Kiểm tra xem một thời điểm [due] có thuộc tab Upcoming (bắt đầu từ ngày mai trở đi) hay không.
bool isDueUpcoming(DateTime due, DateTime now) {
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
  return !due.isBefore(startOfTomorrow);
}

/// Lọc, tìm kiếm và sắp xếp danh sách công việc hiển thị trên màn hình.
///
/// Quy tắc:
/// 1. Hiển thị cả công việc đang làm VÀ công việc đã hoàn thành (được highlight xanh trên giao diện).
/// 2. Phân loại theo [filter]:
///    - [TodoFilter.today]: Các task có hạn trong ngày hôm nay HOẶC các task quá hạn từ ngày trước (Todoist standard).
///    - [TodoFilter.upcoming]: Các task có hạn bắt đầu từ ngày mai trở đi (từ 00:00:00 ngày hôm sau).
///    - [TodoFilter.all]: Toàn bộ task (bao gồm cả task không có hạn).
/// 3. Lọc theo [query]: Tìm kiếm không phân biệt hoa thường trong `title` hoặc `description`.
/// 4. Sắp xếp ổn định (Stable Sort):
///    - Task chưa hoàn thành luôn xếp trước task đã hoàn thành.
///    - Task có hạn xếp trước task không có hạn.
///    - `dueDate` tăng dần (sớm nhất lên đầu).
///    - Nếu cùng `dueDate`, sắp xếp theo `createdAt` tăng dần.
///    - Nếu cùng `createdAt`, sắp xếp theo `id` tăng dần.
List<Todo> visibleTodos(
  List<Todo> todos,
  TodoFilter filter,
  String query,
  DateTime now,
) {
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);

  // 1. Lấy danh sách tasks
  Iterable<Todo> list = todos;

  // 2. Lọc theo filter tab
  switch (filter) {
    case TodoFilter.today:
      list = list.where((t) {
        if (t.dueDate == null) return false;
        // Task có hạn trước ngày mai = task hôm nay HOẶC task quá hạn từ trước
        return t.dueDate!.isBefore(startOfTomorrow);
      });
      break;
    case TodoFilter.upcoming:
      list = list.where((t) {
        if (t.dueDate == null) return false;
        // Task bắt đầu từ ngày mai trở đi
        return !t.dueDate!.isBefore(startOfTomorrow);
      });
      break;
    case TodoFilter.all:
      // Bao gồm cả task không có hạn
      break;
  }

  // 3. Lọc theo chuỗi tìm kiếm nếu có
  if (query.trim().isNotEmpty) {
    final q = query.trim().toLowerCase();
    list = list.where((t) {
      final titleMatch = t.title.toLowerCase().contains(q);
      final descMatch = t.description?.toLowerCase().contains(q) ?? false;
      return titleMatch || descMatch;
    });
  }

  // 4. Sắp xếp ổn định (Stable Sort)
  final sortedList = list.toList();
  sortedList.sort((a, b) {
    // Ưu tiên task chưa hoàn thành lên trước
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }

    if (a.dueDate != null && b.dueDate != null) {
      final cmp = a.dueDate!.compareTo(b.dueDate!);
      if (cmp != 0) return cmp;
    } else if (a.dueDate != null) {
      return -1; // Task có hạn xếp trước
    } else if (b.dueDate != null) {
      return 1;
    }

    final createdCmp = a.createdAt.compareTo(b.createdAt);
    if (createdCmp != 0) return createdCmp;
    return a.id.compareTo(b.id);
  });

  return sortedList;
}

/// Đếm số lượng task active (chưa hoàn thành) trong [filter], độc lập với search query.
/// Phục vụ hiển thị số lượng badge trên Tab / SegmentedButton.
int countForFilter(List<Todo> todos, TodoFilter filter, DateTime now) {
  final activeTodos = todos.where((t) => !t.isCompleted).toList();
  return visibleTodos(activeTodos, filter, '', now).length;
}

/// Lọc và chọn danh sách các task đủ điều kiện đặt lịch thông báo.
/// - Sắp xếp theo thời điểm thông báo sớm nhất lên đầu.
/// - Giới hạn tối đa [limit] task (mặc định 64 theo giới hạn thông báo chờ của hệ điều hành iOS).
List<Todo> selectRemindersToSchedule(
  List<Todo> todos,
  DateTime now, {
  int limit = 64,
  Duration leadTime = const Duration(minutes: 10),
}) {
  final eligible = todos.where((t) {
    return reminderTimeFor(t, now, allowLate: false, leadTime: leadTime) != null;
  }).toList();

  eligible.sort((a, b) {
    final remA =
        reminderTimeFor(a, now, allowLate: false, leadTime: leadTime)!;
    final remB =
        reminderTimeFor(b, now, allowLate: false, leadTime: leadTime)!;
    return remA.compareTo(remB);
  });

  return eligible.take(limit).toList();
}

/// Trả về nội dung (body) của thông báo:
/// - Nếu task có mô tả ([description]) không rỗng: dùng mô tả đó.
/// - Nếu không: trả về câu thông báo mặc định thân thiện.
String reminderBody(Todo todo) {
  if (todo.description != null && todo.description!.trim().isNotEmpty) {
    return todo.description!.trim();
  }
  return 'Your task is due in 10 minutes.';
}

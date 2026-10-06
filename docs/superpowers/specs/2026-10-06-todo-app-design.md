# Todoist-Inspired Flutter TODO App - Design Specification

**Tài liệu Thiết kế Kiến trúc & Kỹ thuật Chi tiết**  
**Ngày:** 2026-10-06  
**Dự án:** `Advanced-Mobile/Todo_App`  
**Nền tảng:** Flutter (iOS & Android)

---

## 1. Mục tiêu & Yêu cầu tổng quan

Xây dựng ứng dụng quản lý công việc (TODO list) hoàn chỉnh trên nền tảng Flutter, lấy cảm hứng từ ứng dụng **Todoist** (giao diện trực quan, tinh gọn, tiện dụng), đáp ứng 6 yêu cầu cốt lõi:
1. Tạo công việc mới với tùy chọn chọn ngày và giờ cụ thể.
2. Màn hình chính phân loại theo 3 chế độ: **All (Tất cả)** / **Today (Hôm nay)** / **Upcoming (Sắp tới)**.
3. Hiển thị danh sách công việc chính xác theo từng bộ lọc.
4. Tìm kiếm công việc theo từ khóa thời gian thực.
5. Thông báo nhắc nhở tự động trước hạn chót 10 phút sử dụng `flutter_local_notifications`.
6. Đánh dấu hoàn thành (soft-delete, ẩn khỏi danh sách active, hủy nhắc nhở) và hỗ trợ hoàn tác (Undo).

---

## 2. Nguyên tắc Kiến trúc (Architecture Principles)

Ứng dụng tuân thủ mô hình **Clean Layered Architecture (MVVM)** theo chuẩn `flutter-apply-architecture-best-practices`:

```text
lib/
├── domain/
│   ├── models/
│   │   ├── todo.dart               # Entity chính, immutable, hỗ trợ clear field, JSON serialize
│   │   └── todo_filter.dart        # Enum: all, today, upcoming
│   └── logic/
│       └── todo_logic.dart         # Toàn bộ hàm thuần túy (pure functions): lọc, sắp xếp, tìm kiếm, nhắc nhở
├── data/
│   └── services/
│       ├── storage_service.dart    # Đọc/ghi SharedPreferences (key phiên bản hóa: todo_items_v1)
│       └── notification_service.dart # Đóng gói flutter_local_notifications & timezone
├── ui/
│   ├── core/
│   │   ├── theme/
│   │   │   └── app_theme.dart      # Todoist Red (#E44332), Material 3, Dark mode
│   │   └── widgets/
│   │       ├── empty_state.dart    # Hiển thị khi danh sách rỗng
│   │       └── permission_banner.dart # Banner cảnh báo khi chưa cấp quyền thông báo
│   └── features/
│       └── todo/
│           ├── view_models/
│           │   └── todo_view_model.dart # ChangeNotifier quản lý state, clock injection, lifecycle refresh
│           └── views/
│               ├── home_screen.dart     # Scaffold, SearchBar, Tab/SegmentedButton, ListenableBuilder
│               └── widgets/
│                   ├── todo_item_tile.dart   # Task tile: checkbox tròn, badge ngày giờ/overdue đỏ
│                   └── add_todo_sheet.dart   # BottomSheet thêm/sửa task (isScrollControlled, viewInsets)
└── main.dart                       # Khởi tạo tz, SharedPreferences, DI và khởi chạy app
```

* **Zero Extra State Package**: Sử dụng `ChangeNotifier` thuần của Flutter SDK kết hợp `ListenableBuilder`. Không phụ thuộc vào Provider/Riverpod/Bloc.
* **Separation of Concerns**: Toàn bộ logic nghiệp vụ (business rules) được chuyển thành **Pure Functions** trong `domain/logic/todo_logic.dart`, nhận `DateTime now` từ ngoài vào, cho phép kiểm thử tự động 100% bằng Unit Test không cần môi trường giả lập Flutter UI hay Context.

---

## 3. Chi tiết Tầng Domain (Domain Layer)

### 3.1. Entity `Todo` (`lib/domain/models/todo.dart`)

```dart
class Todo {
  final int id;                 // ID số nguyên 32-bit tăng dần (dùng chung làm notificationId)
  final String title;           // Tiêu đề công việc (không rỗng)
  final String? description;    // Ghi chú chi tiết (tùy chọn)
  final DateTime? dueDate;      // null = không có hạn chót
  final bool hasTime;           // false = chỉ có ngày, true = có giờ phút cụ thể (để đặt thông báo)
  final bool isCompleted;       // true = đã hoàn thành (soft-delete)
  final DateTime createdAt;     // Thời điểm tạo (dùng để sắp xếp ổn định)

  const Todo({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.hasTime = false,
    this.isCompleted = false,
    required this.createdAt,
  }) : assert(hasTime ? dueDate != null : true, 'hasTime requires a non-null dueDate');

  Todo copyWith({
    String? title,
    String? description,
    bool clearDescription = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? hasTime,
    bool? isCompleted,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      description: clearDescription ? null : (description ?? this.description),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      hasTime: clearDueDate ? false : (hasTime ?? this.hasTime),
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'dueDate': dueDate?.toIso8601String(),
    'hasTime': hasTime,
    'isCompleted': isCompleted,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
    id: json['id'] as int,
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
    hasTime: json['hasTime'] as bool? ?? false,
    isCompleted: json['isCompleted'] as bool? ?? false,
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt'] as String) 
        : DateTime.now(),
  );
}
```

### 3.2. Pure Business Logic (`lib/domain/logic/todo_logic.dart`)

#### A. Thuật toán cấp phát ID (`nextId`)
```dart
int nextId(List<Todo> todos) {
  if (todos.isEmpty) return 1;
  return todos.map((t) => t.id).reduce((max, id) => id > max ? id : max) + 1;
}
```

#### B. Quy tắc tính thời điểm thông báo (`reminderTimeFor`)
* **Chống lặp khi mở app (`rescheduleAll`)**: Thêm cờ `allowLate`. Khi người dùng tạo hoặc sửa task (`allowLate: true`), nếu còn dưới 10 phút nhưng chưa tới giờ hạn, thông báo sẽ bắn sau 5 giây (`now + 5s`) nhưng **không được bắn sau giờ hạn**. Khi app khởi động chạy `rescheduleAll` (`allowLate: false`), các task đã qua mốc 10 phút sẽ **không bắn lại**, tránh spam thông báo mỗi khi mở app.
* **Xử lý biên `due <= now`**: Bỏ qua hoàn toàn.

```dart
DateTime? reminderTimeFor(Todo todo, DateTime now, {bool allowLate = false}) {
  final due = todo.dueDate;
  if (due == null || !todo.hasTime || todo.isCompleted) return null;
  if (!due.isAfter(now)) return null; // Quá hạn hoặc đúng thời điểm hiện tại -> không nhắc

  final reminder = due.subtract(const Duration(minutes: 10));
  if (reminder.isAfter(now)) return reminder;

  if (!allowLate) return null; // rescheduleAll: không nhắc muộn

  final soon = now.add(const Duration(seconds: 5));
  return soon.isBefore(due) ? soon : null; // Đảm bảo không nhắc sau giờ hạn
}
```

#### C. Quy tắc lọc, sắp xếp và tìm kiếm (`visibleTodos`)
* **Định nghĩa bộ lọc**:
  * **Today**: Các task có hạn trong ngày hôm nay ($00:00:00 \le \text{due} \le 23:59:59$) **VÀ** các task **quá hạn từ trước** (Overdue: $\text{due} < \text{startOfToday}$) theo đúng chuẩn hành vi UX của Todoist (giúp người dùng không bị bỏ quên task tồn đọng).
  * **Upcoming**: Các task có hạn từ ngày mai trở đi ($\text{due} \ge \text{startOfTomorrow}$).
  * **All**: Toàn bộ task chưa hoàn thành (bao gồm cả task không có hạn chót). Task không có hạn chót **chỉ xuất hiện ở tab All**.
* **Tìm kiếm**: Áp dụng chuỗi tìm kiếm (không phân biệt hoa thường) trực tiếp trên tab đang chọn. Nếu `query` không rỗng, lọc theo `title` hoặc `description`.
* **Quy tắc sắp xếp ổn định (Stable Sort)**:
  1. Task có hạn xếp trước task không có hạn.
  2. Sắp xếp `dueDate` tăng dần (sớm nhất lên đầu).
  3. Nếu cùng `dueDate`, sắp xếp `createdAt` tăng dần.
  4. Nếu cùng `createdAt`, sắp xếp `id` tăng dần.

```dart
List<Todo> visibleTodos(
  List<Todo> todos,
  TodoFilter filter,
  String query,
  DateTime now,
) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);

  // 1. Chỉ lấy task chưa hoàn thành
  var list = todos.where((t) => !t.isCompleted);

  // 2. Lọc theo tab
  switch (filter) {
    case TodoFilter.today:
      list = list.where((t) {
        if (t.dueDate == null) return false;
        // Chuẩn Todoist: task hôm nay HOẶC task quá hạn từ ngày trước
        return t.dueDate!.isBefore(startOfTomorrow);
      });
      break;
    case TodoFilter.upcoming:
      list = list.where((t) {
        if (t.dueDate == null) return false;
        return !t.dueDate!.isBefore(startOfTomorrow);
      });
      break;
    case TodoFilter.all:
      // Toàn bộ task active
      break;
  }

  // 3. Lọc theo chuỗi tìm kiếm
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
    if (a.dueDate != null && b.dueDate != null) {
      final cmp = a.dueDate!.compareTo(b.dueDate!);
      if (cmp != 0) return cmp;
    } else if (a.dueDate != null) {
      return -1; // Có hạn lên trước
    } else if (b.dueDate != null) {
      return 1;
    }

    final createdCmp = a.createdAt.compareTo(b.createdAt);
    if (createdCmp != 0) return createdCmp;
    return a.id.compareTo(b.id);
  });

  return sortedList;
}
```

---

## 4. Chi tiết Tầng Dữ liệu (Data Layer)

### 4.1. `StorageService` (`lib/data/services/storage_service.dart`)
* Lưu trữ dữ liệu JSON trong `SharedPreferences` với key phân phiên bản: `'todo_items_v1'`.
* **Phương thức**:
  * `Future<List<Todo>> loadTodos()`: Đọc và parse JSON. Nếu không có dữ liệu hoặc lỗi parse, trả về `[]` an toàn.
  * `Future<void> saveTodos(List<Todo> todos)`: Serialize và ghi dữ liệu xuống đĩa.

### 4.2. `NotificationService` (`lib/data/services/notification_service.dart`)
* Sử dụng `flutter_local_notifications` và `timezone/data/latest_all.dart`.
* **Chính sách cấp quyền (Permission Policy)**:
  * Khi mở app: Chỉ yêu cầu quyền thông báo cơ bản (`POST_NOTIFICATIONS` trên Android 13+, notification alert trên iOS). **Không** mở màn hình cài đặt Exact Alarm khi vừa khởi động.
  * Khi người dùng lưu task có giờ lần đầu: Yêu cầu quyền Exact Alarm nếu chưa có. Nếu người dùng từ chối, chuyển sang cơ chế lịch không chính xác (`scheduleMode: inexact`) thay vì báo lỗi.
* **Quy tắc đặt lịch an toàn**:
  * Luôn gọi `cancel(id)` trước khi gọi `zonedSchedule(...)` để tránh trùng lịch khi sửa task.
  * Bọc lệnh đặt lịch trong khối `try-catch`. Nếu hệ điều hành từ chối hoặc lỗi plugin, không làm crash app và không chặn việc lưu task.

---

## 5. Chi tiết Tầng Giao diện & ViewModel (UI & Presentation Layer)

### 5.1. `TodoViewModel` (`lib/ui/features/todo/view_models/todo_view_model.dart`)
* Kế thừa `ChangeNotifier`. Nhận `StorageService`, `NotificationService`, và hàm clock tùy chọn `DateTime Function()? clock` (phục vụ Unit Test biên thời gian).
* **Quản lý Vòng đời & Qua nửa đêm**:
  * Lắng nghe `AppLifecycleListener.onResume`: Khi app mở lại từ background, tự động kích hoạt `notifyListeners()` để cập nhật tab Today nếu đã qua nửa đêm.
* **Xử lý An toàn Dữ liệu**:
  * Mọi thao tác thêm/sửa/xóa đều **ghi vào Storage trước**, sau đó mới gọi NotificationService trong `try-catch`.
* **Luồng Hoàn thành & Xóa kèm Hoàn tác (Undo)**:
  * `completeTodo(int id)`: Đánh dấu `isCompleted = true`, hủy thông báo tương ứng, lưu Storage.
  * `undoComplete(int id)`: Đặt `isCompleted = false`, tính lại `reminderTimeFor(todo, now, allowLate: true)`, lên lại lịch thông báo, lưu Storage.
  * `deleteTodo(int id)`: Xóa hẳn task khỏi danh sách, hủy thông báo, lưu Storage.
  * `undoDelete(Todo todo)`: Khôi phục lại task và lên lại lịch thông báo.
  * **Quy ước Kiến trúc**: `BuildContext` và `SnackBar` hoàn toàn nằm ở View layer. View gọi ViewModel, sau đó hiển thị SnackBar kèm nút Action gọi `undoComplete`.

### 5.2. `HomeScreen` (`lib/ui/features/todo/views/home_screen.dart`)
* **Thanh tìm kiếm (`SearchBar`)**: Nằm ngay trên đầu màn hình, hỗ trợ lọc tức thì.
* **Cảnh báo Quyền (`PermissionBanner`)**: Hiển thị thanh thông báo màu vàng cam nhẹ phía dưới thanh tìm kiếm nếu quyền thông báo bị từ chối: *"Quyền thông báo đang tắt. Bạn sẽ không nhận được thông báo nhắc nhở."* kèm nút *"Bật lại"*.
* **Bộ chọn Tab (`SegmentedButton` hoặc `TabBar`)**:
  * 3 tab: **Hôm nay (Today)**, **Sắp tới (Upcoming)**, **Tất cả (All)**.
  * Hiển thị số lượng task đang có ở từng tab.
* **Danh sách công việc (`ListView.separated`)**:
  * Render các `TodoItemTile`:
    * Nút check tròn viền đỏ Todoist. Chạm vào sẽ kích hoạt animation check và ẩn task.
    * Tiêu đề công việc.
    * Ghi chú/mô tả (nếu có, tối đa 2 dòng).
    * Badge ngày giờ: Nếu là task quá hạn (Overdue), hiển thị chữ và icon màu đỏ đậm `#D1453B` để cảnh báo.
  * Hỗ trợ vuốt ngang (`Dismissible`) để hoàn thành hoặc xóa nhanh.

### 5.3. `AddTodoSheet` (`lib/ui/features/todo/views/widgets/add_todo_sheet.dart`)
* Nhận tham số tùy chọn `Todo? initialTodo` để dùng chung cho cả **Thêm mới** và **Chỉnh sửa**.
* Thiết lập `isScrollControlled: true` và `padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)` để form nhập không bao giờ bị bàn phím ảo che khuất.
* Các trường nhập:
  * TextField Tiêu đề (bắt buộc, tự động focus).
  * TextField Mô tả (tùy chọn).
  * Chip chọn Ngày (mở `showDatePicker`). Có nút `X` để xóa ngày đã chọn.
  * Switch hoặc Chip chọn Giờ (chỉ kích hoạt khi đã có ngày, mở `showTimePicker`).
  * Nút "Lưu": Kiểm tra nếu người dùng chọn giờ trong quá khứ $\rightarrow$ hiển thị cảnh báo lỗi ngay dưới trường giờ, không cho lưu giờ đã qua.

---

## 6. Chiến lược Kiểm thử (Testing Strategy)

Tuân thủ nghiêm ngặt quy trình `test-driven-development` và `micro-task-workflow`:

1. **Unit Test Pure Logic (`test/domain/logic/todo_logic_test.dart`)**:
   * Test `reminderTimeFor`:
     * Task không có hạn $\rightarrow$ trả về `null`.
     * Task có hạn nhưng `hasTime = false` $\rightarrow$ trả về `null`.
     * Task đã quá hạn $\rightarrow$ trả về `null`.
     * Task hạn còn > 10 phút $\rightarrow$ trả về đúng $\text{dueDate} - 10\text{p}$.
     * Task hạn còn < 10 phút với `allowLate: true` $\rightarrow$ trả về $\text{now} + 5\text{s}$.
     * Task hạn còn < 10 phút với `allowLate: false` (`rescheduleAll`) $\rightarrow$ trả về `null` (chống spam).
     * Task hạn còn < 5 giây với `allowLate: true` $\rightarrow$ trả về `null` (không nhắc sau giờ hạn).
   * Test `visibleTodos`:
     * Kiểm tra tab Today gom đúng task hôm nay và task overdue từ ngày trước.
     * Kiểm tra tab Upcoming chỉ gom task từ ngày mai.
     * Kiểm tra tab All chứa cả task không có hạn.
     * Kiểm tra tìm kiếm lọc đúng trên tab đang chọn.
     * Kiểm tra thứ tự sắp xếp ổn định (dueDate $\rightarrow$ createdAt $\rightarrow$ id).
   * Test `nextId`:
     * Danh sách rỗng $\rightarrow$ trả về 1.
     * Danh sách có ID nhảy cóc (1, 5, 3) $\rightarrow$ trả về 6.
2. **Unit Test Model & Serialization (`test/domain/models/todo_test.dart`)**:
   * Test `toJson` và `fromJson` bảo toàn dữ liệu và xử lý giá trị mặc định khi thiếu trường.
   * Test `copyWith` với cờ `clearDueDate` và `clearDescription`.
3. **Unit Test ViewModel (`test/ui/features/todo/todo_view_model_test.dart`)**:
   * Mock `StorageService` và `NotificationService`.
   * Test thêm task, hoàn thành task, hoàn tác (undo), xóa task.
   * Test lưu trữ thành công ngay cả khi `NotificationService` ném exception.

---

## 7. Kế hoạch triển khai (Micro-Task Breakdown)

Kế hoạch sẽ được chia nhỏ thành các nhiệm vụ độc lập, mỗi nhiệm vụ tuân thủ `atomic-conventional-commits` và TDD:

* **Task 1**: Khởi tạo cấu trúc dự án Flutter, cấu hình dependencies (`shared_preferences`, `flutter_local_notifications`, `timezone`, `intl`), thiết lập `.gitignore` an toàn.
* **Task 2**: Viết `Todo` model, `TodoFilter` enum và unit test serialization.
* **Task 3**: Viết pure functions trong `domain/logic/todo_logic.dart` (`reminderTimeFor`, `visibleTodos`, `nextId`) và bộ unit test toàn diện 100% độ phủ.
* **Task 4**: Triển khai `StorageService` với key `todo_items_v1` và unit test.
* **Task 5**: Triển khai `NotificationService` (cấu hình permissions, timezone, cancel trước khi schedule, xử lý lỗi an toàn).
* **Task 6**: Triển khai `TodoViewModel` (`ChangeNotifier`, clock injection, lifecycle listener, storage-first) và unit test.
* **Task 7**: Xây dựng UI Atomic Widgets (`TodoItemTile` checkbox tròn & badge overdue, `EmptyState`, `PermissionBanner`).
* **Task 8**: Xây dựng `AddTodoSheet` (dùng chung cho thêm/sửa, chống che bàn phím, date/time pickers).
* **Task 9**: Xây dựng `HomeScreen` (SearchBar, Tab filters, kết nối `ListenableBuilder`, hiển thị SnackBar Undo).
* **Task 10**: Hoàn thiện UI/UX (Todoist Material 3 Theme, Dark Mode, tap target $\ge 48\text{dp}$, kiểm thử trên simulator/thiết bị thực tế).

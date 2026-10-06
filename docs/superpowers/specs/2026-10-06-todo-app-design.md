# Todoist-Inspired Flutter TODO App - Design Specification (v2.0)

**Architectural & Technical Design Specification**  
**Date:** 2026-10-06  
**Project:** `Advanced-Mobile/Todo_App`  
**Platform:** Flutter (iOS & Android) — Target SDK: Flutter 3.47.6 / Dart 3.13.5  
**UI Language:** English

---

## 1. Overview & Core Requirements

Build a production-grade, Todoist-inspired task management application on Flutter adhering to strict Clean Architecture (MVVM) and the 6 exercise criteria:
1. **Create TODO with Time Option**: Support setting a due date, with an optional specific time (hour & minute).
2. **Main Page Categorization**: Filter tasks by **All**, **Today**, and **Upcoming**.
3. **Display Filtered Lists**: Accurate categorization, with badge counts per tab independent of search query.
4. **Search Functionality**: Real-time search query applied within the active filter tab.
5. **10-Minute Prior Alert Notification**: Scheduled local notification 10 minutes prior to due time using `flutter_local_notifications` + `timezone`.
6. **Completion & Removal (Soft Delete)**: Mark as completed, remove from active lists, cancel notification, with full Undo support.

---

## 2. Architectural Layers & Project Structure

The project follows `flutter-apply-architecture-best-practices` with 100% testable domain logic:

```text
lib/
├── domain/
│   ├── models/
│   │   ├── todo.dart               # Entity with defensive JSON parsing, copyWith, clear flags
│   │   └── todo_filter.dart        # Enum: all, today, upcoming
│   └── logic/
│       └── todo_logic.dart         # Pure functions: isOverdue, reminderTimeFor, visibleTodos, nextId
├── data/
│   └── services/
│       ├── storage_service.dart    # Abstract interface & SharedPrefsStorageService (record-by-record parsing, corrupt backup)
│       └── notification_service.dart # Abstract interface & FlutterLocalNotificationService (timezone, exact alarm fallback)
├── ui/
│   ├── core/
│   │   ├── theme/
│   │   │   └── app_theme.dart      # Todoist Red (#E44332), Material 3, Dark mode
│   │   └── widgets/
│   │       ├── empty_state.dart    # Clean empty state widget
│   │       └── permission_banner.dart # Warning banner with "Open Settings" action via permission_handler
│   └── features/
│       └── todo/
│           ├── view_models/
│           │   └── todo_view_model.dart # ChangeNotifier: write queue, clock injection, 60s ticker & lifecycle refresh
│           └── views/
│               ├── home_screen.dart     # SearchBar, Tab/SegmentedBar with fixed counts, Dismissible list
│               └── widgets/
│                   ├── todo_item_tile.dart   # Circular checkbox, overdue badge, Dismissible (LTR complete, RTL delete)
│                   └── add_todo_sheet.dart   # Shared create/edit sheet, isScrollControlled, viewInsets padding
└── main.dart                       # Local timezone initialization, DI, app entry point
```

### Core Design Rules
* **Zero Extra State Package**: Pure `ChangeNotifier` + `ListenableBuilder` from Flutter SDK.
* **Abstract Interfaces for Testability**: Both `StorageService` and `NotificationService` have abstract interfaces to enable mocking in unit/integration tests without hardware or plugin bindings.
* **Storage-First & Write Queue**: In-memory state and storage are updated first; notifications are scheduled secondary in a `try-catch`. A sequential write queue ensures rapid user actions never result in race-condition overwrites.

---

## 3. Domain Layer

### 3.1. Entity `Todo` (`lib/domain/models/todo.dart`)

```dart
class Todo {
  final int id;                 // 32-bit integer ID, shared with notification ID
  final String title;           // Non-empty title
  final String? description;    // Optional notes
  final DateTime? dueDate;      // Null = No deadline; normalized to 00:00:00 if hasTime == false
  final bool hasTime;           // false = Date only (no notification); true = Specific hour & minute
  final bool isCompleted;       // true = Soft-deleted, hidden from active lists, notification cancelled
  final DateTime createdAt;     // Creation timestamp for deterministic tie-breaking sort

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
    int? id,
  }) {
    return Todo(
      id: id ?? this.id,
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

  /// Defensive JSON deserialization:
  /// - Avoids unsafe casts (as int)
  /// - Uses stable deterministic fallback for createdAt
  /// - Enforces hasTime invariant: hasTime is true ONLY if dueDate != null
  factory Todo.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final title = json['title']?.toString() ?? '';
    final description = json['description']?.toString();
    final dueDate = json['dueDate'] != null ? DateTime.tryParse(json['dueDate'].toString()) : null;
    final rawHasTime = json['hasTime'] == true;
    final isCompleted = json['isCompleted'] == true;
    final createdAt = json['createdAt'] != null
        ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.fromMillisecondsSinceEpoch(0))
        : DateTime.fromMillisecondsSinceEpoch(0);

    return Todo(
      id: id,
      title: title,
      description: description,
      dueDate: dueDate,
      hasTime: rawHasTime && dueDate != null,
      isCompleted: isCompleted,
      createdAt: createdAt,
    );
  }
}
```

### 3.2. Pure Business Logic (`lib/domain/logic/todo_logic.dart`)

#### A. ID Generation (`nextId`)
```dart
int nextId(List<Todo> todos) {
  if (todos.isEmpty) return 1;
  return todos.map((t) => t.id).reduce((max, id) => id > max ? id : max) + 1;
}
```

#### B. Overdue Check (`isOverdue`)
* Invariant: For date-only tasks (`hasTime == false`), `dueDate` is normalized to `00:00:00` on that day.
* A date-only task becomes overdue **only when that calendar day has passed** (`dueDate < startOfToday`).
* A timed task (`hasTime == true`) becomes overdue **the moment `now` passes `dueDate`** (`dueDate < now`).

```dart
bool isOverdue(Todo todo, DateTime now) {
  final due = todo.dueDate;
  if (due == null || todo.isCompleted) return false;
  if (todo.hasTime) {
    return due.isBefore(now);
  } else {
    final startOfToday = DateTime(now.year, now.month, now.day);
    return due.isBefore(startOfToday);
  }
}
```

#### C. Notification Schedule Time (`reminderTimeFor`)
* **Parametric Lead Time**: Defaults to 10 minutes (`Duration leadTime = const Duration(minutes: 10)`), allowing manual testing with 1 minute without changing business logic constants.
* **Anti-Spam on Startup**: `allowLate: false` during `rescheduleAll` skips tasks within the 10-minute window. `allowLate: true` on user create/edit schedules alert for `now + 5s` only if `now + 5s < due`.

```dart
DateTime? reminderTimeFor(
  Todo todo,
  DateTime now, {
  bool allowLate = false,
  Duration leadTime = const Duration(minutes: 10),
}) {
  final due = todo.dueDate;
  if (due == null || !todo.hasTime || todo.isCompleted) return null;
  if (!due.isAfter(now)) return null; // due <= now is ignored

  final reminder = due.subtract(leadTime);
  if (reminder.isAfter(now)) return reminder;

  if (!allowLate) return null; // App launch / rescheduleAll: do not spam late alert

  final soon = now.add(const Duration(seconds: 5));
  return soon.isBefore(due) ? soon : null; // Never alert after due date
}
```

#### D. Tab & Search Filtering with Stable Sort (`visibleTodos`)
* **Today Tab**: Contains tasks due today ($00:00:00 \le \text{due} \le 23:59:59$) **plus** Overdue tasks from previous days (`dueDate < startOfToday`), following Todoist standards.
* **Upcoming Tab**: Tasks due strictly tomorrow onwards ($\text{due} \ge \text{startOfTomorrow}$).
* **All Tab**: All active tasks, including tasks without a due date.
* **Deterministic Stable Sort**:
  1. Tasks with due dates appear before tasks without due dates.
  2. `dueDate` ascending.
  3. `createdAt` ascending.
  4. `id` ascending.

```dart
List<Todo> visibleTodos(
  List<Todo> todos,
  TodoFilter filter,
  String query,
  DateTime now,
) {
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);

  var list = todos.where((t) => !t.isCompleted);

  switch (filter) {
    case TodoFilter.today:
      list = list.where((t) {
        if (t.dueDate == null) return false;
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
      break;
  }

  if (query.trim().isNotEmpty) {
    final q = query.trim().toLowerCase();
    list = list.where((t) {
      final titleMatch = t.title.toLowerCase().contains(q);
      final descMatch = t.description?.toLowerCase().contains(q) ?? false;
      return titleMatch || descMatch;
    });
  }

  final sortedList = list.toList();
  sortedList.sort((a, b) {
    if (a.dueDate != null && b.dueDate != null) {
      final cmp = a.dueDate!.compareTo(b.dueDate!);
      if (cmp != 0) return cmp;
    } else if (a.dueDate != null) {
      return -1;
    } else if (b.dueDate != null) {
      return 1;
    }

    final createdCmp = a.createdAt.compareTo(b.createdAt);
    if (createdCmp != 0) return createdCmp;
    return a.id.compareTo(b.id);
  });

  return sortedList;
}

int countForFilter(List<Todo> todos, TodoFilter filter, DateTime now) {
  return visibleTodos(todos, filter, '', now).length;
}
```

---

## 4. Data Layer

### 4.1. `StorageService` (`lib/data/services/storage_service.dart`)

```dart
abstract class StorageService {
  Future<List<Todo>> loadTodos();
  Future<void> saveTodos(List<Todo> todos);
}
```

#### Defensive Persistence Implementation (`SharedPrefsStorageService`):
1. **Key Versioning**: Uses key `'todo_items_v1'`.
2. **Corrupted String Backup**: If `jsonDecode` fails completely on raw string, copies raw string to `'todo_items_v1_corrupt'` and returns `[]`.
3. **Record-by-Record Deserialization**: Loops through each element in the parsed JSON list. If a single element throws a deserialization error, it logs the error, drops that corrupt record, and retains all valid records.
4. **No Empty Overwrite**: If loading encounters corrupted records, the remaining valid records are kept so user additions don't blindly wipe prior data.

### 4.2. `NotificationService` (`lib/data/services/notification_service.dart`)

```dart
abstract class NotificationService {
  Future<void> initialize();
  Future<bool> checkPermissionStatus();
  Future<bool> requestGeneralPermissions();
  Future<bool> requestExactAlarmPermission();
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  });
  Future<void> cancelNotification(int id);
  Future<void> rescheduleAll(List<Todo> todos, DateTime now);
}
```

#### Timezone & Native Details (`FlutterLocalNotificationService`):
1. **Device Local Timezone**: Uses `flutter_timezone` plugin to resolve device location name (`await FlutterTimezone.getLocalTimezone()`), initializes `tz.initializeTimeZones()`, and binds via `tz.setLocalLocation(tz.getLocation(timeZoneName))`.
2. **Scheduling Conversion**: Converts local `DateTime` into `tz.TZDateTime.from(scheduledDate, tz.local)`.
3. **Cancel Before Schedule**: Every `scheduleNotification(id, ...)` calls `cancelNotification(id)` first to prevent duplicate notifications upon task edits.
4. **Safe Try-Catch**: Scheduling operations are wrapped in `try-catch`; failures log errors and do not crash the app or block storage saves.
5. **iOS 64-Limit & Reschedule All**:
   * On app launch, `TodoViewModel.initialize()` calls `rescheduleAll(activeTodos, clock())`.
   * To obey iOS's hard limit of 64 pending local notifications, `rescheduleAll` sorts eligible tasks by reminder time and schedules only the nearest 64 tasks.

---

## 5. Platform Setup & Native Configuration

### 5.1. Dependencies (`pubspec.yaml`)
```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.5.4
  flutter_local_notifications: ^19.0.0
  timezone: ^0.10.0
  flutter_timezone: ^4.1.0
  permission_handler: ^12.0.1
  intl: ^0.20.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

### 5.2. Android Native Configuration
* **Java 17 & Desugaring**: In `android/app/build.gradle`:
  ```groovy
  compileOptions {
      coreLibraryDesugaringEnabled true
      sourceCompatibility JavaVersion.VERSION_17
      targetCompatibility JavaVersion.VERSION_17
  }
  defaultConfig {
      minSdkVersion 24 // Required for modern local notifications & desugaring
  }
  dependencies {
      coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
  }
  ```
* **Permissions & Receivers**: In `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  <uses-permission android:name="android.permission.VIBRATE"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
  <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>

  <application ...>
      <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
      <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
          <intent-filter>
              <action android:name="android.intent.action.BOOT_COMPLETED"/>
              <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
          </intent-filter>
      </receiver>
  ```

### 5.3. iOS Native Configuration
* In `ios/Runner/AppDelegate.swift`:
  ```swift
  import flutter_local_notifications

  @UIApplicationMain
  @objc class AppDelegate: FlutterAppDelegate {
    override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
      FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
      }
      if #available(iOS 10.0, *) {
        UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
      }
      GeneratedPluginRegistrant.register(with: self)
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
  }
  ```

---

## 6. Presentation & UI Layer

### 6.1. `TodoViewModel` (`lib/ui/features/todo/view_models/todo_view_model.dart`)
* **State**:
  * `List<Todo> _todos`
  * `TodoFilter _currentFilter = TodoFilter.today`
  * `String _searchQuery = ''`
  * `bool _hasNotificationPermission = true`
  * `bool _isLoading = true`
* **Clock & Timers**:
  * Injectable clock `final DateTime Function() _clock` (defaults to `DateTime.now`).
  * 60-second `Timer.periodic`: calls `notifyListeners()` so relative date labels and overdue badges refresh in real-time without user interaction.
  * `AppLifecycleListener.onResume`: re-checks permission status and calls `notifyListeners()` when app returns to foreground.
* **Sequential Write Queue**:
  * Private chain `Future<void> _writeQueue = Future.value();`
  * Every mutation enqueues `_storageService.saveTodos(_todos)` to serialize writes safely.
* **Undo Operations**:
  * `undoComplete(int id)`: Sets `isCompleted = false`. Re-schedules notification with `allowLate: false` (avoids immediate 5-second spam since user already knows of the task).
  * `undoDelete(Todo deletedTodo)`: Checks if `deletedTodo.id` is occupied by another newly created task in `_todos`. If occupied, assigns `nextId(_todos)` to resolve collisions, then adds back and re-schedules notification.

### 6.2. `HomeScreen` (`lib/ui/features/todo/views/home_screen.dart`)
* **Top Search Bar**: "Search tasks..." field with clear icon button.
* **Permission Banner**: Rendered conditionally if `_hasNotificationPermission == false`. Displays:
  *"Notifications are disabled. You will not receive reminders."* with an action button *"Settings"* calling `openAppSettings()`.
* **Filter Bar**: `SegmentedButton<TodoFilter>` with 3 tabs:
  * **Today (N)**
  * **Upcoming (N)**
  * **All (N)**
  * *Note: Tab counts (N) reflect total active tasks in that tab, NOT filtered by search query.*
* **Task List & Dismissible**:
  * Items wrapped in `Dismissible` with `key: ValueKey(todo.id)`.
  * **Left-to-Right (Start-to-End)**: Complete task. Green background with checkmark icon.
  * **Right-to-Left (End-to-Start)**: Delete task. Red background with trash icon.
  * Triggers SnackBar with an **Undo** button.
* **Empty State**: Friendly illustration and text when no tasks match filter or query.

### 6.3. `AddTodoSheet` (`lib/ui/features/todo/views/widgets/add_todo_sheet.dart`)
* Dual-purpose: Handles both **Create** and **Edit** via optional `Todo? initialTodo`.
* Form behavior:
  * `isScrollControlled: true` and `EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)`.
  * Title field (autofocus). Description field.
  * Date Picker (`showDatePicker`). When date is selected, `dueDate` is normalized to `00:00:00`.
  * Time Switch/Picker (`showTimePicker`). Enabled only when a date is selected.
  * Clear Date button to reset task to dateless.
  * Validation: Prevents selecting past date/times when saving a timed task.

---

## 7. Testing Strategy

1. **Unit Test Pure Logic (`test/domain/logic/todo_logic_test.dart`)**:
   * `reminderTimeFor`:
     * No date / no time / completed $\rightarrow$ returns `null`.
     * Overdue / due == now $\rightarrow$ returns `null`.
     * Due in 30 mins $\rightarrow$ returns `due - 10m`.
     * Due in 6 mins, `allowLate: true` $\rightarrow$ returns `now + 5s`.
     * Due in 6 mins, `allowLate: false` $\rightarrow$ returns `null`.
     * Due in 3 seconds, `allowLate: true` $\rightarrow$ returns `null` (never alerts after due).
     * Custom `leadTime: 1m` works accurately.
   * `isOverdue`:
     * Timed task: overdue if `due < now`.
     * Date-only task: overdue only if `due < startOfToday` (NOT overdue in the morning of the same day).
   * `visibleTodos`:
     * Today tab captures today's tasks and prior overdue tasks.
     * Upcoming tab strictly starts tomorrow.
     * All tab captures dateless tasks.
     * Search filters within current tab.
     * Stable sort order verified.
   * `nextId`:
     * Empty $\rightarrow$ 1; Sparse list `[1, 5, 3]` $\rightarrow$ 6.
2. **Unit Test Models & Persistence (`test/domain/models/todo_test.dart`, `test/data/services/storage_service_test.dart`)**:
   * `fromJson` defensive parsing against bad types and missing keys.
   * Corrupt JSON string backed up to `todo_items_v1_corrupt`.
   * Corrupt single record skipped while preserving remaining records.
3. **Unit Test ViewModel (`test/ui/features/todo/todo_view_model_test.dart`)**:
   * Mock `StorageService` and `NotificationService`.
   * Complete & Undo flow with notification cancellation and re-scheduling.
   * Delete & Undo with ID collision handling.
   * Storage-first resilience: storage succeeds even if notification fails.
   * 60s ticker & lifecycle resume triggers `notifyListeners()`.

---

## 8. Micro-Task Breakdown & Implementation Checklist

Each task strictly follows `atomic-conventional-commits`, `micro-task-workflow`, and TDD:

- [ ] **Task 1: Project Scaffolding & Dependencies**
  - Run `flutter create --org com.example todo_app`.
  - Add dependencies: `shared_preferences`, `flutter_local_notifications`, `timezone`, `flutter_timezone`, `permission_handler`, `intl`.
  - Setup `.gitignore` (ignore build artifacts, `.env`, local IDE files).
  - Verification: `flutter pub get` passes.

- [ ] **Task 2: Native Android & iOS Platform Setup**
  - Android: `build.gradle` Java 17, `coreLibraryDesugaringEnabled`, `minSdkVersion 24`.
  - Android: `AndroidManifest.xml` permissions & receivers.
  - iOS: `AppDelegate.swift` plugin registrant & delegate.
  - Verification: Clean build succeeds on Android (`flutter build apk --debug`) and iOS (`flutter build ios --no-codesign`).

- [ ] **Task 3: Domain Model & Entity Tests**
  - Create `TodoFilter` enum.
  - Create `Todo` model with defensive `fromJson`, `toJson`, `copyWith`, `clearDueDate`, `clearDescription`.
  - Create unit tests in `test/domain/models/todo_test.dart`.
  - Verification: `flutter test test/domain/models/todo_test.dart` passes.

- [ ] **Task 4: Domain Business Logic & Comprehensive Pure Tests**
  - Implement `nextId`, `isOverdue`, `reminderTimeFor`, `visibleTodos`, `countForFilter` in `todo_logic.dart`.
  - Implement comprehensive unit tests in `test/domain/logic/todo_logic_test.dart`.
  - Verification: `flutter test test/domain/logic/todo_logic_test.dart` passes (100% logic coverage).

- [ ] **Task 5: Storage Service & Corrupt Recovery**
  - Create abstract `StorageService` and `SharedPrefsStorageService`.
  - Implement record-by-record parsing, `todo_items_v1_corrupt` backup.
  - Create unit tests in `test/data/services/storage_service_test.dart`.
  - Verification: `flutter test test/data/services/storage_service_test.dart` passes.

- [ ] **Task 6: Notification Service & Timezone Engine**
  - Create abstract `NotificationService` and `FlutterLocalNotificationService`.
  - Setup `flutter_timezone`, `tz.initializeTimeZones()`, `zonedSchedule`, `cancelNotification`, and 64-task cap in `rescheduleAll`.
  - Implement unit test with mock service in `test/data/services/notification_service_test.dart`.
  - Verification: Unit tests pass.

- [ ] **Task 7: TodoViewModel & State Management**
  - Create `TodoViewModel` with write queue, clock injection, 60s ticker, `AppLifecycleListener.onResume`.
  - Implement `addTodo`, `editTodo`, `completeTodo`, `undoComplete`, `deleteTodo`, `undoDelete` (with ID collision resolution).
  - Create unit tests in `test/ui/features/todo/todo_view_model_test.dart`.
  - Verification: All ViewModel tests pass.

- [ ] **Task 8: Atomic UI Components**
  - Create `AppTheme` (Todoist Red `#E44332`, Material 3, Dark mode).
  - Create `EmptyState` and `PermissionBanner` (with `openAppSettings()`).
  - Create `TodoItemTile` with circular checkbox, overdue badge, Dismissible (LTR complete, RTL delete).
  - Create widget test in `test/ui/widgets/todo_item_tile_test.dart`.
  - Verification: Widget test passes.

- [ ] **Task 9: Add / Edit Todo Bottom Sheet**
  - Create `AddTodoSheet` supporting both new task creation and editing.
  - Implement `isScrollControlled: true`, `viewInsets` padding, date/time pickers, past-time validation.
  - Create widget test in `test/ui/widgets/add_todo_sheet_test.dart`.
  - Verification: Widget test passes.

- [ ] **Task 10: Home Screen & Flow Integration**
  - Build `HomeScreen` with `SearchBar`, `SegmentedButton` tabs (fixed counts), `ListenableBuilder`, FAB.
  - Wire SnackBar with Undo action on Complete and Delete.
  - Verification: App runs cleanly and integrates all layers.

- [ ] **Task 11: End-to-End QA & Known Platform Limits Documentation**
  - Create `README.md` documenting architecture, test instructions, and platform notes (iOS 64 pending limit, Android Doze mode inexact timing).
  - Manual QA on physical/simulated device: schedule task due in 2 minutes, background/terminate app, verify 10-minute/alert notification fires.
  - Final verification: `flutter analyze` and `flutter test` pass with 0 errors/warnings.

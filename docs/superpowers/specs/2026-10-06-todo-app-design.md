# Todoist-Inspired Flutter TODO App - Design Specification (v2.1)

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
│   │   ├── todo.dart               # Entity with strict JSON validation, copyWith, clear flags
│   │   ├── todo_draft.dart         # Draft entity returned by AddTodoSheet (title, description, dueDate, hasTime)
│   │   └── todo_filter.dart        # Enum: all, today, upcoming
│   └── logic/
│       └── todo_logic.dart         # Pure functions: isOverdue, reminderTimeFor, visibleTodos, nextId, selectRemindersToSchedule, reminderBody
├── data/
│   └── services/
│       ├── storage_service.dart    # Abstract interface & SharedPrefsStorageService (record-by-record parsing, corrupt backup)
│       └── notification_service.dart # Abstract interface & FlutterLocalNotificationService (timezone, exact alarm fallback, cancelAll before reschedule)
├── ui/
│   ├── core/
│   │   ├── theme/
│   │   │   └── app_theme.dart      # Todoist Red (#E44332), Material 3, Dark mode
│   │   └── widgets/
│   │       ├── empty_state.dart    # Clean empty state widget
│   │       └── permission_banner.dart # Warning banner with onOpenSettings callback
│   └── features/
│       └── todo/
│           ├── view_models/
│           │   └── todo_view_model.dart # ChangeNotifier: resilient write queue, clock injection, 60s ticker & lifecycle refresh, 30-day purge
│           └── views/
│               ├── home_screen.dart     # SearchBar, SegmentedButton with fixed counts, Dismissible list, hideCurrentSnackBar
│               └── widgets/
│                   ├── todo_item_tile.dart   # Circular checkbox, overdue badge, Dismissible (LTR complete, RTL delete), accepts now
│                   └── add_todo_sheet.dart   # Shared create/edit sheet returning TodoDraft, isScrollControlled, viewInsets padding
└── main.dart                       # Local timezone initialization, DI, app entry point
```

### Core Design Rules
* **Zero Extra State Package**: Pure `ChangeNotifier` + `ListenableBuilder` from Flutter SDK.
* **Abstract Interfaces for Testability**: Both `StorageService` and `NotificationService` have abstract interfaces to enable mocking in unit/integration tests without hardware or plugin bindings.
* **Storage-First & Resilient Combined Queue**: In-memory state and storage are updated first; notifications are scheduled secondary. A sequential queue (`_enqueue`) with `.catchError` guarantees operations never interleave or permanently halt on failure.

---

## 3. Domain Layer

### 3.1. Entity `TodoDraft` (`lib/domain/models/todo_draft.dart`)

```dart
class TodoDraft {
  final String title;
  final String? description;
  final DateTime? dueDate;
  final bool hasTime;

  const TodoDraft({
    required this.title,
    this.description,
    this.dueDate,
    this.hasTime = false,
  }) : assert(hasTime ? dueDate != null : true, 'hasTime requires non-null dueDate');
}
```

### 3.2. Entity `Todo` (`lib/domain/models/todo.dart`)

```dart
class Todo {
  final int id;                 // 32-bit positive integer ID, shared with notification ID
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

  /// Strict & Defensive JSON deserialization:
  /// - Throws FormatException if `id` is invalid (<= 0, non-int) or `title` is empty
  /// - Other fields use safe fallbacks
  /// - Enforces hasTime invariant: hasTime is true ONLY if dueDate != null
  factory Todo.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null || id <= 0) {
      throw const FormatException('Invalid or missing todo id');
    }

    final title = json['title']?.toString()?.trim() ?? '';
    if (title.isEmpty) {
      throw const FormatException('Invalid or empty todo title');
    }

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

### 3.3. Pure Business Logic (`lib/domain/logic/todo_logic.dart`)

```dart
int nextId(List<Todo> todos) {
  if (todos.isEmpty) return 1;
  return todos.map((t) => t.id).reduce((max, id) => id > max ? id : max) + 1;
}

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

DateTime? reminderTimeFor(
  Todo todo,
  DateTime now, {
  bool allowLate = false,
  Duration leadTime = const Duration(minutes: 10),
}) {
  final due = todo.dueDate;
  if (due == null || !todo.hasTime || todo.isCompleted) return null;
  if (!due.isAfter(now)) return null;

  final reminder = due.subtract(leadTime);
  if (reminder.isAfter(now)) return reminder;

  if (!allowLate) return null;

  final soon = now.add(const Duration(seconds: 5));
  return soon.isBefore(due) ? soon : null;
}

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
    final remA = reminderTimeFor(a, now, allowLate: false, leadTime: leadTime)!;
    final remB = reminderTimeFor(b, now, allowLate: false, leadTime: leadTime)!;
    return remA.compareTo(remB);
  });

  return eligible.take(limit).toList();
}

String reminderBody(Todo todo) {
  if (todo.description != null && todo.description!.trim().isNotEmpty) {
    return todo.description!.trim();
  }
  return 'Your task is due in 10 minutes.';
}
```

---

## 4. Data Layer

### 4.1. `StorageService` (`lib/data/services/storage_service.dart`)

```dart
abstract class StorageService {
  Future<List<Todo>> loadTodos();
  Future<void> saveTodos(List<Todo> todos);
  Future<bool> getHasRequestedNotificationPermission();
  Future<void> setHasRequestedNotificationPermission(bool value);
}
```

#### Defensive Persistence Implementation (`SharedPrefsStorageService`):
1. **Key Versioning**: Uses key `'todo_items_v1'`.
2. **Corrupted String Backup**:
   - If decoded JSON is not a `List` (e.g. `{}` or primitive) OR if `jsonDecode` fails, copies raw string to `'todo_items_v1_corrupt'` and returns `[]`.
   - If any individual record throws an exception during deserialization, it logs the error, drops the corrupted record, and **backs up the original raw string to `'todo_items_v1_corrupt'`** before returning the remaining valid records. This prevents data loss on subsequent saves.

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
  Future<void> cancelAllNotifications();
  Future<void> rescheduleAll(List<Todo> todos, DateTime now);
}
```

#### Timezone & Native Details (`FlutterLocalNotificationService`):
1. **Device Local Timezone**: Uses `flutter_timezone` plugin to resolve device location name (`await FlutterTimezone.getLocalTimezone()`), initializes `tz.initializeTimeZones()`, and binds via `tz.setLocalLocation(tz.getLocation(timeZoneName))`. **Safe Fallback**: If `getLocation` throws on an unusual timezone name, safely falls back to `tz.getLocation('UTC')`.
2. **Scheduling Conversion**: Converts local `DateTime` into `tz.TZDateTime.from(scheduledDate, tz.local)`.
3. **Cancel Before Schedule**: Every `scheduleNotification(id, ...)` calls `cancelNotification(id)` first to prevent duplicate notifications upon task edits.
4. **Safe Try-Catch**: Scheduling operations are wrapped in `try-catch`; failures log errors and do not crash the app or block storage saves.
5. **iOS 64-Limit & Reschedule All**:
   * `rescheduleAll` calls `cancelAllNotifications()` first to purge orphaned alerts.
   * Then schedules eligible tasks from `selectRemindersToSchedule(todos, now, limit: 64)`.

---

## 5. Platform Setup & Native Configuration

### 5.1. Dependencies (`pubspec.yaml`)
```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.5.4
  flutter_local_notifications: ^22.3.1
  timezone: ^0.11.0
  flutter_timezone: ^4.1.0
  permission_handler: ^12.0.1
  intl: ^0.20.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

### 5.2. Android Native Configuration (Kotlin DSL)
* In `android/app/build.gradle.kts`:
  ```kotlin
  android {
      compileSdk = 36
      defaultConfig {
          minSdk = 24
      }
      compileOptions {
          isCoreLibraryDesugaringEnabled = true
          sourceCompatibility = JavaVersion.VERSION_17
          targetCompatibility = JavaVersion.VERSION_17
      }
  }
  dependencies {
      coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
  }
  ```
* **Permissions & Receivers**: In `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  <uses-permission android:name="android.permission.VIBRATE"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>

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
* **Resilient Combined Queue**:
  ```dart
  Future<void> _enqueue(Future<void> Function() job) {
    _writeQueue = _writeQueue.then((_) => job()).catchError((Object e) {
      lastError = e;
    });
    return _writeQueue;
  }
  ```
  Both storage saves and notification operations run sequentially in the same queued job.
* **Initialization Flow**:
  1. Load todos from storage.
  2. Purge completed tasks older than 30 days (`createdAt` or completed threshold > 30 days).
  3. Check permission status.
  4. If `!await storageService.getHasRequestedNotificationPermission()`, call `notificationService.requestGeneralPermissions()` and set flag to true.
  5. Call `notificationService.rescheduleAll(activeTodos, clock())`.
* **Exact Alarm On-Demand**:
  * On saving a task with `hasTime == true` for the first time, invoke `notificationService.requestExactAlarmPermission()`.
* **Undo Operations**:
  * `undoComplete(int id)`: Sets `isCompleted = false`. Re-schedules notification with `allowLate: false`.
  * `undoDelete(Todo deletedTodo)`: If `deletedTodo.id` is occupied by another newly created task, assigns `nextId(_todos)` to resolve collisions, then adds back and re-schedules notification.
* **Cleanup & Timers**:
  * Exposes `setFilter(TodoFilter)`, `setQuery(String)`.
  * 60-second periodic timer + `AppLifecycleListener.onResume`.
  * `dispose()` cancels timer and lifecycle listener.

### 6.2. `HomeScreen` (`lib/ui/features/todo/views/home_screen.dart`)
* **Top Search Bar**: "Search tasks..." field with clear icon button.
* **Permission Banner**: Rendered conditionally if `_hasNotificationPermission == false`.
  * Displays: *"Notifications are disabled. You will not receive reminders."*
  * Action button *"Settings"* calls `openAppSettings()`.
* **Filter Bar**: `SegmentedButton<TodoFilter>` with 3 tabs:
  * **Today (N)**
  * **Upcoming (N)**
  * **All (N)**
  * Tab counts (N) reflect total active tasks in that tab, NOT filtered by search query.
* **Task List & Dismissible**:
  * Items wrapped in `Dismissible` with `key: ValueKey(todo.id)`.
  * **Left-to-Right (Start-to-End)**: Complete task. Green background with checkmark icon.
  * **Right-to-Left (End-to-Start)**: Delete task. Red background with trash icon.
  * Calls `ScaffoldMessenger.of(context).hideCurrentSnackBar()` before showing a new SnackBar with **Undo**.
* **Empty State**: Friendly illustration and text when no tasks match filter or query.

### 6.3. `AddTodoSheet` (`lib/ui/features/todo/views/widgets/add_todo_sheet.dart`)
* Returns `Future<TodoDraft?>`.
* Dual-purpose: Handles both **Create** and **Edit** via optional `Todo? initialTodo`.
* Form behavior:
  * `isScrollControlled: true` and `EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)`.
  * Title input, Description input.
  * Date Picker (`showDatePicker`). When date is selected, `dueDate` is normalized to `00:00:00`.
  * Time Switch/Picker (`showTimePicker`). Enabled only when a date is selected.
  * Clear Date button to reset task to dateless.
  * **Validation Rule**: Prevents saving past date/time **ONLY IF** date/time was modified compared to `initialTodo`.

---

## 7. Testing Strategy

1. **Unit Test Pure Logic (`test/domain/logic/todo_logic_test.dart`)**:
   * `reminderTimeFor` edge cases: boundary at `due == now`, `now + 5s >= due`, custom `leadTime`.
   * `isOverdue`: date-only calendar comparison (`dueDay.isBefore(today)`).
   * `selectRemindersToSchedule`: verifies sorting and 64 limit.
   * `visibleTodos`: Today, Upcoming, All boundaries (00:00:00 tomorrow, 23:59:59).
   * `nextId`: empty and sparse lists.
2. **Unit Test Models & Persistence (`test/domain/models/todo_test.dart`, `test/data/services/storage_service_test.dart`)**:
   * `Todo.fromJson` throws `FormatException` on invalid ID or empty title.
   * Corrupt JSON object `{}` backed up to `todo_items_v1_corrupt` and returns `[]`.
   * Corrupt single record skipped while preserving remaining records and backing up raw string.
3. **Unit Test ViewModel (`test/ui/features/todo/todo_view_model_test.dart`)**:
   * Resilient queue: error in one job does not block subsequent jobs.
   * Initial launch requests permission only once.
   * Exact alarm requested on first timed task.
   * Undo delete with ID collision reallocates ID.
   * Purges completed tasks older than 30 days on launch.
   * Fake timers using `fakeAsync`.
4. **Coverage Target**:
   * `flutter test --coverage` verifies 100% logic coverage in `lib/domain/logic/`.

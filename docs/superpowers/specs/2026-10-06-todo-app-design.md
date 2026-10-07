# Todoist-Inspired Flutter TODO App - Design Specification (v2.2)

**Architectural & Technical Design Specification**  
**Date:** 2026-10-06 (Updated)  
**Project:** `Advanced-Mobile/Todo_App`  
**Platform:** Flutter (iOS & Android) — Target SDK: Flutter 3.47.6 / Dart 3.13.5  
**UI Language:** English

---

## 1. Overview & Core Requirements

Build a production-grade, Todoist-inspired task management application on Flutter adhering to strict Clean Architecture (MVVM) and the core criteria:
1. **Create TODO with Time Option**: Support setting a due date, with an optional specific time (hour & minute).
2. **Main Page Categorization**: Filter tasks by **Today**, **Upcoming**, and **All**.
3. **Display Filtered Lists**: Accurate categorization, with badge counts per tab independent of search query.
4. **Search Functionality**: Real-time search query applied within the active filter tab with instant clear.
5. **10-Minute Prior Alert Notification**: Scheduled local notification 10 minutes prior to due time using `flutter_local_notifications` + `timezone`.
6. **Task Completion & Reopening (Non-Destructive)**:
   - Completed tasks remain visible in active filter lists, styled with a soft green tint, strikethrough, and a "Completed" pill badge, sorted at the bottom after active tasks.
   - Notification is canceled upon completion.
   - Users can swipe right (LTR) to complete or reopen tasks, or tap the circular checkbox.
7. **Task Removal & Undo**:
   - Soft-delete via swipe left (RTL) or direct delete icon button on the card.
   - Floating SnackBar with 10dp rounded corners and high-contrast Undo support.
8. **Notification Tap Navigation & Visual Highlight**:
   - Tapping a notification opens the app, clears active search queries, auto-switches to the appropriate filter tab (Today, Upcoming, or All), smoothly scrolls to the target task, and triggers a 3-second Fade/Glow + slight Scale pulse in warm amber/yellow tone before stopping completely.
9. **User Onboarding & Unified Design System**:
   - Interactive `SwipeTutorialBanner` for new users educating on swipe gestures (complete/delete) and direct delete button, dismissible with persistence in local storage.
   - Cohesive 10dp border radius design language across cards, filter tabs, SearchBar, SnackBar, and tutorial banner.
   - Instant zero-animation filter tab switching with 8dp gap.

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
│       └── todo_logic.dart         # Pure functions: isOverdue, isDueTodayOrOverdue, isDueUpcoming, reminderTimeFor, visibleTodos, nextId, selectRemindersToSchedule, reminderBody
├── data/
│   └── services/
│       ├── storage_service.dart    # Abstract interface & SharedPrefsStorageService (record-by-record parsing, corrupt backup, tutorial persistence)
│       └── notification_service.dart # Abstract interface & FlutterLocalNotificationService (timezone, exact alarm fallback, cancelAll before reschedule, onNotificationTapped callback)
├── ui/
│   ├── core/
│   │   ├── theme/
│   │   │   └── app_theme.dart      # Todoist Red (#E44332), Overdue (#D1453B), Complete (#2E7D32), Reminder (#F59E0B), 10dp unified radius, Material 3, Dark mode
│   │   └── widgets/
│   │       ├── empty_state.dart    # Clean empty state widget
│   │       ├── permission_banner.dart # Warning banner with onOpenSettings callback
│   │       └── swipe_tutorial_banner.dart # Dismissible onboarding banner for swipe gestures and delete button
│   └── features/
│       └── todo/
│           ├── view_models/
│           │   └── todo_view_model.dart # ChangeNotifier: resilient write queue, clock injection, notification tap handling, 3s highlight timer, swipe tutorial state
│           └── views/
│               ├── home_screen.dart     # SearchBar (10dp), 3 custom filter buttons (8dp gap, 10dp radius, instant switch), auto-scroll, floating SnackBar
│               └── widgets/
│                   ├── todo_item_tile.dart   # 10dp card, 3-tone semantic styling (Green/Red/Amber), 3s Fade/Glow+Scale pulse, Dismissible (LTR/RTL), direct delete button
│                   └── add_todo_sheet.dart   # Shared create/edit sheet returning TodoDraft, isScrollControlled, viewInsets padding
└── main.dart                       # Local timezone initialization, DI, notification tap wiring, app entry point
```

### Core Design Rules
* **Zero Extra State Package**: Pure `ChangeNotifier` + `ListenableBuilder` from Flutter SDK.
* **Abstract Interfaces for Testability**: Both `StorageService` and `NotificationService` have abstract interfaces to enable mocking in unit/integration tests without hardware or plugin bindings.
* **Storage-First & Resilient Combined Queue**: In-memory state and storage are updated first; notifications are scheduled secondary. A sequential queue (`_enqueue`) with `.catchError` guarantees operations never interleave or permanently halt on failure.
* **Consistent 10dp Design Language**: Unified border radius (10.0 dp) across all interactive cards, search inputs, tab selectors, and floating snackbars.
* **Hardware-Accelerated Scoped Animations**: Targeted animations (e.g., 3-second reminder highlight) use localized `SingleTickerProviderStateMixin` with auto-reset to avoid unnecessary re-renders or ticker leaks.

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

bool isDueTodayOrOverdue(DateTime due, DateTime now) {
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
  return due.isBefore(startOfTomorrow);
}

bool isDueUpcoming(DateTime due, DateTime now) {
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
  return !due.isBefore(startOfTomorrow);
}

List<Todo> visibleTodos(
  List<Todo> todos,
  TodoFilter filter,
  String query,
  DateTime now,
) {
  final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);

  // Both active and completed tasks remain visible
  Iterable<Todo> list = todos;

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
    // 1. Active (incomplete) tasks always precede completed tasks
    if (a.isCompleted != b.isCompleted) {
      return a.isCompleted ? 1 : -1;
    }

    // 2. Tasks with due dates precede dateless tasks
    if (a.dueDate != null && b.dueDate != null) {
      final cmp = a.dueDate!.compareTo(b.dueDate!);
      if (cmp != 0) return cmp;
    } else if (a.dueDate != null) {
      return -1;
    } else if (b.dueDate != null) {
      return 1;
    }

    // 3. Tie-break by creation timestamp, then ID
    final createdCmp = a.createdAt.compareTo(b.createdAt);
    if (createdCmp != 0) return createdCmp;
    return a.id.compareTo(b.id);
  });

  return sortedList;
}

int countForFilter(List<Todo> todos, TodoFilter filter, DateTime now) {
  final activeTodos = todos.where((t) => !t.isCompleted).toList();
  return visibleTodos(activeTodos, filter, '', now).length;
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
  Future<bool> getHasSeenSwipeTutorial();
  Future<void> setHasSeenSwipeTutorial(bool value);
}
```

#### Defensive Persistence Implementation (`SharedPrefsStorageService`):
1. **Key Versioning**: Uses keys `'todo_items_v1'`, `'has_requested_notification_permission_v1'`, and `'has_seen_swipe_tutorial_v1'`.
2. **Corrupted String Backup**:
   - If decoded JSON is not a `List` (e.g. `{}` or primitive) OR if `jsonDecode` fails, copies raw string to `'todo_items_v1_corrupt'` and returns `[]`.
   - If any individual record throws an exception during deserialization, it logs the error, drops the corrupted record, and **backs up the original raw string to `'todo_items_v1_corrupt'`** before returning the remaining valid records. This prevents data loss on subsequent saves.
3. **Tutorial Persistence**: Remembers whether the user has dismissed the swipe tutorial banner across app launches.

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
  void Function(int todoId)? onNotificationTapped;
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
6. **Notification Tap Callback (`onNotificationTapped`)**:
   * Initialized with `onDidReceiveNotificationResponse: (response) { ... }`.
   * Parses `response.payload` (containing task ID string) into integer ID and invokes `onNotificationTapped?.call(todoId)`. Also inspects `getNotificationAppLaunchDetails()` for cold-start launches.

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
  * `List<Todo> _todos`: Internal task state.
  * `TodoFilter _currentFilter = TodoFilter.today`: Current active filter tab.
  * `String _searchQuery = ''`: Real-time search query.
  * `bool _hasNotificationPermission = true`: Current permission status.
  * `bool _isLoading = true`: Initial loading indicator flag.
  * `bool _hasSeenSwipeTutorial = false`: Persisted flag tracking whether user has dismissed the swipe gesture tutorial banner.
  * `int? _highlightedTaskId`: ID of task temporarily highlighted via notification tap.
  * `Timer? _highlightTimer`: 3-second timer managing highlight expiration.
* **Getters**:
  * `List<Todo> get allTasks`: Unmodifiable view of all tasks.
  * `List<Todo> get visibleTasks`: Visible tasks filtered by `_currentFilter` and `_searchQuery`, with active tasks sorted first followed by completed tasks.
  * `int get todayTasksCount`, `int get upcomingTasksCount`, `int get allTasksCount`: Pre-computed counts of active (incomplete) tasks per tab.
  * `bool get showSwipeTutorial`: `!_hasSeenSwipeTutorial`.
  * `int? get highlightedTaskId`: Currently highlighted task ID.
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
  3. Load `hasSeenSwipeTutorial` from storage.
  4. Check permission status.
  5. If `!await storageService.getHasRequestedNotificationPermission()`, call `notificationService.requestGeneralPermissions()` and set flag to true.
  6. Call `notificationService.rescheduleAll(activeTodos, clock())`.
* **Notification Tap Navigation & Visual Highlight**:
  ```dart
  void handleNotificationTap(int id) {
    final index = _todos.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final targetTask = _todos[index];
    _searchQuery = ''; // Clear search to ensure task is visible

    // Auto-switch filter tab based on task dueDate
    if (targetTask.dueDate != null) {
      if (isDueTodayOrOverdue(targetTask.dueDate!, _clock())) {
        _currentFilter = TodoFilter.today;
      } else if (isDueUpcoming(targetTask.dueDate!, _clock())) {
        _currentFilter = TodoFilter.upcoming;
      } else {
        _currentFilter = TodoFilter.all;
      }
    } else {
      _currentFilter = TodoFilter.all;
    }

    _highlightedTaskId = id;
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(seconds: 3), () {
      _highlightedTaskId = null;
      notifyListeners();
    });
    notifyListeners();
  }
  ```
* **Exact Alarm On-Demand**:
  * On saving a task with `hasTime == true` for the first time, invoke `notificationService.requestExactAlarmPermission()`.
* **Undo & Task Mutations**:
  * `completeTodo(int id)`: Sets `isCompleted = true`, saves to storage, cancels notification.
  * `undoComplete(int id)`: Sets `isCompleted = false`, saves to storage, re-schedules notification with `allowLate: false`.
  * `toggleTodo(int id)`: Toggles between `completeTodo` and `undoComplete`.
  * `deleteTodo(int id)`: Removes task, saves to storage, cancels notification.
  * `undoDelete(Todo deletedTodo)`: If `deletedTodo.id` is occupied by another newly created task, assigns `nextId(_todos)` to resolve collisions, then adds back and re-schedules notification.
  * `dismissSwipeTutorial()`: Sets `_hasSeenSwipeTutorial = true`, saves to storage, notifies listeners.
* **Cleanup & Timers**:
  * Exposes `setFilter(TodoFilter)`, `setQuery(String)`.
  * 60-second periodic timer + `AppLifecycleListener.onResume`.
  * `dispose()` cancels `_tickerTimer`, `_highlightTimer`, and `_lifecycleListener`.

---

### 6.2. `HomeScreen` (`lib/ui/features/todo/views/home_screen.dart`)
* **Top Search Bar**:
  * 10dp rounded corners (`RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0))`).
  * Flat elevation (0.0) with subtle border (`#E5E7EB` light / `#383838` dark).
  * Color matches cards (`Colors.white` light / `#242424` dark).
  * Real-time query filtering with clear button (`Icons.clear`).
* **Permission Banner**:
  * Conditionally rendered when `_hasNotificationPermission == false`.
  * Displays: *"Notifications are disabled. You will not receive reminders."*
  * Action button *"Settings"* invokes `openAppSettings()`.
* **Custom Filter Bar (`Today`, `Upcoming`, `All`)**:
  * Custom 3-button `Row` layout with an **8dp gap** (`SizedBox(width: 8.0)`) between buttons.
  * Each button features a **10dp rounded border radius** (`BorderRadius.circular(10.0)`).
  * **Instantaneous tab switching**: Zero-duration layout transition (avoids `AnimatedContainer` animation lag) for instant responsiveness.
  * Active state: Filled Todoist primary red (`#E44332`) with bold white text.
  * Inactive state: Neutral surface (`#F3F4F6` light / `#2A2A2A` dark) with muted text.
  * Tab counts (N) reflect total active tasks in that tab, independent of search queries.
* **Swipe Tutorial Banner (`SwipeTutorialBanner`)**:
  * Displayed directly above the task list when `viewModel.showSwipeTutorial == true`.
  * Dismissible via "Got it" button or "X" close icon, persisting to storage.
* **Task List Layout**:
  * `ListView.separated` with **10.0 dp vertical spacing** between task cards (`separatorBuilder: (_, __) => SizedBox(height: 10.0)`).
  * Outer list padding: `EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 88.0)`.
  * **Auto-Scroll**: List automatically scrolls (`_scrollController.animateTo`) to the highlighted task when launched via notification tap.
* **Floating SnackBar & Undo**:
  * Configured with `behavior: SnackBarBehavior.floating` and **10dp rounded corners**.
  * Consistent high-contrast slate surfaces: `#202020` in Light mode, `#2C2C2C` in Dark mode.
  * Vibrant accent color for Undo action button: `#FF6B6B` (Light) / `#FF8A80` (Dark).
  * Invokes `ScaffoldMessenger.of(context).hideCurrentSnackBar()` before displaying to prevent queuing delays.

---

### 6.3. `TodoItemTile` (`lib/ui/features/todo/views/widgets/todo_item_tile.dart`)
* **Card Design & Rounded Corners**:
  * Unified **10dp border radius** (`BorderRadius.circular(10.0)`) on card body and Dismissible background containers.
  * Padding: `EdgeInsets.all(14.0)` with clean typographic hierarchy.
* **3-Tone Semantic Status System**:
  1. **Completed Tasks**:
     * Retained in the list, sorted at the bottom.
     * Soft green background: Light `#E8F5E9`, Dark `#142918`.
     * Green border: Light `#A5D6A7`, Dark `#2E7D32` with alpha (width 1.2dp).
     * Green strikethrough title text (`TextDecoration.lineThrough`).
     * Green "Completed" pill badge with `Icons.check_circle_outline`.
  2. **Overdue Tasks**:
     * Soft red background: Light `#FFF0EF`, Dark `#2E1515`.
     * Red border: Light `#EF9A9A`, Dark `#EF5350` with alpha (width 1.2dp).
     * Red title and description text.
     * Red "Overdue" pill badge with `Icons.error_outline`.
  3. **Normal Active Tasks**:
     * Clean surface: Light `Colors.white`, Dark `#242424`.
     * Neutral border: Light `#E5E7EB`, Dark `#383838` (width 1.0dp).
     * Blue-grey due date pill badge.
* **3-Second Notification Reminder Tap Highlight Animation**:
  * Controlled by dedicated `AnimationController` with duration `Duration(seconds: 3)`.
  * Self-terminating: Automatically calls `_highlightController.reset()` on `AnimationStatus.completed`, releasing tickers.
  * Triple-pulse breathing curve:
    $$\text{rawPulse} = \sin(\text{progress} \cdot 3\pi), \quad \text{pulseFactor} = (\text{rawPulse}^2) \cdot (1.0 - 0.2 \cdot \text{progress})$$
  * Multi-attribute visual effects:
    1. **Subtle Scale**: Scales smoothly from `1.0` to `1.025` (2.5% max expansion) via `Transform.scale`.
    2. **Dual-Layer Amber/Yellow Box Glow**: Dynamic `BoxShadow` pair in amber/gold (`#FFB300` Light / `#FFD54F` Dark) with animated blur radius (up to 18dp) and spread radius (up to 3.5dp).
    3. **Warm Amber/Yellow Tint**: Lerped card background (`#FFF9E6` Light / `#332914` Dark) and vibrant amber border (`#FFA000` Light / `#FFD54F` Dark, width up to 2.2dp).
    4. **"Reminded" Pill Badge**: Glowing amber badge with `Icons.notifications_active_outlined` displayed during active highlight.
  * After 3 seconds, returns smoothly and completely to base state.
* **Gestures & Controls**:
  * **Checkbox**: Custom circular button with instant tap response.
  * **Swipe Right (LTR)**: Complete or Reopen task (green/slate background).
  * **Swipe Left (RTL)**: Quick delete task (red background).
  * **Direct Delete Button**: Accessible trash icon button (`Icons.delete_outline`) directly on the card for instant deletion without swiping.
  * **Tap Card**: Opens `AddTodoSheet` to view and edit details.

---

### 6.4. `SwipeTutorialBanner` (`lib/ui/core/widgets/swipe_tutorial_banner.dart`)
* Interactive onboarding banner guiding first-time users:
  * Swipe Right: Complete or reopen tasks.
  * Swipe Left: Quick delete tasks.
  * Trash Icon: Direct deletion without swiping gestures.
* Light/Dark adaptive colors:
  * Light Mode: Background `#EFF6FF`, Border `#BFDBFE`, Title `#1E40AF`.
  * Dark Mode: Background `#1B2430`, Border `#2C3E50`, Title `#93C5FD`.
* Dismiss action: "Got it" button or "X" icon calls `onDismiss`, storing state via `StorageService`.

---

### 6.5. `AddTodoSheet` (`lib/ui/features/todo/views/widgets/add_todo_sheet.dart`)
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

### 6.6. Design System & Theming (`lib/ui/core/theme/app_theme.dart`)
* **Unified Border Radius**: 10.0 dp standardized across Cards, Filter Buttons, SearchBar, SnackBar, and Dialogs.
* **Color Tokens**:
  * Primary: `#E44332` (Todoist Red).
  * Overdue: `#D1453B` (Alert Red).
  * Complete: `#2E7D32` (Forest Green).
  * Reminder: `#F59E0B` (Amber / Yellow).
* **Theme Components**:
  * `SearchBarThemeData`: 0.0 elevation, 10dp radius, theme-matched surface colors.
  * `SnackBarThemeData`: `SnackBarBehavior.floating`, 10dp radius, high-contrast dark slate (`#202020` / `#2C2C2C`).

---

## 7. Testing Strategy

The test suite contains **71 automated tests** verifying every layer:

1. **Unit Test Pure Logic (`test/domain/logic/todo_logic_test.dart`)**:
   * `reminderTimeFor` edge cases: boundary at `due == now`, `now + 5s >= due`, custom `leadTime`.
   * `isOverdue`: date-only calendar comparison (`dueDay.isBefore(today)`), time-specific comparison (`due.isBefore(now)`).
   * `isDueTodayOrOverdue` & `isDueUpcoming`: boundaries around midnight tomorrow.
   * `selectRemindersToSchedule`: verifies sorting by earliest reminder and iOS 64-item ceiling.
   * `visibleTodos`: verifies Today, Upcoming, and All boundaries, query matching, and keeping completed tasks sorted after active tasks.
   * `countForFilter`: verifies counting active tasks only, independent of search queries.
   * `nextId`: handles empty and sparse ID distributions.
2. **Unit Test Models & Persistence (`test/domain/models/todo_test.dart`, `test/data/services/storage_service_test.dart`)**:
   * `Todo.fromJson` throws `FormatException` on invalid ID or empty title.
   * Corrupt JSON object `{}` backed up to `todo_items_v1_corrupt` and returns `[]`.
   * Corrupt single record skipped while preserving remaining records and backing up raw string.
   * `hasSeenSwipeTutorial` persistence verified across saves and reloads.
3. **Unit Test ViewModel (`test/ui/features/todo/todo_view_model_test.dart`)**:
   * Resilient queue: error in one job does not block subsequent jobs.
   * Initial launch requests permission only once.
   * Exact alarm requested on first timed task.
   * Notification tap handling: clears search query, auto-switches filter tab, sets highlighted ID, cancels timer after 3 seconds.
   * Swipe tutorial banner dismissal: updates flag and persists to storage.
   * Toggle todo: switches between complete and undoComplete.
   * Undo delete with ID collision reallocates ID.
   * Purges completed tasks older than 30 days on launch.
   * Fake timers and lifecycle listeners verified using `fakeAsync`.
4. **Coverage Target**:
   * `flutter test --coverage` verifies 100% logic coverage in `lib/domain/logic/`.


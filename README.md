# Todo App (Todoist-Inspired Flutter Application)

A robust, production-ready Todo application built with **Flutter 3** and **Dart**, featuring a clean **MVVM Clean Architecture**, Material 3 design inspired by Todoist, local persistence with automated corruption recovery, and local scheduled push notifications.

---

## 📋 Feature & Requirements Mapping (6 Core Criteria)

This project strictly satisfies all 6 requirements defined in the specification:

| # | Requirement | Implementation Detail | Location in Code |
|---|---|---|---|
| **1** | **Create Task with Optional Due Date & Time** | Users can create tasks with title (required) and description (optional). Date picker sets date at `00:00:00`. Optional time picker enables exact scheduling (`hasTime: true`). Validation prevents selecting past times only when date/time is modified. | `AddTodoSheet` ([`lib/ui/features/todo/views/widgets/add_todo_sheet.dart`](lib/ui/features/todo/views/widgets/add_todo_sheet.dart)) |
| **2** | **Categorize on Main Page: All / Today / Upcoming** | Main screen provides 3 segmented filter tabs. **Today** includes today's tasks and uncompleted overdue tasks (Todoist standard). **Upcoming** includes tasks due tomorrow or later. **All** includes all active tasks (including date-less tasks). | `visibleTodos` ([`lib/domain/logic/todo_logic.dart`](lib/domain/logic/todo_logic.dart)) |
| **3** | **Filtered Display with Fixed Tab Counts** | Tab badges show total active tasks for that filter (`Today (N)`, `Upcoming (N)`, `All (N)`). Count badges remain constant regardless of active search queries. | `countForFilter` ([`lib/domain/logic/todo_logic.dart`](lib/domain/logic/todo_logic.dart)) & `TodoViewModel` |
| **4** | **Real-Time Search Within Active Tab** | Real-time case-insensitive keyword search against both task `title` and `description`. Searching filters only within the active tab category without mutating tab badge counts. | `visibleTodos` query filter & `HomeScreen` SearchBar |
| **5** | **10-Minute Prior Scheduled Notifications** | Automatically schedules local notifications **10 minutes prior** to due time via `flutter_local_notifications` (`^22.3.1`). Configurable via pure `reminderTimeFor` function. Anti-spam on startup (`allowLate: false`) prevents alerting tasks due soon repeatedly upon opening the app. | `FlutterLocalNotificationService` & `reminderTimeFor` |
| **6** | **Mark Task as Completed with Undo** | Tapping the circular checkbox marks task completed (soft-delete), removing it from active lists and cancelling pending notifications. Shows a 4-second SnackBar with **Undo** action to safely restore the task and reschedule its notification. RTL swipe deletes task with Undo support. | `TodoItemTile` ([`lib/ui/features/todo/views/widgets/todo_item_tile.dart`](lib/ui/features/todo/views/widgets/todo_item_tile.dart)) & `HomeScreen` |

---

## 🏛 Architecture & Design Principles

The application is structured following **Clean Architecture (MVVM)** with strict separation of concerns and zero third-party state libraries (uses Flutter's native `ChangeNotifier` and `ListenableBuilder`):

```
lib/
├── domain/                      # 100% pure Dart, zero Flutter dependencies
│   ├── models/                  # Immutable entities (Todo, TodoDraft, TodoFilter)
│   └── logic/                   # Pure business logic functions (isOverdue, reminderTimeFor, visibleTodos)
├── data/                        # Data sources and platform implementations
│   └── services/                # StorageService (SharedPrefs) & NotificationService (LocalNotifications)
├── ui/                          # Presentation layer
│   ├── core/                    # Shared theme (Todoist palette #E44332) and reusable widgets
│   └── features/todo/           # Todo feature: ViewModel, HomeScreen, ItemTile, AddTodoSheet
└── main.dart                    # Composition root and application entry point
```

### Key Architectural Highlights
- **100% Testable Domain Layer**: All business rules (`isOverdue`, `reminderTimeFor`, `visibleTodos`, `nextId`, `selectRemindersToSchedule`) are pure Dart functions with zero side effects. Tested with 100% line and branch coverage without needing Flutter bindings.
- **Resilient Storage with Corruption Recovery**: `SharedPrefsStorageService` parses records individually. If corrupted records or invalid JSON formats are encountered, valid records are preserved, and the raw corrupted payload is backed up to `todo_items_v1_corrupt` before saving.
- **Resilient Sequential Write Queue**: `TodoViewModel` processes all persistent writes and notification scheduling through a resilient serial queue (`_enqueue`) with `.catchError()` handlers to prevent unhandled storage errors from stalling future actions.
- **Stable ID Allocation & Undo Conflict Resolution**: If a user deletes a task, adds a new task (which reuses the incremented ID), and then taps **Undo**, `undoDelete` detects ID collisions and allocates a fresh ID via `nextId`.

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `>= 3.47.0` (Dart SDK `>= 3.13.0`)
- **Android**: Android SDK `>= 36` (compileSdk), minSdk `>= 24`, Java 17
- **iOS**: iOS `>= 14.0`, Xcode `>= 15`

### Installation
```bash
# Clone the repository
cd Todo_App

# Install dependencies
flutter pub get
```

### Running the App
```bash
# Run on connected device or simulator
flutter run
```

---

## 🧪 Testing & Verification

The project includes **56 unit and widget tests** covering all layers of the application.

```bash
# Run the entire test suite
flutter test

# Run tests with code coverage report
flutter test --coverage
```

### Test Coverage Highlights
- `test/domain/logic/todo_logic_test.dart`: 20 unit tests covering edge cases (00:00 vs 23:59 boundaries, overdue rules, startup reschedule anti-spam, 64 notification limit capping).
- `test/domain/models/todo_test.dart`: 12 unit tests verifying strict JSON schema validation, fallback logic, and entity immutability.
- `test/data/services/storage_service_test.dart`: 6 tests verifying record-by-record corruption survival and raw backup recovery.
- `test/data/services/notification_service_test.dart`: 3 tests confirming cancel-before-schedule and cancel-all-before-reschedule contracts.
- `test/ui/features/todo/todo_view_model_test.dart`: 7 tests verifying MVVM coordination, 30-day purge, permission requests, and exact alarm flows.
- `test/ui/widgets/`: 5 widget tests for atomic UI components (`TodoItemTile`, `AddTodoSheet`).
- `test/ui/features/todo/home_screen_test.dart`: 3 integration widget tests verifying tab switching, real-time search, and complete/undo SnackBar flows.

---

## 📱 Platform Configuration & Constraints

### Android Configuration
- **Compile SDK**: 36
- **Min SDK**: 24
- **Java Version**: 17
- **Desugaring**: Enabled (`isCoreLibraryDesugaringEnabled = true`) with `com.android.tools:desugar_jdk_libs:2.1.4` to support `java.time` APIs required by `flutter_local_notifications`.
- **Permissions**:
  - `POST_NOTIFICATIONS` (Android 13+ runtime permission).
  - `SCHEDULE_EXACT_ALARM` (Exact alarm permission, requested on demand when a task with a time is first saved).
  - `RECEIVE_BOOT_COMPLETED` (Persists scheduled alarms across device restarts).

### iOS Configuration
- Configured with `UNUserNotificationCenter` delegate in `AppDelegate.swift`.
- Supports alert, badge, and sound notification presentations in foreground and background.

### Known Platform Constraints
1. **iOS 64 Scheduled Notification Limit**: iOS limits pending local notifications to a maximum of 64 per app. The app automatically sorts pending reminders by time proximity and schedules the nearest 64 reminders via `selectRemindersToSchedule`.
2. **Android Doze Mode & Battery Optimization**: If a user denies exact alarm permissions or enables aggressive battery optimization, Android may deliver inexact alarms within a few minutes of the target time. A `PermissionBanner` is provided on the Home Screen to guide users to settings.

---

## 🔍 Manual QA Protocol Checklist

To verify real-world behavior on physical Android and iOS devices:

1. **10-Minute Prior Alert Verification**:
   - Create a task with due time set to **12 minutes from now**.
   - Terminate/kill the app from the app switcher.
   - Wait 2 minutes: Verify the system push notification arrives exactly **10 minutes prior** to the due time.
2. **Permission Denial Handling**:
   - Deny notification permissions in OS Settings: Verify the yellow `PermissionBanner` appears on the Home Screen.
   - Tap "Settings" button: Verify device application settings opens immediately.
3. **No Duplicate Alert on Edit**:
   - Create a scheduled task, then edit its due time: Verify the previous alert is cancelled and only one notification fires at the new time.
4. **Cancellation on Complete / Delete**:
   - Mark a task as completed or delete it: Verify the pending notification is cancelled immediately.
5. **Reboot Persistence (Android)**:
   - Schedule a task for the afternoon and restart the device: Verify alarms remain registered via the boot receiver after reboot.

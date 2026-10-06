import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:todo_app/domain/logic/todo_logic.dart';
import 'package:todo_app/domain/models/todo.dart';

/// Giao diện trừu tượng cho dịch vụ thông báo nhắc nhở cục bộ.
/// Cho phép ViewModel tương tác mà không bị phụ thuộc vào Flutter platform channels,
/// đồng thời giúp các bài kiểm thử unit test có thể mock/fake 100%.
abstract class NotificationService {
  /// Khởi tạo plugin thông báo và cơ sở dữ liệu múi giờ timezone.
  Future<void> initialize();

  /// Kiểm tra trạng thái cấp quyền thông báo hiện tại của người dùng.
  Future<bool> checkPermissionStatus();

  /// Yêu cầu quyền thông báo cơ bản (POST_NOTIFICATIONS trên Android 13+, alert trên iOS).
  Future<bool> requestGeneralPermissions();

  /// Yêu cầu quyền đặt lịch báo thức chính xác (SCHEDULE_EXACT_ALARM).
  Future<bool> requestExactAlarmPermission();

  /// Đặt lịch thông báo cho một công việc cụ thể.
  /// Bắt buộc phải hủy lịch cũ của [id] này trước khi đặt lịch mới.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  });

  /// Hủy thông báo của task có ID tương ứng.
  Future<void> cancelNotification(int id);

  /// Hủy toàn bộ thông báo đang chờ để dọn dẹp các thông báo mồ côi.
  Future<void> cancelAllNotifications();

  /// Đặt lại lịch cho danh sách task active khi mở app (tối đa 64 task gần nhất).
  Future<void> rescheduleAll(List<Todo> todos, DateTime now);

  /// Callback khi người dùng chạm vào thông báo trên thanh trạng thái hoặc màn hình khóa
  void Function(int todoId)? onNotificationTapped;
}

/// Triển khai thực tế của [NotificationService] sử dụng [flutter_local_notifications]
/// kết hợp với [timezone] và [flutter_timezone].
class FlutterLocalNotificationService implements NotificationService {
  static const String _channelId = 'todo_channel';
  static const String _channelName = 'Todo Reminders';
  static const String _channelDescription =
      'Notifications alerted 10 minutes before a task is due';

  final FlutterLocalNotificationsPlugin _plugin;
  final Future<String> Function() _timezoneProvider;
  bool _isInitialized = false;

  @override
  void Function(int todoId)? onNotificationTapped;

  FlutterLocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    Future<String> Function()? timezoneProvider,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _timezoneProvider =
            timezoneProvider ?? FlutterTimezone.getLocalTimezone;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Khởi tạo cơ sở dữ liệu múi giờ
    tz_data.initializeTimeZones();
    try {
      final tzName = await _timezoneProvider();
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      // Safe fallback: nếu thiết bị trả về tên múi giờ lạ không nhận diện được,
      // rơi về UTC để tránh crash app lúc khởi động
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 2. Cấu hình icon thông báo trên Android (dùng icon launcher mặc định)
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. Cấu hình quyền iOS lúc khởi tạo (chưa yêu cầu ngay, để ViewModel điều khiển)
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null) {
          final id = int.tryParse(payload);
          if (id != null) {
            onNotificationTapped?.call(id);
          }
        }
      },
    );

    // Kiểm tra nếu ứng dụng được mở lên do người dùng chạm vào thông báo từ trạng thái đóng hoàn toàn (Cold Start)
    try {
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;
        if (payload != null) {
          final id = int.tryParse(payload);
          if (id != null) {
            Future.microtask(() => onNotificationTapped?.call(id));
          }
        }
      }
    } catch (_) {
      // Bỏ qua lỗi nếu nền tảng không hỗ trợ truy xuất launch details
    }

    _isInitialized = true;
  }

  @override
  Future<bool> checkPermissionStatus() async {
    // 1. Kiểm tra trên Android
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return (await android.areNotificationsEnabled()) ?? false;
    }

    // 2. Kiểm tra trên iOS
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final permissions = await ios.checkPermissions();
      return permissions?.isEnabled ?? false;
    }

    return true;
  }

  @override
  Future<bool> requestGeneralPermissions() async {
    // 1. Android: xin quyền POST_NOTIFICATIONS (Android 13+)
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return (await android.requestNotificationsPermission()) ?? false;
    }

    // 2. iOS: xin quyền alert, badge, sound
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return (await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          )) ??
          false;
    }

    return true;
  }

  @override
  Future<bool> requestExactAlarmPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return (await android.requestExactAlarmsPermission()) ?? false;
    }
    return true;
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      // Luôn hủy thông báo cũ trước để tránh trùng lặp khi người dùng sửa giờ
      await cancelNotification(id);

      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tzScheduledDate,
        notificationDetails: details,
        payload: id.toString(), // Truyền ID làm payload để nhận diện task khi người dùng bấm vào thông báo
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (_) {
      // Safe try-catch: Nếu hệ điều hành từ chối exact alarm hoặc lỗi plugin,
      // ghi nhận và không làm sập ứng dụng, không cản trở việc lưu dữ liệu
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  @override
  Future<void> cancelAllNotifications() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  @override
  Future<void> rescheduleAll(List<Todo> todos, DateTime now) async {
    // 1. Hủy toàn bộ thông báo đang chờ để dọn dẹp các thông báo mồ côi
    await cancelAllNotifications();

    // 2. Lọc và chọn tối đa 64 task gần nhất theo giới hạn của iOS
    final toSchedule = selectRemindersToSchedule(todos, now, limit: 64);

    // 3. Đặt lịch lại cho từng task
    for (final todo in toSchedule) {
      final reminder = reminderTimeFor(todo, now, allowLate: false);
      if (reminder != null) {
        await scheduleNotification(
          id: todo.id,
          title: todo.title,
          body: reminderBody(todo),
          scheduledDate: reminder,
        );
      }
    }
  }
}

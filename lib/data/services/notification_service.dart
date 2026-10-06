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
}

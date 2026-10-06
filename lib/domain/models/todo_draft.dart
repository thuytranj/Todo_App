/// Đối tượng bản nháp (Draft) do [AddTodoSheet] trả về khi người dùng tạo hoặc sửa task.
///
/// Lớp này chứa dữ liệu người dùng nhập từ giao diện nhưng chưa có [id] và [createdAt]
/// (những thông tin hệ thống này sẽ do ViewModel cấp phát khi lưu vào cơ sở dữ liệu).
class TodoDraft {
  /// Tiêu đề công việc (không được rỗng).
  final String title;

  /// Ghi chú / mô tả chi tiết của công việc (tùy chọn).
  final String? description;

  /// Hạn chót công việc (null nếu người dùng không chọn ngày).
  /// Nếu [hasTime] là false, giá trị này sẽ được chuẩn hóa về 00:00:00 của ngày đó.
  final DateTime? dueDate;

  /// Đánh dấu task có giờ cụ thể hay không:
  /// - `false`: Chỉ có ngày, không kích hoạt đặt lịch thông báo.
  /// - `true`: Có giờ và phút cụ thể, sẽ kích hoạt đặt lịch thông báo trước hạn 10 phút.
  final bool hasTime;

  const TodoDraft({
    required this.title,
    this.description,
    this.dueDate,
    this.hasTime = false,
  }) : assert(
          hasTime ? dueDate != null : true,
          'hasTime=true bắt buộc phải có dueDate hợp lệ',
        );
}

/// Thực thể công việc Todo cốt lõi của ứng dụng.
///
/// Lớp này là bất biến (immutable) và chịu trách nhiệm lưu trữ thông tin công việc,
/// thực hiện chuyển đổi JSON an toàn và tạo bản sao trạng thái qua [copyWith].
class Todo {
  /// Mã định danh số nguyên dương duy nhất (32-bit positive int),
  /// được dùng chung làm ID thông báo cho [flutter_local_notifications].
  final int id;

  /// Tiêu đề công việc (bắt buộc, không được để trống).
  final String title;

  /// Mô tả / ghi chú bổ sung cho công việc (tùy chọn).
  final String? description;

  /// Hạn chót của công việc (null nếu không có hạn).
  /// Nếu [hasTime] là false, giá trị này được chuẩn hóa về 00:00:00 của ngày được chọn.
  final DateTime? dueDate;

  /// Xác định công việc có cài đặt giờ phút cụ thể hay không:
  /// - `false`: Chỉ có ngày, không lên lịch thông báo.
  /// - `true`: Có giờ và phút cụ thể, kích hoạt lên lịch nhắc trước 10 phút.
  final bool hasTime;

  /// Trạng thái hoàn thành của công việc:
  /// - `true`: Công việc đã hoàn thành (soft-delete, ẩn khỏi danh sách active và hủy lịch nhắc).
  /// - `false`: Công việc đang chờ thực hiện.
  final bool isCompleted;

  /// Thời điểm công việc được tạo ra, dùng để sắp xếp ổn định (deterministic tie-breaking sort)
  /// và dọn dẹp các task hoàn thành sau 30 ngày.
  final DateTime createdAt;

  const Todo({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.hasTime = false,
    this.isCompleted = false,
    required this.createdAt,
  }) : assert(
          hasTime ? dueDate != null : true,
          'hasTime=true bắt buộc phải có dueDate hợp lệ',
        );

  /// Tạo bản sao của Todo với các thuộc tính được cập nhật.
  /// Hỗ trợ [clearDueDate] để xóa hạn chót về null (đồng thời đưa [hasTime] về false)
  /// và [clearDescription] để xóa mô tả về null.
  Todo copyWith({
    int? id,
    String? title,
    String? description,
    bool clearDescription = false,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? hasTime,
    bool? isCompleted,
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

  /// Chuyển đổi Todo thành Map để lưu trữ SharedPreferences dưới dạng JSON.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dueDate': dueDate?.toIso8601String(),
        'hasTime': hasTime,
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Khởi tạo Todo từ Map JSON với cơ chế xác thực và phục hồi lỗi an toàn:
  /// - Ném [FormatException] nếu `id` không hợp lệ (null, không phải số nguyên dương, hoặc <= 0).
  /// - Ném [FormatException] nếu `title` bị rỗng hoặc chỉ có khoảng trắng.
  /// - Tự động ép `hasTime = false` nếu `dueDate` là null.
  /// - Tự động rơi về epoch (`0`) nếu `createdAt` bị lỗi định dạng.
  factory Todo.fromJson(Map<String, dynamic> json) {
    // 1. Kiểm tra ID: bắt buộc phải là số nguyên > 0
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
    if (id == null || id <= 0) {
      throw const FormatException('Invalid or missing todo id');
    }

    // 2. Kiểm tra Title: bắt buộc không được rỗng
    final title = json['title']?.toString().trim() ?? '';
    if (title.isEmpty) {
      throw const FormatException('Invalid or empty todo title');
    }

    // 3. Parse các trường tùy chọn và ngày giờ an toàn
    final description = json['description']?.toString();
    final dueDate = json['dueDate'] != null
        ? DateTime.tryParse(json['dueDate'].toString())
        : null;
    final rawHasTime = json['hasTime'] == true;
    final isCompleted = json['isCompleted'] == true;

    // 4. Parse createdAt có fallback xác định (không dùng DateTime.now() để đảm bảo tính tất định)
    final createdAt = json['createdAt'] != null
        ? (DateTime.tryParse(json['createdAt'].toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0))
        : DateTime.fromMillisecondsSinceEpoch(0);

    return Todo(
      id: id,
      title: title,
      description: description,
      dueDate: dueDate,
      // Đảm bảo bất biến: hasTime chỉ có thể là true nếu dueDate tồn tại
      hasTime: rawHasTime && dueDate != null,
      isCompleted: isCompleted,
      createdAt: createdAt,
    );
  }
}

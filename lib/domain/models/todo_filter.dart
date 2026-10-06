/// Enum biểu diễn các bộ lọc chính của ứng dụng Todo.
/// - [all]: Hiển thị toàn bộ công việc chưa hoàn thành (bao gồm cả task không có deadline).
/// - [today]: Hiển thị các công việc có deadline trong ngày hôm nay hoặc đã quá hạn từ trước.
/// - [upcoming]: Hiển thị các công việc có deadline bắt đầu từ ngày mai trở đi.
enum TodoFilter {
  all,
  today,
  upcoming,
}

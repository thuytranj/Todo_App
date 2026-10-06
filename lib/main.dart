import 'package:flutter/material.dart';
import 'package:todo_app/data/services/notification_service.dart';
import 'package:todo_app/data/services/storage_service.dart';
import 'package:todo_app/ui/core/theme/app_theme.dart';
import 'package:todo_app/ui/features/todo/view_models/todo_view_model.dart';
import 'package:todo_app/ui/features/todo/views/home_screen.dart';

/// Điểm khởi chạy chính của ứng dụng Todo App:
/// 1. Đảm bảo Flutter framework binding đã sẵn sàng trước khi tương tác với platform channels.
/// 2. Khởi tạo các dịch vụ tầng Data: [SharedPrefsStorageService] và [FlutterLocalNotificationService].
/// 3. Khởi tạo [TodoViewModel] và nạp dữ liệu ban đầu ([initialize]).
/// 4. Chạy ứng dụng [MaterialApp] với giao diện chuẩn Material 3 ([AppTheme.lightTheme] và [AppTheme.darkTheme]).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = SharedPrefsStorageService();
  final notificationService = FlutterLocalNotificationService();

  final viewModel = TodoViewModel(
    storageService: storageService,
    notificationService: notificationService,
  );

  // Nạp dữ liệu và kiểm tra quyền thông báo khi mở ứng dụng
  await viewModel.initialize();

  runApp(TodoApp(viewModel: viewModel));
}

/// Widget gốc cấu hình giao diện và định tuyến của ứng dụng
class TodoApp extends StatelessWidget {
  final TodoViewModel viewModel;

  const TodoApp({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: HomeScreen(viewModel: viewModel),
    );
  }
}

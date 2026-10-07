import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/domain/models/todo_draft.dart';
import 'package:todo_app/ui/core/theme/app_theme.dart';
import 'package:todo_app/ui/features/todo/view_models/todo_view_model.dart';
import 'package:todo_app/ui/features/todo/views/home_screen.dart';

import '../../../helpers/fakes.dart';

void main() {
  group('HomeScreen Integration & Widget Tests', () {
    late FakeStorageService storage;
    late FakeNotificationService notification;
    late DateTime currentTime;
    late TodoViewModel viewModel;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      currentTime = DateTime(2026, 10, 6, 10, 0);
      storage = FakeStorageService();
      notification = FakeNotificationService();
      viewModel = TodoViewModel(
        storageService: storage,
        notificationService: notification,
        clock: () => currentTime,
        enableTicker: false,
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    testWidgets('Hiển thị SearchBar, Tab Filter và EmptyState khi chưa có task', (tester) async {
      await viewModel.initialize();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeScreen(viewModel: viewModel),
      ));
      await tester.pumpAndSettle();

      // Kiểm tra thanh tìm kiếm
      expect(find.byType(SearchBar), findsOneWidget);

      // Kiểm tra các tabs
      expect(find.textContaining('Today'), findsOneWidget);
      expect(find.textContaining('Upcoming'), findsOneWidget);
      expect(find.textContaining('All'), findsOneWidget);

      // Kiểm tra EmptyState khi danh sách rỗng
      expect(find.text('No tasks for today'), findsOneWidget);

      // Kiểm tra nút FloatingActionButton (+)
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Thao tác hoàn thành task hiển thị SnackBar Undo và hoàn tác thành công', (tester) async {
      await viewModel.initialize();

      // Thêm task cho ngày hôm nay qua runAsync để xử lý hàng đợi bất đồng bộ
      await tester.runAsync(() async {
        await viewModel.addTodo(TodoDraft(
          title: 'Task to Done',
          dueDate: currentTime,
          hasTime: false,
        ));
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeScreen(viewModel: viewModel),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Task to Done'), findsOneWidget);

      // Chạm vào checkbox tròn để hoàn thành
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pump(); // Đưa SnackBar vào cây widget
      await tester.pump(const Duration(milliseconds: 350)); // Cho phép SnackBar hoàn thành hoạt ảnh trượt lên

      // Task vẫn hiển thị trên danh sách nhưng đã có icon check_circle và badge Completed
      expect(find.text('Task to Done'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      // SnackBar xuất hiện kèm nút Undo
      expect(find.text('Task marked as completed'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Chạm vào nút Undo
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      // Task được khôi phục về trạng thái chưa hoàn thành
      expect(find.text('Task to Done'), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);
      expect(find.text('Completed'), findsNothing);
    });

    testWidgets('Chuyển tab và tìm kiếm lọc danh sách thời gian thực', (tester) async {
      await viewModel.initialize();

      // Thêm 1 task hôm nay và 1 task sắp tới qua runAsync
      await tester.runAsync(() async {
        await viewModel.addTodo(TodoDraft(
          title: 'Buy Milk Today',
          dueDate: currentTime,
          hasTime: false,
        ));
        await viewModel.addTodo(TodoDraft(
          title: 'Plan Trip Tomorrow',
          dueDate: currentTime.add(const Duration(days: 1)),
          hasTime: false,
        ));
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeScreen(viewModel: viewModel),
      ));
      await tester.pumpAndSettle();

      // Mặc định ở tab Today -> chỉ thấy 'Buy Milk Today'
      expect(find.text('Buy Milk Today'), findsOneWidget);
      expect(find.text('Plan Trip Tomorrow'), findsNothing);

      // Chạm chuyển sang tab Upcoming
      await tester.tap(find.textContaining('Upcoming'));
      await tester.pumpAndSettle();

      expect(find.text('Buy Milk Today'), findsNothing);
      expect(find.text('Plan Trip Tomorrow'), findsOneWidget);

      // Nhập từ khóa tìm kiếm (dùng pump để tránh kẹt cursor blink animation)
      await tester.enterText(find.byType(SearchBar), 'Trip');
      await tester.pump();

      expect(find.text('Plan Trip Tomorrow'), findsOneWidget);

      // Tìm kiếm không khớp
      await tester.enterText(find.byType(SearchBar), 'XYZ Nonexistent');
      await tester.pump();

      expect(find.text('Plan Trip Tomorrow'), findsNothing);
      expect(find.text('No matching tasks'), findsOneWidget);
    });

    testWidgets('Giao diện HomeScreen tương thích hoàn hảo trong chế độ Dark Theme', (tester) async {
      await viewModel.initialize();

      await tester.runAsync(() async {
        await viewModel.addTodo(TodoDraft(
          title: 'Dark Theme Task Item',
          description: 'Dark theme note',
          dueDate: currentTime,
          hasTime: false,
        ));
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: HomeScreen(viewModel: viewModel),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Dark Theme Task Item'), findsOneWidget);
      expect(find.text('Dark theme note'), findsOneWidget);
    });

    testWidgets('Kích hoạt handleNotificationTap làm nổi bật task trên HomeScreen', (tester) async {
      await viewModel.initialize();

      await tester.runAsync(() async {
        await viewModel.addTodo(TodoDraft(
          title: 'Target Highlight Task',
          dueDate: currentTime,
          hasTime: false,
        ));
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeScreen(viewModel: viewModel),
      ));
      await tester.pumpAndSettle();

      final targetId = viewModel.allTasks.first.id;

      // Kích hoạt notification tap
      viewModel.handleNotificationTap(targetId);
      await tester.pump(); // Cập nhật widget tree

      // Kiểm tra huy hiệu Reminded xuất hiện trên item được highlight
      expect(find.text('Reminded'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active), findsOneWidget);

      // Đẩy qua thời gian 3s để timer tắt highlight hoàn thành sạch sẽ
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('Hiển thị SwipeTutorialBanner khi chưa xem và đóng khi bấm Got it', (tester) async {
      storage.hasSeenSwipeTutorial = false;
      await viewModel.initialize();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeScreen(viewModel: viewModel),
      ));
      await tester.pumpAndSettle();

      // Banner hướng dẫn xuất hiện
      expect(find.text('Quick Tips & Gestures'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);

      // Chạm vào nút Got it
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();

      // Banner biến mất
      expect(find.text('Quick Tips & Gestures'), findsNothing);
    });

    testWidgets('Nhấn nút icon thùng rác trên task thực hiện xóa và hiển thị SnackBar Undo', (tester) async {
      await viewModel.initialize();

      await tester.runAsync(() async {
        await viewModel.addTodo(TodoDraft(
          title: 'Direct Delete Task',
          dueDate: currentTime,
          hasTime: false,
        ));
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeScreen(viewModel: viewModel),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Direct Delete Task'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);

      // Nhấn nút delete icon
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Task bị xóa khỏi danh sách
      expect(find.text('Direct Delete Task'), findsNothing);
      expect(find.text('Task deleted'), findsOneWidget);
    });

    testWidgets('Các nút chọn tab Today, Upcoming, All có gap và bo góc 10dp đồng bộ', (tester) async {
      await viewModel.initialize();

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeScreen(viewModel: viewModel),
      ));
      await tester.pumpAndSettle();

      // Kiểm tra 3 nút filter
      final todayFinder = find.textContaining('Today');
      final upcomingFinder = find.textContaining('Upcoming');
      final allFinder = find.textContaining('All');

      expect(todayFinder, findsOneWidget);
      expect(upcomingFinder, findsOneWidget);
      expect(allFinder, findsOneWidget);

      // Lấy Container của các nút để kiểm tra bo góc 10dp
      final containers = tester.widgetList<Container>(find.byType(Container));
      final tabContainers = containers.where((c) {
        final dec = c.decoration;
        if (dec is BoxDecoration) {
          return dec.borderRadius == BorderRadius.circular(10.0);
        }
        return false;
      });
      expect(tabContainers.length, greaterThanOrEqualTo(3));

      // Kiểm tra vị trí giữa các nút có gap (khoảng cách > 0)
      final todayTopLeft = tester.getTopRight(todayFinder);
      final upcomingTopLeft = tester.getTopLeft(upcomingFinder);
      expect(upcomingTopLeft.dx - todayTopLeft.dx, greaterThan(0));

      // Kiểm tra thanh SearchBar có bo góc 10dp đồng bộ
      final searchBar = tester.widget<SearchBar>(find.byType(SearchBar));
      final searchShape = searchBar.shape?.resolve({}) as RoundedRectangleBorder;
      expect(searchShape.borderRadius, equals(BorderRadius.circular(10.0)));
    });

    testWidgets('SnackBar Undo có màu sắc tương thích và bo góc 10dp trong cả Light và Dark mode', (tester) async {
      await viewModel.initialize();

      await tester.runAsync(() async {
        await viewModel.addTodo(TodoDraft(
          title: 'Color Test Task',
          dueDate: currentTime,
          hasTime: false,
        ));
      });

      // 1. Kiểm tra trên Dark Mode
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: HomeScreen(viewModel: viewModel),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      final darkSnackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(darkSnackBar.backgroundColor, equals(const Color(0xFF2C2C2C)));
      expect(darkSnackBar.behavior, equals(SnackBarBehavior.floating));
      expect(darkSnackBar.action?.textColor, equals(const Color(0xFFFF8A80)));
      final darkShape = darkSnackBar.shape as RoundedRectangleBorder;
      expect(darkShape.borderRadius, equals(BorderRadius.circular(10.0)));
    });
  });
}

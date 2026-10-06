import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/domain/models/todo.dart';
import 'package:todo_app/ui/features/todo/views/widgets/todo_item_tile.dart';

void main() {
  group('TodoItemTile Widget Tests', () {
    final now = DateTime(2026, 10, 6, 12, 0);

    testWidgets('Hiển thị tiêu đề, mô tả và checkbox chưa hoàn thành', (tester) async {
      final todo = Todo(
        id: 1,
        title: 'Buy Milk',
        description: '2 cartons',
        dueDate: now.add(const Duration(hours: 2)),
        hasTime: true,
        createdAt: now,
      );

      var toggled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TodoItemTile(
            todo: todo,
            now: now,
            onToggle: () => toggled = true,
            onTap: () {},
            onDelete: () {},
          ),
        ),
      ));

      expect(find.text('Buy Milk'), findsOneWidget);
      expect(find.text('2 cartons'), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);

      // Chạm vào checkbox tròn
      await tester.tap(find.byType(IconButton));
      expect(toggled, isTrue);
    });

    testWidgets('Hiển thị màu đỏ cảnh báo khi task bị quá hạn (Overdue)', (tester) async {
      final overdueTodo = Todo(
        id: 2,
        title: 'Overdue Project',
        dueDate: now.subtract(const Duration(hours: 2)), // Đã quá hạn 2 tiếng
        hasTime: true,
        createdAt: now.subtract(const Duration(days: 1)),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TodoItemTile(
            todo: overdueTodo,
            now: now,
            onToggle: () {},
            onTap: () {},
            onDelete: () {},
          ),
        ),
      ));

      // Kiểm tra có icon báo quá hạn hoặc text định dạng ngày
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('Hiển thị huy hiệu Reminded khi isHighlighted = true', (tester) async {
      final todo = Todo(
        id: 3,
        title: 'Meeting with Client',
        dueDate: now.add(const Duration(minutes: 10)),
        hasTime: true,
        createdAt: now,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TodoItemTile(
            todo: todo,
            now: now,
            isHighlighted: true,
            onToggle: () {},
            onTap: () {},
            onDelete: () {},
          ),
        ),
      ));

      // Kiểm tra hiển thị huy hiệu Reminded và icon thông báo
      expect(find.text('Reminded'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    });

    testWidgets('Hiển thị chuẩn xác trên nền Dark Mode không bị chữ trắng nền trắng', (tester) async {
      final todo = Todo(
        id: 4,
        title: 'Dark Mode Task',
        description: 'Detail in dark mode',
        dueDate: now.add(const Duration(days: 1)),
        hasTime: false,
        createdAt: now,
      );

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: TodoItemTile(
            todo: todo,
            now: now,
            onToggle: () {},
            onTap: () {},
            onDelete: () {},
          ),
        ),
      ));

      expect(find.text('Dark Mode Task'), findsOneWidget);
      expect(find.text('Detail in dark mode'), findsOneWidget);

      // Xác minh tiêu đề sử dụng màu sáng trên nền tối
      final titleWidget = tester.widget<Text>(find.text('Dark Mode Task'));
      expect(titleWidget.style?.color, equals(Colors.white));
    });
  });
}

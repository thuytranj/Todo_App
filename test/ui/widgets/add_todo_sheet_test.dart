import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/domain/models/todo.dart';
import 'package:todo_app/domain/models/todo_draft.dart';
import 'package:todo_app/ui/features/todo/views/widgets/add_todo_sheet.dart';

void main() {
  group('AddTodoSheet Widget Tests', () {
    final now = DateTime(2026, 10, 6, 10, 0);

    testWidgets('Tạo task mới: nhập tiêu đề và bấm Save trả về TodoDraft', (tester) async {
      TodoDraft? resultDraft;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultDraft = await showModalBottomSheet<TodoDraft>(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => AddTodoSheet(now: now),
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));

      // Mở BottomSheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề form
      expect(find.text('New Task'), findsOneWidget);

      // Nhập tiêu đề
      await tester.enterText(find.byKey(const Key('todo_title_input')), 'Walk Dog');
      await tester.enterText(find.byKey(const Key('todo_desc_input')), 'In the park');

      // Bấm nút Save
      await tester.tap(find.byKey(const Key('todo_save_button')));
      await tester.pumpAndSettle();

      expect(resultDraft, isNotNull);
      expect(resultDraft!.title, 'Walk Dog');
      expect(resultDraft!.description, 'In the park');
      expect(resultDraft!.dueDate, isNull);
      expect(resultDraft!.hasTime, isFalse);
    });

    testWidgets('Chỉnh sửa task cũ: pre-fill dữ liệu và cho phép sửa title của task đã quá hạn mà không bị chặn', (tester) async {
      final pastDue = now.subtract(const Duration(hours: 3));
      final initialTodo = Todo(
        id: 1,
        title: 'Old Overdue Task',
        description: 'Old Notes',
        dueDate: pastDue,
        hasTime: true,
        createdAt: now.subtract(const Duration(days: 1)),
      );

      TodoDraft? resultDraft;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultDraft = await showModalBottomSheet<TodoDraft>(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => AddTodoSheet(
                    initialTodo: initialTodo,
                    now: now,
                  ),
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));

      // Mở BottomSheet ở chế độ Edit
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Task'), findsOneWidget);
      expect(find.text('Old Overdue Task'), findsOneWidget);

      // Chỉ sửa tiêu đề (ngày giờ giữ nguyên không đổi)
      await tester.enterText(find.byKey(const Key('todo_title_input')), 'Renamed Overdue Task');

      // Bấm Save: không bị chặn bởi lỗi quá khứ vì ngày giờ không bị sửa
      await tester.tap(find.byKey(const Key('todo_save_button')));
      await tester.pumpAndSettle();

      expect(resultDraft, isNotNull);
      expect(resultDraft!.title, 'Renamed Overdue Task');
      expect(resultDraft!.dueDate, pastDue);
      expect(resultDraft!.hasTime, isTrue);
    });

    testWidgets('Xóa ngày đã chọn: chuyển task về không có hạn chót', (tester) async {
      final initialTodo = Todo(
        id: 2,
        title: 'Task with Date',
        dueDate: now.add(const Duration(days: 1)),
        hasTime: false,
        createdAt: now,
      );

      TodoDraft? resultDraft;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                resultDraft = await showModalBottomSheet<TodoDraft>(
                  context: context,
                  isScrollControlled: true,
                  builder: (ctx) => AddTodoSheet(
                    initialTodo: initialTodo,
                    now: now,
                  ),
                );
              },
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Bấm nút xóa ngày (deleteIcon của InputChip)
      final deleteIconFinder = find.descendant(
        of: find.byKey(const Key('todo_clear_date_button')),
        matching: find.byIcon(Icons.close),
      );
      await tester.tap(deleteIconFinder);
      await tester.pumpAndSettle();

      // Bấm Save
      await tester.tap(find.byKey(const Key('todo_save_button')));
      await tester.pumpAndSettle();

      expect(resultDraft, isNotNull);
      expect(resultDraft!.dueDate, isNull);
      expect(resultDraft!.hasTime, isFalse);
    });
  });
}

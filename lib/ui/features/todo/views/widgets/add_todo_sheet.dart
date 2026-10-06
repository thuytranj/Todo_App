import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:todo_app/domain/models/todo.dart';
import 'package:todo_app/domain/models/todo_draft.dart';
import 'package:todo_app/ui/core/theme/app_theme.dart';

/// Modal BottomSheet phục vụ cả hai chức năng: Thêm mới công việc và Chỉnh sửa công việc.
///
/// Các tính năng nổi bật:
/// - Tự động co giãn theo bàn phím ảo với `viewInsets.bottom`.
/// - Hỗ trợ chọn ngày (`showDatePicker`) và tùy chọn giờ (`showTimePicker`).
/// - Nút xóa hạn chót để đưa task về trạng thái không có deadline.
/// - Cơ chế kiểm tra an toàn: Chặn chọn giờ trong quá khứ chỉ khi người dùng CÓ THAY ĐỔI ngày giờ
///   (cho phép sửa tiêu đề của các task đã quá hạn từ trước mà không bị khóa form).
class AddTodoSheet extends StatefulWidget {
  final Todo? initialTodo;
  final DateTime now;

  const AddTodoSheet({
    super.key,
    this.initialTodo,
    required this.now,
  });

  @override
  State<AddTodoSheet> createState() => _AddTodoSheetState();
}

class _AddTodoSheetState extends State<AddTodoSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descController;

  DateTime? _selectedDueDate;
  bool _hasTime = false;
  TimeOfDay? _selectedTime;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTodo;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _descController = TextEditingController(text: initial?.description ?? '');

    if (initial != null) {
      _selectedDueDate = initial.dueDate;
      _hasTime = initial.hasTime;
      if (_hasTime && _selectedDueDate != null) {
        _selectedTime = TimeOfDay.fromDateTime(_selectedDueDate!);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// Mở hộp thoại chọn ngày và chuẩn hóa giờ về 00:00:00
  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? widget.now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null) {
      setState(() {
        if (_hasTime && _selectedTime != null) {
          _selectedDueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            _selectedTime!.hour,
            _selectedTime!.minute,
          );
        } else {
          // Chuẩn hóa về 00:00:00 nếu chưa chọn giờ
          _selectedDueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
          );
        }
        _errorMessage = null;
      });
    }
  }

  /// Mở hộp thoại chọn giờ (chỉ khả dụng khi đã có ngày)
  Future<void> _pickTime() async {
    if (_selectedDueDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        _hasTime = true;
        _selectedTime = pickedTime;
        _selectedDueDate = DateTime(
          _selectedDueDate!.year,
          _selectedDueDate!.month,
          _selectedDueDate!.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        _errorMessage = null;
      });
    }
  }

  /// Xóa hạn chót đã chọn
  void _clearDate() {
    setState(() {
      _selectedDueDate = null;
      _hasTime = false;
      _selectedTime = null;
      _errorMessage = null;
    });
  }

  /// Xóa giờ cụ thể (giữ lại ngày)
  void _clearTime() {
    setState(() {
      _hasTime = false;
      _selectedTime = null;
      if (_selectedDueDate != null) {
        _selectedDueDate = DateTime(
          _selectedDueDate!.year,
          _selectedDueDate!.month,
          _selectedDueDate!.day,
        );
      }
      _errorMessage = null;
    });
  }

  /// Xử lý lưu công việc và trả về [TodoDraft]
  void _handleSave() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() {
        _errorMessage = 'Task title cannot be empty.';
      });
      return;
    }

    // Kiểm tra xem người dùng có thay đổi ngày/giờ so với ban đầu hay không
    final isDateChanged = _selectedDueDate != widget.initialTodo?.dueDate ||
        _hasTime != (widget.initialTodo?.hasTime ?? false);

    // Chỉ chặn quá khứ nếu ngày/giờ có sự thay đổi và là task có giờ cụ thể
    if (isDateChanged && _selectedDueDate != null && _hasTime) {
      if (_selectedDueDate!.isBefore(widget.now)) {
        setState(() {
          _errorMessage = 'Cannot set due time in the past.';
        });
        return;
      }
    }

    final desc = _descController.text.trim();
    final draft = TodoDraft(
      title: title,
      description: desc.isEmpty ? null : desc,
      dueDate: _selectedDueDate,
      hasTime: _hasTime,
    );

    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.initialTodo != null;

    return Padding(
      // Padding tự động co giãn theo bàn phím ảo
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tiêu đề Sheet và nút đóng
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEditMode ? 'Edit Task' : 'New Task',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ô nhập tiêu đề (bắt buộc)
            TextField(
              key: const Key('todo_title_input'),
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'What needs to be done?',
                border: InputBorder.none,
                hintStyle: TextStyle(fontSize: 18),
              ),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Ô nhập mô tả / ghi chú (tùy chọn)
            TextField(
              key: const Key('todo_desc_input'),
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Description (optional)',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.notes, size: 20),
              ),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            // Chips chọn Ngày và Giờ
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Chip chọn / hiển thị ngày
                if (_selectedDueDate == null)
                  ActionChip(
                    avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: const Text('Set date'),
                    onPressed: _pickDate,
                  )
                else
                  InputChip(
                    key: const Key('todo_clear_date_button'),
                    avatar: const Icon(Icons.calendar_today, size: 16),
                    label: Text(DateFormat('EEE, MMM d').format(_selectedDueDate!)),
                    onPressed: _pickDate,
                    onDeleted: _clearDate,
                    deleteIcon: const Icon(Icons.close, size: 16),
                  ),

                // Chip chọn / hiển thị giờ (chỉ hiển thị khi đã chọn ngày)
                if (_selectedDueDate != null) ...[
                  if (!_hasTime)
                    ActionChip(
                      avatar: const Icon(Icons.access_time_outlined, size: 16),
                      label: const Text('Set time'),
                      onPressed: _pickTime,
                    )
                  else
                    InputChip(
                      avatar: const Icon(Icons.access_time, size: 16),
                      label: Text(DateFormat('h:mm a').format(_selectedDueDate!)),
                      onPressed: _pickTime,
                      onDeleted: _clearTime,
                      deleteIcon: const Icon(Icons.close, size: 16),
                    ),
                ],
              ],
            ),

            // Thông báo lỗi nếu có
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: AppTheme.overdueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Nút Lưu / Cập nhật
            ElevatedButton(
              key: const Key('todo_save_button'),
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isEditMode ? 'Update Task' : 'Save Task',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

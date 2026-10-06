---
name: micro-task-workflow
description: "Guides workflow and task breakdown into small, bite-sized, independently testable units. Prevents monolithic tasks and ensures incremental progress with clear gates."
---

# Micro-Task Workflow & Decomposition

## Core Principles

1. **Task Right-Sizing (Kích thước task chuẩn)**:
   - Một task lý tưởng chỉ giải quyết **1 thành phần duy nhất** (1 Model, 1 Service method, 1 Widget độc lập, hoặc 1 View logic).
   - Thời gian thực thi một task nên ngắn và có thể đánh giá được ngay (khoảng 2–5 phút làm việc của agent).
   - Nếu một task chứa quá nhiều bước (ví dụ: "Viết toàn bộ chức năng Todo bao gồm Model, Service, UI và Notification"), đó là **Monolithic Task** và **BẮT BUỘC PHẢI CHIA NHỎ**.

2. **Step Granularity (Mỗi bước là một hành động kiểm chứng được)**:
   Mỗi micro-task tuân thủ chu trình TDD chặt chẽ:
   - **Bước 1**: Viết test trường hợp cần kiểm tra (Red).
   - **Bước 2**: Chạy test và xác nhận test fail đúng lý do.
   - **Bước 3**: Viết lượng code tối thiểu để pass test (Green).
   - **Bước 4**: Chạy lại test và xác nhận passed.
   - **Bước 5**: Tối ưu (Refactor) nếu cần và tạo một **Atomic Commit**.

3. **Checklist & Tracking (`- [ ]`)**:
   - Mọi kế hoạch công việc đều phải được thể hiện dưới dạng Markdown checklist `- [ ]`.
   - Hoàn thành bước nào thì tích `- [x]` ngay bước đó để người dùng và agent luôn nắm rõ tiến độ.

4. **Task Decomposition Template**:

Khi chia nhỏ một tính năng phức tạp, áp dụng ma trận phân tách:
* **Task 1: Domain / Model**: Tạo entity, validation, serialization, unit tests cho model.
* **Task 2: Service / Storage**: Viết service đọc/ghi độc lập, unit test cho service.
* **Task 3: Integration / External Plugin**: Cấu hình platform channel / plugin (ví dụ Notification), mock và test service.
* **Task 4: State Management / ViewModel**: Viết ViewModel/Controller xử lý nghiệp vụ, viết test logic.
* **Task 5: Atomic UI Components**: Tạo các widget nhỏ (Item tile, Checkbox tròn, Empty state).
* **Task 6: Feature Screen & Assembly**: Ráp các widget thành màn hình hoàn chỉnh, tích hợp ViewModel.

## Anti-Patterns (Cần tránh)

| Phản mẫu (Anti-Pattern) | Cách sửa chuẩn (Micro-Task Standard) |
|---|---|
| "Code toàn bộ tính năng Todo" | Chia thành: Task 1 (Model) $\rightarrow$ Task 2 (Storage) $\rightarrow$ Task 3 (ViewModel) $\rightarrow$ Task 4 (UI). |
| Gộp code logic và code giao diện cùng lúc | Xong phần logic và test pass trước, sau đó mới viết giao diện kết nối vào. |
| Làm nhiều file rồi mới commit 1 lần | Xong mỗi micro-task là commit 1 lần ngay. |
| Để task mơ hồ ("Làm đẹp giao diện") | Quy định tiêu chí rõ ràng: "Tạo TodoItemTile với checkbox tròn 24dp, text gạch ngang khi done, hiển thị chip ngày". |

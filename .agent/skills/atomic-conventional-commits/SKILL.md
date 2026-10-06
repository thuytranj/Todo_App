---
name: atomic-conventional-commits
description: "Enforces atomic Git commits with Conventional Commits standards, concise messages (<=72 chars), and zero secret leaks (no hardcoded keys, tokens, or credentials)."
---

# Atomic Conventional Commits & Secret Hygiene

## Core Principles

1. **Atomic Commits (Commit nhỏ)**:
   - Mỗi commit chỉ giải quyết MỘT trách nhiệm duy nhất (single responsibility).
   - Không gộp việc thêm feature, sửa bug, và refactor code vào cùng một commit.
   - Code sau mỗi commit phải luôn biên dịch được và pass tests.

2. **Secret & Key Hygiene (Không hardcode / commit secrets)**:
   - **TUYỆT ĐỐI KHÔNG** commit các file chứa secret: `.env`, `*.keystore`, `*.jks`, `google-services.json`, `GoogleService-Info.plist`, API keys, private tokens, passwords.
   - **Luôn kiểm tra `.gitignore`** trước khi commit.
   - **Luôn chạy `git diff --staged`** hoặc `git status` trước khi thực hiện commit để rà soát:
     - Có vô tình hardcode secret key / API key vào mã nguồn không?
     - Có file rác / build artifact / file tạm nào bị add nhầm không?

3. **Conventional Commits Standard (Đúng chuẩn)**:
   Format chuẩn:
   ```text
   <type>(<scope>): <subject>
   ```

   - **Types hợp lệ**:
     - `feat`: Tính năng mới cho người dùng.
     - `fix`: Sửa lỗi.
     - `test`: Thêm hoặc sửa unit test/widget test.
     - `refactor`: Tái cấu trúc code nhưng không đổi hành vi/tính năng.
     - `style`: Định dạng code (whitespace, lint format, không đổi logic).
     - `docs`: Cập nhật tài liệu, README, spec, plans.
     - `chore`: Cấu hình build, dependencies, `.gitignore`.

   - **Scope**: Tên module/tính năng ngắn gọn (ví dụ: `todo`, `storage`, `notification`, `theme`, `search`).

   - **Subject Rules**:
     - Viết ngắn gọn, rõ ràng, tối đa **72 ký tự**.
     - Bắt đầu bằng động từ nguyên mẫu (imperative mood): `add`, `update`, `fix`, `remove`, `implement`.
     - Không viết hoa chữ cái đầu subject (sau dấu hai chấm).
     - Không để dấu chấm kết thúc câu.
     - **Tránh viết lan man, dài dòng.**

## Commit Checklist

Trước khi gõ lệnh `git commit`, agent PHẢI tự kiểm tra:
- [ ] Thay đổi này có thực sự atomic (chỉ 1 việc)?
- [ ] Đã chạy linter / tests và đảm bảo code chạy tốt?
- [ ] Đã quét `git diff` xem có API key, secret, token nào bị lộ không?
- [ ] Message có tuân thủ format `<type>(<scope>): <subject>` và <= 72 ký tự không?

## Ví dụ chuẩn

```bash
# Thêm data model Todo
git commit -m "feat(todo): define Todo model with json serialization"

# Thêm unit test cho filter
git commit -m "test(todo): add unit tests for Today and Upcoming filters"

# Triển khai notification service
git commit -m "feat(notification): schedule alert 10 minutes before due date"

# Sửa lỗi hiển thị ngày
git commit -m "fix(ui): fix date formatting for overdue tasks"

# Cập nhật .gitignore
git commit -m "chore(git): ignore local environment and build artifacts"
```

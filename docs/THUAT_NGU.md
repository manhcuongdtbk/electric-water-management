# Thuật ngữ & từ viết tắt — Hệ thống quản lý điện nội bộ Sư đoàn

> **Phiên bản:** 1.0.0
> **Ngày:** 10/06/2026
> **Tính chất:** Nguồn **duy nhất** (canonical) cho định nghĩa thuật ngữ, từ viết tắt và các gloss khái niệm của dự án. Mọi tài liệu khác **trỏ về đây**, không chép lại. Gặp thuật ngữ mới, hoặc thấy một giải thích cũ chưa đủ dễ hiểu → cập nhật ở file này.

Tài liệu dự án dùng **nhất quán** các từ dưới đây. Học một lần, rồi mọi tài liệu khác dùng đúng những từ này (không chế thêm từ đồng nghĩa).

## 1. Từ viết tắt được phép

Quy ước dự án: **tuyệt đối không viết tắt** (xem `AGENTS.md` mục "Nguyên tắc viết"). Bảng dưới đây là **danh sách duy nhất các từ viết tắt được phép** — muốn dùng một từ viết tắt thì nó phải có trong bảng. **Tiêu chí để được thêm:** từ đã đủ phổ biến để ai cũng hiểu ngay. Cần dùng một từ viết tắt mới → cân nhắc tiêu chí đó rồi **thêm vào bảng này trước khi dùng**.

| Viết tắt | Đầy đủ | Nghĩa | Nguồn chính thống |
|---|---|---|---|
| CI | Continuous Integration | Máy chủ tự chạy kiểm tra (test/lint) trên mỗi pull request | [Martin Fowler — Continuous Integration](https://martinfowler.com/articles/continuousIntegration.html) |
| ADR | Architecture Decision Record | Bản ghi một quyết định kiến trúc kèm lý do (trong `docs/superpowers/specs/`) | [adr.github.io](https://adr.github.io/) |
| CRUD | Create, Read, Update, Delete | Bốn thao tác cơ bản với dữ liệu | — |
| UI | User Interface | Giao diện người dùng | — |
| SDLC | Software Development Life Cycle | Vòng đời phát triển phần mềm (quy trình tổng thể) | — |
| SemVer | Semantic Versioning | Quy ước đánh số version `MAJOR.MINOR.PATCH` | [semver.org (tiếng Việt)](https://semver.org/lang/vi/) |

## 2. Thuật ngữ quy trình

| Từ | Nghĩa đời thường |
|---|---|
| **Branch** | Một "đường làm việc" riêng (nhánh) để bạn sửa code mà không đụng người khác. |
| **Commit** | Một lần "lưu" thay đổi, kèm một câu mô tả ngắn. |
| **Push** | Đẩy các commit từ máy bạn lên GitHub. |
| **Merge** | Nhập một nhánh vào nhánh khác (ví dụ nhập việc của bạn vào nhánh chung). Tài liệu dự án luôn gọi là "merge". |
| **Squash** | Một kiểu merge: dồn mọi commit của một pull request thành **một** commit duy nhất cho lịch sử gọn. |
| **Rebase** | Dời các commit của nhánh bạn lên trên một "nền" mới — dùng khi cập nhật nhánh theo `develop` mới nhất, hoặc khi dùng "nhánh xếp chồng" (xem `CONTRIBUTING.md` mục 4). |
| **Pull request** | Lời đề nghị merge nhánh của bạn vào nhánh khác, kèm chỗ để người khác xem và bàn trước khi merge. (Trên GitHub hay viết tắt là "PR"; tài liệu dự án viết đủ "pull request".) |
| **Tag** | Một cái nhãn cố định ghim vào một bản đã phát hành (ví dụ `v1.1.0`). |
| **Issue** | Một phiếu trên GitHub ghi một việc cần làm hoặc một lỗi; có số thứ tự `#N`. |
| **Milestone** | Một nhóm Issue dự kiến cho cùng một bản phát hành (chính là *version đích*). |
| **Version** | Số phiên bản đánh dấu một bản phát hành, theo **SemVer** (mục 1). |
| **Hotfix** | Bản vá **gấp** cho một lỗi *nghiêm trọng* đang chạy thật ở chỗ khách. |
| **Restore** | Khôi phục dữ liệu từ một bản sao lưu. |

> Tên các loại nhánh (`main`, `develop`, `feature/*`, `release/*`, `hotfix/*`) được giải thích ở `CONTRIBUTING.md` mục 2 và `docs/HUONG_DAN_SDLC.md` mục 2. Ba nghĩa của "môi trường" (environment): xem `AGENTS.md` mục "Thuật ngữ environment" và `docs/HUONG_DAN_SDLC.md` mục 6.

## 3. Gloss khái niệm

| Khái niệm | Nghĩa |
|---|---|
| **Canonical** | "Nguồn chuẩn gốc" — nơi **duy nhất** định nghĩa một quy ước/fact; mọi nơi khác **trỏ về** chứ không chép lại (để khỏi lệch nhau). `AGENTS.md` là tài liệu canonical cho quy ước dự án; `docs/THUAT_NGU.md` (file này) là canonical cho thuật ngữ. |
| **Chủ dự án** (project owner) | Người sở hữu và duy trì repository của dự án (vai trò *maintainer*): quyết định ưu tiên và **duyệt + merge** mọi pull request. Là vai trò người phụ trách, *không phải* tính năng "Projects" của GitHub. |

## Lịch sử thay đổi

- **1.0.0 (10/06/2026):** Bản đầu — gom thành nguồn duy nhất: bảng từ viết tắt (chuyển từ `AGENTS.md`), thuật ngữ quy trình (chuyển từ `docs/HUONG_DAN_SDLC.md` §1), gloss "canonical"/"chủ dự án" (gom từ `AGENTS.md`, `CONTRIBUTING.md`, `docs/HUONG_DAN_SDLC.md`). ADR-023, Issue #310.

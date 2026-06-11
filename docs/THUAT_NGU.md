# Thuật ngữ & từ viết tắt — Hệ thống quản lý điện nội bộ Sư đoàn

> **Phiên bản:** 1.1.0
> **Ngày:** 11/06/2026
> **Tính chất:** Nguồn **duy nhất** (canonical) cho định nghĩa thuật ngữ, từ viết tắt và các gloss khái niệm của dự án. Mọi tài liệu khác **trỏ về đây**, không chép lại. Gặp thuật ngữ mới, hoặc thấy một giải thích cũ chưa đủ dễ hiểu → cập nhật ở file này. Kể cả thuật ngữ chỉ còn xuất hiện trong tài liệu **lịch sử** (không sửa được, ví dụ spec/ADR cũ) — vẫn định nghĩa ở đây để bản ghi đó đọc hiểu được, **không phải viết lại** nó.

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
| **Merge-back** | Sau khi `release/*` hoặc `hotfix/*` đã vào `main`, **merge ngược** các commit đó về `develop` để bản vá không bị mất ở các lần phát triển sau (xem `CONTRIBUTING.md` mục 2). |
| **Rollback** | Tạm quay hệ thống về một bản đã phát hành (tag) trước đó — bước "chữa cháy" khi bản mới gặp sự cố nghiêm trọng. |
| **Release candidate** | Bản ứng viên (hậu tố `-rc.N`) chờ nghiệm thu trước khi phát hành chính thức. **Dự án này KHÔNG dùng `-rc.N` trong luồng deploy** — môi trường Acceptance chạy thẳng `main` (ADR-005/008); thuật ngữ chỉ nhắc tới như lựa chọn đã loại. |
| **Reslot** | Dời một Issue sang milestone (bản phát hành) sau khi nó chưa kịp xong, để không chặn việc cắt `release/*` (xem `CONTRIBUTING.md` mục 11). |

> Tên các loại nhánh (`main`, `develop`, `feature/*`, `release/*`, `hotfix/*`) được giải thích ở `CONTRIBUTING.md` mục 2 và `docs/HUONG_DAN_SDLC.md` mục 2. Ba nghĩa của "môi trường" (environment): xem `AGENTS.md` mục "Thuật ngữ environment" và `docs/HUONG_DAN_SDLC.md` mục 6.

## 3. Gloss khái niệm

| Khái niệm | Nghĩa |
|---|---|
| **Canonical** | "Nguồn chuẩn gốc" — nơi **duy nhất** định nghĩa một quy ước/fact; mọi nơi khác **trỏ về** chứ không chép lại (để khỏi lệch nhau). `AGENTS.md` là tài liệu canonical cho quy ước dự án; `docs/THUAT_NGU.md` (file này) là canonical cho thuật ngữ. |
| **Chủ dự án** (project owner) | Người sở hữu và duy trì repository của dự án (vai trò *maintainer*): quyết định ưu tiên và **duyệt + merge** mọi pull request. Là vai trò người phụ trách, *không phải* tính năng "Projects" của GitHub. |
| **Distill** (chắt lọc, cô đọng) | Rút gọn phần cốt lõi của một nội dung rồi **trỏ về** nguồn canonical để xem chi tiết, thay vì chép lại — để khỏi tạo nguồn sự thật thứ hai. Ví dụ `docs/HUONG_DAN_SDLC.md` là bản distill của quy trình SDLC (tóm tắt + bản đồ trỏ tới spec và `CONTRIBUTING.md`). Từ này còn xuất hiện trong vài spec/ADR cũ; định nghĩa ở đây để các tài liệu đó vẫn đọc hiểu được mà không phải viết lại. |
| **Supersede** | Một quyết định/ADR mới **thay thế** quyết định cũ nhưng **giữ nguyên** bản cũ làm lịch sử (không xóa, không sửa nội dung cũ). |
| **Anchor** (`NV-...`) | Mã định danh gắn trước một mục yêu cầu trong `docs/V2_XAC_NHAN_NGHIEP_VU.md` (dạng `<a id="NV-chủ-đề">`), để truy vết yêu cầu → thiết kế → test bằng grep (xem `CONTRIBUTING.md` mục 9). |
| **Fail-open** | Khi một cơ chế tự động (ví dụ hook) không xác định được tình huống thì **cho qua, không chặn** — ưu tiên không cản trở công việc; đánh đổi: có thể bỏ sót. |
| **Fail-safe** | Khi không chắc thì **nghiêng về phương án an toàn** (ví dụ cứ chạy đủ test) — ưu tiên không bỏ sót, chấp nhận làm thừa. |
| **Path filter** | Bộ lọc trong CI quyết định job nào chạy dựa trên *đường dẫn file* thay đổi (ví dụ chỉ sửa tài liệu → bỏ qua job test); xem ADR-021. |
| **Grooming** | Rà soát/sắp xếp lại backlog. **Dự án này KHÔNG họp grooming định kỳ** — gộp vào lúc phân loại Issue (ADR-019/020); thuật ngữ chỉ nhắc tới như cái "không làm". |
| **Prose** (văn xuôi) | Lời văn giải thích thông thường cho người đọc — đối lập với **luật máy ép được** (code/CI/hook). Câu "đừng viết prose rồi mong người nhớ" (ADR-002): cái gì máy kiểm được thì để máy ép; chỉ để lại prose ngắn + kỷ luật cho phần máy không ép được. |

## Lịch sử thay đổi

- **1.1.0 (11/06/2026):** Thêm gloss **"prose"** (văn xuôi — đối lập luật-máy-ép) vì đang dùng ở ADR-002 và nhiều spec mà chưa định nghĩa. Đăng ký vào `.github/dictionaries/glossary-terms.txt` để guardrail ADR-024 giữ. Issue #313.
- **1.0.0 (10/06/2026):** Bản đầu — gom thành nguồn duy nhất: bảng từ viết tắt (chuyển từ `AGENTS.md`), thuật ngữ quy trình (chuyển từ `docs/HUONG_DAN_SDLC.md` §1), gloss "canonical"/"chủ dự án" (gom từ `AGENTS.md`, `CONTRIBUTING.md`, `docs/HUONG_DAN_SDLC.md`). ADR-023, Issue #310.

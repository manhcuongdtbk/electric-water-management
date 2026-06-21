# Xác nhận nghiệp vụ bổ sung (đợt 2) — Hệ thống quản lý điện nước nội bộ (Hệ thống v2)

> **Phiên bản:** 2.5.0
> **Ngày:** 21/06/2026
> **Bối cảnh:** Quản trị viên hệ thống kiểm thử trên môi trường Acceptance và đưa ra 2 mong muốn mới.

---

## Mục lục

1. [Tên phần mềm trên trang đăng nhập](#1-tên-phần-mềm-trên-trang-đăng-nhập)
2. [Vai trò mới — Chỉ huy Sư đoàn](#2-vai-trò-mới--chỉ-huy-sư-đoàn)
3. [Tổng hợp cần xác nhận](#3-tổng-hợp-cần-xác-nhận)

---

## 1. Tên phần mềm trên trang đăng nhập

> **Trạng thái: Đã triển khai** (PR #417, issue #418 đã đóng).

### Vấn đề thực tế

Hiện tại trang đăng nhập có hiển thị tên phần mềm nhưng nhỏ và không nổi bật. Khi mở hệ thống lên chưa thấy rõ đây là phần mềm gì.

### Giải pháp đề xuất

Hiển thị tên **"Hệ thống quản lý điện nước nội bộ"** nổi bật trên trang đăng nhập, là thứ đầu tiên thấy khi mở phần mềm.

### Quy tắc

- Tên hiển thị xuyên suốt: trang đăng nhập, tiêu đề trình duyệt.
- Tên chính thức: **Hệ thống quản lý điện nước nội bộ**.

---

## 2. Vai trò mới — Chỉ huy Sư đoàn

### Vấn đề thực tế

Hiện tại hệ thống có 6 vai trò thực tế (4 giá trị trong cơ sở dữ liệu, trong đó quản trị viên đơn vị và chỉ huy đơn vị mỗi vai trò chia thành 2 biến thể tuỳ đơn vị có quản lý khu vực hay không — xem `V2_HANH_VI_HE_THONG.md` mục 1). Chỉ huy đơn vị xem được đơn vị mình. Nhưng chưa có vai trò cho chỉ huy cao nhất — người cần xem tất cả đơn vị để nắm tình hình chung mà không cần (và không nên) sửa số liệu.

### Giải pháp đề xuất

Thêm vai trò **Chỉ huy Sư đoàn**:

| | Quản trị viên hệ thống | Chỉ huy Sư đoàn (mới) | Chỉ huy đơn vị |
|---|---|---|---|
| Phạm vi | Tất cả | Tất cả | Đơn vị mình |
| Xem | Có | **Có** | Có |
| Sửa/tạo/xóa | Có | **Không** | Không |
| Tính toán lại | Có | **Không** | Không |

Nói ngắn gọn: **xem tất cả như quản trị viên hệ thống, không sửa được gì** — giống chỉ huy đơn vị nhưng phạm vi toàn hệ thống thay vì 1 đơn vị.

### Chi tiết quyền xem

Chỉ huy Sư đoàn thấy cùng các trang với quản trị viên hệ thống, tất cả ở chế độ chỉ xem:

| Trang | Chỉ huy Sư đoàn thấy | Sửa được |
|---|---|---|
| Tổng quan | Tổng quan toàn hệ thống (như quản trị viên hệ thống) | Không |
| Bảng tính tiền | Tất cả đơn vị, có ô lọc khu vực/đơn vị | Không (có nút Tính toán lại — giống chỉ huy đơn vị) |
| Tra cứu lịch sử | Tất cả | Không |
| Chỉ số đầu mối | Tất cả, có ô lọc khu vực/đơn vị | Không (tất cả ô nhập vô hiệu hóa) |
| Chỉ số bơm nước | Tất cả, có ô lọc khu vực | Không |
| Nhập số điện lực | Tất cả | Không |
| Đầu mối | Tất cả, có ô lọc khu vực/đơn vị | Không (không có nút tạo/sửa/xóa) |
| Khối, Nhóm | Tất cả | Không |
| Cấu hình đơn vị | Tất cả, có ô lọc khu vực/đơn vị | Không |
| Khu vực | Tất cả | Không |
| Đơn vị | Tất cả | Không |
| Phân bổ bơm nước | Tất cả, có ô lọc khu vực | Không |
| Đơn giá điện | Xem đơn giá và danh sách kỳ | Không (không có nút mở/đóng kỳ) |
| Nhóm cấp bậc | Tất cả | Không |
| Nhật ký hoạt động | Xem | — |
| Tài khoản | Không thấy | — |
| Sao lưu dữ liệu | Không thấy | — |

### Quy tắc

- Chỉ huy Sư đoàn không thuộc đơn vị nào — trang tạo tài khoản không yêu cầu chọn đơn vị cho vai trò này.
- Kỹ thuật viên hoặc quản trị viên hệ thống tạo tài khoản chỉ huy Sư đoàn.
- Giao diện giống quản trị viên hệ thống nhưng tất cả ô nhập vô hiệu hóa, các nút tạo/sửa/xóa/lưu/mở kỳ/đóng kỳ ẩn đi. Nút Tính toán lại hiện (giống các loại chỉ huy khác).
- Sidebar hiển thị cùng các mục với quản trị viên hệ thống, trừ Tài khoản. (Sao lưu dữ liệu vốn chỉ hiện cho kỹ thuật viên — quản trị viên hệ thống cũng không thấy mục này trên sidebar.)
- Xuất Excel: cho phép (chỉ đọc, không ảnh hưởng dữ liệu).

---

## 3. Tổng hợp cần xác nhận

---

**Câu 1 — Tên phần mềm:**

Hiển thị "Hệ thống quản lý điện nước nội bộ" nổi bật trên trang đăng nhập. Chi tiết ở mục 1.

→ **Đã triển khai** (PR #417, issue #418 đã đóng).

---

**Câu 2 — Chỉ huy Sư đoàn:**

Thêm vai trò mới "Chỉ huy Sư đoàn" — xem tất cả như quản trị viên hệ thống, không sửa được gì. Chi tiết ở mục 2.

→ **Đã triển khai** (PR #422, issue #419).

---

## Truy vết

- Issue tên phần mềm: [#418](https://github.com/manhcuongdtbk/electric-water-management/issues/418)
- Issue vai trò Chỉ huy Sư đoàn: [#419](https://github.com/manhcuongdtbk/electric-water-management/issues/419)

## Lịch sử thay đổi

### v2.5.0 (21/06/2026)

- Mục 2 bảng quyền: Chỉ huy Sư đoàn có nút Tính toán lại trên bảng tính tiền (giống các loại chỉ huy khác).
- Mục 2 quy tắc: bỏ "tính toán lại" khỏi danh sách nút ẩn.

### v2.4.0 (21/06/2026)

- Mục 3 câu 2: đánh dấu "Đã triển khai" (PR #422, issue #419).

### v2.3.0 (21/06/2026)

- Mục 1: đánh dấu "Đã triển khai" (PR #417, issue #418 đã đóng).
- Mục 2 sidebar: làm rõ Sao lưu dữ liệu vốn chỉ hiện cho kỹ thuật viên — quản trị viên hệ thống cũng không có mục này trên sidebar (trước đó viết "trừ Tài khoản và Sao lưu" gây hiểu nhầm SA đang có backups).
- Mục 3 tổng hợp: cập nhật trạng thái câu 1 (đã triển khai) và câu 2 (chưa triển khai, issue #419 đang mở).

### v2.2.1 (21/06/2026)

- Sửa tên hệ thống trong tiêu đề: "Hệ thống quản lý điện nước nội bộ" (khớp tên chính thức).
- Sửa thuật ngữ: "staging" → "môi trường Acceptance" (khớp batch 1 và quy ước dự án).
- Sửa fact: trang đăng nhập đã có tên phần mềm nhưng nhỏ (không phải "chưa hiển thị").
- Sửa fact: hệ thống có 6 vai trò thực tế, không phải 4 (trỏ `V2_HANH_VI_HE_THONG.md` mục 1).
- Thêm mục Truy vết: trỏ tới issue #418 và #419.

### v2.2.0 (11/06/2026)

- Tài liệu ban đầu với 2 mục: tên phần mềm trên trang đăng nhập, vai trò mới Chỉ huy Sư đoàn.

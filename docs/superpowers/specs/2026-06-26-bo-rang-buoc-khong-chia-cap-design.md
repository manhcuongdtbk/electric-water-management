---
customer_facing: false
---

# Bỏ ràng buộc "không chia cấp" trong phân bổ bơm nước theo trạm

> **Phiên bản:** 0.1.0
> **Ngày:** 26/06/2026
> **Issue:** #481

## ADR-067: Bỏ ràng buộc "không chia cấp", giữ "không chồng chéo"

**Trạng thái:** Accepted · 26/06/2026

**Bối cảnh:**

ADR-026 thiết kế phân bổ bơm nước theo trạm với 2 ràng buộc xuyên trạm:

1. **Không chồng chéo:** tập đầu mối sinh hoạt phân giải từ mỗi đối tượng nhận không giao nhau.
2. **Không chia cấp:** toàn bộ đơn vị thuộc một trạm duy nhất — không chia bất cứ cấp nào ra nhiều trạm.

Ràng buộc (2) dựa trên giả định "mỗi đơn vị nhận từ một pool duy nhất" — kế thừa từ cơ chế gộp toàn khu vực cũ.

Khách test Acceptance v1.2.0 cho thấy giả định sai: trong 1 đơn vị có 4 khối và 2 trạm bơm, các khối khác nhau được phục vụ bởi trạm bơm khác nhau (vị trí vật lý). Ràng buộc (2) chặn cấu hình này.

**Phân tích gốc rễ:**

Trạm bơm phục vụ vùng vật lý, không phụ thuộc cấp tổ chức. Đối tượng nhận cuối cùng luôn là đầu mối — đơn vị/khối/nhóm chỉ là cách gộp. Ràng buộc (2) áp đặt cấu trúc tổ chức lên thực tế vật lý.

Ràng buộc (1) đã đủ đảm bảo tính đúng đắn: mỗi đầu mối sinh hoạt nhận điện bơm nước từ đúng 1 nguồn, không tính trùng. Mọi kịch bản mà (2) chặn đúng (ví dụ: gán cả Đơn vị lẫn Khối trong Đơn vị cho 2 trạm) đều đã bị (1) chặn vì chồng chéo tập đầu mối.

**Quyết định:** Bỏ hoàn toàn ràng buộc "không chia cấp". Giữ nguyên "không chồng chéo" và 5 ràng buộc theo từng trạm.

**Lý do:**

- Ràng buộc (2) không bảo vệ gì mà (1) chưa bảo vệ — chỉ thêm hạn chế không khớp thực tế.
- Bỏ đi đơn giản hóa hệ thống (xóa code, xóa test, xóa thông báo lỗi), không thêm phức tạp.
- Không cần sửa engine — `PumpAllocationCalculator` xử lý từng trạm độc lập, không phụ thuộc ràng buộc phân cấp.

**Phương án đã loại:**

- *Nới lỏng chỉ ở mức đơn vị (giữ ở mức khối/nhóm)*: không có bằng chứng cần giữ ở mức nào — thêm ràng buộc dựa trên giả định là cách tạo ra vấn đề hiện tại.
- *Thêm ràng buộc "1 trạm không phục vụ 2 đơn vị"*: chưa có bằng chứng cần — mục 3 nghiệp vụ ghi "các đơn vị chia sẻ hạ tầng điện" gợi ý ngược lại.

**Ghi chú thiết kế — trạm bơm là thực thể riêng về khái niệm:**

Trạm bơm (đầu mối `water_pump`) không phải "đầu mối" theo định nghĩa nghiệp vụ ("đại diện cho 1 người hoặc 1 nhóm người") — nó là hạ tầng vật lý. Hiện nằm trong `contact_points` vì chia sẻ thuộc tính (tên, công tơ, thuộc khu vực). Tách thành bảng riêng khi: trạm bơm cần thuộc tính riêng (công suất, vị trí, bảo trì), cần quan hệ không phù hợp đầu mối (xuyên khu vực), hoặc sự khác biệt hành vi gây nhầm lẫn. Hiện chưa cần — schema hoạt động đúng.

## Truy vết

- Nghiệp vụ: `V2_XAC_NHAN_NGHIEP_VU.md` mục 9.6 (anchor `NV-phan-bo-bom-theo-tram`)
- Thiết kế gốc: ADR-026 trong `2026-06-11-phan-bo-bom-theo-tram-design.md`
- Issue: #481
- Nguồn: cuộc trao đổi Acceptance v1.2.0 với khách, 26/06/2026

## Lịch sử thay đổi

- **0.1.0 (26/06/2026):** Bản đầu — ADR-067 bỏ ràng buộc "không chia cấp".

# Mẫu ADR (Architecture Decision Record)

> Dán khối dưới vào mục `## Quyết định (ADR)` của một spec trong `docs/superpowers/specs/`.
> ADR đánh **số toàn cục, tăng dần** (số mới nhất: xem spec gần nhất). Giữ đúng **7 mục, đúng thứ tự**.
> ADR mới có thể **thay** (supersede) ADR cũ — ghi rõ ở Trạng thái, giữ lịch sử.

### ADR-NNN: <Tiêu đề quyết định, ngắn gọn>
- **Trạng thái:** Accepted · YYYY-MM-DD  <!-- Merge = Accepted: ghi Accepted ngay trong PR (ADR-033). Proposed CHỈ khi cố ý hoãn: `Proposed (chờ quyết #<issue>)`. Superseded by ADR-XXX khi bị thay. Frontmatter spec KHÔNG mang `status:` — nguồn duy nhất là dòng này. -->
- **Bối cảnh:** <Vấn đề/ràng buộc dẫn tới quyết định. Nêu sự thật, chưa nêu giải pháp.>
- **Quyết định:** <Chọn gì — cụ thể, đủ để thực thi.>
- **Lý do:** <Vì sao lựa chọn này thắng — bám sát Bối cảnh.>
- **Tradeoff:** (+) <được gì> (−) <mất/chấp nhận gì>
- **Phương án đã loại:** <Mỗi phương án + một câu vì sao loại.>
- **Điều kiện xem lại:** <Khi nào nên mở lại quyết định này.>

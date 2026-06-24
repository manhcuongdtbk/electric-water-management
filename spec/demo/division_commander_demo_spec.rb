require "rails_helper"

# Demo spec for division_commander role (#419) — a narrated, recorded walkthrough
# covering all 18 pages (16 accessible + 2 blocked). Follows the business flow:
# cấu trúc → thiết lập → nhập liệu → kết quả → hệ thống → bị chặn.
#
# Customer story: the Division Commander needs to see the overall electricity
# situation across all units — who's over budget, who hasn't entered data — but
# currently has no way to access the system. The unit commander can only see
# their own unit.
#
# ADR-059 checklist:
#   1. Cho thấy, đừng nói (highlight)
#   2. Kể đúng chuyện khách
#   3. Diễn kết quả + cái đau được xoá
#   4. Trung thực với medium (không diễn Excel — browser không render .xlsx)
#   5. Đủ cung đường khách quan tâm (18/18 trang)
#   6. Ổn định (dùng primitive confirm:/unpoint)
RSpec.describe "Demo: vai trò Chỉ huy Sư đoàn", type: :demo do
  include_context "demo seeded world"

  before do
    zone = Zone.find_by!(name: "Khu vực 1")
    period = Period.find_by!(year: 2026, month: 6)
    CalculationOrchestrator.new(zone: zone, period: period).call
  end

  it "xem tất cả như quản trị viên hệ thống, không sửa được gì",
     demo_id: "vai_tro_chi_huy_su_doan",
     demo_nv: %w[NV-vai-tro-chi-huy-su-doan] do
    demo = DemoRecorder.new(self)

    zone = Zone.find_by!(name: "Khu vực 1")
    period = Period.find_by!(year: 2026, month: 6)

    # -----------------------------------------------------------------------
    # Beat 1 — Cái đau: chỉ huy đơn vị chỉ thấy đơn vị mình
    # -----------------------------------------------------------------------
    demo.sign_in_as(User.find_by!(username: "demo_commander"), role_label: "Chỉ huy đơn vị")
    expect(page).to have_current_path("/", wait: 10)
    demo.narrate("Chỉ huy đơn vị chỉ thấy đơn vị mình — muốn biết tình hình chung phải hỏi quản trị viên")

    # -----------------------------------------------------------------------
    # Beat 2 — Giải pháp: đăng nhập Chỉ huy Sư đoàn
    # -----------------------------------------------------------------------
    demo.sign_in_as(User.find_by!(username: "demo_dc"), role_label: "Chỉ huy Sư đoàn")
    expect(page).to have_current_path("/", wait: 10)
    demo.narrate("Vai trò mới: Chỉ huy Sư đoàn — xem tất cả, không sửa số liệu đầu vào")

    # -----------------------------------------------------------------------
    # Beat 3 — Xem cấu trúc (lớn → nhỏ)
    # -----------------------------------------------------------------------

    # 3a. Khu vực
    demo.visit("/zones", caption: "Xem cấu trúc: Khu vực — toàn bộ khu vực trong hệ thống")
    expect(page).to have_content(zone.name, wait: 10)
    expect(page).to have_no_link("Thêm khu vực")

    # 3b. Đơn vị
    demo.visit("/units", caption: "Đơn vị — tất cả đơn vị, có ô lọc khu vực")
    expect(page).to have_content("Tiểu đoàn 1", wait: 10)
    expect(page).to have_no_link("Thêm đơn vị")

    # 3c. Khối
    demo.visit("/blocks", caption: "Khối — nhóm hiển thị lớn, không có nút thêm/sửa/xóa")
    expect(page).to have_no_link("Thêm khối")

    # 3d. Nhóm
    demo.visit("/groups", caption: "Nhóm — nhóm hiển thị nhỏ, không có nút thêm/sửa/xóa")
    expect(page).to have_no_link("Thêm nhóm")

    # 3e. Đầu mối
    demo.visit("/contact_points", caption: "Đầu mối — tất cả đầu mối, có ô lọc khu vực và đơn vị")
    expect(page).to have_css("select#zone_id", wait: 10)
    expect(page).to have_css("select#unit_id")
    demo.narrate("Xem cấu trúc toàn bộ (lớn → nhỏ) — nhưng không thêm, sửa, xóa được")
    expect(page).to have_no_link("Thêm đầu mối")

    # -----------------------------------------------------------------------
    # Beat 4 — Xem thiết lập
    # -----------------------------------------------------------------------

    # 4a. Đơn giá điện
    demo.visit("/pricing", caption: "Thiết lập: Đơn giá điện — xem đơn giá và danh sách kỳ")
    expect(page).to have_content("đ/kW", wait: 10)
    expect(page).to have_no_button("Đóng kỳ hiện tại")
    expect(page).to have_no_button("Lưu cập nhật")
    demo.narrate("Xem đơn giá, không có nút mở kỳ/đóng kỳ/sửa — chỉ quản trị viên hệ thống quản lý kỳ")

    # 4b. Nhóm cấp bậc
    demo.visit("/ranks", caption: "Nhóm cấp bậc — xem định mức điện từng cấp bậc")
    expect(page).to have_css("thead", text: /KWH\/NGƯỜI/i, wait: 10)
    expect(page).to have_no_link("Thêm nhóm cấp bậc")

    # 4c. Phân bổ bơm nước
    demo.visit("/pump_allocations", caption: "Phân bổ bơm nước — xem cấu hình phân bổ, không sửa được")
    expect(page).to have_no_link("Thêm phân bổ bơm nước")

    # -----------------------------------------------------------------------
    # Beat 5 — Xem nhập liệu (tổng quan → chuyên sâu)
    # -----------------------------------------------------------------------

    # 5a. Nhập số điện lực (công tơ tổng khu vực)
    demo.visit("/electricity_supply", caption: "Nhập liệu: Nhập số điện lực — số điện lực cấp cho khu vực")
    expect(page).to have_css("input[disabled]", wait: 10)
    demo.narrate("Số liệu đã nhập — mọi ô khóa, nút Lưu vô hiệu hóa")

    # 5b. Chỉ số đầu mối (công tơ từng đầu mối)
    demo.visit("/meter_entries", caption: "Chỉ số đầu mối — chỉ số công tơ từng đầu mối, có ô lọc khu vực và đơn vị")
    expect(page).to have_css("select#zone_id", wait: 10)
    expect(page).to have_css("input[disabled]")
    expect(page).to have_button("Lưu toàn bộ", disabled: true)

    # 5c. Chỉ số bơm nước
    demo.visit("/pump_entries", caption: "Chỉ số bơm nước — công tơ bơm nước, tất cả ô khóa")
    expect(page).to have_css("input[disabled]", wait: 10)

    # 5d. Cấu hình đơn vị
    unit = Unit.find_by!(name: "Tiểu đoàn 1")
    demo.visit("/unit_config?zone_id=#{zone.id}&unit_id=#{unit.id}",
               caption: "Cấu hình đơn vị — tỷ lệ công cộng và khoản trừ, tất cả ô khóa")
    expect(page).to have_no_button("Lưu cấu hình")
    demo.narrate("Xem cấu hình tính tiền — không sửa được, không có nút Lưu")

    # -----------------------------------------------------------------------
    # Beat 6 — Xem kết quả (tổng quan → chi tiết → lịch sử)
    # -----------------------------------------------------------------------

    # 6a. Dashboard (tổng quan)
    demo.visit("/", caption: "Kết quả: Tổng quan — toàn bộ đơn vị và khu vực")
    expect(page).to have_content(zone.name, wait: 10)
    expect(page).to have_content("Tiểu đoàn 1")
    demo.highlight("table", caption: "Bảng tổng hợp: thâm điện, thành tiền phải thu, trạng thái nhập liệu — tất cả đơn vị")

    # 6b. Bảng tính tiền (chi tiết)
    demo.visit("/billing?zone_id=#{zone.id}", caption: "Bảng tính tiền — chi tiết từng đầu mối, có ô lọc khu vực/đơn vị")
    expect(page).to have_css("select#zone_id", wait: 10)
    expect(page).to have_content("Xuất Excel")
    demo.click("Tính toán lại", confirm: true, caption: "Tính toán lại — Chỉ huy Sư đoàn dùng được, giống chỉ huy đơn vị")
    expect(page).to have_content("Đã tính toán lại", wait: 15)
    demo.narrate("Xem bảng tính tiền đầy đủ, xuất Excel được, tính toán lại được")

    # 6c. Tra cứu lịch sử
    demo.visit("/history", caption: "Tra cứu lịch sử — so sánh kỳ và xem theo khoảng thời gian")
    expect(page).to have_content("Kỳ", wait: 10)

    # -----------------------------------------------------------------------
    # Beat 7 — Xem hệ thống
    # -----------------------------------------------------------------------
    demo.visit("/audit_logs", caption: "Nhật ký hoạt động — xem mọi thao tác trong hệ thống")
    expect(page).to have_content("Nhật ký hoạt động", wait: 10)

    # -----------------------------------------------------------------------
    # Beat 8 — Bị chặn
    # -----------------------------------------------------------------------

    # 8a. Tài khoản
    demo.visit("/users", caption: "Tài khoản — Chỉ huy Sư đoàn không được phép truy cập")
    expect(page).to have_current_path("/", wait: 10)
    demo.narrate("Quản trị tài khoản chỉ dành cho quản trị viên hệ thống và kỹ thuật viên")

    # 8b. Sao lưu dữ liệu
    demo.visit("/backups", caption: "Sao lưu dữ liệu — Chỉ huy Sư đoàn không được phép truy cập")
    expect(page).to have_current_path("/", wait: 10)

    # -----------------------------------------------------------------------
    # Beat 9 — Kết
    # -----------------------------------------------------------------------
    demo.narrate("7 vai trò: thêm Chỉ huy Sư đoàn — xem tất cả 16 trang, không sửa số liệu đầu vào, có thể tính toán lại. Quyền truy cập từng trang được kiểm thử tự động đủ cả 7 vai trò")
  end
end

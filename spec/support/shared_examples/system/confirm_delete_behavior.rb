# Shared system spec example cho confirm xóa (turbo_confirm) trên trang danh sách.
# Dùng Capybara API — chỉ dùng trong type: :system.
#
# Yêu cầu trong caller:
#   path:                      → URL trang index
#   deletable_name:            → Tên hiển thị trong bảng để tìm row và click xóa
#
# Tùy chọn:
#   confirm_message_pattern:   → Regex verify nội dung confirm dialog (vd: /quản lý khu vực/)
RSpec.shared_examples "confirm delete behavior" do
  it "confirm xóa và xóa thành công" do
    visit path
    msg = accept_confirm do
      within("tr", text: deletable_name) { click_on I18n.t("common.actions.destroy") }
    end
    if respond_to?(:confirm_message_pattern)
      expect(msg).to match(confirm_message_pattern)
    end
    expect(page).to have_current_path(path, ignore_query: true)
    expect(page).not_to have_css("table tbody tr", text: deletable_name)
  end
end

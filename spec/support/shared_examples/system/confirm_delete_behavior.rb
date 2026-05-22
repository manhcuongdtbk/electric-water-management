# Shared system spec example cho confirm xóa (turbo_confirm) trên trang danh sách.
# Dùng Capybara API — chỉ dùng trong type: :system.
#
# Yêu cầu trong caller:
#   path:               → URL trang index
#   deletable_record:   → Record có thể xóa (không vi phạm constraint)
#   deletable_name:     → Tên hiển thị trong bảng và confirm dialog
RSpec.shared_examples "confirm delete behavior" do
  it "confirm xóa hiện tên entity và xóa thành công" do
    deletable_record # force creation
    visit path
    accept_confirm(/#{Regexp.escape(deletable_name)}/) do
      within("tr", text: deletable_name) { click_on I18n.t("common.actions.destroy") }
    end
    expect(page).to have_current_path(path)
    expect(page).not_to have_css("table tbody tr", text: deletable_name)
  end
end

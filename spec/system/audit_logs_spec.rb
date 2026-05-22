require "rails_helper"

RSpec.describe "Audit logs", type: :system do
  let(:system_admin) { create(:user, :system_admin) }
  let!(:zone) { create(:zone, name: "Khu vực test") }

  before { sign_in system_admin }

  let(:path) { audit_logs_path }
  def path_with_params(**params) = audit_logs_path(**params)
  def create_extra_data
    30.times { |i| PaperTrail::Version.create!(item_type: "Zone", item_id: i + 100, event: "create") }
  end

  it_behaves_like "per_page auto-submit behavior"

  it "dropdown sự kiện auto-submit lọc đúng" do
    visit audit_logs_path
    select I18n.t("audit_logs.events.create"), from: "event"
    expect(page).to have_select("event", selected: I18n.t("audit_logs.events.create"))
  end

  it "dropdown đối tượng auto-submit lọc đúng" do
    visit audit_logs_path
    select I18n.t("audit_logs.item_types.Zone", default: "Zone"), from: "item_type"
    expect(page).to have_select("item_type", selected: I18n.t("audit_logs.item_types.Zone", default: "Zone"))
  end

  it "date filter auto-submit khi chọn ngày" do
    visit audit_logs_path
    date_value = Date.current.strftime("%Y-%m-%d")
    page.execute_script("document.getElementById('from').value = '#{date_value}'; document.getElementById('from').dispatchEvent(new Event('change', { bubbles: true }))")
    expect(page).to have_current_path(/from=#{date_value}/)
  end

  it "Xóa bộ lọc reset tất cả filter" do
    visit audit_logs_path(event: "create")
    expect(page).to have_content("Xóa bộ lọc")

    click_on "Xóa bộ lọc"
    expect(page).not_to have_content("Xóa bộ lọc")
    expect(find("select#event").value).to eq("")
  end
end

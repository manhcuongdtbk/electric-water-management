require "rails_helper"

RSpec.describe "Pricing", type: :system do
  let!(:period) { create(:period, year: 2026, month: 6, closed: false, unit_price: 2336) }
  let!(:old_periods) do
    (1..12).map { |m| create(:period, year: 2025, month: m, closed: true, unit_price: 2000) }
  end
  let(:system_admin) { create(:user, :system_admin) }

  before { sign_in system_admin }

  # --- Toolbar shared examples ---
  let(:path) { pricing_path }
  let(:filter_param) { "year" }
  let(:filter_option_text) { "2025" }
  let(:filter_option_value) { "2025" }
  let(:content_included) { "Tháng 12/2025" }
  let(:content_excluded) { "Tháng 6/2026" }
  let(:sort_column) { nil }
  def path_with_params(**params) = pricing_path(**params)
  def create_extra_data
    (1..12).map { |m| create(:period, year: 2024, month: m, closed: true, unit_price: 1800) }
  end

  it_behaves_like "single filter behavior"
  it_behaves_like "per_page auto-submit behavior"

  # --- Page-specific ---

  it "confirm đóng kỳ hiện tại" do
    visit pricing_path
    accept_confirm(/bị khóa/) do
      click_on "Đóng kỳ hiện tại"
    end
    expect(page).to have_current_path(pricing_path, ignore_query: true)
  end

  it "confirm mở kỳ mới" do
    period.update!(closed: true)
    visit pricing_path
    accept_confirm(/Mở kỳ tháng/) do
      click_on "Mở kỳ tháng 7/2026"
    end
    expect(page).to have_current_path(pricing_path, ignore_query: true)
  end

  it "confirm mở lại kỳ cũ" do
    period.update!(closed: true)
    visit pricing_path
    accept_confirm(/Mở lại/) do
      within("tr", text: "Tháng 6/2026") { click_on "Mở lại" }
    end
    expect(page).to have_current_path(pricing_path, ignore_query: true)
  end

  it "non-SA không thấy nút đóng kỳ và mở kỳ" do
    zone = create(:zone)
    unit = create(:unit, zone: zone)
    unit_admin = create(:user, :unit_admin, unit: unit)
    sign_in unit_admin
    visit pricing_path
    expect(page).not_to have_button("Đóng kỳ hiện tại")
    expect(page).not_to have_button("Mở lại")
  end
end

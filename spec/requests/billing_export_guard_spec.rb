require "rails_helper"

RSpec.describe "Billing Excel export guard", type: :request do
  include XlsxHelpers

  let(:period) { Period.current || create(:period, closed: false) }
  let(:zone) { create(:zone) }
  let(:unit) { create(:unit, zone: zone) }
  let(:sa) { create(:user, :system_admin) }
  let!(:contact_point) { create(:contact_point, :residential, unit: unit) }
  let!(:meter) { create(:meter, contact_point: contact_point) }
  let!(:meter_reading) do
    MeterReading.find_by(meter_id: meter.id, period_id: period.id) ||
      create(:meter_reading, meter: meter, period: period, reading_start: 0, reading_end: 100)
  end
  before { sign_in sa }

  def make_stale!
    CalculationOrchestrator.new(zone: zone, period: period).call
    meter_reading.reload.update!(reading_end: 77)
  end

  it "CHIEU-do-tuoi-excel-block: redirects with alert when exporting stale data without acknowledgement" do
    make_stale!
    get billing_path(period_id: period.id, format: :xlsx)
    expect(response).to have_http_status(:redirect)
    follow_redirect!
    expect(response.body).to include(I18n.t("billing.export.stale_blocked"))
  end

  it "allows export of fresh data" do
    CalculationOrchestrator.new(zone: zone, period: period).call
    get billing_path(period_id: period.id, format: :xlsx)
    expect(response).to have_http_status(:ok)
    expect(response.content_type).to include("spreadsheetml")
  end

  it "allows export of stale data when acknowledged" do
    make_stale!
    get billing_path(period_id: period.id, format: :xlsx, acknowledged_stale: "1")
    expect(response).to have_http_status(:ok)
  end

  it "CHIEU-do-tuoi-excel-stamp: stamps a warning into the file when exporting acknowledged stale data" do
    make_stale!
    get billing_path(period_id: period.id, format: :xlsx, acknowledged_stale: "1")
    expect(response).to have_http_status(:ok)
    xlsx = parse_xlsx(response.body)
    expect(xlsx.rows.first.first).to include("CẢNH BÁO")
  end

  it "CHIEU-do-tuoi-excel-stamp: stamped file keeps formulas/totals correct (shifted down by 2 rows)" do
    make_stale!
    get billing_path(period_id: period.id, format: :xlsx, acknowledged_stale: "1")
    expect(response).to have_http_status(:ok)
    xlsx = parse_xlsx(response.body)

    # 2 stamp rows (warning + blank spacer) shift every absolute reference down by 2:
    # unit price B1 → B3, data band that started at row 6 → row 8.
    # The single-sheet export must be numerically identical to the unstamped one,
    # just relocated; assert the shifted anchors instead of the original B1 / row 6.

    # (a) Unit price now sits at B3 (was B1), and amount formulas multiply by $B$3.
    expect(xlsx.rows[2][1].to_f).to eq(period.unit_price.to_f)
    amount_formulas = xlsx.formulas.select { |_ref, f| f.include?("$B$3") }
    expect(amount_formulas.size).to be >= 2
    # The OLD anchor must NOT leak through — proves the shift actually happened.
    expect(xlsx.formulas.values).to all(satisfy { |f| !f.include?("$B$1") })

    # (b) Per-row formulas reference the shifted data band (row 8), not row 6.
    row8_formulas = xlsx.formulas.select { |ref, _f| ref =~ /8$/ }
    expect(row8_formulas).not_to be_empty
    expect(xlsx.formulas.select { |_ref, f| f =~ /SUM\([A-Z]+8:[A-Z]+8\)/ }).not_to be_empty

    # (c) Grand-total SUM ranges start at the shifted data row (row 8), never row 6.
    total_formulas = xlsx.formulas.select { |_ref, f| f =~ /SUM\([A-Z]+8:[A-Z]+\d+\)/ }
    expect(total_formulas).not_to be_empty
    expect(xlsx.formulas.values).to all(satisfy { |f| f !~ /SUM\([A-Z]+6:/ })

    # (d) Header band merges follow the shift to rows 5/6/7 (were 3/4/5): the
    # "nhóm lớn" merges anchor on the shifted top header (row 5), and nothing
    # merges the now-empty old header rows 3/4.
    merge_start_row = ->(m) { m[/\A[A-Z]+(\d+):/, 1].to_i }
    expect(xlsx.merges.any? { |m| merge_start_row.call(m) == 5 }).to be(true)
    expect(xlsx.merges.none? { |m| [3, 4].include?(merge_start_row.call(m)) }).to be(true)
  end
end

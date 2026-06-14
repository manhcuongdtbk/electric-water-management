require "rails_helper"

RSpec.describe LossBreakdown do
  let(:sample) { setup_zone_one_full_sample }

  # Loss snapshot (meter_readings.loss + loss_summaries) chỉ tồn tại sau khi tính.
  before { CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

  subject(:result) { described_class.new(zone: sample.zone, period: sample.period).call }

  let(:summary) { LossSummary.find_by!(zone_id: sample.zone.id, period_id: sample.period.id) }

  def row_for(type)
    result.rows.find { |r| r.type == type }
  end

  it "CHIEU-breakdown-tong-theo-loai: Σ loại = B/C/A (raw)" do
    expect(result.rows.sum(&:usage)).to eq(summary.b)
    expect(result.rows.sum(&:loss)).to eq(summary.c)
    expect(result.loss_bearing_total.usage).to eq(summary.b)
    expect(result.loss_bearing_total.loss).to eq(summary.c)
    expect(result.loss_bearing_total.actual).to eq(summary.a)
  end

  it "khớp ví dụ mẫu #332 theo từng loại (usage thô + loss làm tròn 2 chữ số)" do
    expect(row_for("residential").usage).to eq(BigDecimal("1230"))
    expect(row_for("public").usage).to eq(BigDecimal("400"))
    expect(row_for("water_pump").usage).to eq(BigDecimal("300"))
    expect(row_for("residential").loss.round(2)).to eq(BigDecimal("38.24"))
    expect(row_for("public").loss.round(2)).to eq(BigDecimal("12.44"))
    expect(row_for("water_pump").loss.round(2)).to eq(BigDecimal("9.33"))
  end

  it "CHIEU-breakdown-doi-chieu-cong-to-tong: Tổng cộng/thực tế = công tơ tổng" do
    expect(result.grand_total.usage).to eq(BigDecimal("2040"))
    expect(result.grand_total.actual).to eq(sample.main_meter_reading.usage) # 2100
  end

  it "CHIEU-breakdown-khong-ton-hao: no_loss loại khỏi B; dòng Không tổn hao = Σ usage no_loss" do
    expect(result.no_loss_total.usage).to eq(BigDecimal("110"))
    expect(result.no_loss_total.loss).to eq(BigDecimal("0"))
    expect(result.no_loss_by_type["residential"]).to eq(BigDecimal("110"))
  end

  it "rows theo đúng thứ tự TYPE_ORDER" do
    expect(result.rows.map(&:type)).to eq(%w[residential public water_pump])
  end

  it "actual mỗi dòng = usage + loss" do
    result.rows.each do |r|
      expect(r.actual).to eq(r.usage + r.loss)
    end
  end

  it "CHIEU-breakdown-chua-tinh: chưa tính (không có LossSummary) → trả nil" do
    LossSummary.where(period: sample.period).delete_all
    expect(described_class.new(zone: sample.zone, period: sample.period).call).to be_nil
  end

  describe "CHIEU-breakdown-doi-chieu-sinh-hoat: khớp tổng cột bảng tính tiền" do
    let(:billing_summary) do
      ability = Ability.new(create(:user, :system_admin))
      scope = Billing::Query.apply_zone_unit_filter(
        Billing::Query.base_scope(sample.period, ability), zone: sample.zone, unit: nil
      )
      Billing::Query.summary(scope, period: sample.period)
    end

    it "Sinh hoạt/Tổn hao = TỔNG cột Tổn hao (loss_deduction)" do
      residential = row_for("residential")
      expect(residential.loss).to eq(BigDecimal(billing_summary[:loss_deduction].to_s))
    end

    it "(Sinh hoạt có-tổn-hao + Sinh hoạt không-tổn-hao) = TỔNG Sử dụng sinh hoạt (residential_usage)" do
      residential = row_for("residential")
      total = residential.usage + result.no_loss_by_type["residential"]
      expect(total).to eq(BigDecimal(billing_summary[:residential_usage].to_s))
    end
  end
end

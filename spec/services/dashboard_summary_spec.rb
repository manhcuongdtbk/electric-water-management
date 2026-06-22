require "rails_helper"

RSpec.describe DashboardSummary do
  let(:sample) { setup_zone_one_full_sample }
  before { CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call }

  describe "system_admin (T80)" do
    let(:user) { create(:user, :system_admin) }
    let(:ability) { Ability.new(user) }

    it "trả về list đơn vị với deficit_kw, deficit_amount, input_status" do
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      expect(summary.role).to eq(:system_admin)
      expect(summary.units.map { |d| d[:unit].name }).to include("Đơn vị A", "Đơn vị B")
      summary.units.each do |data|
        expect(data).to have_key(:deficit_kw)
        expect(data).to have_key(:deficit_amount)
        expect(data[:input_status]).to be_in(%i[entered pending])
      end
    end

    it "sort đơn vị theo deficit_kw giảm dần" do
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      deficits = summary.units.map { |d| d[:deficit_kw].to_f }
      expect(deficits).to eq(deficits.sort.reverse)
    end

    it "zones chứa public_usage = 400, pump_usage = 300 per khu vực" do
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      expect(summary.zones).to be_an(Array)
      zone_data = summary.zones.find { |z| z[:zone].id == sample.zone.id }
      expect(zone_data[:public_usage]).to eq_display("400.00")
      expect(zone_data[:pump_usage]).to eq_display("300.00")
    end
  end

  describe "unit_admin zone-manager (T81)" do
    let(:user) { create(:user, :unit_admin, unit: sample.unit_a) }
    let(:ability) { Ability.new(user) }

    it "deficit_count + surplus_count bao gồm cả đầu mối zone" do
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      # Đơn vị A có 3 contact (Ban Tác huấn, Văn thư, Kho vật tư) + Chỉ huy khu vực (zone) = 4
      # Theo T81: 2 thiếu (Ban Tác huấn, Chỉ huy khu vực), 2 thừa (Văn thư, Kho vật tư)
      expect(summary.deficit_count + summary.surplus_count).to eq(4)
      expect(summary.deficit_count).to eq(2)
      expect(summary.surplus_count).to eq(2)
    end

    it "deficit_kw, deficit_amount > 0" do
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      expect(summary.deficit_kw.to_f).to be > 0
      expect(summary.deficit_amount.to_f).to be > 0
    end

    it "input_status = :entered khi data đầy đủ" do
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      expect(summary.input_status).to eq(:entered)
    end
  end

  describe "unit_admin không phải zone-manager" do
    let(:user) { create(:user, :unit_admin, unit: sample.unit_b) }
    let(:ability) { Ability.new(user) }

    it "chỉ thấy đầu mối đơn vị mình, không thấy đầu mối khu vực" do
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      expect(summary.deficit_count + summary.surplus_count).to eq(1)
    end

    it "managed_zone_ids rỗng" do
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      expect(summary.managed_zone_ids).to be_empty
    end
  end

  describe "commander zone-manager" do
    let(:user) { create(:user, :commander, unit: sample.unit_a) }
    let(:ability) { Ability.new(user) }

    it "thấy đầu mối đơn vị + khu vực (như UA-ZM)" do
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      expect(summary.deficit_count + summary.surplus_count).to eq(4)
    end
  end

  describe "commander không phải zone-manager" do
    let(:user) { create(:user, :commander, unit: sample.unit_b) }
    let(:ability) { Ability.new(user) }

    it "chỉ thấy đầu mối đơn vị mình" do
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      expect(summary.deficit_count + summary.surplus_count).to eq(1)
    end
  end

  describe "role not system_admin/unit_admin/commander (line 15)" do
    let(:user) { create(:user, role: :technician) }
    let(:ability) { Ability.new(user) }

    it "returns minimal summary with role and empty warnings" do
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      expect(summary.role).to eq(:technician)
      expect(summary.warnings).to be_empty
    end
  end

  describe "unit_admin with no unit (line 68)" do
    it "returns summary with unit nil and empty warnings" do
      # Bypass validation to create a unit_admin without a unit (defensive guard)
      user = build(:user, role: :unit_admin, unit: nil)
      user.save!(validate: false)
      ability = Ability.new(user)
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      expect(summary.role).to eq(:unit_admin)
      expect(summary.unit).to be_nil
      expect(summary.warnings).to be_empty
    end
  end

  describe "T82 — warning tổn hao âm" do
    let(:user) { create(:user, :system_admin) }
    let(:ability) { Ability.new(user) }

    it "summary.warnings có subtotal_exceeds_main khi main meter quá nhỏ, có tên khu vực" do
      sample.main_meter_reading.update!(usage: 1900)
      summary = described_class.new(user: user, ability: ability, period: sample.period).call
      expect(summary.warnings.join(" ")).to include(sample.zone.name)
        .and include(I18n.t("services.loss_calculator.warnings.subtotal_exceeds_main"))
    end
  end
end

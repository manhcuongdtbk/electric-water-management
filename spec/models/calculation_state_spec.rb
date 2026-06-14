require "rails_helper"

RSpec.describe CalculationState, type: :model do
  let(:zone) { create(:zone) }
  let(:period) { create(:period) }

  describe "freshness state" do
    context "when last_calculated_at is nil" do
      subject(:state) do
        described_class.new(
          zone: zone,
          period: period,
          inputs_changed_at: Time.current,
          last_calculated_at: nil
        )
      end

      it "reports the never_calculated status" do
        expect(state.status).to eq(:never_calculated)
      end

      it "is not stale" do
        expect(state.stale?).to be(false)
      end

      it "is not fresh" do
        expect(state.fresh?).to be(false)
      end
    end

    context "when inputs changed before the calculation" do
      subject(:state) do
        described_class.new(
          zone: zone,
          period: period,
          inputs_changed_at: 2.hours.ago,
          last_calculated_at: 1.hour.ago
        )
      end

      it "reports the fresh status" do
        expect(state.status).to eq(:fresh)
      end

      it "is fresh" do
        expect(state.fresh?).to be(true)
      end

      it "is not stale" do
        expect(state.stale?).to be(false)
      end
    end

    context "when inputs changed after the calculation" do
      subject(:state) do
        described_class.new(
          zone: zone,
          period: period,
          inputs_changed_at: 1.hour.ago,
          last_calculated_at: 2.hours.ago
        )
      end

      it "reports the stale status" do
        expect(state.status).to eq(:stale)
      end

      it "is stale" do
        expect(state.stale?).to be(true)
      end

      it "is not fresh" do
        expect(state.fresh?).to be(false)
      end
    end

    context "when calculated and inputs_changed_at is nil" do
      subject(:state) do
        described_class.new(
          zone: zone,
          period: period,
          inputs_changed_at: nil,
          last_calculated_at: 1.hour.ago
        )
      end

      it "reports the fresh status" do
        expect(state.status).to eq(:fresh)
      end

      it "is fresh" do
        expect(state.fresh?).to be(true)
      end

      it "is not stale" do
        expect(state.stale?).to be(false)
      end
    end
  end

  describe "upsert writers (persistence)" do
    def row
      described_class.find_by(zone: zone, period: period)
    end

    it "merges touch_inputs! and mark_calculated! into one row with both timestamps set" do
      touched_at = 2.minutes.ago
      calculated_at = Time.current

      described_class.touch_inputs!(zone_id: zone.id, period_id: period.id, at: touched_at)
      described_class.mark_calculated!(zone_id: zone.id, period_id: period.id, at: calculated_at)

      expect(described_class.where(zone: zone, period: period).count).to eq(1)
      expect(row.inputs_changed_at).to be_within(1.second).of(touched_at)
      expect(row.last_calculated_at).to be_within(1.second).of(calculated_at)
    end

    it "does not reset last_calculated_at when touch_inputs! runs after mark_calculated! (clobber protection)" do
      calculated_at = 2.minutes.ago
      touched_at = Time.current

      described_class.mark_calculated!(zone_id: zone.id, period_id: period.id, at: calculated_at)
      described_class.touch_inputs!(zone_id: zone.id, period_id: period.id, at: touched_at)

      expect(row.last_calculated_at).to be_within(1.second).of(calculated_at)
      expect(row.inputs_changed_at).to be_within(1.second).of(touched_at)
    end

    it "does not reset inputs_changed_at when mark_calculated! runs after touch_inputs! (clobber protection)" do
      touched_at = 2.minutes.ago
      calculated_at = Time.current

      described_class.touch_inputs!(zone_id: zone.id, period_id: period.id, at: touched_at)
      described_class.mark_calculated!(zone_id: zone.id, period_id: period.id, at: calculated_at)

      expect(row.inputs_changed_at).to be_within(1.second).of(touched_at)
      expect(row.last_calculated_at).to be_within(1.second).of(calculated_at)
    end

    it "is idempotent for repeated touch_inputs! calls (still exactly one row)" do
      3.times do
        described_class.touch_inputs!(zone_id: zone.id, period_id: period.id, at: Time.current)
      end

      expect(described_class.where(zone: zone, period: period).count).to eq(1)
    end

    it "is idempotent for repeated mark_calculated! calls (still exactly one row)" do
      3.times do
        described_class.mark_calculated!(zone_id: zone.id, period_id: period.id, at: Time.current)
      end

      expect(described_class.where(zone: zone, period: period).count).to eq(1)
    end

    it "preserves created_at on a second call while advancing updated_at" do
      first_at = 2.minutes.ago
      second_at = Time.current

      described_class.touch_inputs!(zone_id: zone.id, period_id: period.id, at: first_at)
      original_created_at = row.created_at

      described_class.mark_calculated!(zone_id: zone.id, period_id: period.id, at: second_at)
      reloaded = row

      expect(reloaded.created_at).to be_within(1.second).of(original_created_at)
      expect(reloaded.updated_at).to be > original_created_at
      expect(reloaded.updated_at).to be_within(1.second).of(second_at)
    end
  end
end

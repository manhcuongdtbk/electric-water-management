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
end

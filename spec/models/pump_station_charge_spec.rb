require "rails_helper"

RSpec.describe PumpStationCharge do
  let(:sample) { setup_zone_one_full_sample }
  let(:recipient) { sample.contact_points[:ban_tac_huan] }
  let(:station) { sample.contact_points[:tram_bom_1] }

  it "thuộc về period, zone, contact_point (recipient) và pump_contact_point (trạm)" do
    charge = PumpStationCharge.new(period: sample.period, zone: sample.zone,
                                   contact_point: recipient, pump_contact_point: station,
                                   amount: BigDecimal("52.65"))
    expect(charge).to be_valid
    expect(charge.contact_point).to eq(recipient)
    expect(charge.pump_contact_point).to eq(station)
  end

  it "amount bắt buộc" do
    charge = PumpStationCharge.new(period: sample.period, zone: sample.zone,
                                   contact_point: recipient, pump_contact_point: station)
    expect(charge).not_to be_valid
    expect(charge.errors[:amount]).to be_present
  end
end

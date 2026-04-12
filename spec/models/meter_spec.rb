require "rails_helper"

RSpec.describe Meter, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:contact_point).optional }
    it { is_expected.to have_many(:meter_readings) }
    it { is_expected.to have_one(:pump_station) }
  end

  describe "validations" do
    subject { build(:meter) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
    it { is_expected.to validate_presence_of(:meter_type) }
    it { is_expected.to validate_uniqueness_of(:serial_number).allow_blank }
    it { is_expected.to validate_length_of(:serial_number).is_at_most(50) }

    it "is valid without a serial number" do
      expect(build(:meter, serial_number: nil)).to be_valid
    end

    it "is valid without a contact_point" do
      expect(build(:meter, contact_point: nil)).to be_valid
    end
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:meter_type)
        .with_values(normal: 0, public_meter: 1, pump_station: 2)
    }
  end

  describe "scopes" do
    let!(:org)    { create(:organization) }
    let!(:m_norm) { create(:meter, organization: org, meter_type: :normal) }
    let!(:m_pub)  { create(:meter, organization: org, meter_type: :public_meter) }
    let!(:m_ps)   { create(:meter, meter_type: :pump_station) }

    it ".by_organization filters correctly" do
      expect(Meter.by_organization(org.id)).to include(m_norm, m_pub)
      expect(Meter.by_organization(org.id)).not_to include(m_ps)
    end

    it ".by_type filters by meter_type" do
      expect(Meter.by_type(:normal)).to include(m_norm)
      expect(Meter.by_type(:normal)).not_to include(m_pub)
    end
  end
end

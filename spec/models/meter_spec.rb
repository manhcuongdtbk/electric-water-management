require "rails_helper"

RSpec.describe Meter, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to belong_to(:contact_point).optional }
    it { is_expected.to belong_to(:pump_station).optional }
    it { is_expected.to have_many(:meter_readings) }
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

  describe "pump_station consistency validation" do
    let(:org) { create(:organization) }
    let(:pump_station) { create(:pump_station, organization: org) }
    let(:contact_point) { create(:contact_point, organization: org) }

    context "for a pump_station meter" do
      it "is valid with pump_station and no contact_point" do
        meter = build(:meter, meter_type: :pump_station, organization: org,
                              pump_station: pump_station, contact_point: nil)
        expect(meter).to be_valid
      end

      it "is invalid when pump_station is missing" do
        meter = build(:meter, meter_type: :pump_station, organization: org,
                              pump_station: nil, contact_point: nil)
        expect(meter).not_to be_valid
        expect(meter.errors[:pump_station_id]).to be_present
      end

      it "is invalid when contact_point is set" do
        meter = build(:meter, meter_type: :pump_station, organization: org,
                              pump_station: pump_station, contact_point: contact_point)
        expect(meter).not_to be_valid
        expect(meter.errors[:contact_point_id]).to be_present
      end
    end

    context "for a non-pump_station meter" do
      it "is invalid when pump_station is set" do
        meter = build(:meter, meter_type: :normal, organization: org,
                              contact_point: contact_point, pump_station: pump_station)
        expect(meter).not_to be_valid
        expect(meter.errors[:pump_station_id]).to be_present
      end

      it "is valid without pump_station" do
        meter = build(:meter, meter_type: :normal, organization: org, contact_point: contact_point)
        expect(meter).to be_valid
      end
    end
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:meter_type)
        .with_values(normal: 0, public_meter: 1, pump_station: 2, no_loss: 3)
    }

    it "is valid with meter_type :no_loss" do
      expect(build(:meter, :no_loss)).to be_valid
    end
  end

  describe "CONTACT_POINT_FORM_TYPES" do
    it "lists every type selectable in the contact-point meter form" do
      expect(Meter::CONTACT_POINT_FORM_TYPES).to eq(%w[normal public_meter no_loss])
    end

    it "excludes pump_station so admin_unit cannot create those via the contact-point form" do
      expect(Meter::CONTACT_POINT_FORM_TYPES).not_to include("pump_station")
    end
  end

  describe "scopes" do
    let!(:org)    { create(:organization) }
    let!(:m_norm) { create(:meter, organization: org, meter_type: :normal) }
    let!(:m_pub)  { create(:meter, organization: org, meter_type: :public_meter) }
    let!(:m_ps)   { create(:meter, :pump_station) }

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

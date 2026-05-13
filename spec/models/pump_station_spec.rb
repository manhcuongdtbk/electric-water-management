require "rails_helper"

RSpec.describe PumpStation, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:zone) }
    it { is_expected.to have_many(:meters).dependent(:destroy) }
    it { is_expected.to have_many(:pump_station_assignments) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  describe "destroy cascade" do
    it "destroys its meters when destroyed" do
      ps = create(:pump_station)
      division = create(:organization, :division)
      m1 = create(:meter, :pump_station, organization: division, pump_station: ps)
      m2 = create(:meter, :pump_station, organization: division, pump_station: ps)

      expect { ps.destroy! }.to change(Meter, :count).by(-2)
      expect(Meter.where(id: [ m1.id, m2.id ])).to be_empty
    end
  end
end

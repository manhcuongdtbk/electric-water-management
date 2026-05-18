require "rails_helper"

RSpec.describe Zone do
  describe "associations" do
    it { is_expected.to have_many(:units) }
    it { is_expected.to have_many(:contact_points).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:main_meters).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:pump_allocations).dependent(:restrict_with_error) }
    it { is_expected.to belong_to(:manager_unit).class_name("Unit").optional }
  end

  describe "validations" do
    subject { build(:zone) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
  end

  describe "nested main_meters (T27, T28)" do
    it "tạo khu vực kèm công tơ tổng qua nested attributes" do
      zone = Zone.new(name: "Khu vực 1",
                      main_meters_attributes: [{ name: "CT-Tổng-KV1" }])
      expect(zone.save).to be true
      expect(zone.main_meters.count).to eq(1)
      expect(zone.main_meters.first.name).to eq("CT-Tổng-KV1")
    end

    it "không cho tạo khu vực khi thiếu công tơ tổng (T28)" do
      zone = Zone.new(name: "Khu vực 2")
      expect(zone.save).to be false
      expect(zone.errors[:base]).to include(
        I18n.t("activerecord.errors.models.zone.attributes.base.must_have_at_least_one_main_meter")
      )
    end

    it "không cho tạo khi nested attributes có tên trống" do
      zone = Zone.new(name: "Khu vực 3",
                      main_meters_attributes: [{ name: "" }])
      expect(zone.save).to be false
    end
  end

  describe "before_destroy :ensure_no_kept_units (T40)" do
    it "không cho xóa khu vực còn đơn vị kept" do
      zone = Zone.create!(name: "Khu vực 4",
                          main_meters_attributes: [{ name: "CT" }])
      create(:unit, zone: zone)
      MainMeter.where(zone_id: zone.id).delete_all
      zone.reload
      expect(zone.destroy).to be false
      expect(zone.errors[:base]).to include(
        I18n.t("activerecord.errors.models.zone.attributes.base.has_kept_units")
      )
    end
  end
end

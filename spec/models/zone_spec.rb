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

  describe "before_discard :ensure_no_kept_dependents (T40)" do
    it "không cho discard khu vực còn đơn vị kept" do
      zone = Zone.create!(name: "Khu vực 4",
                          main_meters_attributes: [{ name: "CT" }])
      create(:unit, zone: zone)
      expect(zone.discard).to be false
      expect(zone.errors[:base]).to include(
        I18n.t("activerecord.errors.models.zone.attributes.base.has_kept_units")
      )
      expect(zone.reload.discarded_at).to be_nil
    end

    it "không cho discard khu vực còn đầu mối trực tiếp kept" do
      zone = Zone.create!(name: "Khu vực 5",
                          main_meters_attributes: [{ name: "CT" }])
      cp = ContactPoint.new(name: "Trạm bơm A",
                            contact_point_type: "water_pump",
                            zone: zone)
      cp.meters.build(name: "Công tơ bơm 1")
      cp.save!
      expect(zone.discard).to be false
      expect(zone.errors[:base]).to include(
        I18n.t("activerecord.errors.models.zone.attributes.base.has_kept_contact_points")
      )
      expect(zone.reload.discarded_at).to be_nil
    end
  end

  describe "before_discard :discard_main_meters (v2.3.0)" do
    it "cascade discard các main_meters thuộc zone khi discard zone" do
      zone = Zone.create!(name: "Khu vực 6",
                          main_meters_attributes: [{ name: "CT-Tổng-1" }, { name: "CT-Tổng-2" }])
      expect(zone.main_meters.kept.count).to eq(2)
      expect(zone.discard).to be true
      expect(zone.reload.discarded_at).not_to be_nil
      expect(zone.main_meters.kept).to be_empty
      expect(zone.main_meters.with_discarded.count).to eq(2)
    end
  end

  describe ".kept scope (v2.3.0)" do
    it "không trả zones đã discard" do
      zone = Zone.create!(name: "Khu vực 7",
                          main_meters_attributes: [{ name: "CT" }])
      expect(Zone.kept).to include(zone)
      zone.discard
      expect(Zone.kept).not_to include(zone)
      expect(Zone.with_discarded).to include(zone)
    end
  end
end

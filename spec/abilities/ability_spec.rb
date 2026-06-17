require "rails_helper"
require "cancan/matchers"

RSpec.describe Ability do
  describe "khi user nil" do
    it "không có quyền nào" do
      ability = Ability.new(nil)
      expect(ability).not_to be_able_to(:read, Zone.new)
      expect(ability).not_to be_able_to(:manage, User.new)
    end
  end

  describe "khi user force_password_change" do
    it "chỉ có quyền update chính mình" do
      user = create(:user, :system_admin)
      user.update_column(:force_password_change, true)
      ability = Ability.new(user)
      expect(ability).to be_able_to(:update, user)
      expect(ability).not_to be_able_to(:read, Zone.new)
      expect(ability).not_to be_able_to(:manage, ContactPoint.new)
    end
  end

  describe "technician" do
    let(:user) { create(:user) }
    subject(:ability) { Ability.new(user) }

    it "manage được tất cả User (kể cả technician khác)" do
      expect(ability).to be_able_to(:manage, User.new)
    end

    it "đọc audit logs" do
      expect(ability).to be_able_to(:read, PaperTrail::Version.new)
    end

    it "không truy cập data nghiệp vụ" do
      expect(ability).not_to be_able_to(:read, ContactPoint.new)
      expect(ability).not_to be_able_to(:read, Zone.new)
      expect(ability).not_to be_able_to(:read, MeterReading.new)
    end
  end

  describe "system_admin" do
    let(:user) { create(:user, :system_admin) }
    subject(:ability) { Ability.new(user) }

    it "manage business models" do
      [Zone, Unit, ContactPoint, Meter, MainMeter, Block, Group,
       Period, Rank, PumpAllocation,
       MeterReading, MainMeterReading, PersonnelEntry,
       NonEstablishmentSnapshot, UnitConfig, OtherDeduction].each do |klass|
        expect(ability).to be_able_to(:manage, klass.new), "Expected manage #{klass}"
      end
    end

    it "đọc + manage user role unit_admin/commander/system_admin" do
      %i[system_admin unit_admin commander].each do |role|
        u = build(:user, role)
        expect(ability).to be_able_to(:manage, u), "Expected manage user role #{role}"
      end
    end

    it "đọc được technician (xem trong danh sách)" do
      tech = build(:user)
      expect(ability).to be_able_to(:read, tech)
    end

    it "không create/update/destroy technician (T66)" do
      tech = build(:user)
      expect(ability).not_to be_able_to(:create, tech)
      expect(ability).not_to be_able_to(:update, tech)
      expect(ability).not_to be_able_to(:destroy, tech)
    end
  end

  describe "unit_admin không phải zone-manager" do
    let(:zone) { create(:zone) }
    let!(:first_unit) { create(:unit, zone: zone) }
    let!(:my_unit) { create(:unit, zone: zone) }
    let(:user) { create(:user, :unit_admin, unit: my_unit) }
    subject(:ability) { Ability.new(user) }

    it "đọc đơn vị mình" do
      expect(ability).to be_able_to(:read, my_unit)
    end

    it "không đọc đơn vị khác" do
      expect(ability).not_to be_able_to(:read, first_unit)
    end

    it "CRUD contact_point đơn vị mình" do
      cp = build(:contact_point, :residential, unit: my_unit)
      expect(ability).to be_able_to(:create, cp)
      expect(ability).to be_able_to(:read, cp)
      expect(ability).to be_able_to(:update, cp)
      expect(ability).to be_able_to(:destroy, cp)
    end

    it "không CRUD contact_point đơn vị khác (T61)" do
      cp_other = build(:contact_point, :residential, unit: first_unit)
      expect(ability).not_to be_able_to(:create, cp_other)
      expect(ability).not_to be_able_to(:update, cp_other)
    end

    it "không truy cập main_meter_readings (không phải zone-manager)" do
      mm = create(:main_meter, zone: zone)
      reading = build(:main_meter_reading, main_meter: mm)
      expect(ability).not_to be_able_to(:update, reading)
    end

    it "không quản lý pump_allocations (chỉ system_admin)" do
      alloc = build(:pump_allocation, zone: zone, unit: my_unit, contact_point: nil)
      expect(ability).not_to be_able_to(:create, alloc)
      expect(ability).not_to be_able_to(:update, alloc)
    end

    it "không quản lý zones (read-only ở UI)" do
      expect(ability).not_to be_able_to(:update, zone)
      expect(ability).not_to be_able_to(:create, Zone.new)
    end

    it "KHÔNG đọc được zone (không quản lý khu vực → không có quyền :read Zone)" do
      expect(ability).not_to be_able_to(:read, zone)
    end

    it "đọc đơn vị mình" do
      expect(ability).to be_able_to(:read, my_unit)
    end
  end

  describe "unit_admin là zone-manager (T62)" do
    let(:zone) { create(:zone) }
    let!(:my_unit) { create(:unit, zone: zone) }
    let(:user) { create(:user, :unit_admin, unit: my_unit) }
    subject(:ability) { Ability.new(user) }

    it "đọc + update main_meter_readings của zone mình" do
      mm = create(:main_meter, zone: zone)
      reading = build(:main_meter_reading, main_meter: mm)
      expect(ability).to be_able_to(:read, reading)
      expect(ability).to be_able_to(:update, reading)
    end

    it "đọc + update meter_readings công tơ bơm nước thuộc zone" do
      cp = create(:contact_point, :water_pump, zone: zone)
      meter = create(:meter, contact_point: cp)
      reading = build(:meter_reading, meter: meter)
      expect(ability).to be_able_to(:update, reading)
    end

    it "đọc + update personnel_entries đầu mối sinh hoạt thuộc khu vực" do
      cp_zone_res = create(:contact_point, :zone_residential, zone: zone)
      period = create(:period, closed: false)
      rank = create(:rank, period: period, position: 1, name: "R1")
      entry = PersonnelEntry.create!(contact_point: cp_zone_res, period: period, rank: rank, count: 1)
      expect(ability).to be_able_to(:update, entry)
    end

    it "CRUD pump_allocations khu vực mình quản lý" do
      alloc = build(:pump_allocation, zone: zone, unit: my_unit, contact_point: nil)
      expect(ability).to be_able_to(:create, alloc)
      expect(ability).to be_able_to(:read, alloc)
      expect(ability).to be_able_to(:update, alloc)
      expect(ability).to be_able_to(:destroy, alloc)
    end
  end

  describe "commander (T63)" do
    let(:zone) { create(:zone) }
    let!(:my_unit) { create(:unit, zone: zone) }
    let(:user) { create(:user, :commander, unit: my_unit) }
    subject(:ability) { Ability.new(user) }

    it "đọc đơn vị mình" do
      expect(ability).to be_able_to(:read, my_unit)
    end

    it "đọc contact_point đơn vị mình" do
      cp = build(:contact_point, :residential, unit: my_unit)
      expect(ability).to be_able_to(:read, cp)
    end

    it "không tạo/sửa contact_point" do
      cp = build(:contact_point, :residential, unit: my_unit)
      expect(ability).not_to be_able_to(:create, cp)
      expect(ability).not_to be_able_to(:update, cp)
    end

    it "không nhập meter_readings" do
      cp = build(:contact_point, :residential, unit: my_unit)
      meter = build(:meter, contact_point: cp)
      reading = build(:meter_reading, meter: meter)
      expect(ability).not_to be_able_to(:update, reading)
    end
  end

  describe "commander zone-manager (CMD-ZM)" do
    let(:zone) { create(:zone) }
    let!(:my_unit) { create(:unit, zone: zone) }
    let(:user) { create(:user, :commander, unit: my_unit) }
    subject(:ability) { Ability.new(user) }

    it "đọc contact_point thuộc khu vực" do
      cp = build(:contact_point, :zone_residential, zone: zone)
      expect(ability).to be_able_to(:read, cp)
    end

    it "không tạo/sửa contact_point thuộc khu vực" do
      cp = build(:contact_point, :zone_residential, zone: zone)
      expect(ability).not_to be_able_to(:create, cp)
      expect(ability).not_to be_able_to(:update, cp)
    end

    it "đọc main_meter khu vực mình" do
      mm = create(:main_meter, zone: zone)
      expect(ability).to be_able_to(:read, mm)
    end

    it "đọc main_meter_readings khu vực mình" do
      mm = create(:main_meter, zone: zone)
      reading = build(:main_meter_reading, main_meter: mm)
      expect(ability).to be_able_to(:read, reading)
    end

    it "không sửa main_meter_readings" do
      mm = create(:main_meter, zone: zone)
      reading = build(:main_meter_reading, main_meter: mm)
      expect(ability).not_to be_able_to(:update, reading)
    end

    it "đọc pump_allocations khu vực mình" do
      alloc = build(:pump_allocation, zone: zone, unit: my_unit, contact_point: nil)
      expect(ability).to be_able_to(:read, alloc)
    end

    it "không CRUD pump_allocations" do
      alloc = build(:pump_allocation, zone: zone, unit: my_unit, contact_point: nil)
      expect(ability).not_to be_able_to(:create, alloc)
      expect(ability).not_to be_able_to(:update, alloc)
    end

    it "đọc calculations khu vực mình" do
      cp = create(:contact_point, :zone_residential, zone: zone)
      period = create(:period, closed: false)
      calc = create(:calculation, contact_point: cp, period: period)
      expect(ability).to be_able_to(:read, calc)
    end

    it "không recalculate" do
      expect(ability).not_to be_able_to(:recalculate, Calculation.new)
    end
  end

  describe "unknown role" do
    it "grants no abilities for an unrecognized role" do
      user = create(:user)
      user.define_singleton_method(:role) { "unknown_role" }
      ability = Ability.new(user)
      expect(ability).not_to be_able_to(:read, Zone.new)
      expect(ability).not_to be_able_to(:manage, User.new)
      expect(ability).not_to be_able_to(:read, ContactPoint.new)
    end
  end

  describe "Calculation accessible_by + :recalculate" do
    let(:zone_a) { create(:zone, name: "Zone A") }
    let(:zone_b) { create(:zone, name: "Zone B") }
    let(:unit_a) { create(:unit, zone: zone_a) }
    let(:unit_b) { create(:unit, zone: zone_b) }
    let(:period) { create(:period, closed: false) }
    let(:cp_a) { create(:contact_point, :residential, unit: unit_a) }
    let(:cp_b) { create(:contact_point, :residential, unit: unit_b) }
    let!(:calc_a) { create(:calculation, contact_point: cp_a, period: period) }
    let!(:calc_b) { create(:calculation, contact_point: cp_b, period: period) }

    it "system_admin :recalculate cho mọi Calculation" do
      admin = create(:user, :system_admin)
      expect(Ability.new(admin)).to be_able_to(:recalculate, Calculation.new)
    end

    it "unit_admin A KHÔNG read được calc của unit B (T87)" do
      ua = create(:user, :unit_admin, unit: unit_a)
      ability = Ability.new(ua)
      accessible_ids = Calculation.accessible_by(ability).pluck(:id)
      expect(accessible_ids).to include(calc_a.id)
      expect(accessible_ids).not_to include(calc_b.id)
    end

    it "unit_admin :recalculate calc đơn vị mình" do
      ua = create(:user, :unit_admin, unit: unit_a)
      expect(Ability.new(ua)).to be_able_to(:recalculate, calc_a)
      expect(Ability.new(ua)).not_to be_able_to(:recalculate, calc_b)
    end

    it "commander KHÔNG :recalculate" do
      cmd = create(:user, :commander, unit: unit_a)
      expect(Ability.new(cmd)).not_to be_able_to(:recalculate, calc_a)
    end
  end
end

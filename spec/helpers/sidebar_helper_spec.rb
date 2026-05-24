require "rails_helper"

RSpec.describe SidebarHelper, type: :helper do
  let(:zone) { create(:zone) }
  let!(:manager_unit) { create(:unit, zone: zone) }
  let!(:other_unit) { create(:unit, zone: zone) }

  def items_for(user)
    allow(helper).to receive(:current_user).and_return(user)
    zone_manager = user.unit_id.present? && Zone.kept.exists?(manager_unit_id: user.unit_id)
    # current_zone_manager? is defined on ApplicationController, need to define on helper for testing
    helper.define_singleton_method(:current_zone_manager?) { zone_manager }
    helper.allowed_sidebar_items
  end

  describe "#allowed_sidebar_items" do
    it "SA: 17 items (tất cả trừ backups)" do
      sa = create(:user, :system_admin)
      items = items_for(sa)
      expect(items.size).to eq(17)
      expect(items).to include(:dashboard, :billing, :contact_points, :zones, :units, :pricing, :users)
      expect(items).not_to include(:backups)
    end

    it "TECH: 3 items (users, audit_logs, backups)" do
      tech = create(:user, :technician)
      items = items_for(tech)
      expect(items).to contain_exactly(:users, :audit_logs, :backups)
    end

    it "UA (non-ZM): 8 items — không có electricity_supply, pump_entries, zones, pump_allocations" do
      ua = create(:user, :unit_admin, unit: other_unit)
      items = items_for(ua)
      expect(items.size).to eq(8)
      expect(items).to include(:dashboard, :billing, :meter_entries, :contact_points, :unit_config)
      expect(items).not_to include(:electricity_supply, :pump_entries, :zones, :pump_allocations)
    end

    it "UA-ZM: 12 items — thêm electricity_supply, pump_entries, zones, pump_allocations" do
      ua_zm = create(:user, :unit_admin, unit: manager_unit)
      items = items_for(ua_zm)
      expect(items.size).to eq(12)
      expect(items).to include(:electricity_supply, :pump_entries, :zones, :pump_allocations)
    end

    it "CMD (non-ZM): 8 items — có meter_entries, không có pump_entries" do
      cmd = create(:user, :commander, unit: other_unit)
      items = items_for(cmd)
      expect(items.size).to eq(8)
      expect(items).to include(:dashboard, :billing, :history, :meter_entries, :contact_points, :blocks, :groups, :unit_config)
      expect(items).not_to include(:pump_entries, :electricity_supply)
    end

    it "CMD-ZM: 11 items — thêm pump_entries, zones, pump_allocations" do
      cmd_zm = create(:user, :commander, unit: manager_unit)
      items = items_for(cmd_zm)
      expect(items.size).to eq(11)
      expect(items).to include(:meter_entries, :pump_entries, :zones, :pump_allocations, :unit_config)
      expect(items).not_to include(:electricity_supply)
    end
  end
end

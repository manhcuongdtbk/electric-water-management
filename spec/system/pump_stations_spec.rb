require "rails_helper"

# Quản lý trạm bơm — admin_level1 setup từ zero qua UI:
# tạo trạm bơm → thêm/xoá công tơ → gán/bỏ gán đơn vị → nhập chỉ số.
RSpec.describe "Pump stations management", type: :system do
  let(:scenario) { setup_basic_scenario }

  describe "admin_level1" do
    before { login_as scenario.admin_level1, scope: :user }

    it "tạo trạm bơm mới + công tơ đầu tiên trong cùng một bước" do
      scenario
      zone = create(:zone, name: "Khu vực bơm A")
      visit pump_stations_path
      click_on I18n.t("pump_stations.index.new_button")

      fill_in I18n.t("pump_stations.form.name"), with: "Trạm bơm A"
      select zone.name, from: I18n.t("pump_stations.form.zone")
      fill_in I18n.t("pump_stations.form.first_meter_name"), with: "CT01 đầu vào"
      click_on I18n.t("pump_stations.form.submit_create")

      expect(page).to have_current_path(pump_stations_path)
      expect(page).to have_content(I18n.t("flash.pump_stations.created"))
      expect(page).to have_content("Trạm bơm A")
      expect(page).to have_content("CT01 đầu vào")

      ps = PumpStation.find_by!(name: "Trạm bơm A")
      expect(ps.zone).to eq(zone)
      expect(ps.meters.count).to eq(1)
      expect(ps.meters.first.meter_type).to eq("pump_station")
      expect(ps.meters.first.organization).to eq(scenario.division)
    end

    it "thêm + xoá công tơ; chặn xoá công tơ cuối cùng" do
      ps = create(:pump_station, name: "Trạm B")
      create(:meter, :pump_station,
             pump_station: ps, organization: scenario.division, name: "CT gốc")

      visit pump_stations_path
      within("[data-pump-station-id='#{ps.id}']") do
        click_on I18n.t("pump_stations.index.add_meter")
      end

      fill_in I18n.t("pump_station_meters.form.name"), with: "CT phụ"
      click_on I18n.t("pump_station_meters.form.submit_create")

      expect(page).to have_content(I18n.t("flash.pump_station_meters.created"))
      expect(ps.meters.pluck(:name)).to contain_exactly("CT gốc", "CT phụ")

      # Xoá CT phụ → success
      visit pump_stations_path
      within("tr", text: "CT phụ") do
        click_button I18n.t("pump_station_meters.actions.delete")
      end
      expect(page).to have_content(I18n.t("flash.pump_station_meters.destroyed"))

      # Xoá CT gốc (cuối cùng) → bị chặn
      within("tr", text: "CT gốc") do
        click_button I18n.t("pump_station_meters.actions.delete")
      end
      expect(page).to have_content(I18n.t("flash.pump_station_meters.cannot_destroy_last_meter"))
      expect(ps.reload.meters.count).to eq(1)
    end

    it "gán + bỏ gán đơn vị cho trạm bơm" do
      ps = create(:pump_station, name: "Trạm C", zone: scenario.unit.zone)
      create(:meter, :pump_station,
             pump_station: ps, organization: scenario.division)

      visit pump_stations_path
      within("[data-pump-station-id='#{ps.id}']") do
        click_on I18n.t("pump_stations.index.add_assignment")
      end

      select scenario.unit.name, from: I18n.t("pump_station_assignments.form.organization")
      fill_in I18n.t("pump_station_assignments.form.fixed_pump_percentage"), with: "30"
      click_on I18n.t("pump_station_assignments.form.submit_create")

      expect(page).to have_content(I18n.t("flash.pump_station_assignments.created"))
      asg = ps.pump_station_assignments.find_by(assignable_type: "Organization",
                                                assignable_id: scenario.unit.id)
      expect(asg).to be_present
      expect(asg.fixed_pump_percentage).to eq(BigDecimal("30"))

      visit pump_stations_path
      within("tr", text: scenario.unit.name) do
        click_button I18n.t("pump_station_assignments.actions.delete")
      end
      expect(page).to have_content(I18n.t("flash.pump_station_assignments.destroyed"))
      expect(PumpStationAssignment.exists?(asg.id)).to be false
    end

    it "nhập chỉ số công tơ trạm bơm cho kỳ và lưu thành công" do
      ps = create(:pump_station, name: "Trạm D")
      meter = create(:meter, :pump_station,
                     pump_station: ps,
                     organization: scenario.division,
                     name: "CT D1")

      visit pump_station_readings_path
      expect(page).to have_content(I18n.t("pump_station_readings.show.title"))

      fill_in "readings[#{meter.id}][reading_start]", with: "100"
      fill_in "readings[#{meter.id}][reading_end]",   with: "350"
      click_on I18n.t("pump_station_readings.save_all")

      expect(page).to have_content(I18n.t("flash.pump_station_readings.saved"))
      reading = MeterReading.find_by!(meter: meter, monthly_period: scenario.period)
      expect(reading.consumption).to eq(BigDecimal("250"))
    end

    it "không xoá được trạm bơm có dữ liệu chỉ số (bảo toàn lịch sử)" do
      ps = create(:pump_station, name: "Trạm E")
      meter = create(:meter, :pump_station,
                     pump_station: ps, organization: scenario.division)
      create(:meter_reading,
             meter: meter, monthly_period: scenario.period,
             reading_start: 0, reading_end: 100)

      visit pump_stations_path
      within("[data-pump-station-id='#{ps.id}']") do
        # First "Xoá" button in the card is the pump-station delete (header bar);
        # subsequent "Xoá" buttons belong to meter rows.
        first("button", text: I18n.t("pump_stations.actions.delete")).click
      end

      expect(page).to have_content(I18n.t("flash.pump_stations.cannot_destroy_with_readings"))
      expect(PumpStation.exists?(ps.id)).to be true
    end
  end

  describe "admin_unit" do
    before { login_as scenario.admin_unit, scope: :user }

    it "không truy cập được trang quản lý trạm bơm" do
      visit pump_stations_path
      expect(page).to have_current_path(root_path)
    end

    it "không truy cập được trang nhập chỉ số trạm bơm" do
      visit pump_station_readings_path
      expect(page).to have_current_path(root_path)
    end
  end

  describe "commander" do
    before { login_as scenario.commander, scope: :user }

    it "không truy cập được trang quản lý trạm bơm" do
      visit pump_stations_path
      expect(page).to have_current_path(root_path)
    end
  end
end

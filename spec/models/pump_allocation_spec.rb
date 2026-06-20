require "rails_helper"

RSpec.describe PumpAllocation do
  describe "associations" do
    it { is_expected.to belong_to(:zone) }
    it { is_expected.to belong_to(:period) }
    it { is_expected.to belong_to(:unit).optional }
    it { is_expected.to belong_to(:block).optional }
    it { is_expected.to belong_to(:group).optional }
    it { is_expected.to belong_to(:contact_point).optional }
    it { is_expected.to belong_to(:pump_contact_point).class_name("ContactPoint").optional }
  end

  describe "validations" do
    subject { build(:pump_allocation) }

    it { is_expected.to validate_presence_of(:coefficient) }
    it { is_expected.to validate_numericality_of(:coefficient).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:fixed_percentage).is_greater_than_or_equal_to(0).is_less_than_or_equal_to(100).allow_nil }

    it "cho phép coefficient = 0 (T112)" do
      allocation = build(:pump_allocation, coefficient: 0)
      expect(allocation).to be_valid
    end

    describe "đúng một recipient" do
      it "hợp lệ với unit và không có recipient khác" do
        allocation = build(:pump_allocation)
        expect(allocation).to be_valid
      end

      it "hợp lệ với contact_point và không có recipient khác" do
        allocation = build(:pump_allocation, :for_contact_point)
        expect(allocation).to be_valid
      end

      it "không hợp lệ khi có hai recipient (unit + contact_point)" do
        allocation = build(:pump_allocation, contact_point: create(:contact_point, :residential))
        expect(allocation).not_to be_valid
        expect(allocation.errors[:base])
          .to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.base.recipient_must_be_one"))
      end

      it "không hợp lệ khi không có recipient nào" do
        allocation = build(:pump_allocation, unit: nil, contact_point: nil, block: nil, group: nil)
        expect(allocation).not_to be_valid
        expect(allocation.errors[:base])
          .to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.base.recipient_required"))
      end
    end

    describe "tổng fixed_percentage trong cùng zone+period không vượt quá 100" do
      let(:zone) { create(:zone) }
      let(:period) { create(:period, closed: true) }
      let(:unit_one) { u = create(:unit, zone: zone); create(:contact_point, :residential, unit: u, name: "ĐM fp1"); u }
      let(:unit_two) { u = create(:unit, zone: zone); create(:contact_point, :residential, unit: u, name: "ĐM fp2"); u }
      let(:unit_three) { u = create(:unit, zone: zone); create(:contact_point, :residential, unit: u, name: "ĐM fp3"); u }

      it "hợp lệ khi tổng = 100" do
        create(:pump_allocation, zone: zone, period: period, unit: unit_one, fixed_percentage: 60)
        allocation = build(:pump_allocation, zone: zone, period: period, unit: unit_two, fixed_percentage: 40)
        expect(allocation).to be_valid
      end

      it "không hợp lệ khi tổng > 100" do
        create(:pump_allocation, zone: zone, period: period, unit: unit_one, fixed_percentage: 60)
        allocation = build(:pump_allocation, zone: zone, period: period, unit: unit_two, fixed_percentage: 41)
        expect(allocation).not_to be_valid
        expect(allocation.errors[:base])
          .to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.base.fixed_percentage_sum_exceeds_one_hundred"))
      end

      it "không tính chính bản ghi đang update" do
        allocation = create(:pump_allocation, zone: zone, period: period, unit: unit_one, fixed_percentage: 70)
        allocation.fixed_percentage = 80
        expect(allocation).to be_valid
      end

      it "không ảnh hưởng giữa các zone khác nhau" do
        other_zone = create(:zone)
        other_unit = create(:unit, zone: other_zone)
        create(:contact_point, :residential, unit: other_unit, name: "ĐM other zone")
        create(:pump_allocation, zone: other_zone, period: period, unit: other_unit, fixed_percentage: 90)
        allocation = build(:pump_allocation, zone: zone, period: period, unit: unit_one, fixed_percentage: 90)
        expect(allocation).to be_valid
      end

      it "không ảnh hưởng giữa các period khác nhau" do
        # Dùng năm xa để tránh đụng sequence của :period factory.
        other_period = create(:period, year: 2099, month: 12, closed: true)
        create(:pump_allocation, zone: zone, period: other_period, unit: unit_one, fixed_percentage: 90)
        allocation = build(:pump_allocation, zone: zone, period: period, unit: unit_one, fixed_percentage: 90)
        expect(allocation).to be_valid
      end

      it "không cấm khi fixed_percentage = nil" do
        create(:pump_allocation, zone: zone, period: period, unit: unit_one, fixed_percentage: 100)
        allocation = build(:pump_allocation, zone: zone, period: period, unit: unit_two, fixed_percentage: nil, coefficient: 2)
        expect(allocation).to be_valid
      end
    end
  end

  # TN2 nới ràng buộc: contact_point recipient không còn bắt buộc zone-level.
  # Đầu mối sinh hoạt thuộc đơn vị giờ được phép nhận phân bổ trực tiếp.
  describe "contact_point recipient (nới ràng buộc TN2)" do
    let(:zone) { create(:zone) }
    let(:unit) { create(:unit, zone: zone) }
    let(:period) { create(:period, closed: false) }

    it "cho phép CP thuộc đơn vị (residential unit-level)" do
      unit_cp = create(:contact_point, :residential, unit: unit)
      alloc = build(:pump_allocation, zone: zone, period: period, contact_point: unit_cp, unit: nil)
      expect(alloc).to be_valid
    end

    it "cho phép CP thuộc khu vực (zone-level)" do
      zone_cp = create(:contact_point, :zone_residential, zone: zone)
      alloc = build(:pump_allocation, zone: zone, period: period, contact_point: zone_cp, unit: nil)
      expect(alloc).to be_valid
    end
  end

  describe "validate_target_belongs_to_zone (I5)" do
    let(:zone_a) { create(:zone) }
    let(:zone_b) { create(:zone) }
    let(:unit_a) { create(:unit, zone: zone_a) }
    let(:period) { create(:period, closed: false) }

    it "chặn unit thuộc zone khác" do
      unit_b = create(:unit, zone: zone_b)
      alloc = build(:pump_allocation, zone: zone_a, period: period, unit: unit_b, contact_point: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:unit_id]).to be_present
    end

    it "chặn CP thuộc zone khác" do
      cp_b = create(:contact_point, :zone_residential, zone: zone_b)
      alloc = build(:pump_allocation, zone: zone_a, period: period, contact_point: cp_b, unit: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:contact_point_id]).to be_present
    end

    it "chặn khối thuộc zone khác" do
      block_b = create(:block, unit: create(:unit, zone: zone_b))
      alloc = build(:pump_allocation, zone: zone_a, period: period, unit: nil, block: block_b)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:block_id]).to be_present
    end

    it "chặn nhóm thuộc zone khác" do
      group_b = create(:group, unit: create(:unit, zone: zone_b))
      alloc = build(:pump_allocation, zone: zone_a, period: period, unit: nil, group: group_b)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:group_id]).to be_present
    end

    it "cho phép khối/nhóm cùng zone (nhánh hợp lệ)" do
      block_a = create(:block, unit: unit_a)
      create(:contact_point, :residential, unit: unit_a, block: block_a, name: "ĐM khối A")
      alloc = build(:pump_allocation, zone: zone_a, period: period, unit: nil, block: block_a)
      expect(alloc).to be_valid
    end
  end

  # CHIEU-phan-bo-tram-bon-recipient: bốn loại recipient hợp lệ (đơn vị/khối/nhóm/đầu mối).
  # CHIEU-phan-bo-tram-rang-buoc: đúng một recipient; Σ fixed% ≤ 100 theo từng trạm;
  #   pump_contact_point bắt buộc + phải là water_pump cùng zone trên kỳ per-trạm.
  describe "TN2 — recipient bốn loại & per-trạm" do
    let(:zone) { create(:zone, name: "KV TN2") }
    let!(:period) { create(:period, closed: false, pump_allocation_per_station: true) }
    let(:unit) do
      u = create(:unit, zone: zone)
      create(:contact_point, :residential, unit: u, name: "ĐM TN2")
      u
    end
    let(:block) do
      b = create(:block, unit: unit)
      create(:contact_point, :residential, unit: unit, block: b, name: "ĐM khối TN2")
      b
    end
    let(:group) do
      g = create(:group, unit: unit)
      create(:contact_point, :residential, unit: unit, group: g, name: "ĐM nhóm TN2")
      g
    end
    let(:station) { create(:contact_point, :water_pump, name: "Trạm 1", zone: zone) }

    def base_attrs
      { zone: zone, period: period, coefficient: 1, pump_contact_point: station }
    end

    it "hợp lệ khi đúng một recipient = khối" do
      alloc = build(:pump_allocation, **base_attrs, unit: nil, contact_point: nil, block: block, group: nil)
      expect(alloc).to be_valid
    end

    it "không hợp lệ khi không có recipient nào" do
      alloc = build(:pump_allocation, **base_attrs, unit: nil, contact_point: nil, block: nil, group: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:base]).to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.base.recipient_required"))
    end

    it "không hợp lệ khi có hai recipient (đơn vị + khối)" do
      alloc = build(:pump_allocation, **base_attrs, unit: unit, contact_point: nil, block: block, group: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:base]).to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.base.recipient_must_be_one"))
    end

    it "cho phép contact_point recipient là residential thuộc đơn vị (nới ràng buộc)" do
      cp = create(:contact_point, :residential, unit: unit)
      alloc = build(:pump_allocation, **base_attrs, unit: nil, contact_point: cp, block: nil, group: nil)
      expect(alloc).to be_valid
    end

    it "kỳ per-trạm: thiếu pump_contact_point → chặn" do
      alloc = build(:pump_allocation, zone: zone, period: period, coefficient: 1,
                    pump_contact_point: nil, unit: unit, contact_point: nil, block: nil, group: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:pump_contact_point_id]).to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.pump_contact_point_id.required_for_station"))
    end

    it "kỳ per-trạm: pump_contact_point phải là water_pump cùng zone" do
      not_pump = create(:contact_point, :residential, unit: unit)
      alloc = build(:pump_allocation, zone: zone, period: period, coefficient: 1,
                    pump_contact_point: not_pump, unit: unit, contact_point: nil, block: nil, group: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:pump_contact_point_id]).to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.pump_contact_point_id.must_be_water_pump"))
    end

    it "Σ fixed_percentage ≤ 100 tính THEO TỪNG TRẠM" do
      station2 = create(:contact_point, :water_pump, name: "Trạm 2", zone: zone)
      create(:pump_allocation, zone: zone, period: period, coefficient: 1, pump_contact_point: station,
             unit: unit, contact_point: nil, block: nil, group: nil, fixed_percentage: 70)
      unit_ok = create(:unit, zone: zone)
      create(:contact_point, :residential, unit: unit_ok, name: "ĐM ok")
      ok = build(:pump_allocation, zone: zone, period: period, coefficient: 1, pump_contact_point: station2,
                 unit: unit_ok, contact_point: nil, block: nil, group: nil, fixed_percentage: 80)
      expect(ok).to be_valid
      unit_bad = create(:unit, zone: zone)
      create(:contact_point, :residential, unit: unit_bad, name: "ĐM bad")
      bad = build(:pump_allocation, zone: zone, period: period, coefficient: 1, pump_contact_point: station,
                  unit: unit_bad, contact_point: nil, block: nil, group: nil, fixed_percentage: 40)
      expect(bad).not_to be_valid
      expect(bad.errors[:base]).to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.base.fixed_percentage_sum_exceeds_one_hundred"))
    end

    it "kỳ cũ (per_station=false): pump_contact_point để trống, ràng buộc theo zone như cũ" do
      old = create(:period, closed: true, pump_allocation_per_station: false)
      alloc = build(:pump_allocation, zone: zone, period: old, coefficient: 1,
                    pump_contact_point: nil, unit: unit, contact_point: nil, block: nil, group: nil)
      expect(alloc).to be_valid
    end

    it "kỳ cũ (per_station=false): gắn pump_contact_point → chặn (không cho phép trạm ở kỳ cũ)" do
      old = create(:period, closed: true, pump_allocation_per_station: false)
      alloc = build(:pump_allocation, zone: zone, period: old, coefficient: 1,
                    pump_contact_point: station, unit: unit, contact_point: nil, block: nil, group: nil)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:pump_contact_point_id]).to include(I18n.t("activerecord.errors.models.pump_allocation.attributes.pump_contact_point_id.not_allowed_legacy"))
    end
  end

  # CHIEU-phan-bo-tram-rang-buoc: uniqueness scope theo (zone, period, pump_contact_point)
  # — cùng đối tượng nhận được phép xuất hiện ở NHIỀU trạm (nới ràng buộc per-trạm), nhưng
  # KHÔNG được trùng trong cùng một trạm.
  describe "uniqueness per-trạm (unit recipient)" do
    let(:zone) { create(:zone, name: "KV uniq") }
    let!(:period) { create(:period, closed: false, pump_allocation_per_station: true) }
    let(:unit) do
      u = create(:unit, zone: zone)
      create(:contact_point, :residential, unit: u, name: "ĐM uniq")
      u
    end
    let(:station_one) { create(:contact_point, :water_pump, name: "Trạm uniq 1", zone: zone) }
    let(:station_two) { create(:contact_point, :water_pump, name: "Trạm uniq 2", zone: zone) }

    it "cùng đơn vị + cùng zone/kỳ + CÙNG trạm → trùng lặp, không hợp lệ" do
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_one,
             unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
      dup = build(:pump_allocation, zone: zone, period: period, pump_contact_point: station_one,
                  unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
      expect(dup).not_to be_valid
      expect(dup.errors[:unit_id]).to be_present
    end

    it "cùng đơn vị + cùng zone/kỳ nhưng KHÁC trạm → chặn (no-split)" do
      create(:pump_allocation, zone: zone, period: period, pump_contact_point: station_one,
             unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
      other = build(:pump_allocation, zone: zone, period: period, pump_contact_point: station_two,
                    unit: unit, contact_point: nil, block: nil, group: nil, coefficient: 1)
      expect(other).not_to be_valid
      expect(other.errors[:base]).to include(
        I18n.t("activerecord.errors.models.pump_allocation.attributes.base.split_across_stations")
      )
    end
  end

  # CHIEU-phan-bo-tram-rang-buoc: đúng-một-recipient cho các cặp còn thiếu test (khối+nhóm,
  # nhóm+đầu mối) và trường hợp ba recipient → tất cả không hợp lệ với recipient_must_be_one.
  describe "đúng một recipient — các cặp/bộ ba còn lại" do
    let(:zone) { create(:zone, name: "KV exactly-one") }
    let(:period) { create(:period, closed: false) }
    let(:unit) { create(:unit, zone: zone) }
    let(:msg) do
      I18n.t("activerecord.errors.models.pump_allocation.attributes.base.recipient_must_be_one")
    end

    it "không hợp lệ khi có hai recipient (khối + nhóm)" do
      alloc = build(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: nil,
                    block: create(:block, unit: unit), group: create(:group, unit: unit))
      expect(alloc).not_to be_valid
      expect(alloc.errors[:base]).to include(msg)
    end

    it "không hợp lệ khi có hai recipient (nhóm + đầu mối)" do
      alloc = build(:pump_allocation, zone: zone, period: period, unit: nil, block: nil,
                    group: create(:group, unit: unit),
                    contact_point: create(:contact_point, :residential, unit: unit))
      expect(alloc).not_to be_valid
      expect(alloc.errors[:base]).to include(msg)
    end

    it "không hợp lệ khi có ba recipient (đơn vị + khối + nhóm)" do
      alloc = build(:pump_allocation, zone: zone, period: period, contact_point: nil,
                    unit: unit, block: create(:block, unit: unit), group: create(:group, unit: unit))
      expect(alloc).not_to be_valid
      expect(alloc.errors[:base]).to include(msg)
    end
  end

  describe "#calculation_state_targets" do
    it "returns zone_id and period_id from direct attributes" do
      allocation = PumpAllocation.new(zone_id: nil, period_id: nil)
      targets = allocation.send(:calculation_state_targets)
      expect(targets).to eq([[nil, nil]])
    end
  end

  # CHIEU-phan-bo-tram-khong-chong-cheo
  describe "ràng buộc không chồng chéo (non-overlap)" do
    let(:zone) { create(:zone) }
    let(:unit) { create(:unit, zone: zone) }
    let(:period) { create(:period, pump_allocation_per_station: true) }
    let(:station) do
      create(:contact_point, :water_pump, zone: zone, name: "Trạm Tây")
    end

    it "đơn vị là đối tượng nhận + khối bên trong cũng là đối tượng nhận → chặn" do
      block = create(:block, unit: unit)
      create(:contact_point, :residential, unit: unit, block: block, name: "ĐM trong khối")
      create(:pump_allocation, zone: zone, period: period, unit: unit,
             pump_contact_point: station, coefficient: 1)
      dup = build(:pump_allocation, zone: zone, period: period, unit: nil, block: block,
                  pump_contact_point: station, coefficient: 1)
      expect(dup).not_to be_valid
      expect(dup.errors[:base]).to include(
        I18n.t("activerecord.errors.models.pump_allocation.attributes.base.overlapping_recipients")
      )
    end

    it "khối là đối tượng nhận + đầu mối bên trong khối cũng là đối tượng nhận → chặn" do
      block = create(:block, unit: unit)
      cp = create(:contact_point, :residential, unit: unit, block: block, name: "ĐM trong khối")
      create(:pump_allocation, zone: zone, period: period, unit: nil, block: block,
             pump_contact_point: station, coefficient: 1)
      dup = build(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: cp,
                  pump_contact_point: station, coefficient: 1)
      expect(dup).not_to be_valid
    end

    it "hai đối tượng nhận không chồng chéo → cho phép" do
      unit2 = create(:unit, zone: zone)
      create(:contact_point, :residential, unit: unit, name: "ĐM đơn vị 1")
      create(:contact_point, :residential, unit: unit2, name: "ĐM đơn vị 2")
      create(:pump_allocation, zone: zone, period: period, unit: unit,
             pump_contact_point: station, coefficient: 1)
      ok = build(:pump_allocation, zone: zone, period: period, unit: unit2,
                 pump_contact_point: station, coefficient: 1)
      expect(ok).to be_valid
    end

    it "chồng chéo xuyên trạm cũng bị chặn" do
      station2 = create(:contact_point, :water_pump, zone: zone, name: "Trạm Đông")
      block = create(:block, unit: unit)
      create(:contact_point, :residential, unit: unit, block: block, name: "ĐM trong khối")
      create(:pump_allocation, zone: zone, period: period, unit: unit,
             pump_contact_point: station, coefficient: 1)
      dup = build(:pump_allocation, zone: zone, period: period, block: block,
                  pump_contact_point: station2, coefficient: 1)
      expect(dup).not_to be_valid
    end
  end

  # CHIEU-phan-bo-tram-khong-chong-cheo (no-split)
  describe "ràng buộc không chia cấp (no-split)" do
    let(:zone) { create(:zone) }
    let(:unit) do
      u = create(:unit, zone: zone)
      create(:contact_point, :residential, unit: u, name: "ĐM no-split")
      u
    end
    let(:period) { create(:period, pump_allocation_per_station: true) }
    let(:station_tay) { create(:contact_point, :water_pump, zone: zone, name: "Trạm Tây") }
    let(:station_dong) { create(:contact_point, :water_pump, zone: zone, name: "Trạm Đông") }

    it "đối tượng cùng đơn vị ở 2 trạm khác nhau → chặn" do
      block = create(:block, unit: unit)
      create(:contact_point, :residential, unit: unit, name: "ĐM đơn vị")
      create(:contact_point, :residential, unit: unit, block: block, name: "ĐM khối")
      create(:pump_allocation, zone: zone, period: period, unit: unit,
             pump_contact_point: station_tay, coefficient: 1)
      split = build(:pump_allocation, zone: zone, period: period, unit: nil, block: block,
                    pump_contact_point: station_dong, coefficient: 1)
      expect(split).not_to be_valid
      expect(split.errors[:base]).to include(
        I18n.t("activerecord.errors.models.pump_allocation.attributes.base.split_across_stations")
      )
    end

    it "hai đơn vị khác nhau cùng trạm → cho phép (no-split không chặn)" do
      unit2 = create(:unit, zone: zone)
      create(:contact_point, :residential, unit: unit, name: "ĐM đơn vị 1")
      create(:contact_point, :residential, unit: unit2, name: "ĐM đơn vị 2")
      create(:pump_allocation, zone: zone, period: period, unit: unit,
             pump_contact_point: station_tay, coefficient: 1)
      ok = build(:pump_allocation, zone: zone, period: period, unit: unit2,
                 pump_contact_point: station_tay, coefficient: 1)
      expect(ok).to be_valid
    end

    it "đầu mối thuộc khu vực (không có đơn vị) → không bị chặn no-split" do
      zone_cp = create(:contact_point, :zone_residential, zone: zone, name: "ĐM khu vực")
      create(:pump_allocation, zone: zone, period: period, unit: unit,
             pump_contact_point: station_tay, coefficient: 1)
      ok = build(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: zone_cp,
                 pump_contact_point: station_dong, coefficient: 1)
      expect(ok).to be_valid
    end
  end

  # CHIEU-phan-bo-tram-recipient-rong
  describe "ràng buộc đối tượng nhận rỗng — chặn khi cấu hình" do
    let(:zone) { create(:zone) }
    let(:unit) { create(:unit, zone: zone) }
    let(:period) { create(:period) }

    it "đơn vị không có đầu mối sinh hoạt → chặn" do
      alloc = PumpAllocation.new(zone: zone, period: period, unit: unit, coefficient: 1)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:unit_id]).to include(
        I18n.t("activerecord.errors.models.pump_allocation.attributes.unit_id.no_residential_contact_points")
      )
    end

    it "đơn vị có đầu mối sinh hoạt → cho phép" do
      create(:contact_point, :residential, unit: unit, name: "ĐM có người")
      alloc = build(:pump_allocation, zone: zone, period: period, unit: unit, coefficient: 1)
      expect(alloc).to be_valid
    end

    it "khối không có đầu mối sinh hoạt → chặn" do
      block = create(:block, unit: unit)
      alloc = build(:pump_allocation, zone: zone, period: period, unit: nil, block: block, coefficient: 1)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:block_id]).to be_present
    end

    it "nhóm không có đầu mối sinh hoạt → chặn" do
      group = create(:group, unit: unit)
      alloc = build(:pump_allocation, zone: zone, period: period, unit: nil, group: group, coefficient: 1)
      expect(alloc).not_to be_valid
      expect(alloc.errors[:group_id]).to be_present
    end

    it "đầu mối trực tiếp (contact_point) → không kiểm tra (tự nó là leaf)" do
      cp = create(:contact_point, :zone_residential, zone: zone, name: "ĐM khu vực")
      alloc = build(:pump_allocation, zone: zone, period: period, unit: nil, contact_point: cp, coefficient: 1)
      expect(alloc).to be_valid
    end
  end

  describe "optimistic locking" do
    it "có cột lock_version" do
      expect(PumpAllocation.column_names).to include("lock_version")
    end

    it "raise StaleObjectError khi xung đột" do
      allocation = create(:pump_allocation)
      copy = PumpAllocation.find(allocation.id)
      allocation.update!(coefficient: 2)
      expect { copy.update!(coefficient: 3) }.to raise_error(ActiveRecord::StaleObjectError)
    end
  end
end

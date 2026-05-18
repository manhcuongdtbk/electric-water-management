require "rails_helper"

RSpec.describe ContactPoint do
  describe "associations" do
    it { is_expected.to belong_to(:unit).optional }
    it { is_expected.to belong_to(:zone).optional }
    it { is_expected.to belong_to(:block).optional }
    it { is_expected.to belong_to(:group).optional }
    it { is_expected.to have_many(:meters) }
    it { is_expected.to have_many(:meter_readings).through(:meters) }
    it { is_expected.to have_many(:personnel_entries) }
    it { is_expected.to have_many(:non_establishment_snapshots) }
    it { is_expected.to have_many(:other_deductions) }
    it { is_expected.to have_many(:calculations) }
    it { is_expected.to have_many(:pump_allocations) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:contact_point_type) }

    describe "uniqueness :name scoped_to (unit_id, zone_id, contact_point_type)" do
      let(:unit) { create(:unit) }

      it "không cho trùng tên trong cùng unit + cùng loại" do
        create(:contact_point, :residential, name: "Đầu mối A", unit: unit)
        dup = build(:contact_point, :residential, name: "Đầu mối A", unit: unit)
        expect(dup).not_to be_valid
        expect(dup.errors[:name]).to be_present
      end

      it "cho phép trùng tên giữa loại khác nhau trong cùng unit" do
        create(:contact_point, :residential, name: "Đầu mối A", unit: unit)
        other = build(:contact_point, :public_type, name: "Đầu mối A", unit: unit)
        expect(other).to be_valid
      end

      it "cho phép trùng tên giữa unit khác nhau" do
        unit2 = create(:unit)
        create(:contact_point, :residential, name: "Đầu mối A", unit: unit)
        other = build(:contact_point, :residential, name: "Đầu mối A", unit: unit2)
        expect(other).to be_valid
      end

      it "cho phép trùng tên giữa zone và unit (khác phạm vi)" do
        zone = create(:zone)
        create(:contact_point, :water_pump, name: "Đầu mối A", zone: zone)
        other = build(:contact_point, :residential, name: "Đầu mối A", unit: unit)
        expect(other).to be_valid
      end
    end

    describe "residential" do
      it "hợp lệ với unit, không có zone" do
        expect(build(:contact_point, :residential)).to be_valid
      end

      it "hợp lệ với zone, không có unit" do
        expect(build(:contact_point, :zone_residential)).to be_valid
      end

      it "không hợp lệ khi có cả unit và zone" do
        cp = build(:contact_point, :residential, zone: create(:zone))
        expect(cp).not_to be_valid
      end

      it "không hợp lệ khi cả unit và zone đều null" do
        cp = build(:contact_point, :residential, unit: nil, zone: nil)
        expect(cp).not_to be_valid
      end
    end

    describe "public" do
      it "hợp lệ với unit, không có zone" do
        expect(build(:contact_point, :public_type)).to be_valid
      end

      it "không hợp lệ khi có cả unit và zone" do
        cp = build(:contact_point, :public_type, zone: create(:zone))
        expect(cp).not_to be_valid
      end

      it "không hợp lệ khi cả unit và zone đều null" do
        cp = build(:contact_point, :public_type, unit: nil, zone: nil)
        expect(cp).not_to be_valid
      end
    end

    describe "water_pump" do
      it "hợp lệ với zone" do
        expect(build(:contact_point, :water_pump)).to be_valid
      end

      it "không hợp lệ khi có unit" do
        cp = build(:contact_point, :water_pump, unit: create(:unit))
        expect(cp).not_to be_valid
      end

      it "không hợp lệ khi có personnel_count" do
        cp = build(:contact_point, :water_pump, personnel_count: 5)
        expect(cp).not_to be_valid
      end

      it "không hợp lệ khi zone null" do
        cp = build(:contact_point, :water_pump, zone: nil)
        expect(cp).not_to be_valid
      end
    end

    describe "non_establishment" do
      it "hợp lệ với zone + personnel_count >= 1" do
        expect(build(:contact_point, :non_establishment)).to be_valid
      end

      it "không hợp lệ khi personnel_count < 1" do
        cp = build(:contact_point, :non_establishment, personnel_count: 0)
        expect(cp).not_to be_valid
      end

      it "không hợp lệ khi personnel_count nil" do
        cp = build(:contact_point, :non_establishment, personnel_count: nil)
        expect(cp).not_to be_valid
      end

      it "không hợp lệ khi có unit" do
        cp = build(:contact_point, :non_establishment, unit: create(:unit))
        expect(cp).not_to be_valid
      end
    end
  end

  describe "enum :contact_point_type" do
    it "định nghĩa 4 loại" do
      expect(ContactPoint.contact_point_types.keys)
        .to match_array(%w[residential public water_pump non_establishment])
    end

    it "tạo các method với prefix :type" do
      cp = build(:contact_point, :water_pump)
      expect(cp.type_water_pump?).to be true
      expect(cp.type_residential?).to be false
    end
  end

  describe "after_discard cascade" do
    it "discard meters khi discard contact_point" do
      cp = create(:contact_point, :residential)
      create_list(:meter, 2, contact_point: cp)
      expect { cp.discard }.to change { cp.meters.kept.count }.from(2).to(0)
    end
  end

  describe "scope :in_zone" do
    let(:zone) { create(:zone) }
    let(:unit_in_zone) { create(:unit, zone: zone) }
    let!(:cp_via_unit) { create(:contact_point, :residential, unit: unit_in_zone) }
    let!(:cp_via_zone) { create(:contact_point, :water_pump, zone: zone) }
    let!(:cp_other) { create(:contact_point, :residential) }

    it "trả về đầu mối thuộc zone trực tiếp + qua unit" do
      result = ContactPoint.in_zone(zone)
      expect(result).to include(cp_via_unit, cp_via_zone)
      expect(result).not_to include(cp_other)
    end
  end

  describe "#effective_zone" do
    it "trả về zone trực tiếp nếu có" do
      zone = create(:zone)
      cp = create(:contact_point, :water_pump, zone: zone)
      expect(cp.effective_zone).to eq(zone)
    end

    it "trả về zone qua unit nếu không có zone trực tiếp" do
      unit = create(:unit)
      cp = create(:contact_point, :residential, unit: unit)
      expect(cp.effective_zone).to eq(unit.zone)
    end
  end

  describe "auto-snapshot khi tạo đầu mối lúc kỳ đang mở (T25, T26)" do
    context "khi không có kỳ đang mở (T26)" do
      it "không tạo personnel_entries cho residential" do
        cp = create(:contact_point, :residential)
        expect(cp.personnel_entries).to be_empty
        expect(cp.other_deductions).to be_empty
      end

      it "không tạo non_establishment_snapshot cho non_establishment" do
        cp = create(:contact_point, :non_establishment)
        expect(cp.non_establishment_snapshots).to be_empty
      end
    end

    context "khi kỳ đang mở (T25)" do
      let!(:period) { create(:period, year: 2026, month: 5, closed: false) }
      let!(:ranks) {
        7.times.map { |i| create(:rank, period: period, name: "Cấp #{i + 1}", quota: 100, position: i + 1) }
      }

      it "tạo personnel_entries cho residential — count = 0 mặc định cho mọi rank" do
        cp = create(:contact_point, :residential)
        expect(cp.personnel_entries.count).to eq(7)
        expect(cp.personnel_entries.pluck(:count)).to all(eq(0))
      end

      it "dùng initial_personnel_counts khi cung cấp" do
        ha_si_quan_rank = ranks.last
        cp = create(:contact_point, :residential,
                    initial_personnel_counts: { ha_si_quan_rank.id => 3 })
        expect(cp.personnel_entries.count).to eq(7)
        expect(cp.personnel_entries.find_by(rank: ha_si_quan_rank).count).to eq(3)
        other_entries = cp.personnel_entries.where.not(rank_id: ha_si_quan_rank.id)
        expect(other_entries.pluck(:count)).to all(eq(0))
      end

      it "tạo other_deduction mặc định fixed 0 cho residential" do
        cp = create(:contact_point, :residential)
        deduction = cp.other_deductions.find_by(period: period)
        expect(deduction).to be_present
        expect(deduction.other_type).to eq("fixed")
        expect(deduction.other_value).to eq(0)
      end

      it "tạo non_establishment_snapshot cho non_establishment với personnel_count từ contact_point" do
        cp = create(:contact_point, :non_establishment, personnel_count: 7)
        snapshot = cp.non_establishment_snapshots.find_by(period: period)
        expect(snapshot).to be_present
        expect(snapshot.personnel_count).to eq(7)
      end

      it "không tạo snapshots cho public" do
        cp = create(:contact_point, :public_type)
        expect(cp.personnel_entries).to be_empty
        expect(cp.other_deductions).to be_empty
        expect(cp.non_establishment_snapshots).to be_empty
      end

      it "không tạo snapshots cho water_pump" do
        cp = create(:contact_point, :water_pump)
        expect(cp.personnel_entries).to be_empty
        expect(cp.other_deductions).to be_empty
        expect(cp.non_establishment_snapshots).to be_empty
      end
    end
  end
end

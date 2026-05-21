require "rails_helper"

# Test sửa đầu mối khi kỳ cũ mở lại (PR #171).
# Kỳ cũ: cho sửa data per kỳ (quân số, no_loss, non_establishment snapshot),
# không cho sửa cấu trúc (tên, block, group, thêm/xóa meter).
RSpec.describe "Sửa đầu mối khi kỳ cũ mở lại", type: :request do
  let(:service) { PeriodService.new }
  let(:sample) { setup_zone_one_full_sample }
  let(:system_admin) { create(:user, :system_admin) }

  before do
    # Kỳ 5 (latest), đóng kỳ 5, mở kỳ 6, đóng kỳ 6, mở lại kỳ 5
    CalculationOrchestrator.new(zone: sample.zone, period: sample.period).call
    sample.period.update!(closed: true)
    @period_6 = service.open_new_period.period
    @period_6.update!(closed: true)
    service.reopen_period(sample.period)
    sign_in system_admin
  end

  let(:period_5) { sample.period }

  describe "residential: sửa quân số" do
    let(:ban_tac_huan) { sample.contact_points[:ban_tac_huan] }
    let(:rank) { period_5.ranks.find_by(position: 7) }

    it "cập nhật personnel_entries cho kỳ cũ" do
      entry = ban_tac_huan.personnel_entries.find_by(period: period_5, rank: rank)
      old_count = entry.count

      patch contact_point_path(ban_tac_huan), params: {
        contact_point: {
          name: ban_tac_huan.name,
          personnel_counts: { rank.id.to_s => (old_count + 5).to_s },
          personnel_lock_versions: { rank.id.to_s => entry.lock_version.to_s }
        }
      }
      expect(response).to redirect_to(contact_points_path(type: "residential"))

      entry.reload
      expect(entry.count).to eq(old_count + 5)
    end

    it "không sửa được tên đầu mối" do
      patch contact_point_path(ban_tac_huan), params: {
        contact_point: { name: "Tên mới" }
      }
      expect(response).to redirect_to(contact_points_path(type: "residential"))
      expect(ban_tac_huan.reload.name).to eq("Ban Tác huấn")
    end

    it "không sửa được block_id, group_id" do
      block = create(:block, unit: sample.unit_a)
      patch contact_point_path(ban_tac_huan), params: {
        contact_point: { block_id: block.id }
      }
      expect(response).to redirect_to(contact_points_path(type: "residential"))
      expect(ban_tac_huan.reload.block_id).not_to eq(block.id)
    end
  end

  describe "residential: sửa no_loss" do
    let(:ban_tac_huan) { sample.contact_points[:ban_tac_huan] }
    let(:meter) { sample.meters[:ct_a1] }

    it "toggle no_loss trên meter" do
      old_no_loss = meter.no_loss
      patch contact_point_path(ban_tac_huan), params: {
        contact_point: {
          meters_attributes: { "0" => { id: meter.id, no_loss: old_no_loss ? "0" : "1" } }
        }
      }
      expect(response).to redirect_to(contact_points_path(type: "residential"))
      expect(meter.reload.no_loss).to eq(!old_no_loss)
    end

    it "không thêm được meter mới" do
      meter_count_before = ban_tac_huan.meters.kept.count
      patch contact_point_path(ban_tac_huan), params: {
        contact_point: {
          meters_attributes: { "999" => { name: "CT-NEW", no_loss: "0" } }
        }
      }
      expect(ban_tac_huan.meters.kept.count).to eq(meter_count_before)
    end

    it "không xóa được meter" do
      patch contact_point_path(ban_tac_huan), params: {
        contact_point: {
          meters_attributes: { "0" => { id: meter.id, _destroy: "1" } }
        }
      }
      expect(meter.reload).not_to be_discarded
    end

    it "không đổi được tên meter" do
      old_name = meter.name
      patch contact_point_path(ban_tac_huan), params: {
        contact_point: {
          meters_attributes: { "0" => { id: meter.id, name: "CT-RENAMED", no_loss: meter.no_loss ? "1" : "0" } }
        }
      }
      expect(meter.reload.name).to eq(old_name)
    end
  end

  describe "non_establishment: sửa quân số snapshot trực tiếp" do
    let(:tho_xay) { sample.contact_points[:tho_xay] }

    it "cập nhật non_establishment_snapshots, không đụng master" do
      snapshot = tho_xay.non_establishment_snapshots.find_by(period: period_5)
      master_before = tho_xay.personnel_count

      patch contact_point_path(tho_xay), params: {
        contact_point: { personnel_count: "8" }
      }
      expect(response).to redirect_to(contact_points_path(type: "non_establishment"))

      snapshot.reload
      expect(snapshot.personnel_count).to eq(8)
      expect(tho_xay.reload.personnel_count).to eq(master_before)
    end

    it "không sửa được tên" do
      patch contact_point_path(tho_xay), params: {
        contact_point: { name: "Tên mới", personnel_count: "8" }
      }
      expect(tho_xay.reload.name).to eq("Thợ xây")
    end
  end

  describe "water_pump: sửa no_loss" do
    let(:tram_bom) { sample.contact_points[:tram_bom_1] }
    let(:meter) { sample.meters[:ct_bn1] }

    it "toggle no_loss" do
      patch contact_point_path(tram_bom), params: {
        contact_point: {
          meters_attributes: { "0" => { id: meter.id, no_loss: "1" } }
        }
      }
      expect(response).to redirect_to(contact_points_path(type: "water_pump"))
      expect(meter.reload.no_loss).to be true
    end
  end

  describe "public: sửa no_loss" do
    let(:nha_an) { sample.contact_points[:nha_an] }
    let(:meter) { sample.meters[:ct_cc_a] }

    it "toggle no_loss" do
      patch contact_point_path(nha_an), params: {
        contact_point: {
          meters_attributes: { "0" => { id: meter.id, no_loss: "1" } }
        }
      }
      expect(response).to redirect_to(contact_points_path(type: "public"))
      expect(meter.reload.no_loss).to be true
    end
  end

  describe "FE: form disabled fields khi kỳ cũ" do
    let(:ban_tac_huan) { sample.contact_points[:ban_tac_huan] }

    it "tên đầu mối disabled" do
      get edit_contact_point_path(ban_tac_huan)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Đang mở lại kỳ cũ")
    end

    it "không có nút Thêm công tơ và Xóa công tơ" do
      get edit_contact_point_path(ban_tac_huan)
      expect(response.body).not_to include("+ Thêm công tơ")
      expect(response.body).not_to include(">Xóa</button>")
    end
  end

  describe "StructureChangeGuard vẫn chặn create/destroy" do
    it "không tạo được đầu mối mới" do
      post contact_points_path, params: {
        contact_point: {
          name: "Test CP", contact_point_type: "residential",
          unit_id: sample.unit_a.id
        }
      }
      expect(response).to be_redirect
      expect(ContactPoint.find_by(name: "Test CP")).to be_nil
    end

    it "không xóa được đầu mối" do
      cp = sample.contact_points[:ban_tac_huan]
      delete contact_point_path(cp)
      expect(response).to be_redirect
      expect(cp.reload).not_to be_discarded
    end
  end

  describe "kỳ mới nhất mở: mọi thứ hoạt động bình thường" do
    before do
      # Đóng kỳ 5 (cũ), mở lại kỳ 6 (latest)
      service.close_period(period_5)
      service.reopen_period(@period_6)
    end

    let(:ban_tac_huan) { sample.contact_points[:ban_tac_huan] }

    it "sửa được tên đầu mối" do
      patch contact_point_path(ban_tac_huan), params: {
        contact_point: { name: "Tên mới" }
      }
      expect(response).to redirect_to(contact_points_path(type: "residential"))
      expect(ban_tac_huan.reload.name).to eq("Tên mới")
    end

    it "form không hiện thông báo kỳ cũ" do
      get edit_contact_point_path(ban_tac_huan)
      expect(response.body).not_to include("Đang mở lại kỳ cũ")
    end
  end
end

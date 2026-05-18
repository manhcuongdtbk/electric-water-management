require "rails_helper"

RSpec.describe "Backups", type: :request do
  let(:technician) { create(:user, role: :technician) }
  let(:system_admin) { create(:user, :system_admin) }
  let(:zone) { create(:zone) }
  let(:unit) { create(:unit, zone: zone) }
  let(:unit_admin) { create(:user, :unit_admin, unit: unit) }

  describe "GET /backups" do
    it "T96: technician thấy danh sách" do
      sign_in technician
      get backups_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sao lưu dữ liệu")
    end

    it "T99: system_admin bị deny (redirect root + access_denied)" do
      sign_in system_admin
      get backups_path
      expect(response).to redirect_to(root_path)
    end

    it "T99: unit_admin bị deny" do
      sign_in unit_admin
      get backups_path
      expect(response).to redirect_to(root_path)
    end

    it "hiển thị tfoot tổng dung lượng khi có backups" do
      sign_in technician
      create(:backup, filename: "backup_20260518_120000.dump", size_bytes: 1024)
      create(:backup, filename: "backup_20260518_130000.dump", size_bytes: 2048)
      get backups_path
      expect(response.body).to include("Tổng dung lượng")
    end
  end

  describe "POST /backups" do
    before { sign_in technician }

    it "T96: success → flash notice + redirect" do
      backup = create(:backup, filename: "backup_20260518_120000.dump")
      allow(BackupService).to receive(:create).with(user: technician)
        .and_return(BackupService::Result.new(backup: backup, warnings: []))
      post backups_path
      expect(response).to redirect_to(backups_path)
      follow_redirect!
      expect(flash[:notice]).to include("Đã tạo bản sao lưu")
    end

    it "T97: đã đạt max 3 → flash alert" do
      3.times { |i| create(:backup, filename: "backup_2026051#{i}_120000.dump", status: "completed") }
      post backups_path
      expect(response).to redirect_to(backups_path)
      follow_redirect!
      expect(flash[:alert]).to include("Đã đạt giới hạn 3")
    end

    it "DumpError → flash alert" do
      allow(BackupService).to receive(:create).with(user: technician)
        .and_raise(BackupService::DumpError, "pg_dump lỗi cụ thể")
      post backups_path
      expect(response).to redirect_to(backups_path)
      follow_redirect!
      expect(flash[:alert]).to include("pg_dump lỗi cụ thể")
    end
  end

  describe "DELETE /backups/:id" do
    before { sign_in technician }

    it "xóa record + xóa file nếu tồn tại" do
      backup = create(:backup, filename: "backup_20260518_120000.dump")
      allow_any_instance_of(Pathname).to receive(:exist?).and_return(true)
      allow(File).to receive(:delete).and_return(1)
      delete backup_path(backup)
      expect(Backup.where(id: backup.id)).to be_empty
    end

    it "không lỗi nếu file đã missing" do
      backup = create(:backup, filename: "backup_20260518_120000.dump")
      allow_any_instance_of(Pathname).to receive(:exist?).and_return(false)
      delete backup_path(backup)
      expect(Backup.where(id: backup.id)).to be_empty
    end
  end
end

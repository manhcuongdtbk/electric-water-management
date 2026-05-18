require "rails_helper"

RSpec.describe Backup do
  describe "validations" do
    it "hợp lệ với filename đúng format và size_bytes >= 0" do
      backup = build(:backup, filename: "backup_20260518_120000.dump", size_bytes: 0, status: "completed")
      expect(backup).to be_valid
    end

    it "không hợp lệ khi filename trống" do
      backup = build(:backup, filename: nil)
      expect(backup).not_to be_valid
    end

    it "không hợp lệ khi filename sai format" do
      backup = build(:backup, filename: "wrong_name.dump")
      expect(backup).not_to be_valid
      expect(backup.errors[:filename]).to be_present
    end

    it "không hợp lệ khi filename trùng" do
      create(:backup, filename: "backup_20260518_120000.dump")
      dup = build(:backup, filename: "backup_20260518_120000.dump")
      expect(dup).not_to be_valid
    end

    it "không hợp lệ khi status không trong whitelist" do
      backup = build(:backup, status: "unknown")
      expect(backup).not_to be_valid
    end
  end

  describe ".at_capacity?" do
    it "true khi có >= 3 backups completed" do
      3.times { |i| create(:backup, filename: "backup_2026051#{i}_120000.dump", status: "completed") }
      expect(described_class.at_capacity?).to be true
    end

    it "false khi có 2 completed + 1 failed" do
      2.times { |i| create(:backup, filename: "backup_2026051#{i}_120000.dump", status: "completed") }
      create(:backup, filename: "backup_20260519_120000.dump", status: "failed", size_bytes: 0)
      expect(described_class.at_capacity?).to be false
    end

    it "false khi chưa có backup nào" do
      expect(described_class.at_capacity?).to be false
    end
  end

  describe "#absolute_path" do
    it "kết hợp backup_dir + filename" do
      backup = build(:backup, filename: "backup_20260518_120000.dump")
      expect(backup.absolute_path.basename.to_s).to eq("backup_20260518_120000.dump")
    end
  end

  describe "audit" do
    it "tạo Backup ghi nhật ký PaperTrail event=create" do
      expect {
        create(:backup, filename: "backup_20260518_220000.dump")
      }.to change { PaperTrail::Version.where(item_type: "Backup", event: "create").count }.by(1)
    end
  end
end

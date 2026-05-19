require "rails_helper"

RSpec.describe BackupService do
  let(:user) { create(:user, role: :technician) }

  describe ".backup_dir" do
    it "ưu tiên ENV[BACKUP_DIR] khi có" do
      stub_const("ENV", ENV.to_h.merge("BACKUP_DIR" => "/tmp/test_backups"))
      expect(described_class.backup_dir.to_s).to eq("/tmp/test_backups")
    end

    it "fallback Rails.root/storage/backups khi không có ENV" do
      stub_const("ENV", ENV.to_h.merge("BACKUP_DIR" => nil))
      expect(described_class.backup_dir.to_s).to end_with("storage/backups")
    end
  end

  describe ".create" do
    it "T97: raise CapacityError khi đã có 3 backups completed" do
      3.times { |i| create(:backup, filename: "backup_2026051#{i}_120000.dump", status: "completed") }
      expect {
        described_class.create(user: user)
      }.to raise_error(BackupService::CapacityError, /giới hạn 3/)
    end

    it "raise DumpError khi pg_dump exit code khác 0" do
      allow(Open3).to receive(:capture3).and_return([
        "", "pg_dump: error: connection failed\nmore detail",
        instance_double(Process::Status, success?: false)
      ])
      expect {
        described_class.create(user: user)
      }.to raise_error(BackupService::DumpError, /Tạo bản sao lưu thất bại/)
    end

    it "T96: success → tạo Backup record với filename đúng format + size > 0" do
      Dir.mktmpdir do |dir|
        stub_const("ENV", ENV.to_h.merge("BACKUP_DIR" => dir))
        allow(Open3).to receive(:capture3) do |_env, *cmd|
          path = cmd.find { |a| a.is_a?(String) && a.start_with?("--file=") }.split("=", 2).last
          File.write(path, "fake dump content")
          ["", "", instance_double(Process::Status, success?: true)]
        end

        result = described_class.create(user: user)
        expect(result.backup).to be_persisted
        expect(result.backup.filename).to match(/\Abackup_\d{8}_\d{6}\.dump\z/)
        expect(result.backup.size_bytes).to be > 0
        expect(result.backup.status).to eq("completed")
        expect(result.backup.created_by).to eq(user)
      end
    end

    it "xóa file dở nếu pg_dump fail" do
      Dir.mktmpdir do |dir|
        stub_const("ENV", ENV.to_h.merge("BACKUP_DIR" => dir))
        allow(Open3).to receive(:capture3) do |_env, *cmd|
          path = cmd.find { |a| a.is_a?(String) && a.start_with?("--file=") }.split("=", 2).last
          File.write(path, "partial")
          ["", "pg_dump: error", instance_double(Process::Status, success?: false)]
        end
        expect { described_class.create(user: user) }.to raise_error(BackupService::DumpError)
        expect(Dir.glob(File.join(dir, "*.dump"))).to be_empty
      end
    end
  end
end

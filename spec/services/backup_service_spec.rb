require "rails_helper"

RSpec.describe BackupService do
  let(:backup_dir) { Rails.root.join("tmp/test_backups").to_s }

  before do
    stub_const("BackupService::BACKUP_DIR", backup_dir)
    FileUtils.mkdir_p(backup_dir)
  end

  after { FileUtils.rm_rf(backup_dir) }

  describe ".backup!" do
    context "when pg_dump succeeds" do
      before do
        allow(Open3).to receive(:capture3).and_return(
          [ "", "", instance_double(Process::Status, success?: true) ]
        )
      end

      it "returns a timestamped .dump filename" do
        filename = BackupService.backup!
        expect(filename).to match(/\Abackup_\d{8}_\d{6}\.dump\z/)
      end
    end

    context "when pg_dump fails" do
      before do
        allow(Open3).to receive(:capture3).and_return(
          [ "", "connection refused", instance_double(Process::Status, success?: false) ]
        )
      end

      it "raises with stderr content" do
        expect { BackupService.backup! }.to raise_error(RuntimeError, /pg_dump failed/)
      end

      it "logs the error" do
        allow(Rails.logger).to receive(:error)
        BackupService.backup! rescue nil
        expect(Rails.logger).to have_received(:error).with(/pg_dump failed/)
      end
    end
  end

  describe ".restore!" do
    context "when file exists and pg_restore succeeds" do
      let(:filename) { "backup_20260423_120000.dump" }

      before do
        FileUtils.touch(File.join(backup_dir, filename))
        allow(Open3).to receive(:capture3).and_return(
          [ "", "", instance_double(Process::Status, success?: true) ]
        )
      end

      it "does not raise" do
        expect { BackupService.restore!(filename) }.not_to raise_error
      end
    end

    context "when pg_restore fails" do
      let(:filename) { "backup_fail.dump" }

      before do
        FileUtils.touch(File.join(backup_dir, filename))
        allow(Open3).to receive(:capture3).and_return(
          [ "", "pg_restore: error", instance_double(Process::Status, success?: false) ]
        )
      end

      it "raises with stderr content" do
        expect { BackupService.restore!(filename) }.to raise_error(RuntimeError, /pg_restore failed/)
      end
    end

    context "with path traversal attempt" do
      it "raises ArgumentError for ../path" do
        expect { BackupService.restore!("../config/master.key") }
          .to raise_error(ArgumentError, "invalid filename")
      end

      it "raises ArgumentError for /absolute/path" do
        expect { BackupService.restore!("/etc/passwd") }
          .to raise_error(ArgumentError, "invalid filename")
      end
    end

    context "when file does not exist" do
      it "raises RuntimeError" do
        expect { BackupService.restore!("nonexistent.dump") }
          .to raise_error(RuntimeError, "File not found")
      end
    end
  end

  describe ".list" do
    it "returns empty array when no backups" do
      expect(BackupService.list).to eq([])
    end

    it "returns files sorted newest first" do
      older = File.join(backup_dir, "backup_20260401_000000.dump")
      newer = File.join(backup_dir, "backup_20260423_000000.dump")
      FileUtils.touch(older)
      FileUtils.touch(newer)
      File.utime(1.day.ago.to_time, 1.day.ago.to_time, older)
      File.utime(Time.current.to_time, Time.current.to_time, newer)

      result = BackupService.list
      expect(result.first[:name]).to eq("backup_20260423_000000.dump")
      expect(result.last[:name]).to eq("backup_20260401_000000.dump")
    end

    it "includes name, size, created_at for each file" do
      FileUtils.touch(File.join(backup_dir, "backup_test.dump"))
      result = BackupService.list
      expect(result.first).to include(:name, :size, :created_at)
    end
  end

  describe ".delete!" do
    context "when file exists" do
      let(:filename) { "backup_delete_me.dump" }

      before { FileUtils.touch(File.join(backup_dir, filename)) }

      it "removes the file" do
        BackupService.delete!(filename)
        expect(File.exist?(File.join(backup_dir, filename))).to be false
      end
    end

    context "with path traversal" do
      it "raises ArgumentError" do
        expect { BackupService.delete!("../../Gemfile") }
          .to raise_error(ArgumentError, "invalid filename")
      end
    end

    context "when file does not exist" do
      it "raises RuntimeError" do
        expect { BackupService.delete!("missing.dump") }
          .to raise_error(RuntimeError, "File not found")
      end
    end
  end
end

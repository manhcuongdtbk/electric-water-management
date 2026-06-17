require "rails_helper"
require Rails.root.join("lib/backup_restore_runner")

RSpec.describe BackupRestoreRunner do
  let(:backup) { instance_double("Backup") }
  subject { described_class.new(backup: backup) }

  describe "#call" do
    it "raises Error when backup file does not exist" do
      allow(backup).to receive(:file_exists?).and_return(false)
      expect { subject.call }.to raise_error(BackupRestoreRunner::Error)
    end

    it "raises Error when pg_restore fails" do
      allow(backup).to receive(:file_exists?).and_return(true)
      allow(backup).to receive(:absolute_path).and_return(Pathname.new("/tmp/fake.dump"))
      allow(ActiveRecord::Base.connection_pool).to receive(:disconnect!)
      allow(ActiveRecord::Base).to receive(:establish_connection)

      status = instance_double(Process::Status, success?: false)
      allow(Open3).to receive(:capture3).and_return(["", "restore failed", status])

      expect { subject.call }.to raise_error(BackupRestoreRunner::Error, /restore failed/)
    end

    it "succeeds when pg_restore exits with status 0" do
      allow(backup).to receive(:file_exists?).and_return(true)
      allow(backup).to receive(:absolute_path).and_return(Pathname.new("/tmp/fake.dump"))
      allow(ActiveRecord::Base.connection_pool).to receive(:disconnect!)
      allow(ActiveRecord::Base).to receive(:establish_connection)

      status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3).and_return(["", "", status])

      expect { subject.call }.not_to raise_error
    end
  end
end

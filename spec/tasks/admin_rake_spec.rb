require "rails_helper"
require "rake"

RSpec.describe "admin:reset_password rake task", type: :task do
  let(:task_name) { "admin:reset_password" }

  before(:all) do
    Rails.application.load_tasks
  end

  before do
    Rake::Task[task_name].reenable
  end

  let!(:division) { create(:organization, :division) }
  let!(:user) do
    # Create unlocked first (validation blocks setting locked_at on a sole admin),
    # then lock via update_column to simulate Devise auto-lock bypassing validations.
    u = create(:user, :admin_level1, organization: division)
    u.update_column(:locked_at, Time.current)
    u.update_column(:failed_attempts, 5)
    u
  end

  describe "with no email argument" do
    it "aborts with usage message" do
      expect {
        Rake::Task[task_name].invoke(nil)
      }.to raise_error(SystemExit)
    end
  end

  describe "with unknown email" do
    it "aborts with not-found message" do
      expect {
        Rake::Task[task_name].invoke("nobody@example.com")
      }.to raise_error(SystemExit)
    end
  end

  describe "with valid email" do
    it "resets password and unlocks the account" do
      Rake::Task[task_name].invoke(user.email)
      user.reload
      expect(user.locked_at).to be_nil
      expect(user.failed_attempts).to eq(0)
      expect(user.force_password_change).to be true
    end

    it "sets a new valid password" do
      expect {
        Rake::Task[task_name].invoke(user.email)
      }.not_to raise_error
      user.reload
      # New password must differ from the original encrypted password
      expect(user.encrypted_password).to be_present
    end

    it "outputs the new password and email" do
      expect { Rake::Task[task_name].invoke(user.email) }.to output(/#{user.email}/).to_stdout
      Rake::Task[task_name].reenable
      expect { Rake::Task[task_name].invoke(user.email) }.to output(/New password:/).to_stdout
    end
  end
end

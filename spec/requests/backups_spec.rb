require "rails_helper"

RSpec.describe "Backups", type: :request do
  let!(:division) { create(:organization, :division) }
  let!(:org_a)    { create(:organization, :unit, parent: division) }

  let(:tech_user)  { create(:user, :tech,         organization: division) }
  let(:admin1)     { create(:user, :admin_level1,  organization: division) }
  let(:admin_unit) { create(:user, :admin_unit,    organization: org_a) }
  let(:commander)  { create(:user, :commander,     organization: org_a) }

  before do
    allow(BackupService).to receive(:backup!).and_return("backup_test.dump")
    allow(BackupService).to receive(:restore!)
    allow(BackupService).to receive(:delete!)
    allow(BackupService).to receive(:list).and_return([
      { name: "backup_test.dump", size: 1024, created_at: Time.current }
    ])
  end

  # ---------------------------------------------------------------------------
  # GET /backups
  # ---------------------------------------------------------------------------
  describe "GET /backups" do
    context "as tech" do
      it "returns 200" do
        sign_in tech_user
        get backups_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin_level1" do
      before { sign_in admin1 and get backups_path }
      include_examples "redirects with access_denied"
    end

    context "as admin_unit" do
      before { sign_in admin_unit and get backups_path }
      include_examples "redirects with access_denied"
    end

    context "as commander" do
      before { sign_in commander and get backups_path }
      include_examples "redirects with access_denied"
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get backups_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /backups (create)
  # ---------------------------------------------------------------------------
  describe "POST /backups" do
    context "as tech" do
      it "triggers backup and redirects to index" do
        sign_in tech_user
        post backups_path
        expect(BackupService).to have_received(:backup!)
        expect(response).to redirect_to(backups_path)
        follow_redirect!
        expect(response.body).to include("backup_test.dump")
      end
    end

    context "when backup! raises" do
      before { allow(BackupService).to receive(:backup!).and_raise("pg_dump failed: connection refused") }

      it "redirects to index with alert" do
        sign_in tech_user
        post backups_path
        expect(response).to redirect_to(backups_path)
        follow_redirect!
        expect(response.body).to include("Sao lưu thất bại")
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit and post backups_path }
      include_examples "redirects with access_denied"
    end
  end

  # ---------------------------------------------------------------------------
  # POST /backups/restore
  # ---------------------------------------------------------------------------
  describe "POST /backups/restore" do
    context "as tech" do
      it "restores and redirects to login page" do
        sign_in tech_user
        post restore_backups_path, params: { filename: "backup_test.dump" }
        expect(BackupService).to have_received(:restore!).with("backup_test.dump")
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when restore! raises" do
      before { allow(BackupService).to receive(:restore!).and_raise("pg_restore failed: error") }

      it "redirects to index with alert" do
        sign_in tech_user
        post restore_backups_path, params: { filename: "backup_test.dump" }
        expect(response).to redirect_to(backups_path)
        follow_redirect!
        expect(response.body).to include("Phục hồi thất bại")
      end
    end

    context "when filename param is missing" do
      it "redirects to backups with alert" do
        sign_in tech_user
        post restore_backups_path
        expect(response).to redirect_to(backups_path)
      end
    end

    context "as admin_unit" do
      before { sign_in admin_unit and post restore_backups_path, params: { filename: "backup_test.dump" } }
      include_examples "redirects with access_denied"
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE /backups/destroy_file
  # ---------------------------------------------------------------------------
  describe "DELETE /backups/destroy_file" do
    context "as tech" do
      it "deletes file and redirects to index" do
        sign_in tech_user
        delete destroy_file_backups_path, params: { filename: "backup_test.dump" }
        expect(BackupService).to have_received(:delete!).with("backup_test.dump")
        expect(response).to redirect_to(backups_path)
      end
    end

    context "when delete! raises" do
      before { allow(BackupService).to receive(:delete!).and_raise("File not found") }

      it "redirects to index with alert" do
        sign_in tech_user
        delete destroy_file_backups_path, params: { filename: "missing.dump" }
        expect(response).to redirect_to(backups_path)
        follow_redirect!
        expect(response.body).to include("Xóa thất bại")
      end
    end

    context "as commander" do
      before { sign_in commander and delete destroy_file_backups_path, params: { filename: "backup_test.dump" } }
      include_examples "redirects with access_denied"
    end
  end
end

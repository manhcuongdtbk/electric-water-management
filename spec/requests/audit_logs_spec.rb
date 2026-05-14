require "rails_helper"

RSpec.describe "AuditLogs", type: :request do
  let_it_be(:division) { create(:organization, :division) }
  let_it_be(:org)      { create(:organization, :unit, parent: division) }

  let_it_be(:admin1)     { create(:user, :admin_level1, organization: division) }
  let_it_be(:tech_user)  { create(:user, :tech,         organization: division) }
  let_it_be(:admin_unit) { create(:user, :admin_unit,   organization: org) }
  let_it_be(:commander)  { create(:user, :commander,    organization: org) }

  describe "GET /audit_logs" do
    context "as admin_level1" do
      it "returns 200" do
        sign_in admin1
        get audit_logs_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as tech" do
      it "returns 200" do
        sign_in tech_user
        get audit_logs_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin_unit" do
      it "redirects with access_denied alert" do
        sign_in admin_unit
        get audit_logs_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t("flash.access_denied"))
      end
    end

    context "as commander" do
      it "redirects with access_denied alert" do
        sign_in commander
        get audit_logs_path
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t("flash.access_denied"))
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get audit_logs_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end

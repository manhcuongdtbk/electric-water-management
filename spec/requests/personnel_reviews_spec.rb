require "rails_helper"

RSpec.describe "PersonnelReviews", type: :request do
  let(:division)     { create(:organization, level: :division, parent: nil) }
  let(:org_a)        { create(:organization, level: :unit, parent: division) }
  let(:org_b)        { create(:organization, level: :unit, parent: division) }

  let(:admin1)       { create(:user, role: :admin_level1, organization: org_a) }
  let(:admin_unit_a) { create(:user, role: :admin_unit,   organization: org_a) }
  let(:admin_unit_b) { create(:user, role: :admin_unit,   organization: org_b) }
  let(:commander)    { create(:user, role: :commander,    organization: org_a) }
  let(:tech_user)    { create(:user, role: :tech,         organization: org_a) }

  let!(:cp_a) { create(:contact_point, organization: org_a) }
  let!(:cp_b) { create(:contact_point, organization: org_b) }
  let!(:period) { create(:monthly_period, year: 2026, month: 2) }

  # ---------------------------------------------------------------------------
  # GET /personnel_review — overview page
  # ---------------------------------------------------------------------------
  describe "GET /personnel_review" do
    context "as admin_unit" do
      before { sign_in admin_unit_a }

      it "returns ok" do
        get personnel_review_path
        expect(response).to have_http_status(:ok)
      end

      it "scopes contact points to own organization" do
        get personnel_review_path(period_id: period.id)
        expect(response.body).to include(cp_a.name)
        expect(response.body).not_to include(cp_b.name)
      end
    end

    context "as admin_level1" do
      before { sign_in admin1 }

      it "returns ok" do
        get personnel_review_path
        expect(response).to have_http_status(:ok)
      end

      it "can scope to a specific organization via org_id" do
        get personnel_review_path(period_id: period.id, org_id: org_b.id)
        expect(response.body).to include(cp_b.name)
        expect(response.body).not_to include(cp_a.name)
      end
    end

    context "as commander" do
      before { sign_in commander }

      it "returns ok (read-only access)" do
        get personnel_review_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as tech" do
      before { sign_in tech_user }

      it "is redirected to user management" do
        get personnel_review_path
        expect(response).to redirect_to(users_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /contact_points/:id/personnel/toggle_review
  # ---------------------------------------------------------------------------
  describe "PATCH /contact_points/:contact_point_id/personnel/toggle_review" do
    let!(:personnel_record) { create(:personnel, contact_point: cp_a, monthly_period: period) }

    context "as admin_unit of same org" do
      before { sign_in admin_unit_a }

      it "marks personnel as reviewed when not yet reviewed" do
        expect(personnel_record.reviewed_at).to be_nil
        patch toggle_review_contact_point_personnel_path(cp_a),
              params: { period_id: period.id }
        expect(personnel_record.reload.reviewed_at).not_to be_nil
      end

      it "unmarks personnel review when already reviewed" do
        personnel_record.mark_reviewed!
        patch toggle_review_contact_point_personnel_path(cp_a),
              params: { period_id: period.id }
        expect(personnel_record.reload.reviewed_at).to be_nil
      end

      it "redirects back to personnel_review" do
        patch toggle_review_contact_point_personnel_path(cp_a),
              params: { period_id: period.id }
        expect(response).to redirect_to(personnel_review_path(period_id: period.id))
      end

      it "cannot toggle review for another org's contact point" do
        expect {
          patch toggle_review_contact_point_personnel_path(cp_b),
                params: { period_id: period.id }
        }.not_to(change { Personnel.find_by(contact_point: cp_b, monthly_period: period)&.reviewed_at })
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t("flash.access_denied"))
      end
    end

    context "as admin_level1" do
      before { sign_in admin1 }

      it "can toggle review for any contact point" do
        patch toggle_review_contact_point_personnel_path(cp_a),
              params: { period_id: period.id }
        expect(personnel_record.reload.reviewed_at).not_to be_nil
      end
    end

    context "as commander" do
      before { sign_in commander }

      it "is forbidden" do
        patch toggle_review_contact_point_personnel_path(cp_a),
              params: { period_id: period.id }
        expect(response).to redirect_to(root_path)
      end
    end

    context "when personnel record does not exist" do
      before { sign_in admin_unit_a }

      it "redirects with an alert" do
        cp_empty = create(:contact_point, organization: org_a)
        patch toggle_review_contact_point_personnel_path(cp_empty),
              params: { period_id: period.id }
        expect(response).to redirect_to(personnel_review_path(period_id: period.id))
      end
    end

    context "when the period is locked" do
      let!(:locked_period) { create(:monthly_period, :locked, year: 2026, month: 1) }
      let!(:locked_pers)   { create(:personnel, contact_point: cp_a, monthly_period: locked_period) }

      before { sign_in admin_unit_a }

      it "does not change reviewed_at" do
        expect {
          patch toggle_review_contact_point_personnel_path(cp_a),
                params: { period_id: locked_period.id }
        }.not_to(change { locked_pers.reload.reviewed_at })
      end

      it "redirects with an alert" do
        patch toggle_review_contact_point_personnel_path(cp_a),
              params: { period_id: locked_period.id }
        expect(response).to redirect_to(personnel_review_path(period_id: locked_period.id))
      end
    end
  end
end

require "rails_helper"

RSpec.describe "Meters", type: :request do
  let(:division) { create(:organization, level: :division, parent: nil) }
  let(:org_a) { create(:organization, level: :unit, parent: division) }
  let(:org_b) { create(:organization, level: :unit, parent: division) }

  let(:admin1) { create(:user, role: :admin_level1, organization: org_a) }
  let(:admin_unit_a) { create(:user, role: :admin_unit, organization: org_a) }
  let(:admin_unit_b) { create(:user, role: :admin_unit, organization: org_b) }
  let(:commander) { create(:user, role: :commander, organization: org_a) }
  let(:tech_user) { create(:user, role: :tech, organization: org_a) }

  let!(:cp_a) { create(:contact_point, organization: org_a) }
  let!(:cp_b) { create(:contact_point, organization: org_b) }

  let!(:meter_a) { create(:meter, contact_point: cp_a, organization: org_a, meter_type: :normal) }
  let!(:meter_b) { create(:meter, contact_point: cp_b, organization: org_b, meter_type: :public_meter) }

  # ---------------------------------------------------------------------------
  # INDEX
  # ---------------------------------------------------------------------------
  describe "GET /contact_points/:contact_point_id/meters" do
    context "as admin_unit of org_a" do
      it "shows meters of own contact_point" do
        sign_in admin_unit_a
        get contact_point_meters_path(cp_a)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(meter_a.name)
      end

      context "when contact_point belongs to another org" do
        before  { sign_in admin_unit_a }
        subject { get contact_point_meters_path(cp_b) }
        it_behaves_like "denies cross-org parent access"
      end
    end

    context "when contact_point does not exist (existence enumeration)" do
      before  { sign_in admin_unit_a }
      subject { get contact_point_meters_path(contact_point_id: 999_999) }
      it_behaves_like "denies cross-org parent access"
    end

    context "as admin_level1" do
      it "can access any contact_point's meters" do
        sign_in admin1
        get contact_point_meters_path(cp_b)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(meter_b.name)
      end
    end

    context "as commander" do
      it "can view own contact_point meters (read-only)" do
        sign_in commander
        get contact_point_meters_path(cp_a)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(meter_a.name)
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get contact_point_meters_path(cp_a)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # NEW
  # ---------------------------------------------------------------------------
  describe "GET /contact_points/:contact_point_id/meters/new" do
    it "allows admin_unit" do
      sign_in admin_unit_a
      get new_contact_point_meter_path(cp_a)
      expect(response).to have_http_status(:ok)
    end

    it "allows admin_level1" do
      sign_in admin1
      get new_contact_point_meter_path(cp_a)
      expect(response).to have_http_status(:ok)
    end

    it "redirects commander" do
      sign_in commander
      get new_contact_point_meter_path(cp_a)
      expect(response).to redirect_to(root_path)
    end

    it "redirects tech to user management" do
      sign_in tech_user
      get new_contact_point_meter_path(cp_a)
      expect(response).to redirect_to(users_path)
    end

    context "when contact_point belongs to another org (admin_unit)" do
      before  { sign_in admin_unit_a }
      subject { get new_contact_point_meter_path(cp_b) }
      it_behaves_like "denies cross-org parent access"
    end

    context "when contact_point does not exist (existence enumeration)" do
      before  { sign_in admin_unit_a }
      subject { get new_contact_point_meter_path(contact_point_id: 999_999) }
      it_behaves_like "denies cross-org parent access"
    end
  end

  # ---------------------------------------------------------------------------
  # CREATE
  # ---------------------------------------------------------------------------
  describe "POST /contact_points/:contact_point_id/meters" do
    let(:valid_params) { { meter: { name: "Công tơ tầng 1", meter_type: "normal", position: 0 } } }

    context "as admin_unit" do
      it "creates a meter for own contact_point" do
        sign_in admin_unit_a
        expect {
          post contact_point_meters_path(cp_a), params: valid_params
        }.to change(Meter, :count).by(1)

        meter = Meter.last
        expect(meter.organization).to eq(org_a)
        expect(meter.contact_point).to eq(cp_a)
        expect(meter.meter_type).to eq("normal")
        expect(response).to redirect_to(contact_point_meters_path(cp_a))
      end

      context "when targeting another org's contact_point" do
        before  { sign_in admin_unit_a }
        subject { post contact_point_meters_path(cp_b), params: valid_params }

        it_behaves_like "denies cross-org parent access"

        it "does not create any meter" do
          expect { subject }.not_to change(Meter, :count)
        end
      end

      it "re-renders form on invalid data (blank name)" do
        sign_in admin_unit_a
        post contact_point_meters_path(cp_a), params: { meter: { name: "", meter_type: "normal" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "as admin_level1" do
      it "creates a meter for any contact_point" do
        sign_in admin1
        expect {
          post contact_point_meters_path(cp_b), params: { meter: { name: "Công tơ B1", meter_type: "no_loss" } }
        }.to change(Meter, :count).by(1)

        meter = Meter.last
        expect(meter.organization).to eq(org_b)
        expect(meter.meter_type).to eq("no_loss")
      end
    end

    context "as commander" do
      it "is redirected" do
        sign_in commander
        expect {
          post contact_point_meters_path(cp_a), params: valid_params
        }.not_to change(Meter, :count)
        expect(response).to redirect_to(root_path)
      end
    end

    context "notes field" do
      it "saves notes when provided" do
        sign_in admin_unit_a
        post contact_point_meters_path(cp_a),
             params: { meter: { name: "CT ghi chú", meter_type: "normal", notes: "Gần cầu dao tổng" } }
        expect(Meter.last.notes).to eq("Gần cầu dao tổng")
      end

      it "allows blank notes" do
        sign_in admin_unit_a
        post contact_point_meters_path(cp_a),
             params: { meter: { name: "CT không ghi chú", meter_type: "normal", notes: "" } }
        expect(response).to redirect_to(contact_point_meters_path(cp_a))
        expect(Meter.last.notes).to be_blank
      end

      it "rejects notes over 1000 characters" do
        sign_in admin_unit_a
        post contact_point_meters_path(cp_a),
             params: { meter: { name: "CT", meter_type: "normal", notes: "x" * 1001 } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "meter_type validation" do
      it "rejects invalid meter_type" do
        sign_in admin_unit_a
        expect {
          post contact_point_meters_path(cp_a), params: { meter: { name: "CT", meter_type: "bogus" } }
        }.not_to change(Meter, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "accepts every type selectable in the contact-point form" do
        sign_in admin_unit_a
        Meter::CONTACT_POINT_FORM_TYPES.each_with_index do |type, i|
          expect {
            post contact_point_meters_path(cp_a), params: { meter: { name: "CT #{i}", meter_type: type } }
          }.to change(Meter, :count).by(1)
        end
      end

      it "rejects pump_station even when posted directly (controller filter)" do
        sign_in admin_unit_a
        expect {
          post contact_point_meters_path(cp_a),
               params: { meter: { name: "CT bom", meter_type: "pump_station" } }
        }.not_to change(Meter, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects pump_station for admin_level1 too — pump-station meters do not belong to a contact_point" do
        sign_in admin1
        expect {
          post contact_point_meters_path(cp_b),
               params: { meter: { name: "CT bom 2", meter_type: "pump_station" } }
        }.not_to change(Meter, :count)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # EDIT
  # ---------------------------------------------------------------------------
  describe "GET /contact_points/:contact_point_id/meters/:id/edit" do
    it "allows admin_unit to edit own meter" do
      sign_in admin_unit_a
      get edit_contact_point_meter_path(cp_a, meter_a)
      expect(response).to have_http_status(:ok)
    end

    context "when contact_point belongs to another org (admin_unit)" do
      before  { sign_in admin_unit_a }
      subject { get edit_contact_point_meter_path(cp_b, meter_b) }
      it_behaves_like "denies cross-org parent access"
    end
  end

  # ---------------------------------------------------------------------------
  # UPDATE
  # ---------------------------------------------------------------------------
  describe "PATCH /contact_points/:contact_point_id/meters/:id" do
    context "as admin_unit" do
      it "updates own meter" do
        sign_in admin_unit_a
        patch contact_point_meter_path(cp_a, meter_a),
              params: { meter: { name: "Công tơ mới", meter_type: "public_meter" } }
        expect(response).to redirect_to(contact_point_meters_path(cp_a))
        expect(meter_a.reload.name).to eq("Công tơ mới")
        expect(meter_a.reload.meter_type).to eq("public_meter")
      end

      context "when targeting another org's meter" do
        before  { sign_in admin_unit_a }
        subject { patch contact_point_meter_path(cp_b, meter_b), params: { meter: { name: "Hacked" } } }

        it_behaves_like "denies cross-org parent access"

        it "does not mutate the cross-org meter" do
          subject
          expect(meter_b.reload.name).not_to eq("Hacked")
        end
      end

      it "re-renders form on invalid data" do
        sign_in admin_unit_a
        patch contact_point_meter_path(cp_a, meter_a),
              params: { meter: { name: "" } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # DESTROY
  # ---------------------------------------------------------------------------
  describe "DELETE /contact_points/:contact_point_id/meters/:id" do
    context "as admin_unit" do
      it "destroys own meter" do
        sign_in admin_unit_a
        expect {
          delete contact_point_meter_path(cp_a, meter_a)
        }.to change(Meter, :count).by(-1)
        expect(response).to redirect_to(contact_point_meters_path(cp_a))
      end

      context "when targeting another org's meter" do
        before  { sign_in admin_unit_a }
        subject { delete contact_point_meter_path(cp_b, meter_b) }

        it_behaves_like "denies cross-org parent access"

        it "does not destroy the cross-org meter" do
          subject
          expect { meter_b.reload }.not_to raise_error
        end
      end
    end

    context "as commander" do
      it "is redirected" do
        sign_in commander
        expect {
          delete contact_point_meter_path(cp_a, meter_a)
        }.not_to change(Meter, :count)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end

require "rails_helper"

RSpec.describe "Users", type: :request do
  let!(:division) { create(:organization, :division) }
  let!(:org_a)    { create(:organization, :unit, parent: division) }

  let(:admin1)     { create(:user, :admin_level1, organization: division) }
  let(:tech_user)  { create(:user, :tech,         organization: division) }
  let(:admin_unit) { create(:user, :admin_unit,   organization: org_a) }
  let(:commander)  { create(:user, :commander,    organization: org_a) }

  # ---------------------------------------------------------------------------
  # GET /users
  # ---------------------------------------------------------------------------
  describe "GET /users" do
    context "as admin_level1" do
      it "lists all users" do
        sign_in admin1
        get users_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(admin1.full_name)
      end
    end

    context "as tech" do
      it "lists all users" do
        sign_in tech_user
        get users_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin_unit" do
      it "redirects to root" do
        sign_in admin_unit
        get users_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "as commander" do
      it "redirects to root" do
        sign_in commander
        get users_path
        expect(response).to redirect_to(root_path)
      end
    end

    context "when not authenticated" do
      it "redirects to sign in" do
        get users_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/new
  # ---------------------------------------------------------------------------
  describe "GET /users/new" do
    it "allows admin_level1" do
      sign_in admin1
      get new_user_path
      expect(response).to have_http_status(:ok)
    end

    it "allows tech" do
      sign_in tech_user
      get new_user_path
      expect(response).to have_http_status(:ok)
    end

    it "redirects admin_unit" do
      sign_in admin_unit
      get new_user_path
      expect(response).to redirect_to(root_path)
    end
  end

  # ---------------------------------------------------------------------------
  # POST /users
  # ---------------------------------------------------------------------------
  describe "POST /users" do
    let(:valid_params) do
      {
        user: {
          email:                 "new@army.mil",
          full_name:             "Nguyen Van B",
          password:              "Password1!",
          password_confirmation: "Password1!",
          role:                  "admin_unit",
          organization_id:       org_a.id
        }
      }
    end

    context "as admin_level1" do
      before { sign_in admin1 }

      it "creates an admin_unit user" do
        expect {
          post users_path, params: valid_params
        }.to change(User, :count).by(1)

        expect(response).to redirect_to(users_path)
        expect(User.last.organization).to eq(org_a)
      end

      it "auto-assigns division org for admin_level1 role" do
        expect {
          post users_path, params: {
            user: {
              email:                 "admin2@army.mil",
              full_name:             "Admin Hai",
              password:              "Password1!",
              password_confirmation: "Password1!",
              role:                  "admin_level1",
              organization_id:       ""
            }
          }
        }.to change(User, :count).by(1)

        expect(User.last.organization).to eq(division)
      end

      it "auto-assigns division org for tech role" do
        expect {
          post users_path, params: {
            user: {
              email:                 "tech2@army.mil",
              full_name:             "Tech Hai",
              password:              "Password1!",
              password_confirmation: "Password1!",
              role:                  "tech",
              organization_id:       ""
            }
          }
        }.to change(User, :count).by(1)

        expect(User.last.organization).to eq(division)
      end

      it "re-renders form on invalid data" do
        post users_path, params: { user: { email: "", full_name: "", role: "admin_unit", organization_id: org_a.id } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "as tech" do
      before { sign_in tech_user }

      it "can create a user" do
        expect {
          post users_path, params: valid_params
        }.to change(User, :count).by(1)
      end
    end

    context "as admin_unit" do
      it "is redirected" do
        sign_in admin_unit
        expect {
          post users_path, params: valid_params
        }.not_to change(User, :count)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # GET /users/:id/edit
  # ---------------------------------------------------------------------------
  describe "GET /users/:id/edit" do
    let!(:target) { create(:user, :admin_unit, organization: org_a) }

    it "allows admin_level1" do
      sign_in admin1
      get edit_user_path(target)
      expect(response).to have_http_status(:ok)
    end

    it "allows tech" do
      sign_in tech_user
      get edit_user_path(target)
      expect(response).to have_http_status(:ok)
    end

    it "redirects commander" do
      sign_in commander
      get edit_user_path(target)
      expect(response).to redirect_to(root_path)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /users/:id
  # ---------------------------------------------------------------------------
  describe "PATCH /users/:id" do
    let!(:target) { create(:user, :admin_unit, organization: org_a) }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "updates full_name and role" do
        patch user_path(target), params: {
          user: { full_name: "Tran Van C", role: "commander", organization_id: org_a.id }
        }
        expect(response).to redirect_to(users_path)
        expect(target.reload.full_name).to eq("Tran Van C")
        expect(target.reload.role).to eq("commander")
      end

      it "updates password when provided" do
        patch user_path(target), params: {
          user: { full_name: target.full_name, role: target.role,
                  organization_id: org_a.id, password: "NewPass1!", password_confirmation: "NewPass1!" }
        }
        expect(response).to redirect_to(users_path)
        expect(target.reload.valid_password?("NewPass1!")).to be true
      end

      it "does not change password when fields are blank" do
        old_hash = target.encrypted_password
        patch user_path(target), params: {
          user: { full_name: "Same", role: target.role, organization_id: org_a.id,
                  password: "", password_confirmation: "" }
        }
        expect(target.reload.encrypted_password).to eq(old_hash)
      end

      it "auto-reassigns org when role changes to admin_level1" do
        patch user_path(target), params: {
          user: { full_name: target.full_name, role: "admin_level1", organization_id: org_a.id }
        }
        expect(response).to redirect_to(users_path)
        expect(target.reload.organization).to eq(division)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /users/:id/lock
  # ---------------------------------------------------------------------------
  describe "PATCH /users/:id/lock" do
    let!(:target) { create(:user, :admin_unit, organization: org_a) }

    context "as admin_level1" do
      before { sign_in admin1 }

      it "locks the target user" do
        patch lock_user_path(target)
        expect(response).to redirect_to(users_path)
        expect(target.reload.access_locked?).to be true
      end

      it "cannot lock self" do
        patch lock_user_path(admin1)
        expect(response).to redirect_to(users_path)
        expect(admin1.reload.access_locked?).to be false
      end
    end

    context "as tech" do
      it "can lock a user" do
        sign_in tech_user
        patch lock_user_path(target)
        expect(response).to redirect_to(users_path)
        expect(target.reload.access_locked?).to be true
      end
    end

    context "as admin_unit" do
      it "is redirected" do
        sign_in admin_unit
        patch lock_user_path(target)
        expect(response).to redirect_to(root_path)
        expect(target.reload.access_locked?).to be false
      end
    end

    context "last admin_level1 safeguard" do
      it "blocks locking when target is the last active admin_level1" do
        # admin1 is the only admin_level1; tech attempts to lock them
        sign_in tech_user
        patch lock_user_path(admin1)
        expect(response).to redirect_to(users_path)
        expect(flash[:alert]).to include("cuối cùng")
        expect(admin1.reload.access_locked?).to be false
      end

      it "allows locking an admin_level1 when another active admin_level1 exists" do
        admin2 = create(:user, :admin_level1, organization: division)
        sign_in tech_user
        # Force admin1 to be created so admin2 is not the last active admin_level1
        expect(admin1).to be_persisted
        patch lock_user_path(admin2)
        expect(response).to redirect_to(users_path)
        expect(admin2.reload.access_locked?).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH /users/:id/unlock
  # ---------------------------------------------------------------------------
  describe "PATCH /users/:id/unlock" do
    let!(:locked_user) { create(:user, :admin_unit, organization: org_a) }

    before { locked_user.lock_access!(send_instructions: false) }

    context "as admin_level1" do
      it "unlocks the user" do
        sign_in admin1
        patch unlock_user_path(locked_user)
        expect(response).to redirect_to(users_path)
        expect(locked_user.reload.access_locked?).to be false
      end
    end

    context "as tech" do
      it "can unlock a user" do
        sign_in tech_user
        patch unlock_user_path(locked_user)
        expect(response).to redirect_to(users_path)
        expect(locked_user.reload.access_locked?).to be false
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Tech restriction: redirected from all business controllers
  # ---------------------------------------------------------------------------
  describe "tech user restricted to user management" do
    before { sign_in tech_user }

    it "is redirected from contact_points" do
      get contact_points_path
      expect(response).to redirect_to(users_path)
    end

    it "is redirected from meter_readings" do
      get meter_readings_path
      expect(response).to redirect_to(users_path)
    end
  end
end

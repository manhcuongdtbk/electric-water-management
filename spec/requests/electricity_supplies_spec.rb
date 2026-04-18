require "rails_helper"

RSpec.describe "ElectricitySupplies", type: :request do
  let(:division) { create(:organization, :division) }
  let(:org_a)    { create(:organization, :unit, parent: division) }
  let(:org_b)    { create(:organization, :unit, parent: division) }

  let(:admin1)       { create(:user, :admin_level1, organization: division) }
  let(:admin_unit_a) { create(:user, :admin_unit,   organization: org_a) }
  let(:admin_unit_b) { create(:user, :admin_unit,   organization: org_b) }
  let(:commander)    { create(:user, :commander,    organization: org_a) }
  let(:tech_user)    { create(:user, :tech,          organization: org_a) }

  let!(:period)  { create(:monthly_period, year: 2026, month: 2) }
  let!(:period2) { create(:monthly_period, year: 2026, month: 1) }

  # ---------------------------------------------------------------------------
  # SHOW
  # ---------------------------------------------------------------------------
  describe "GET /electricity_supply" do
    context "as admin_unit" do
      it "returns ok" do
        sign_in admin_unit_a
        get electricity_supply_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
      end

      it "shows only their own org data" do
        create(:unit_config, organization: org_b, monthly_period: period,
               electricity_supply_kw: 5000)
        sign_in admin_unit_a
        get electricity_supply_path(period_id: period.id)
        # org_b's data should not appear
        expect(response.body).not_to include(org_b.name)
      end

      # Regression lock: set_target_org forces admin_unit to current_user.organization
      # regardless of params[:org_id]. If someone refactors set_target_org to honor
      # the param for all roles, this test catches the cross-org leak.
      it "ignores params[:org_id] and uses own org config" do
        create(:unit_config, organization: org_a, monthly_period: period,
               electricity_supply_kw: 11_111)
        create(:unit_config, organization: org_b, monthly_period: period,
               electricity_supply_kw: 22_222)
        sign_in admin_unit_a
        get electricity_supply_path(period_id: period.id, org_id: org_b.id)
        expect(response.body).to include("11111")
        expect(response.body).not_to include("22222")
      end
    end

    context "as admin_level1" do
      it "returns ok with org selector" do
        sign_in admin1
        get electricity_supply_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
      end

      it "can view a specific org via org_id param" do
        sign_in admin1
        get electricity_supply_path(period_id: period.id, org_id: org_b.id)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(org_b.name)
      end
    end

    context "as commander" do
      it "returns ok (read-only)" do
        sign_in commander
        get electricity_supply_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as tech" do
      it "is silently redirected to user management" do
        sign_in tech_user
        get electricity_supply_path
        expect(response).to redirect_to(users_path)
        expect(flash[:alert]).to be_blank
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get electricity_supply_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with no monthly periods" do
      before { MonthlyPeriod.delete_all }

      it "renders ok showing no-period message" do
        sign_in admin_unit_a
        get electricity_supply_path
        expect(response).to have_http_status(:ok)
      end
    end

    context "history display" do
      it "shows past periods' entries for own org" do
        create(:unit_config, organization: org_a, monthly_period: period2,
               electricity_supply_kw: 3500)
        sign_in admin_unit_a
        get electricity_supply_path(period_id: period.id)
        expect(response.body).to include("3,500.00")
      end

      it "excludes the currently selected period from history" do
        create(:unit_config, organization: org_a, monthly_period: period,
               electricity_supply_kw: 9999)
        sign_in admin_unit_a
        # period2 is the only other period; no past configs with supply set → empty
        get electricity_supply_path(period_id: period.id)
        expect(response.body).to include(I18n.t("electricity_supplies.section_history.empty"))
      end

      it "does not show nil-supply configs in history table" do
        create(:unit_config, organization: org_a, monthly_period: period2,
               electricity_supply_kw: nil)
        sign_in admin_unit_a
        get electricity_supply_path(period_id: period.id)
        expect(response.body).to include(I18n.t("electricity_supplies.section_history.empty"))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # UPDATE
  # ---------------------------------------------------------------------------
  describe "PATCH /electricity_supply" do
    let(:valid_params) do
      { period_id: period.id, electricity_supply: { electricity_supply_kw: "12345.67" } }
    end

    context "as admin_unit" do
      it "creates unit_config with electricity_supply_kw and redirects" do
        sign_in admin_unit_a
        expect {
          patch electricity_supply_path, params: valid_params
        }.to change(UnitConfig, :count).by(1)

        config = UnitConfig.find_by(organization: org_a, monthly_period: period)
        expect(config.electricity_supply_kw).to eq(BigDecimal("12345.67"))
        expect(response).to redirect_to(electricity_supply_path(period_id: period.id, org_id: nil))
      end

      it "updates existing unit_config" do
        existing = create(:unit_config, organization: org_a, monthly_period: period,
                          electricity_supply_kw: 1000)
        sign_in admin_unit_a
        expect {
          patch electricity_supply_path, params: valid_params
        }.not_to change(UnitConfig, :count)

        expect(existing.reload.electricity_supply_kw).to eq(BigDecimal("12345.67"))
      end

      it "cannot update another org's data" do
        sign_in admin_unit_a
        params = valid_params.merge(org_id: org_b.id)
        patch electricity_supply_path, params: params

        # org_b should have no config (admin_unit_a's org is org_a, not org_b)
        config_b = UnitConfig.find_by(organization: org_b, monthly_period: period)
        expect(config_b).to be_nil
      end
    end

    context "as admin_level1" do
      it "can update any org via org_id param and stays on that org" do
        sign_in admin1
        params = valid_params.merge(org_id: org_b.id)
        patch electricity_supply_path, params: params

        config = UnitConfig.find_by(organization: org_b, monthly_period: period)
        expect(config.electricity_supply_kw).to eq(BigDecimal("12345.67"))
        expect(response).to redirect_to(electricity_supply_path(period_id: period.id, org_id: org_b.id.to_s))
      end

      it "defaults to first org when no org_id given, and preserves it in redirect" do
        # Force unit orgs to exist so set_target_org can find a first org
        org_a
        org_b
        sign_in admin1
        # No org_id in params — defaults to first unit org
        patch electricity_supply_path, params: valid_params

        first_org = Organization.units.ordered.first
        config = UnitConfig.find_by(organization: first_org, monthly_period: period)
        expect(config.electricity_supply_kw).to eq(BigDecimal("12345.67"))
        # redirect preserves the first org so UI stays stable
        expect(response).to redirect_to(electricity_supply_path(period_id: period.id, org_id: first_org.id.to_s))
      end
    end

    context "as commander" do
      it "redirects — no write access" do
        sign_in commander
        patch electricity_supply_path, params: valid_params
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq(I18n.t("flash.access_denied"))
      end
    end

    context "as tech" do
      it "is redirected to user management" do
        sign_in tech_user
        patch electricity_supply_path, params: valid_params
        expect(response).to redirect_to(users_path)
      end
    end
  end
end

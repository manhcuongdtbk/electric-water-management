require "rails_helper"

RSpec.describe "UnitConfigs", type: :request do
  let(:division) { create(:organization, :division) }
  let(:org_a)    { create(:organization, :unit, parent: division) }
  let(:org_b)    { create(:organization, :unit, parent: division) }

  let(:admin1)      { create(:user, :admin_level1, organization: division) }
  let(:admin_unit_a) { create(:user, :admin_unit,   organization: org_a) }
  let(:admin_unit_b) { create(:user, :admin_unit,   organization: org_b) }
  let(:commander)   { create(:user, :commander,     organization: org_a) }
  let(:tech_user)   { create(:user, :tech,           organization: org_a) }

  let!(:period) { create(:monthly_period) }

  let!(:cp_a1) { create(:contact_point, organization: org_a) }
  let!(:cp_a2) { create(:contact_point, organization: org_a) }

  # ---------------------------------------------------------------------------
  # SHOW
  # ---------------------------------------------------------------------------
  describe "GET /unit_config" do
    context "as admin_level1" do
      it "returns ok" do
        sign_in admin1
        get unit_config_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as admin_unit" do
      it "returns ok" do
        sign_in admin_unit_a
        get unit_config_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as commander" do
      it "returns ok (read-only view)" do
        sign_in commander
        get unit_config_path(period_id: period.id)
        expect(response).to have_http_status(:ok)
      end
    end

    context "as tech" do
      it "is redirected to user management" do
        sign_in tech_user
        get unit_config_path(period_id: period.id)
        expect(response).to redirect_to(users_path)
      end
    end

    context "when unauthenticated" do
      it "redirects to sign in" do
        get unit_config_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with no monthly periods" do
      before { MonthlyPeriod.delete_all }

      it "renders ok showing no-period message" do
        sign_in admin_unit_a
        get unit_config_path
        expect(response).to have_http_status(:ok)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # UPDATE — Division config (admin_level1 only)
  # ---------------------------------------------------------------------------
  describe "PATCH /unit_config (section=division)" do
    let(:valid_division_params) do
      {
        section: "division",
        period_id: period.id,
        division_config: { savings_rate: "7.00", division_public_rate: "8.00" }
      }
    end

    context "as admin_level1" do
      it "creates division config and redirects" do
        sign_in admin1
        expect {
          patch unit_config_path, params: valid_division_params
        }.to change(UnitConfig, :count).by(1)

        config = UnitConfig.find_by(organization: division, monthly_period: period)
        expect(config.savings_rate).to eq(BigDecimal("0.07"))
        expect(config.division_public_rate).to eq(BigDecimal("0.08"))
        expect(response).to redirect_to(unit_config_path(period_id: period.id))
      end

      it "updates existing division config" do
        existing = create(:unit_config, organization: division, monthly_period: period,
                                        savings_rate: 0.05, division_public_rate: 0.05)
        sign_in admin1
        patch unit_config_path, params: valid_division_params
        expect(existing.reload.savings_rate).to eq(BigDecimal("0.07"))
        expect(existing.reload.division_public_rate).to eq(BigDecimal("0.08"))
      end
    end

    context "as admin_unit" do
      it "is redirected — cannot update division config" do
        sign_in admin_unit_a
        patch unit_config_path, params: valid_division_params
        expect(response).to redirect_to(unit_config_path)
        expect(flash[:alert]).to eq(I18n.t("flash.unauthorized"))
      end
    end

    context "as commander" do
      it "is redirected" do
        sign_in commander
        patch unit_config_path, params: valid_division_params
        expect(response).to redirect_to(unit_config_path)
        expect(flash[:alert]).to eq(I18n.t("flash.unauthorized"))
      end
    end
  end

  # ---------------------------------------------------------------------------
  # UPDATE — Unit config (admin_unit only)
  # ---------------------------------------------------------------------------
  describe "PATCH /unit_config (section=unit)" do
    let(:valid_unit_params) do
      {
        section: "unit",
        period_id: period.id,
        unit_config: { unit_public_rate: "15.00" },
        khac: {
          cp_a1.id.to_s => { other_type: "fixed_kw",        other_value: "100" },
          cp_a2.id.to_s => { other_type: "factor_per_person", other_value: "5"  }
        }
      }
    end

    context "as admin_unit of org_a" do
      it "creates unit config and contact_point deductions" do
        sign_in admin_unit_a
        expect {
          patch unit_config_path, params: valid_unit_params
        }.to change(UnitConfig, :count).by(1)
                                       .and change(ContactPointOtherDeduction, :count).by(2)

        config = UnitConfig.find_by(organization: org_a, monthly_period: period)
        expect(config.unit_public_rate).to eq(BigDecimal("0.15"))

        ded1 = ContactPointOtherDeduction.find_by(contact_point: cp_a1, monthly_period: period)
        expect(ded1.other_type).to eq("fixed_kw")
        expect(ded1.other_value).to eq(BigDecimal("100"))

        ded2 = ContactPointOtherDeduction.find_by(contact_point: cp_a2, monthly_period: period)
        expect(ded2.other_type).to eq("factor_per_person")
        expect(ded2.other_value).to eq(BigDecimal("5"))

        expect(response).to redirect_to(unit_config_path(period_id: period.id))
      end

      it "updates existing records on second save" do
        create(:unit_config, organization: org_a, monthly_period: period, unit_public_rate: 0.10)
        create(:contact_point_other_deduction, contact_point: cp_a1, monthly_period: period,
               other_type: :fixed_kw, other_value: 50)
        sign_in admin_unit_a

        expect {
          patch unit_config_path, params: valid_unit_params
        }.not_to change(UnitConfig, :count)

        ded1 = ContactPointOtherDeduction.find_by(contact_point: cp_a1, monthly_period: period)
        expect(ded1.other_value).to eq(BigDecimal("100"))
      end

      it "ignores contact_points from other organizations" do
        cp_b = create(:contact_point, organization: org_b)
        sign_in admin_unit_a

        params_with_foreign_cp = valid_unit_params.deep_merge(
          khac: { cp_b.id.to_s => { other_type: "fixed_kw", other_value: "999" } }
        )
        patch unit_config_path, params: params_with_foreign_cp

        expect(ContactPointOtherDeduction.find_by(contact_point: cp_b)).to be_nil
      end
    end

    context "as admin_level1" do
      it "is redirected — cannot update unit config" do
        sign_in admin1
        patch unit_config_path, params: valid_unit_params
        expect(response).to redirect_to(unit_config_path)
        expect(flash[:alert]).to eq(I18n.t("flash.unauthorized"))
      end
    end

    context "as commander" do
      it "is redirected" do
        sign_in commander
        patch unit_config_path, params: valid_unit_params
        expect(response).to redirect_to(unit_config_path)
        expect(flash[:alert]).to eq(I18n.t("flash.unauthorized"))
      end
    end
  end
end

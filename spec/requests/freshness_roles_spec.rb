require "rails_helper"

# Task 13 of #334 — request-spec coverage of the freshness (độ tuổi) indicator
# across the system's SIX real roles (V2_HANH_VI_HE_THONG.md section 1):
#   SA, UA, UA-ZM, CMD, CMD-ZM, TECH.
#
# Role construction mirrors spec/requests/role_access_matrix_spec.rb and
# spec/requests/billing_spec.rb: the sample's unit_a is the zone manager
# (zone.manager_unit = unit_a), unit_b is a plain unit in the same zone.
#   SA     = create(:user, :system_admin)
#   UA     = create(:user, :unit_admin, unit: unit_b)   # plain unit admin
#   UA-ZM  = create(:user, :unit_admin, unit: unit_a)   # admin of the zone-manager unit
#   CMD    = create(:user, :commander,  unit: unit_b)   # read-only counterpart of UA
#   CMD-ZM = create(:user, :commander,  unit: unit_a)   # read-only counterpart of UA-ZM
#   TECH   = create(:user, :technician)                 # blocked from billing
#
# Freshness is computed per ZONE (FreshnessIndicatable#freshness_zones). Every
# non-SA role here has its unit in "Khu vực 1", so a single stale edit on that
# zone's data surfaces the banner for all of SA/UA/UA-ZM/CMD/CMD-ZM. TECH cannot
# reach billing at all — its assertion is the block (redirect), not the banner.
RSpec.describe "Freshness indicator across the six roles", type: :request do
  let(:sample) { setup_zone_one_full_sample }
  let(:zone) { sample.zone }
  let(:period) { sample.period }

  # Run the real calculation, then edit a meter reading so the zone's derived
  # data goes stale (mirrors spec/requests/billing_freshness_spec.rb).
  def make_zone_stale
    CalculationOrchestrator.new(zone: zone, period: period).call
    reading = sample.meters[:ct_a1].meter_readings.find_by!(period: period)
    reading.update!(reading_end: reading.reading_end + 50)
  end

  before { make_zone_stale }

  describe "roles that can see billing → stale banner shows for their zone" do
    it "CHIEU-do-tuoi-vai-tro: SA sees the stale banner" do
      sign_in create(:user, :system_admin)
      get billing_path(period_id: period.id)
      expect(response.body).to include("freshness-stale")
      expect(response.body).to include(zone.name)
    end

    it "CHIEU-do-tuoi-vai-tro: UA (plain unit admin) sees the stale banner for their zone" do
      sign_in create(:user, :unit_admin, unit: sample.unit_b)
      get billing_path(period_id: period.id)
      expect(response.body).to include("freshness-stale")
      expect(response.body).to include(zone.name)
    end

    it "CHIEU-do-tuoi-vai-tro: UA-ZM (unit admin managing the zone) sees the stale banner" do
      sign_in create(:user, :unit_admin, unit: sample.unit_a)
      get billing_path(period_id: period.id)
      expect(response.body).to include("freshness-stale")
      expect(response.body).to include(zone.name)
    end

    it "CHIEU-do-tuoi-vai-tro: CMD (read-only commander) sees the stale banner for their zone" do
      sign_in create(:user, :commander, unit: sample.unit_b)
      get billing_path(period_id: period.id)
      expect(response.body).to include("freshness-stale")
      expect(response.body).to include(zone.name)
    end

    it "CHIEU-do-tuoi-vai-tro: CMD-ZM (read-only commander managing the zone) sees the stale banner" do
      sign_in create(:user, :commander, unit: sample.unit_a)
      get billing_path(period_id: period.id)
      expect(response.body).to include("freshness-stale")
      expect(response.body).to include(zone.name)
    end

    it "CHIEU-do-tuoi-vai-tro: DC (division commander) sees the stale banner" do
      sign_in create(:user, :division_commander)
      get billing_path(period_id: period.id)
      expect(response.body).to include("freshness-stale")
      expect(response.body).to include(zone.name)
    end
  end

  # The "Tính toán lại" button is gated by can?(:recalculate, Calculation) in the
  # billing view, and renders as a form posting to recalculate_billing_path. We
  # assert the read-only contract two ways: the Ability denies :recalculate, and the
  # page omits the recalculate form. (We cannot assert absence of the literal text
  # "Tính toán lại" because the stale banner's recalculate_hint contains it — and
  # that banner IS expected to show for commanders.)
  describe "commanders are read-only → no recalculate action" do
    it "CHIEU-do-tuoi-vai-tro: CMD cannot recalculate and the page hides the recalculate button" do
      commander = create(:user, :commander, unit: sample.unit_b)
      expect(Ability.new(commander).can?(:recalculate, Calculation)).to be(false)

      sign_in commander
      get billing_path(period_id: period.id)
      expect(response.body).to include("freshness-stale")
      doc = Nokogiri::HTML(response.body)
      expect(doc.css("form[action*='#{recalculate_billing_path}']")).to be_empty
    end

    it "CHIEU-do-tuoi-vai-tro: CMD-ZM cannot recalculate and the page hides the recalculate button" do
      commander = create(:user, :commander, unit: sample.unit_a)
      expect(Ability.new(commander).can?(:recalculate, Calculation)).to be(false)

      sign_in commander
      get billing_path(period_id: period.id)
      expect(response.body).to include("freshness-stale")
      doc = Nokogiri::HTML(response.body)
      expect(doc.css("form[action*='#{recalculate_billing_path}']")).to be_empty
    end
  end

  describe "technician is blocked from billing" do
    it "CHIEU-do-tuoi-vai-tro: TECH is redirected away from billing (no indicator to see)" do
      sign_in create(:user, :technician)
      get billing_path(period_id: period.id)
      expect(response).to have_http_status(:redirect)
      expect(response.body).not_to include("freshness-stale")
    end
  end
end

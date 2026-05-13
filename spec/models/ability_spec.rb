require "rails_helper"
require "cancan/matchers"

RSpec.describe Ability do
  subject(:ability) { described_class.new(user) }

  let(:division)    { create(:organization, :division) }
  let(:unit_a)      { create(:organization, :unit, parent: division) }
  let(:unit_b)      { create(:organization, :unit, parent: division) }
  let(:period)      { create(:monthly_period) }
  let(:cp_a)        { create(:contact_point, organization: unit_a) }
  let(:cp_b)        { create(:contact_point, organization: unit_b) }
  let(:meter_a)     { create(:meter, organization: unit_a, contact_point: cp_a) }
  let(:meter_b)     { create(:meter, organization: unit_b, contact_point: cp_b) }
  let(:personnel_a) { create(:personnel, contact_point: cp_a, monthly_period: period) }
  let(:personnel_b) { create(:personnel, contact_point: cp_b, monthly_period: period) }
  let(:reading_a)   { create(:meter_reading, meter: meter_a, monthly_period: period) }
  let(:reading_b)   { create(:meter_reading, meter: meter_b, monthly_period: period) }
  let(:calc_a)      { create(:monthly_calculation, contact_point: cp_a, monthly_period: period) }
  let(:calc_b)      { create(:monthly_calculation, contact_point: cp_b, monthly_period: period) }
  let(:config_a)    { create(:unit_config, organization: unit_a, monthly_period: period) }
  let(:config_b)    { create(:unit_config, organization: unit_b, monthly_period: period) }
  let(:division_config) { create(:unit_config, organization: division, monthly_period: period) }
  let(:main_meter)       { create(:main_meter) }
  let(:other_main_meter) { create(:main_meter) }
  let(:main_meter_reading) { create(:main_meter_reading, main_meter: main_meter, monthly_period: period) }
  let(:other_main_meter_reading) { create(:main_meter_reading, main_meter: other_main_meter, monthly_period: period) }

  # F05 zone access — admin_unit/commander get read on the MainMeter their org belongs to.
  # The ability hash query (MainMeter, organizations: { id: org_id }) walks the
  # `has_many :organizations, through: :zone` association, so the unit must share
  # the meter's zone — the legacy main_meter_id link alone is no longer enough.
  before do
    unit_a.update!(main_meter: main_meter, zone: main_meter.zone)
    unit_b.update!(main_meter: other_main_meter, zone: other_main_meter.zone)
  end

  context "when user is nil" do
    let(:user) { nil }

    it { is_expected.not_to be_able_to(:read, ContactPoint) }
    it { is_expected.not_to be_able_to(:manage, User) }
  end

  context "when user is admin_level1" do
    let(:user) { create(:user, :admin_level1, organization: division) }

    it { is_expected.to be_able_to(:manage, cp_a) }
    it { is_expected.to be_able_to(:manage, cp_b) }
    it { is_expected.to be_able_to(:manage, meter_a) }
    it { is_expected.to be_able_to(:manage, meter_b) }
    it { is_expected.to be_able_to(:manage, personnel_a) }
    it { is_expected.to be_able_to(:manage, personnel_b) }
    it { is_expected.to be_able_to(:manage, reading_a) }
    it { is_expected.to be_able_to(:manage, reading_b) }
    it { is_expected.to be_able_to(:manage, calc_a) }
    it { is_expected.to be_able_to(:manage, calc_b) }
    it { is_expected.to be_able_to(:manage, config_a) }
    it { is_expected.to be_able_to(:manage, division_config) }
    it { is_expected.not_to be_able_to(:update_unit_config, config_a) }
    it { is_expected.to be_able_to(:manage, User.new) }
    it { is_expected.to be_able_to(:manage, MonthlyPeriod.new) }
    it { is_expected.to be_able_to(:manage, RankQuota.new) }
    it { is_expected.to be_able_to(:manage, main_meter) }
    it { is_expected.to be_able_to(:manage, main_meter_reading) }
    it { is_expected.not_to be_able_to(:manage, :backup) }
  end

  context "when user is admin_unit of unit_a" do
    let(:user) { create(:user, :admin_unit, organization: unit_a) }

    it { is_expected.to be_able_to(:manage, cp_a) }
    it { is_expected.not_to be_able_to(:read, cp_b) }
    it { is_expected.to be_able_to(:manage, meter_a) }
    it { is_expected.not_to be_able_to(:read, meter_b) }
    it { is_expected.to be_able_to(:manage, personnel_a) }
    it { is_expected.not_to be_able_to(:read, personnel_b) }
    it { is_expected.to be_able_to(:manage, reading_a) }
    it { is_expected.not_to be_able_to(:read, reading_b) }
    it { is_expected.to be_able_to(:read, calc_a) }
    it { is_expected.to be_able_to(:recalculate, calc_a) }
    it { is_expected.not_to be_able_to(:create, calc_a) }
    it { is_expected.not_to be_able_to(:update, calc_a) }
    it { is_expected.not_to be_able_to(:destroy, calc_a) }
    it { is_expected.not_to be_able_to(:read, calc_b) }

    it { is_expected.to be_able_to(:read, config_a) }
    it { is_expected.to be_able_to(:update_unit_config, config_a) }
    it { is_expected.not_to be_able_to(:update, config_a) }
    it { is_expected.not_to be_able_to(:update, division_config) }
    it { is_expected.not_to be_able_to(:read, config_b) }

    it { is_expected.not_to be_able_to(:manage, User.new) }
    it { is_expected.not_to be_able_to(:manage, MonthlyPeriod.new) }
    it { is_expected.not_to be_able_to(:manage, RankQuota.new) }
    it { is_expected.to be_able_to(:read, main_meter) }
    it { is_expected.not_to be_able_to(:read, other_main_meter) }
    it { is_expected.not_to be_able_to(:manage, main_meter) }
    it { is_expected.to be_able_to(:read, main_meter_reading) }
    it { is_expected.not_to be_able_to(:read, other_main_meter_reading) }
    it { is_expected.not_to be_able_to(:update, main_meter_reading) }
  end

  context "when user is commander of unit_a" do
    let(:user) { create(:user, :commander, organization: unit_a) }

    it { is_expected.to be_able_to(:read, cp_a) }
    it { is_expected.not_to be_able_to(:create, ContactPoint) }
    it { is_expected.not_to be_able_to(:update, cp_a) }
    it { is_expected.not_to be_able_to(:destroy, cp_a) }
    it { is_expected.not_to be_able_to(:read, cp_b) }

    it { is_expected.to be_able_to(:read, meter_a) }
    it { is_expected.not_to be_able_to(:update, meter_a) }
    it { is_expected.not_to be_able_to(:read, meter_b) }

    it { is_expected.to be_able_to(:read, personnel_a) }
    it { is_expected.not_to be_able_to(:update, personnel_a) }
    it { is_expected.not_to be_able_to(:read, personnel_b) }

    it { is_expected.to be_able_to(:read, reading_a) }
    it { is_expected.not_to be_able_to(:update, reading_a) }
    it { is_expected.not_to be_able_to(:read, reading_b) }

    it { is_expected.to be_able_to(:read, calc_a) }
    it { is_expected.not_to be_able_to(:manage, calc_a) }
    it { is_expected.not_to be_able_to(:read, calc_b) }

    it { is_expected.to be_able_to(:read, config_a) }
    it { is_expected.not_to be_able_to(:update_unit_config, config_a) }
    it { is_expected.not_to be_able_to(:update, config_a) }

    it { is_expected.to be_able_to(:read, main_meter) }
    it { is_expected.not_to be_able_to(:read, other_main_meter) }
    it { is_expected.not_to be_able_to(:manage, main_meter) }
    it { is_expected.to be_able_to(:read, main_meter_reading) }
    it { is_expected.not_to be_able_to(:update, main_meter_reading) }

    it { is_expected.not_to be_able_to(:manage, User.new) }
    it { is_expected.not_to be_able_to(:manage, MonthlyPeriod.new) }
  end

  context "when user is tech" do
    let(:user) { create(:user, :tech, organization: division) }

    it { is_expected.to be_able_to(:manage, User.new) }
    it { is_expected.to be_able_to(:manage, create(:user, :admin_unit, organization: unit_a)) }
    it { is_expected.to be_able_to(:manage, :backup) }

    it { is_expected.not_to be_able_to(:read, cp_a) }
    it { is_expected.not_to be_able_to(:read, meter_a) }
    it { is_expected.not_to be_able_to(:read, personnel_a) }
    it { is_expected.not_to be_able_to(:read, reading_a) }
    it { is_expected.not_to be_able_to(:read, calc_a) }
    it { is_expected.not_to be_able_to(:read, config_a) }
    it { is_expected.not_to be_able_to(:manage, MonthlyPeriod.new) }
    it { is_expected.not_to be_able_to(:manage, RankQuota.new) }
  end

  describe "ContactPointGroup abilities" do
    let(:cpg_a) { create(:contact_point_group, organization: unit_a) }
    let(:cpg_b) { create(:contact_point_group, organization: unit_b) }

    context "when user is admin_level1" do
      let(:user) { create(:user, :admin_level1, organization: division) }

      it { is_expected.to be_able_to(:manage, cpg_a) }
      it { is_expected.to be_able_to(:manage, cpg_b) }
    end

    context "when user is admin_unit of unit_a" do
      let(:user) { create(:user, :admin_unit, organization: unit_a) }

      it { is_expected.to be_able_to(:manage, cpg_a) }
      it { is_expected.not_to be_able_to(:read, cpg_b) }
      it { is_expected.not_to be_able_to(:manage, cpg_b) }
    end

    context "when user is commander of unit_a" do
      let(:user) { create(:user, :commander, organization: unit_a) }

      it { is_expected.to be_able_to(:read, cpg_a) }
      it { is_expected.not_to be_able_to(:update, cpg_a) }
      it { is_expected.not_to be_able_to(:destroy, cpg_a) }
      it { is_expected.not_to be_able_to(:read, cpg_b) }
    end
  end

  describe ".accessible_by" do
    let!(:cp_a_record) { cp_a }
    let!(:cp_b_record) { cp_b }

    context "for admin_level1" do
      let(:user) { create(:user, :admin_level1, organization: division) }

      it "returns all contact_points" do
        expect(ContactPoint.accessible_by(ability)).to match_array([ cp_a_record, cp_b_record ])
      end
    end

    context "for admin_unit of unit_a" do
      let(:user) { create(:user, :admin_unit, organization: unit_a) }

      it "returns only own org contact_points" do
        expect(ContactPoint.accessible_by(ability)).to eq([ cp_a_record ])
      end
    end

    context "for commander of unit_a" do
      let(:user) { create(:user, :commander, organization: unit_a) }

      it "returns only own org contact_points (read)" do
        expect(ContactPoint.accessible_by(ability, :read)).to eq([ cp_a_record ])
      end
    end

    context "for tech" do
      let(:user) { create(:user, :tech, organization: division) }

      it "returns no contact_points" do
        expect(ContactPoint.accessible_by(ability)).to be_empty
      end
    end
  end
end

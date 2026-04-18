require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to have_many(:locked_monthly_periods).class_name("MonthlyPeriod") }
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:full_name) }
    it { is_expected.to validate_length_of(:full_name).is_at_most(100) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_presence_of(:role) }

    it "is valid with all required attributes" do
      expect(build(:user)).to be_valid
    end
  end

  describe "password complexity" do
    it "rejects a password with only letters" do
      user = build(:user, password: "abcdefgh", password_confirmation: "abcdefgh")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("phải có ít nhất 1 chữ và 1 số")
    end

    it "rejects a password with only digits" do
      user = build(:user, password: "12345678", password_confirmation: "12345678")
      expect(user).not_to be_valid
    end

    it "rejects a password shorter than 8 characters" do
      user = build(:user, password: "abc123", password_confirmation: "abc123")
      expect(user).not_to be_valid
    end

    it "accepts a password with at least 8 characters containing letters and digits" do
      user = build(:user, password: "abc12345", password_confirmation: "abc12345")
      expect(user).to be_valid
    end
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:role)
        .with_values(admin_level1: 0, admin_unit: 1, commander: 2, tech: 3)
    }
  end

  describe "scopes" do
    let!(:org)      { create(:organization, :division) }
    let!(:unit_org) { create(:organization, :unit, parent: org) }
    let!(:u1)       { create(:user, :admin_level1, organization: org) }
    let!(:u2)       { create(:user, :commander,    organization: unit_org) }
    let!(:u3)       { create(:user, :admin_unit) }

    it ".by_organization filters by organization" do
      expect(User.by_organization(org.id)).to include(u1)
      expect(User.by_organization(org.id)).not_to include(u2, u3)
    end

    it ".admins returns admin_level1 and admin_unit" do
      expect(User.admins).to include(u1, u3)
      expect(User.admins).not_to include(u2)
    end
  end
end

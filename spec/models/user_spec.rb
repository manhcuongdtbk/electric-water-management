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

  describe "last admin safeguards" do
    let!(:division) { create(:organization, :division) }
    let!(:admin)    { create(:user, :admin_level1, organization: division) }

    describe "#last_active_admin_level1?" do
      it "returns true when only active admin_level1" do
        expect(admin.last_active_admin_level1?).to be true
      end

      it "returns false when another active admin exists" do
        create(:user, :admin_level1, organization: division)
        expect(admin.last_active_admin_level1?).to be false
      end

      it "returns false for non-admin_level1 role" do
        other = create(:user, :tech, organization: division)
        expect(other.last_active_admin_level1?).to be false
      end

      it "returns true when other admin_level1 exists but is locked" do
        other = create(:user, :admin_level1, organization: division)
        other.update_column(:locked_at, Time.current)
        expect(admin.last_active_admin_level1?).to be true
      end
    end

    describe "prevent_locking_last_admin_level1 (model validation via direct AR save)" do
      it "is invalid when last admin attempts to set locked_at directly" do
        admin.locked_at = Time.current
        expect(admin).not_to be_valid
        expect(admin.errors[:base].join).to match(/cuối cùng/)
      end

      it "allows locking when another active admin exists" do
        create(:user, :admin_level1, organization: division)
        admin.locked_at = Time.current
        expect(admin).to be_valid
      end

      it "does not fire when unlocking (locked_at_was present → nil)" do
        admin.update_column(:locked_at, Time.current)
        admin.reload
        admin.locked_at = nil
        expect(admin).to be_valid
      end

      it "does not fire for non-admin_level1 users" do
        tech = create(:user, :tech, organization: division)
        tech.locked_at = Time.current
        expect(tech).to be_valid
      end
    end

    describe "prevent_destroying_last_admin_level1" do
      it "prevents destroy and adds error when last admin" do
        expect { admin.destroy }.not_to change(User, :count)
        expect(admin.errors[:base].join).to match(/cuối cùng/)
      end

      it "allows destroy when another active admin_level1 exists" do
        create(:user, :admin_level1, organization: division)
        expect { admin.destroy }.to change(User, :count).by(-1)
      end

      it "allows destroy of non-admin_level1 users even when no other admin" do
        tech = create(:user, :tech, organization: division)
        expect { tech.destroy }.to change(User, :count).by(-1)
      end
    end

    describe "#lock_access! override (auto-lock warning)" do
      it "logs WARN when last admin is auto-locked" do
        expect(Rails.logger).to receive(:warn).with(/\[SECURITY\].*Last active admin_level1/)
        admin.lock_access!
      end

      it "does not log SECURITY warning when another active admin exists" do
        create(:user, :admin_level1, organization: division)
        expect(Rails.logger).not_to receive(:warn).with(/\[SECURITY\]/)
        admin.lock_access!
      end

      it "still locks the account even when last admin (auto-lock not blocked)" do
        expect { admin.lock_access! }.to change { admin.reload.access_locked? }.to(true)
      end

      it "validation does NOT block lock_access! (Devise bypasses AR validations)" do
        expect { admin.lock_access!(send_instructions: false) }.not_to raise_error
        expect(admin.reload.access_locked?).to be true
      end
    end
  end
end

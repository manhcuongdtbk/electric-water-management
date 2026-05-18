require "rails_helper"

RSpec.describe User do
  describe "associations" do
    it { is_expected.to belong_to(:unit).optional }
  end

  describe "validations" do
    subject { build(:user) }
    it { is_expected.to validate_presence_of(:username) }
    it { is_expected.to validate_uniqueness_of(:username) }
    it { is_expected.to validate_presence_of(:display_name) }
    it { is_expected.to validate_presence_of(:role) }
  end

  describe "conditional unit_id validation" do
    it "yêu cầu unit_id khi role = unit_admin" do
      user = build(:user, role: "unit_admin", unit: nil)
      expect(user).not_to be_valid
      expect(user.errors[:unit_id]).to be_present
    end

    it "yêu cầu unit_id khi role = commander" do
      user = build(:user, role: "commander", unit: nil)
      expect(user).not_to be_valid
      expect(user.errors[:unit_id]).to be_present
    end

    it "không yêu cầu unit_id khi role = technician" do
      user = build(:user, role: "technician", unit: nil)
      expect(user).to be_valid
    end

    it "không yêu cầu unit_id khi role = system_admin" do
      user = build(:user, role: "system_admin", unit: nil)
      expect(user).to be_valid
    end
  end

  describe "enum :role" do
    it "có 4 giá trị" do
      expect(User.roles.keys).to match_array(%w[technician system_admin unit_admin commander])
    end
  end

  describe "password complexity" do
    let(:base_attrs) { { username: "test", display_name: "Test", role: "technician" } }

    it "valid khi đủ điều kiện (8 ký tự, hoa, thường, số, đặc biệt)" do
      user = User.new(base_attrs.merge(password: "Abc@1234", password_confirmation: "Abc@1234"))
      expect(user).to be_valid
    end

    it "invalid khi < 8 ký tự" do
      user = User.new(base_attrs.merge(password: "Ab@1", password_confirmation: "Ab@1"))
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "invalid khi thiếu chữ hoa" do
      user = User.new(base_attrs.merge(password: "abc@1234", password_confirmation: "abc@1234"))
      expect(user).not_to be_valid
    end

    it "invalid khi thiếu chữ thường" do
      user = User.new(base_attrs.merge(password: "ABC@1234", password_confirmation: "ABC@1234"))
      expect(user).not_to be_valid
    end

    it "invalid khi thiếu số" do
      user = User.new(base_attrs.merge(password: "Abcdefg@", password_confirmation: "Abcdefg@"))
      expect(user).not_to be_valid
    end

    it "invalid khi thiếu ký tự đặc biệt" do
      user = User.new(base_attrs.merge(password: "Abcd1234", password_confirmation: "Abcd1234"))
      expect(user).not_to be_valid
    end
  end

  describe "default_account destroy guard" do
    it "không cho phép xóa khi default_account = true" do
      user = create(:user, :default_account)
      result = user.destroy
      expect(result).to be_falsey
      expect(user).to be_persisted
      expect(User.exists?(user.id)).to be true
    end

    it "cho phép xóa khi default_account = false" do
      user = create(:user)
      result = user.destroy
      expect(result).to be_truthy
      expect(User.exists?(user.id)).to be false
    end
  end

  describe "Devise" do
    it "xác thực bằng username (không yêu cầu email)" do
      user = create(:user, username: "abcUser", password: "Abc@1234", password_confirmation: "Abc@1234")
      expect(user.valid_password?("Abc@1234")).to be true
      expect(user.valid_password?("wrong")).to be false
    end

    it "không có cột email" do
      expect(User.column_names).not_to include("email")
    end

    it "timeout 2 giờ" do
      expect(build(:user).timeout_in).to eq(2.hours)
    end
  end
end

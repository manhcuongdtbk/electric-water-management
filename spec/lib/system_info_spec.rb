require "rails_helper"

RSpec.describe SystemInfo do
  describe ".version" do
    it "trả về hằng số VERSION đã đóng băng" do
      expect(described_class.version).to equal(SystemInfo::VERSION)
      expect(SystemInfo::VERSION).to be_frozen
    end

    it "khớp nội dung version.txt ở gốc repo" do
      expected = File.read(Rails.root.join("version.txt")).strip
      expect(described_class.version).to eq(expected)
    end
  end

  describe ".application_environment" do
    before { allow(ENV).to receive(:[]).and_call_original }

    it "dùng APPLICATION_ENVIRONMENT_LABEL khi được đặt" do
      allow(ENV).to receive(:[]).with("APPLICATION_ENVIRONMENT_LABEL").and_return("Acceptance")
      expect(described_class.application_environment).to eq("Acceptance")
    end

    it "cắt khoảng trắng thừa của APPLICATION_ENVIRONMENT_LABEL" do
      allow(ENV).to receive(:[]).with("APPLICATION_ENVIRONMENT_LABEL").and_return("  Mirror  ")
      expect(described_class.application_environment).to eq("Mirror")
    end

    it "dự phòng Rails.env.capitalize khi biến trống" do
      allow(ENV).to receive(:[]).with("APPLICATION_ENVIRONMENT_LABEL").and_return(nil)
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))
      expect(described_class.application_environment).to eq("Production")
    end
  end

  describe ".to_h" do
    it "trả version, application_environment, rails_environment" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("APPLICATION_ENVIRONMENT_LABEL").and_return(nil)
      expect(described_class.to_h).to eq(
        version: SystemInfo::VERSION,
        application_environment: Rails.env.to_s.capitalize,
        rails_environment: Rails.env.to_s
      )
    end
  end

  describe ".log_tag" do
    it "gộp phiên bản và môi trường thành một tag" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("APPLICATION_ENVIRONMENT_LABEL").and_return("Acceptance")
      expect(described_class.log_tag).to eq("v#{SystemInfo::VERSION} Acceptance")
    end
  end
end

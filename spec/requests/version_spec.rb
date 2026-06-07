require "rails_helper"

RSpec.describe "Version", type: :request do
  describe "GET /version" do
    it "trả JSON phiên bản, không cần đăng nhập" do
      get "/version"

      expect(response).to have_http_status(:ok)
      expect(response).not_to have_http_status(:redirect)
      expect(response.media_type).to eq("application/json")
      body = JSON.parse(response.body)
      expect(body["version"]).to eq(ElectricWaterManagement::VERSION)
      expect(body["environment"]).to eq(SystemInfo.environment_label)
      expect(body["rails_env"]).to eq(Rails.env.to_s)
    end
  end
end

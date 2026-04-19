require "rails_helper"

RSpec.describe "Rack::Attack", type: :request do
  before do
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
    Rack::Attack.reset!
  end

  describe "login throttle" do
    it "allows 5 login attempts then returns 429" do
      5.times do
        post user_session_path, params: { user: { email: "x@x.com", password: "wrong" } }
        expect(response.status).not_to eq(429)
      end
      post user_session_path, params: { user: { email: "x@x.com", password: "wrong" } }
      expect(response).to have_http_status(429)
    end
  end

  describe "bot probe blocklist" do
    it "blocks /.env probe" do
      get "/.env"
      expect(response).to have_http_status(403)
    end

    it "blocks /wp-admin probe" do
      get "/wp-admin"
      expect(response).to have_http_status(403)
    end
  end
end

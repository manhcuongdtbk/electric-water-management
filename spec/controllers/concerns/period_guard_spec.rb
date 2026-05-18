require "rails_helper"

RSpec.describe PeriodGuard, type: :controller do
  controller(ActionController::Base) do
    include PeriodGuard

    before_action :require_open_period, only: [:create, :update, :destroy]

    def index
      render plain: "index ok"
    end

    def show
      render plain: "show ok"
    end

    def create
      render plain: "created"
    end

    def update
      render plain: "updated"
    end

    def destroy
      render plain: "destroyed"
    end
  end

  before do
    routes.draw do
      resources :anonymous, only: [:index, :show, :create, :update, :destroy]
    end
  end

  context "khi có kỳ đang mở" do
    let!(:period) { create(:period, closed: false) }

    it "cho phép create" do
      post :create
      expect(response.body).to eq("created")
      expect(response).to have_http_status(:ok)
    end

    it "cho phép update" do
      put :update, params: { id: 1 }
      expect(response.body).to eq("updated")
    end

    it "cho phép destroy" do
      delete :destroy, params: { id: 1 }
      expect(response.body).to eq("destroyed")
    end
  end

  context "khi không có kỳ đang mở (T22)" do
    let!(:period) { create(:period, closed: true) }

    it "chặn create với redirect + flash" do
      post :create
      expect(response).to be_redirect
      expect(flash[:alert])
        .to eq(I18n.t("services.period_service.errors.no_open_period"))
    end

    it "chặn update" do
      put :update, params: { id: 1 }
      expect(response).to be_redirect
    end

    it "chặn destroy" do
      delete :destroy, params: { id: 1 }
      expect(response).to be_redirect
    end

    it "cho phép index (chỉ chặn write actions)" do
      get :index
      expect(response.body).to eq("index ok")
    end

    it "cho phép show" do
      get :show, params: { id: 1 }
      expect(response.body).to eq("show ok")
    end
  end

  context "khi không có kỳ nào tồn tại (T26 — CRUD đầu mối không bị chặn ở layer model)" do
    it "vẫn chặn write actions" do
      post :create
      expect(response).to be_redirect
      expect(flash[:alert])
        .to eq(I18n.t("services.period_service.errors.no_open_period"))
    end
  end
end

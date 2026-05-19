require "rails_helper"

RSpec.describe StructureChangeGuard, type: :controller do
  controller(ActionController::Base) do
    include StructureChangeGuard

    before_action :require_latest_period_when_open,
      only: [:new, :create, :edit, :update, :destroy]

    def index
      render plain: "index ok"
    end

    def show
      render plain: "show ok"
    end

    def new
      render plain: "new ok"
    end

    def create
      render plain: "created"
    end

    def edit
      render plain: "edit ok"
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
      resources :anonymous, only: [:index, :show, :new, :create, :edit, :update, :destroy]
    end
  end

  context "khi không có kỳ đang mở" do
    let!(:closed_period) { create(:period, year: 2026, month: 1, closed: true) }

    it "cho phép create" do
      post :create
      expect(response.body).to eq("created")
    end

    it "cho phép update" do
      put :update, params: { id: 1 }
      expect(response.body).to eq("updated")
    end

    it "cho phép destroy" do
      delete :destroy, params: { id: 1 }
      expect(response.body).to eq("destroyed")
    end

    it "cho phép new" do
      get :new
      expect(response.body).to eq("new ok")
    end

    it "cho phép edit" do
      get :edit, params: { id: 1 }
      expect(response.body).to eq("edit ok")
    end
  end

  context "khi kỳ đang mở là kỳ mới nhất" do
    let!(:period_jan) { create(:period, year: 2026, month: 1, closed: true) }
    let!(:period_feb) { create(:period, year: 2026, month: 2, closed: false) }

    it "cho phép create" do
      post :create
      expect(response.body).to eq("created")
    end

    it "cho phép new" do
      get :new
      expect(response.body).to eq("new ok")
    end

    it "cho phép destroy" do
      delete :destroy, params: { id: 1 }
      expect(response.body).to eq("destroyed")
    end
  end

  context "khi kỳ đang mở KHÔNG phải kỳ mới nhất (đang mở lại kỳ cũ — v2.3.0)" do
    let!(:period_jan) { create(:period, year: 2026, month: 1, closed: false) }
    let!(:period_feb) { create(:period, year: 2026, month: 2, closed: true) }
    let!(:period_mar) { create(:period, year: 2026, month: 3, closed: true) }

    let(:expected_message) {
      I18n.t("services.period_service.errors.structure_change_blocked_old_period")
    }

    it "chặn create với redirect + flash" do
      post :create
      expect(response).to be_redirect
      expect(flash[:alert]).to eq(expected_message)
    end

    it "chặn update" do
      put :update, params: { id: 1 }
      expect(response).to be_redirect
      expect(flash[:alert]).to eq(expected_message)
    end

    it "chặn destroy" do
      delete :destroy, params: { id: 1 }
      expect(response).to be_redirect
      expect(flash[:alert]).to eq(expected_message)
    end

    it "chặn new (UX: chặn sớm trước khi điền form)" do
      get :new
      expect(response).to be_redirect
      expect(flash[:alert]).to eq(expected_message)
    end

    it "chặn edit (UX: chặn sớm trước khi điền form)" do
      get :edit, params: { id: 1 }
      expect(response).to be_redirect
      expect(flash[:alert]).to eq(expected_message)
    end

    it "cho phép index (chỉ chặn structure write + form actions)" do
      get :index
      expect(response.body).to eq("index ok")
    end

    it "cho phép show" do
      get :show, params: { id: 1 }
      expect(response.body).to eq("show ok")
    end
  end
end

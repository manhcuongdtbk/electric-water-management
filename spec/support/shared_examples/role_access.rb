RSpec.shared_examples "redirects with access_denied" do
  it "redirects to root_path with access_denied flash" do
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq(I18n.t("flash.access_denied"))
  end
end

RSpec.shared_examples "silently redirects tech to users_path" do
  it "redirects tech to users_path without flash" do
    expect(response).to redirect_to(users_path)
    expect(flash[:alert]).to be_blank
  end
end

# Shared example for nested-resource controllers that must reject requests
# whose parent resource is not accessible to the current user (either because
# it belongs to another organization, or because it does not exist at all).
#
# Callers must define:
#   - `subject { make_request }` — the HTTP call under test
#   - `before  { sign_in user_with_access }` — an authenticated session
#
# Both cross-org and non-existent parent IDs are expected to produce the same
# response, so attackers cannot enumerate existence of cross-org records.
RSpec.shared_examples "denies cross-org parent access" do
  it "redirects to root_path with access_denied flash" do
    subject
    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq(I18n.t("flash.access_denied"))
  end
end

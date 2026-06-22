# Request-type shared example: non-SA roles see ONLY their unit/zone's data.
# Anti-vacuous precondition: SA must render EVERY record string and the strings
# must be distinct — so a page with nothing to distinguish (or duplicate text)
# fails instead of passing silently. References `scenario` from the host `let`.
RSpec.shared_examples "role data scoping" do
  it "data scoping: SA thấy tất cả; mỗi non-SA chỉ thấy phạm vi mình" do
    expect(scenario.all_texts.uniq.length).to eq(scenario.all_texts.length) # distinct

    sign_in scenario.sa_user
    get scenario.path
    scenario.all_texts.each { |t| expect(response.body).to include(t) }     # precondition

    scenario.checks.each do |check|
      check[:hides].each { |h| expect(scenario.all_texts).to include(h) }   # foreign is real
      sign_out :user
      sign_in check[:user]
      get scenario.path
      expect(response.body).to include(check[:sees])
      check[:hides].each { |h| expect(response.body).not_to include(h) }
    end
  end
end

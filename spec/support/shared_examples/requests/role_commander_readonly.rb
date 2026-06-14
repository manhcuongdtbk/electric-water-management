# Request-type shared example: commanders (CMD/CMD-ZM) see the data but every
# business input is disabled and the save button is hidden/disabled. Anti-vacuous
# precondition: the CONTROL unit_admin role must have >=1 ENABLED input in the
# same view — so a page that simply has no inputs (or disables for everyone)
# can't pass as "commander read-only". Config from scenario.commander.
RSpec.shared_examples "role commander read-only" do
  it "commander read-only: input disabled + Lưu ẩn/disabled; control role enabled" do
    cfg = scenario.commander

    # precondition: control unit_admin sees at least one ENABLED input
    sign_in cfg[:control_user]
    get scenario.path
    control_html = Nokogiri::HTML(response.body)
    control_inputs = control_html.css(cfg[:input_css])
                       .reject { |i| i["type"] == "hidden" }
    expect(control_inputs).not_to be_empty
    expect(control_inputs.any? { |i| i["disabled"].nil? }).to be(true),
      "control role should have at least one enabled input"
    # anti-vacuous precondition: when the save button is expected to exist, the
    # control role MUST render it — otherwise a stale/wrong submit_css would make
    # the commander save-button assertion pass vacuously.
    unless cfg[:submit_optional]
      expect(control_html.css(cfg[:submit_css])).not_to be_empty,
        "control role should render the save button (submit_css=#{cfg[:submit_css].inspect}); " \
        "a stale selector would make the commander save-button check vacuous"
    end

    cfg[:commander_users].each do |cmd_user|
      sign_out :user
      sign_in cmd_user
      get scenario.path
      html = Nokogiri::HTML(response.body)
      inputs = html.css(cfg[:input_css]).reject { |i| i["type"] == "hidden" }
      expect(inputs).not_to be_empty
      inputs.each do |i|
        expect(i["disabled"]).to be_present,
          "expected input '#{i['name']}' disabled for commander on #{scenario.path}"
      end
      submit = html.css(cfg[:submit_css])
      if submit.any?
        expect(submit.first["disabled"]).to be_present
      elsif !cfg[:submit_optional]
        expect(submit).to be_empty
      end
    end
  end
end

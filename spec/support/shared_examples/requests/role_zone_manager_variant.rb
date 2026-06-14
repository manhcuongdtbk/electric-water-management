# Request-type shared example: UA-ZM (unit_admin managing a zone) sees a
# zone-manager-only marker that a plain UA (same page, also accessible) does not.
# This is BEHAVIOR difference once both are IN — access-only differences belong
# to #359 and are declared `na` here. Config from scenario.zm. Two modes:
#   - marker_values: option values that must appear in scenario.zm[:marker_css]
#   - marker_text:   a body substring that must appear
# Each mode keeps an anti-vacuous precondition (UA-ZM really shows the marker).
RSpec.shared_examples "role zone-manager variant" do
  it "zone-manager variant: UA-ZM thấy marker; UA không" do
    cfg = scenario.zm

    if cfg[:marker_values]
      sign_in cfg[:zm_user]
      get scenario.path
      zm_values = Nokogiri::HTML(response.body).css(cfg[:marker_css])
                    .map { |o| o["value"] }.compact
      cfg[:marker_values].each { |v| expect(zm_values).to include(v) }  # precondition

      sign_out :user
      sign_in cfg[:non_zm_user]
      get scenario.path
      ua_values = Nokogiri::HTML(response.body).css(cfg[:marker_css])
                    .map { |o| o["value"] }.compact
      cfg[:marker_values].each { |v| expect(ua_values).not_to include(v) }
    else
      sign_in cfg[:zm_user]
      get scenario.path
      expect(response.body).to include(cfg[:marker_text])               # precondition

      sign_out :user
      sign_in cfg[:non_zm_user]
      get scenario.path
      expect(response.body).not_to include(cfg[:marker_text])
    end
  end
end

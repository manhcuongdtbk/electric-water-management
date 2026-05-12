FactoryBot.define do
  # Caveat: by default a pump_station and its `:organization` each get their own
  # newly created zone via factory chains, so `ps.zone != ps.organization.zone`.
  # Specs that need a shared zone (engine, integration) must wire it manually:
  #
  #   zone = create(:zone)
  #   unit = create(:organization, :unit, zone: zone)
  #   ps   = create(:pump_station, zone: zone, organization: unit)
  factory :pump_station do
    sequence(:name) { |n| "Tram bom #{n}" }
    association :zone
    association :organization
  end
end

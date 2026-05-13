FactoryBot.define do
  # `organization` is set transiently until the legacy `pump_stations.organization_id`
  # column is dropped (DropLegacyColumns migration in this same PR). The column is
  # still NOT NULL in the DB at this point, so we satisfy it with a default org.
  # Specs that need a specific org can pass `organization: foo` explicitly; the
  # parameter is harmless once the column is gone.
  factory :pump_station do
    sequence(:name) { |n| "Tram bom #{n}" }
    association :zone
    association :organization
  end
end

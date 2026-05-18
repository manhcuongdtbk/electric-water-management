FactoryBot.define do
  factory :unit_config do
    association :unit
    association :period
    unit_public_rate { 0 }
  end
end

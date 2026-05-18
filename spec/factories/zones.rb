FactoryBot.define do
  factory :zone do
    sequence(:name) { |n| "Khu vực #{n}" }

    after(:build) do |zone|
      if zone.main_meters.empty?
        zone.main_meters.build(name: "CT-Tổng-#{zone.name}")
      end
    end
  end
end

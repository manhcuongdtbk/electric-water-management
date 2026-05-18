FactoryBot.define do
  factory :rank do
    sequence(:name) { |n| "Nhóm cấp bậc #{n}" }
    quota { 100 }
    sequence(:position) { |n| n }
    association :period
  end
end

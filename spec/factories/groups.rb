FactoryBot.define do
  factory :group do
    sequence(:name) { |n| "Nhóm #{n}" }
    association :unit
  end
end

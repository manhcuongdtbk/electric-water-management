FactoryBot.define do
  factory :meter do
    sequence(:name) { |n| "Công tơ #{n}" }
    association :contact_point
    no_loss { false }
  end
end

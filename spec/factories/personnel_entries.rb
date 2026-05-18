FactoryBot.define do
  factory :personnel_entry do
    association :contact_point, factory: [:contact_point, :residential]
    association :period
    association :rank
    count { 1 }
  end
end

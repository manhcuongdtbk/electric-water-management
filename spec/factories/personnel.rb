FactoryBot.define do
  factory :personnel do
    association :contact_point
    association :monthly_period
    rank1_count { 2 }
    rank2_count { 5 }
    rank3_count { 10 }
    rank4_count { 20 }
    rank5_count { 0 }
    rank6_count { 3 }
    rank7_count { 0 }
  end
end

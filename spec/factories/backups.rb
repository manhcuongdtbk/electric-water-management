FactoryBot.define do
  factory :backup do
    sequence(:filename) { |n| "backup_2026051#{n % 9}_12000#{n % 10}.dump" }
    size_bytes { 1024 }
    status { "completed" }
    association :created_by, factory: :user
  end
end

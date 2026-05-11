FactoryBot.define do
  factory :pump_station_assignment do
    association :pump_station

    # Default assignable: a unit-level Organization. Specs that pre-date the
    # polymorphic refactor can still pass `organization: foo` as a transient
    # shim and have it routed to `assignable`.
    transient do
      organization { nil }
    end

    assignable { organization || association(:organization, :unit) }

    trait :fixed do
      transient do
        percentage { 30 }
      end
      fixed_pump_percentage { percentage }
    end

    trait :for_contact_point do
      assignable { association(:contact_point) }
    end

    trait :for_work_group do
      assignable { association(:work_group) }
    end
  end
end

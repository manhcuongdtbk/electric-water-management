FactoryBot.define do
  factory :pump_allocation do
    association :zone
    association :period
    # Recipient được persist (create) vì PumpAllocation validate theo cột _id;
    # association(:unit) build sẽ để unit_id nil khi dùng strategy build.
    unit do
      u = create(:unit, zone: zone)
      create(:contact_point, :residential, unit: u, name: "ĐM #{u.name}")
      u
    end
    contact_point { nil }
    block { nil }
    group { nil }
    coefficient { 1 }

    after(:build) do |alloc|
      next unless alloc.unit_id.present?
      unless ContactPoint.where(unit_id: alloc.unit_id, contact_point_type: "residential").exists?
        create(:contact_point, :residential, unit_id: alloc.unit_id, name: "ĐM auto #{alloc.unit_id}")
      end
    end

    trait :for_station do
      transient { station_zone { zone } }
      pump_contact_point { create(:contact_point, :water_pump, zone: station_zone) }
    end

    trait :for_contact_point do
      unit { nil }
      contact_point do
        cp_unit = create(:unit, zone: zone)
        create(:contact_point, :residential, unit: cp_unit, zone: nil)
      end
    end
  end
end

FactoryBot.define do
  factory :rank_quota do
    sequence(:rank_group) { |n| ((n - 1) % 7) + 1 }
    rank_name { "Si quan cap cao" }
    quota_kw { 570 }
    sequence(:effective_from) { |n| Date.new(2020, 1, 1) + ((n - 1) / 7).years }

    (1..7).each do |group|
      quotas = { 1 => 570, 2 => 440, 3 => 305, 4 => 130, 5 => 210, 6 => 110, 7 => 24 }
      names  = { 1 => "Si quan cap cao", 2 => "Si quan", 3 => "Ha si quan", 4 => "Binh si",
                 5 => "Chuyen nghiep", 6 => "Cong nhan vien quoc phong", 7 => "Hoc vien" }
      trait :"rank#{group}" do
        rank_group { group }
        rank_name  { names[group] }
        quota_kw   { quotas[group] }
        effective_from { Date.new(2024, 1, 1) }
      end
    end
  end
end

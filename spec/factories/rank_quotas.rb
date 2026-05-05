FactoryBot.define do
  factory :rank_quota do
    sequence(:rank_group) { |n| ((n - 1) % 7) + 1 }
    rank_name { "Chỉ huy Sư đoàn; SQ có trần quân hàm là Đại tá" }
    quota_kw { 570 }
    sequence(:effective_from) { |n| Date.new(2020, 1, 1) + ((n - 1) / 7).years }

    (1..7).each do |group|
      quotas = { 1 => 570, 2 => 440, 3 => 305, 4 => 130, 5 => 210, 6 => 110, 7 => 24 }
      names  = {
        1 => "Chỉ huy Sư đoàn; SQ có trần quân hàm là Đại tá",
        2 => "Chỉ huy Trung đoàn; SQ có trần quân hàm là Thượng tá",
        3 => "Chỉ huy tiểu đoàn; SQ có trần quân hàm là Trung tá, Thiếu tá",
        4 => "Chỉ huy đại đội, trung đội; SQ có trần quân hàm là cấp Úy",
        5 => "Cơ quan sư đoàn, trung đoàn",
        6 => "Tiểu đoàn, đại đội",
        7 => "Hạ sĩ quan, binh sĩ"
      }
      trait :"rank#{group}" do
        rank_group { group }
        rank_name  { names[group] }
        quota_kw   { quotas[group] }
        effective_from { Date.new(2024, 1, 1) }
      end
    end
  end
end

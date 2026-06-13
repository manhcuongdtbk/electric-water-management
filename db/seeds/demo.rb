# db/seeds/demo.rb — Curated demo dataset for demo recordings.
#
# Idempotent: safe to run multiple times. All demo records are identified by
# canonical names and guarded with find_or_create_by! or conditional creation.
#
# Run via:   RAILS_ENV=<env> bin/rails demo:seed
# Reset run: RAILS_ENV=<env> bin/rails db:reset && RAILS_ENV=<env> bin/rails demo:seed

puts "Loading demo dataset..."

ActiveRecord::Base.transaction do
  # ---------------------------------------------------------------------------
  # Demo system-admin user (fixed credentials so the demo can log in)
  # ---------------------------------------------------------------------------
  demo_admin = User.find_or_create_by!(username: "demo_admin") do |u|
    u.display_name        = "Quản trị viên Demo"
    u.role                = :system_admin
    u.password            = "Demo@1234"
    u.password_confirmation = "Demo@1234"
    u.force_password_change = false
    u.default_account     = false
  end
  puts "  User: #{demo_admin.username} (#{demo_admin.role})"

  # ---------------------------------------------------------------------------
  # Zone "Khu vực Trung tâm" with one main meter
  # Validations: name uniqueness; must have at least one main_meter on create.
  # We build the main_meter in the same transaction via accepts_nested_attributes.
  # ---------------------------------------------------------------------------
  zone = Zone.find_by(name: "Khu vực Trung tâm")
  unless zone
    zone = Zone.new(name: "Khu vực Trung tâm")
    zone.main_meters.build(name: "CT-Tổng-Trung tâm")
    zone.save!
  end
  puts "  Zone: #{zone.name}"

  main_meter = zone.main_meters.kept.find_or_create_by!(name: "CT-Tổng-Trung tâm")
  puts "  MainMeter: #{main_meter.name}"

  # ---------------------------------------------------------------------------
  # Two units belonging to the zone.
  # Callback after_create :assign_as_zone_manager makes the FIRST unit the
  # zone manager automatically when zone.manager_unit_id is nil.
  # ---------------------------------------------------------------------------
  unit_alpha = Unit.find_or_create_by!(name: "Tiểu đoàn Alpha") do |u|
    u.zone = zone
  end
  puts "  Unit: #{unit_alpha.name}"

  unit_beta = Unit.find_or_create_by!(name: "Tiểu đoàn Beta") do |u|
    u.zone = zone
  end
  puts "  Unit: #{unit_beta.name}"

  # Ensure unit_alpha is the zone manager (auto-assigned if it was the first,
  # but we set it explicitly so idempotent re-runs are consistent).
  zone.reload
  zone.update!(manager_unit_id: unit_alpha.id) if zone.manager_unit_id != unit_alpha.id

  # ---------------------------------------------------------------------------
  # Open period for June 2026 (or find the existing one).
  # PeriodService raises if an open period already exists — we guard first.
  # Ranks are seeded automatically by PeriodService when no previous period.
  # ---------------------------------------------------------------------------
  period = Period.find_by(year: 2026, month: 6)
  unless period
    result = PeriodService.new.open_new_period(
      year: 2026, month: 6,
      unit_price: BigDecimal("3500")
    )
    period = result.period
  end
  # Make sure the period is open (idempotent re-run might have left it closed).
  period.update!(closed: false) if period.closed?
  puts "  Period: #{period.month}/#{period.year} (open: #{period.open?})"

  # Ranks are created by PeriodService (7 default ranks).
  ranks = period.ranks.order(:position).to_a
  puts "  Ranks: #{ranks.count}"

  # ---------------------------------------------------------------------------
  # Blocks and Groups for unit_alpha
  # ---------------------------------------------------------------------------
  block_ban_chi_huy = Block.find_or_create_by!(name: "Ban Chỉ huy", unit: unit_alpha)
  group_tham_muu    = Group.find_or_create_by!(name: "Tổ Tham mưu", unit: unit_alpha)
  puts "  Block: #{block_ban_chi_huy.name}, Group: #{group_tham_muu.name}"

  # ---------------------------------------------------------------------------
  # Helper: build initial_personnel_counts hash keyed by rank.id
  # Ranks from PeriodService (positions 1..7):
  #   1 = chi huy su doan (Đại tá)  quota=570
  #   2 = chi huy trung doan (Thượng tá) quota=440
  #   3 = chi huy tieu doan (Trung tá/Thiếu tá) quota=305
  #   4 = chi huy dai doi (Úy) quota=130
  #   5 = co quan su doan/trung doan quota=210
  #   6 = tieu doan/dai doi quota=110
  #   7 = ha si quan/binh si quota=24
  # ---------------------------------------------------------------------------
  rank_by_pos = ranks.index_by(&:position)

  def personnel_counts(rank_by_pos, counts_by_position)
    counts_by_position.transform_keys { |pos| rank_by_pos.fetch(pos).id }
  end

  # ---------------------------------------------------------------------------
  # Contact points for unit_alpha (residential + public)
  # Validation :validate_residential_personnel_sum_on_create: total >= 1
  # initial_personnel_counts is an attr_accessor (not persisted) used in after_create.
  # ---------------------------------------------------------------------------

  # Residential: Ban Chỉ huy (chỉ huy tiểu đoàn rank, position 3)
  cp_ban_chi_huy = ContactPoint.find_by(
    name: "Ban Chỉ huy Tiểu đoàn Alpha",
    contact_point_type: "residential",
    unit_id: unit_alpha.id
  )
  unless cp_ban_chi_huy
    cp_ban_chi_huy = ContactPoint.new(
      name: "Ban Chỉ huy Tiểu đoàn Alpha",
      contact_point_type: "residential",
      unit: unit_alpha,
      block: block_ban_chi_huy,
      group: group_tham_muu,
      initial_personnel_counts: personnel_counts(rank_by_pos, 3 => 2, 5 => 1, 7 => 3)
    )
    cp_ban_chi_huy.save!
  end
  puts "  ContactPoint (residential): #{cp_ban_chi_huy.name}"

  # Residential: Đại đội 1 (unit_alpha)
  cp_dai_doi_1 = ContactPoint.find_by(
    name: "Đại đội 1",
    contact_point_type: "residential",
    unit_id: unit_alpha.id
  )
  unless cp_dai_doi_1
    cp_dai_doi_1 = ContactPoint.new(
      name: "Đại đội 1",
      contact_point_type: "residential",
      unit: unit_alpha,
      initial_personnel_counts: personnel_counts(rank_by_pos, 4 => 1, 6 => 3, 7 => 12)
    )
    cp_dai_doi_1.save!
  end
  puts "  ContactPoint (residential): #{cp_dai_doi_1.name}"

  # Residential: Đại đội 1 (unit_beta)
  cp_dai_doi_b1 = ContactPoint.find_by(
    name: "Đại đội 1",
    contact_point_type: "residential",
    unit_id: unit_beta.id
  )
  unless cp_dai_doi_b1
    cp_dai_doi_b1 = ContactPoint.new(
      name: "Đại đội 1",
      contact_point_type: "residential",
      unit: unit_beta,
      initial_personnel_counts: personnel_counts(rank_by_pos, 4 => 1, 6 => 5, 7 => 20)
    )
    cp_dai_doi_b1.save!
  end
  puts "  ContactPoint (residential): unit_beta / #{cp_dai_doi_b1.name}"

  # Public: Nhà ăn (unit_alpha) — no block/group, no personnel_count
  cp_nha_an = ContactPoint.find_or_create_by!(
    name: "Nhà ăn",
    contact_point_type: "public",
    unit_id: unit_alpha.id
  ) { |cp| cp.unit = unit_alpha }
  puts "  ContactPoint (public): #{cp_nha_an.name}"

  # Water pump: belongs to zone (not unit)
  cp_tram_bom = ContactPoint.find_or_create_by!(
    name: "Trạm bơm Trung tâm",
    contact_point_type: "water_pump",
    zone_id: zone.id
  ) { |cp| cp.zone = zone }
  puts "  ContactPoint (water_pump): #{cp_tram_bom.name}"

  # Zone residential: Chỉ huy khu vực (belongs to zone, not unit)
  cp_chi_huy_kv = ContactPoint.find_by(
    name: "Chỉ huy khu vực Trung tâm",
    contact_point_type: "residential",
    zone_id: zone.id,
    unit_id: nil
  )
  unless cp_chi_huy_kv
    cp_chi_huy_kv = ContactPoint.new(
      name: "Chỉ huy khu vực Trung tâm",
      contact_point_type: "residential",
      zone: zone,
      unit: nil,
      initial_personnel_counts: personnel_counts(rank_by_pos, 1 => 1)
    )
    cp_chi_huy_kv.save!
  end
  puts "  ContactPoint (zone residential): #{cp_chi_huy_kv.name}"

  # ---------------------------------------------------------------------------
  # Meters (one per contact point — each meter triggers after_create which
  # creates a meter_reading for the current open period)
  # ---------------------------------------------------------------------------
  ct_a1 = Meter.find_or_create_by!(name: "CT-A1", contact_point: cp_ban_chi_huy) do |m|
    m.no_loss = false
  end
  ct_a2 = Meter.find_or_create_by!(name: "CT-A2", contact_point: cp_dai_doi_1) do |m|
    m.no_loss = false
  end
  ct_b1 = Meter.find_or_create_by!(name: "CT-B1", contact_point: cp_dai_doi_b1) do |m|
    m.no_loss = false
  end
  ct_cc = Meter.find_or_create_by!(name: "CT-CC-NA", contact_point: cp_nha_an) do |m|
    m.no_loss = false
  end
  ct_bom = Meter.find_or_create_by!(name: "CT-BOM", contact_point: cp_tram_bom) do |m|
    m.no_loss = false
  end
  ct_kv = Meter.find_or_create_by!(name: "CT-KV", contact_point: cp_chi_huy_kv) do |m|
    m.no_loss = false
  end
  puts "  Meters: #{[ct_a1, ct_a2, ct_b1, ct_cc, ct_bom, ct_kv].map(&:name).join(', ')}"

  # ---------------------------------------------------------------------------
  # Meter readings for the open period — update reading_start and reading_end
  # (the after_create on Meter already seeded a blank reading; we just fill it in)
  # ---------------------------------------------------------------------------
  readings = {
    ct_a1  => { start: 1_200, finish: 1_450 },
    ct_a2  => { start: 3_000, finish: 3_320 },
    ct_b1  => { start: 5_500, finish: 5_980 },
    ct_cc  => { start: 800,   finish: 950  },
    ct_bom => { start: 200,   finish: 350  },
    ct_kv  => { start: 400,   finish: 520  }
  }
  readings.each do |meter, attrs|
    reading = meter.meter_readings.find_by(period: period)
    next unless reading
    reading.update!(
      reading_start: BigDecimal(attrs[:start].to_s),
      reading_end:   BigDecimal(attrs[:finish].to_s)
    )
  end
  puts "  MeterReadings updated for #{readings.size} meters"

  # ---------------------------------------------------------------------------
  # Main meter reading for the zone
  # ---------------------------------------------------------------------------
  main_reading = MainMeterReading.find_or_initialize_by(main_meter: main_meter, period: period)
  main_reading.usage = BigDecimal("2800")
  main_reading.save!
  puts "  MainMeterReading: #{main_reading.usage} kWh"

  # ---------------------------------------------------------------------------
  # Unit configs (unit_public_rate) — created by Unit#create_current_period_unit_config
  # callback; we just update the rate here
  # ---------------------------------------------------------------------------
  [unit_alpha, unit_beta].each do |unit|
    config = unit.unit_configs.find_or_create_by!(period: period) { |c| c.unit_public_rate = 0 }
    config.update!(unit_public_rate: BigDecimal("5")) unless config.unit_public_rate == BigDecimal("5")
  end
  puts "  UnitConfigs updated"
end

puts "Demo dataset loaded successfully."
puts "  Demo admin credentials: username=demo_admin  password=Demo@1234"

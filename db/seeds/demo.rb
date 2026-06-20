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
  # Zone "Khu vực 1" with one main meter
  # Validations: name uniqueness; must have at least one main_meter on create.
  # We build the main_meter in the same transaction via accepts_nested_attributes.
  # ---------------------------------------------------------------------------
  zone = Zone.find_by(name: "Khu vực 1")
  unless zone
    zone = Zone.new(name: "Khu vực 1")
    zone.main_meters.build(name: "CT-Tổng-Khu vực 1")
    zone.save!
  end
  puts "  Zone: #{zone.name}"

  main_meter = zone.main_meters.kept.find_or_create_by!(name: "CT-Tổng-Khu vực 1")
  puts "  MainMeter: #{main_meter.name}"

  # ---------------------------------------------------------------------------
  # Two units belonging to the zone.
  # Callback after_create :assign_as_zone_manager makes the FIRST unit the
  # zone manager automatically when zone.manager_unit_id is nil.
  # ---------------------------------------------------------------------------
  unit_alpha = Unit.find_or_create_by!(name: "Tiểu đoàn 1") do |u|
    u.zone = zone
  end
  puts "  Unit: #{unit_alpha.name}"

  unit_beta = Unit.find_or_create_by!(name: "Tiểu đoàn 2") do |u|
    u.zone = zone
  end
  puts "  Unit: #{unit_beta.name}"

  # Demo commander of Tiểu đoàn 1 — read-only role, so the demo can show that
  # a commander views the billing config but cannot change it (#363, CHIEU-vai-tro).
  demo_commander = User.find_or_create_by!(username: "demo_commander") do |u|
    u.display_name          = "Chỉ huy Demo"
    u.role                  = :commander
    u.unit                  = unit_alpha
    u.password              = "Demo@1234"
    u.password_confirmation = "Demo@1234"
    u.force_password_change = false
    u.default_account       = false
  end
  puts "  User: #{demo_commander.username} (#{demo_commander.role})"

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
  # Make sure the period is open and per-station (idempotent re-run on pre-TN2 database
  # may have left it closed or with pump_allocation_per_station = false).
  period.update!(closed: false) if period.closed?
  period.update!(pump_allocation_per_station: true) unless period.pump_allocation_per_station?
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
  # Block and Group for unit_beta — so the eastern pump station can pay out to a
  # Nhóm recipient (TN2 per-station billing exercises all four recipient types).
  # The group must contain at least one residential contact point with personnel
  # for the by-coefficient distribution to land somewhere.
  # ---------------------------------------------------------------------------
  block_hau_can_beta = Block.find_or_create_by!(name: "Khối Hậu cần", unit: unit_beta)
  group_quan_y_beta  = Group.find_or_create_by!(name: "Tổ Quân y", unit: unit_beta) do |g|
    g.block = block_hau_can_beta
  end
  puts "  Block: #{block_hau_can_beta.name}, Group: #{group_quan_y_beta.name}"

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
    name: "Nhà Ban Chỉ huy",
    contact_point_type: "residential",
    unit_id: unit_alpha.id
  )
  unless cp_ban_chi_huy
    cp_ban_chi_huy = ContactPoint.new(
      name: "Nhà Ban Chỉ huy",
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

  # Residential: Bếp ăn (unit_alpha) — the battalion's shared kitchen. Demonstrates
  # the unit-coefficient "Khác" (nghiệp vụ 10.2.1, ADR-025): each soldier in the
  # battalion contributes a share and the kitchen receives the total back, so its
  # deduction = hệ số × (Σ residential headcount of the unit − the kitchen's own).
  # Kept meter-less on purpose: the demo highlights its "Khác" credit, not usage,
  # and that keeps the zone loss numbers (and the loss-breakdown demo) untouched.
  cp_bep = ContactPoint.find_by(
    name: "Bếp ăn Tiểu đoàn 1",
    contact_point_type: "residential",
    unit_id: unit_alpha.id
  )
  unless cp_bep
    cp_bep = ContactPoint.new(
      name: "Bếp ăn Tiểu đoàn 1",
      contact_point_type: "residential",
      unit: unit_alpha,
      initial_personnel_counts: personnel_counts(rank_by_pos, 7 => 8)
    )
    cp_bep.save!
  end
  puts "  ContactPoint (residential): #{cp_bep.name}"

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

  # Residential: Tổ Quân y (unit_beta) — sits in block "Khối Hậu cần" / group
  # "Tổ Quân y" so the eastern pump station can allocate to that Nhóm by hệ số.
  # Holds real personnel so the group's by-coefficient share has somewhere to land.
  cp_to_quan_y_beta = ContactPoint.find_by(
    name: "Nhà Quân y",
    contact_point_type: "residential",
    unit_id: unit_beta.id
  )
  unless cp_to_quan_y_beta
    cp_to_quan_y_beta = ContactPoint.new(
      name: "Nhà Quân y",
      contact_point_type: "residential",
      unit: unit_beta,
      block: block_hau_can_beta,
      group: group_quan_y_beta,
      initial_personnel_counts: personnel_counts(rank_by_pos, 4 => 1, 6 => 2, 7 => 6)
    )
    cp_to_quan_y_beta.save!
  end
  puts "  ContactPoint (residential): unit_beta / #{cp_to_quan_y_beta.name}"

  # Public: Nhà ăn (unit_alpha) — no block/group, no personnel_count
  cp_nha_an = ContactPoint.find_or_create_by!(
    name: "Nhà ăn",
    contact_point_type: "public",
    unit_id: unit_alpha.id
  ) { |cp| cp.unit = unit_alpha }
  puts "  ContactPoint (public): #{cp_nha_an.name}"

  # Water pump station 1: belongs to zone (not unit) — serves the western area
  # (Tiểu đoàn 1 + the zone commander residence).
  cp_tram_bom = ContactPoint.find_or_create_by!(
    name: "Trạm bơm Tây",
    contact_point_type: "water_pump",
    zone_id: zone.id
  ) { |cp| cp.zone = zone }
  puts "  ContactPoint (water_pump): #{cp_tram_bom.name}"

  # Water pump station 2: a SECOND station in the same zone — serves the eastern
  # area (Tiểu đoàn 2). Per-station billing (ADR-059 / TN2): each station's
  # electricity is shared only among the recipients of its own area.
  cp_tram_bom_dong = ContactPoint.find_or_create_by!(
    name: "Trạm bơm Đông",
    contact_point_type: "water_pump",
    zone_id: zone.id
  ) { |cp| cp.zone = zone }
  puts "  ContactPoint (water_pump): #{cp_tram_bom_dong.name}"

  # Zone residential: Chỉ huy khu vực (belongs to zone, not unit)
  cp_chi_huy_kv = ContactPoint.find_by(
    name: "Chỉ huy khu vực 1",
    contact_point_type: "residential",
    zone_id: zone.id,
    unit_id: nil
  )
  unless cp_chi_huy_kv
    cp_chi_huy_kv = ContactPoint.new(
      name: "Chỉ huy khu vực 1",
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
  # The kitchen draws real power — so it shows up in billing (the engine skips
  # residential contact points with no metered reading for the period). See #363.
  ct_bep = Meter.find_or_create_by!(name: "CT-BEP", contact_point: cp_bep) do |m|
    m.no_loss = false
  end
  ct_b1 = Meter.find_or_create_by!(name: "CT-B1", contact_point: cp_dai_doi_b1) do |m|
    m.no_loss = false
  end
  ct_b2 = Meter.find_or_create_by!(name: "CT-B2", contact_point: cp_to_quan_y_beta) do |m|
    m.no_loss = false
  end
  ct_cc = Meter.find_or_create_by!(name: "CT-CC-NA", contact_point: cp_nha_an) do |m|
    m.no_loss = false
  end
  ct_bom = Meter.find_or_create_by!(name: "CT-BOM", contact_point: cp_tram_bom) do |m|
    m.no_loss = false
  end
  ct_bom_dong = Meter.find_or_create_by!(name: "CT-BOM-D", contact_point: cp_tram_bom_dong) do |m|
    m.no_loss = false
  end
  ct_kv = Meter.find_or_create_by!(name: "CT-KV", contact_point: cp_chi_huy_kv) do |m|
    m.no_loss = false
  end
  # no_loss meter on cp_ban_chi_huy — makes "Không tổn hao" row non-zero in the
  # per-type breakdown table (#332 demo requirement).
  ct_kth = Meter.find_or_create_by!(name: "CT-KTH", contact_point: cp_ban_chi_huy) do |m|
    m.no_loss = true
  end
  puts "  Meters: #{[ct_a1, ct_a2, ct_bep, ct_b1, ct_b2, ct_cc, ct_bom, ct_bom_dong, ct_kv, ct_kth].map(&:name).join(', ')}"

  # ---------------------------------------------------------------------------
  # Meter readings for the open period — update reading_start and reading_end
  # (the after_create on Meter already seeded a blank reading; we just fill it in)
  # ---------------------------------------------------------------------------
  readings = {
    ct_a1  => { start: 1_200, finish: 1_450 },
    ct_a2  => { start: 3_000, finish: 3_320 },
    ct_bep => { start: 600,   finish: 720  },
    ct_b1  => { start: 5_500, finish: 5_980 },
    ct_b2  => { start: 1_000, finish: 1_080 },
    ct_cc  => { start: 800,   finish: 950  },
    ct_bom => { start: 200,   finish: 350  },
    ct_bom_dong => { start: 100, finish: 180 },
    ct_kv  => { start: 400,   finish: 520  },
    ct_kth => { start: 0,     finish: 90   }
  }
  readings.each do |meter, attrs|
    reading = meter.meter_readings.find_or_initialize_by(period: period)
    reading.update!(
      reading_start: BigDecimal(attrs[:start].to_s),
      reading_end:   BigDecimal(attrs[:finish].to_s),
      no_loss:       meter.no_loss
    )
  end
  puts "  MeterReadings updated for #{readings.size} meters"

  # ---------------------------------------------------------------------------
  # Main meter reading for the zone
  # ---------------------------------------------------------------------------
  # Realistic supply: a little above the measured sub-meters so loss is a few %
  # (measured = loss-bearing 1.750 [incl. kitchen 120, two pump stations 150+80,
  # đoàn 2 Tổ Quân y 80] + no-loss 90 = 1.840 → ~4% loss), not an alarming figure
  # that makes the demo look broken.
  main_reading = MainMeterReading.find_or_initialize_by(main_meter: main_meter, period: period)
  main_reading.usage = BigDecimal("1920")
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

  # ---------------------------------------------------------------------------
  # Pump allocations — per-station (ADR-059 / TN2). The open period is opened by
  # PeriodService, which marks new periods pump_allocation_per_station = true, so
  # EVERY allocation MUST name a station (a water_pump contact point in the zone).
  #
  # Two stations, two recipient lists spanning ALL FOUR recipient types — the
  # whole point of per-station billing (Đơn vị / Khối / Nhóm / Đầu mối):
  #   - Trạm bơm Tây (western area):
  #       • Khối "Ban Chỉ huy" (Tiểu đoàn 1) — by hệ số (headcount of the block)
  #       • Đầu mối khu vực "Chỉ huy khu vực 1" — fixed 30% slice
  #   - Trạm bơm Đông (eastern area):
  #       • Đại đội 1 (đầu mối trực tiếp, Tiểu đoàn 2) — by hệ số
  #       • Nhóm "Tổ Quân y" (Tiểu đoàn 2) — by hệ số (headcount of the group)
  # Each station's metered electricity is shared only among its own recipients.
  # Every station has ≥1 hệ-số recipient, so the whole station load is allocated
  # (no unallocated remainder); Σ fixed % ≤ 100 per station (Tây = 30%).
  # ---------------------------------------------------------------------------
  def upsert_pump_allocation!(period:, zone:, station:, recipient_key:, recipient:, attrs:)
    alloc = PumpAllocation.find_or_initialize_by(
      period_id: period.id, zone_id: zone.id, pump_contact_point_id: station.id,
      recipient_key => recipient.id
    )
    alloc.assign_attributes(attrs)
    alloc.save!
    alloc
  end

  # Idempotency: an earlier seed revision allocated Trạm bơm Tây to the
  # whole Tiểu đoàn 1 (unit). The recipient is now the Khối "Ban Chỉ huy", so
  # drop the stale unit allocation on a re-run against an existing database.
  PumpAllocation.where(
    period_id: period.id, zone_id: zone.id,
    pump_contact_point_id: cp_tram_bom.id, unit_id: unit_alpha.id
  ).delete_all

  # Trạm bơm Tây → Khối "Ban Chỉ huy" (hệ số) + Đầu mối khu vực (30% cố định)
  upsert_pump_allocation!(
    period: period, zone: zone, station: cp_tram_bom,
    recipient_key: :block_id, recipient: block_ban_chi_huy,
    attrs: { coefficient: BigDecimal("1"), fixed_percentage: nil }
  )
  upsert_pump_allocation!(
    period: period, zone: zone, station: cp_tram_bom,
    recipient_key: :contact_point_id, recipient: cp_chi_huy_kv,
    attrs: { coefficient: BigDecimal("0"), fixed_percentage: BigDecimal("30") }
  )

  # Trạm bơm Đông → Đại đội 1 (đầu mối trực tiếp, hệ số) + Nhóm "Tổ Quân y" (hệ số).
  # Không dùng đơn vị Tiểu đoàn 2 vì chồng chéo với nhóm bên trong (non-overlap).
  # Idempotency: xóa allocation đơn vị cũ nếu tồn tại (seed cũ dùng unit_beta).
  PumpAllocation.where(
    period_id: period.id, zone_id: zone.id,
    pump_contact_point_id: cp_tram_bom_dong.id, unit_id: unit_beta.id
  ).delete_all
  upsert_pump_allocation!(
    period: period, zone: zone, station: cp_tram_bom_dong,
    recipient_key: :contact_point_id, recipient: cp_dai_doi_b1,
    attrs: { coefficient: BigDecimal("1"), fixed_percentage: nil }
  )
  upsert_pump_allocation!(
    period: period, zone: zone, station: cp_tram_bom_dong,
    recipient_key: :group_id, recipient: group_quan_y_beta,
    attrs: { coefficient: BigDecimal("1"), fixed_percentage: nil }
  )
  puts "  PumpAllocations: #{period.pump_allocations.where(zone_id: zone.id).count} (2 stations, 3 recipient types)"
end

# -----------------------------------------------------------------------------
# OLDER, CLOSED legacy period: May 2026, pump_allocation_per_station = false.
#
# Production has periods predating TN2 where ALL pump electricity of the zone was
# pooled and split zone-wide (the pre-TN2 behavior). This block seeds one such
# legacy period so the demo can REOPEN it and prove TN2 left the old mechanism
# untouched: a single "Gộp toàn khu vực (kỳ cũ)" card on Phân bổ bơm nước, and the
# pooled "Sử dụng điện bơm nước" on Bảng tính tiền with NO per-station detail table.
#
# Built in a SECOND transaction (after June committed) because:
#   - June is the open period; the DB allows exactly one open period, so May is
#     created closed: true directly (PeriodService.open_new_period would raise).
#   - Meter#after_create seeds readings only for the OPEN period, so May's per-period
#     snapshots (readings, personnel, configs, deductions) are created explicitly here,
#     mirroring what PeriodService#snapshot_existing_entities does for a real period.
# Legacy allocations carry pump_contact_point_id = NULL (zone-wide shape); the
# calculator's allocate_zone_wide branch handles them, producing zero
# PumpStationCharge rows (→ no per-station table) but a correct pooled water_pump_usage.
# -----------------------------------------------------------------------------
ActiveRecord::Base.transaction do
  zone       = Zone.find_by!(name: "Khu vực 1")
  june       = Period.find_by!(year: 2026, month: 6)
  unit_alpha = Unit.find_by!(name: "Tiểu đoàn 1")
  unit_beta  = Unit.find_by!(name: "Tiểu đoàn 2")
  main_meter = zone.main_meters.kept.first!

  legacy_period = Period.find_by(year: 2026, month: 5)
  unless legacy_period
    legacy_period = Period.create!(
      year: 2026, month: 5, closed: true,
      unit_price: june.unit_price,
      savings_rate: june.savings_rate,
      division_public_rate: june.division_public_rate,
      water_pump_standard: june.water_pump_standard,
      pump_allocation_per_station: false
    )
  end
  legacy_period.update!(closed: true, pump_allocation_per_station: false)

  # Ranks: copy June's positions/quotas so personnel snapshots line up by position.
  if legacy_period.ranks.empty?
    june.ranks.order(:position).each do |rank|
      legacy_period.ranks.create!(name: rank.name, quota: rank.quota, position: rank.position)
    end
  end
  legacy_rank_by_pos = legacy_period.ranks.index_by(&:position)

  # Personnel snapshot for every residential contact point (inherit June's counts).
  ContactPoint.kept.where(contact_point_type: "residential").find_each do |cp|
    legacy_period.ranks.each do |rank|
      june_rank  = june.ranks.find_by(position: rank.position)
      june_entry = june_rank && PersonnelEntry.find_by(contact_point: cp, period: june, rank: june_rank)
      cp.personnel_entries.find_or_create_by!(period: legacy_period, rank: rank) do |entry|
        entry.count = june_entry&.count || 0
      end
    end
    cp.other_deductions.find_or_create_by!(period: legacy_period) do |deduction|
      deduction.other_type  = "fixed"
      deduction.other_value = 0
    end
  end

  # Unit configs (unit_public_rate) — needed by SummaryCalculator for the public share.
  [unit_alpha, unit_beta].each do |unit|
    config = unit.unit_configs.find_or_create_by!(period: legacy_period) { |c| c.unit_public_rate = 0 }
    config.update!(unit_public_rate: BigDecimal("5")) unless config.unit_public_rate == BigDecimal("5")
  end

  # Meter readings for the legacy period. Both pump stations carry real readings so
  # the pooled pump electricity (D toàn khu vực) is non-zero; the rest get small
  # readings so the per-type loss breakdown and main billing table have data.
  legacy_readings = {
    "CT-A1"    => { start: 1_000, finish: 1_180 },
    "CT-A2"    => { start: 2_700, finish: 2_960 },
    "CT-BEP"   => { start: 500,   finish: 590  },
    "CT-B1"    => { start: 5_100, finish: 5_480 },
    "CT-B2"    => { start: 900,   finish: 960  },
    "CT-CC-NA" => { start: 700,   finish: 800  },
    "CT-BOM"   => { start: 60,    finish: 160  }, # Trạm bơm Tây: 100
    "CT-BOM-D" => { start: 40,    finish: 100  }, # Trạm bơm Đông: 60
    "CT-KV"    => { start: 300,   finish: 400  },
    "CT-KTH"   => { start: 0,     finish: 70   }
  }
  legacy_readings.each do |meter_name, attrs|
    meter = Meter.kept.find_by(name: meter_name)
    next unless meter
    reading = meter.meter_readings.find_or_initialize_by(period: legacy_period)
    reading.update!(
      reading_start: BigDecimal(attrs[:start].to_s),
      reading_end:   BigDecimal(attrs[:finish].to_s),
      no_loss:       meter.no_loss
    )
  end
  # Any remaining kept meter without a legacy reading gets a zero reading so the
  # loss calculation never trips on a missing reading.
  Meter.kept.find_each do |meter|
    next if meter.meter_readings.exists?(period: legacy_period)
    meter.meter_readings.create!(period: legacy_period, reading_start: 0, reading_end: 0, no_loss: meter.no_loss)
  end

  # Main meter reading — a little above measured so loss is a few percent.
  legacy_main = MainMeterReading.find_or_initialize_by(main_meter: main_meter, period: legacy_period)
  legacy_main.usage = BigDecimal("1480")
  legacy_main.save!

  # Legacy ZONE-WIDE pump allocations: pump_contact_point_id = NULL. Recipients are a
  # đơn vị (Tiểu đoàn 2, by hệ số) and a zone-level đầu mối (Chỉ huy khu vực 1, 30%
  # cố định) — the legacy shape where one pool is split across the whole zone.
  cp_chi_huy_kv = ContactPoint.find_by!(
    name: "Chỉ huy khu vực 1", contact_point_type: "residential",
    zone_id: zone.id, unit_id: nil
  )
  PumpAllocation.where(period_id: legacy_period.id, zone_id: zone.id).delete_all
  PumpAllocation.create!(
    period: legacy_period, zone: zone, pump_contact_point: nil,
    unit: unit_beta, coefficient: BigDecimal("1"), fixed_percentage: nil
  )
  PumpAllocation.create!(
    period: legacy_period, zone: zone, pump_contact_point: nil,
    contact_point: cp_chi_huy_kv, coefficient: BigDecimal("0"), fixed_percentage: BigDecimal("30")
  )

  # Run the real calculation engine for the legacy period so its billing page has
  # data (pooled pump electricity, zero per-station charges).
  CalculationOrchestrator.new(zone: zone, period: legacy_period).call

  puts "  Legacy period: #{legacy_period.month}/#{legacy_period.year} " \
       "(per_station: #{legacy_period.pump_allocation_per_station}, closed: #{legacy_period.closed?})"
  puts "  Legacy pump allocations: #{legacy_period.pump_allocations.where(zone_id: zone.id).count} " \
       "(zone-wide, pump_contact_point_id = NULL)"
  puts "  Legacy PumpStationCharge rows: " \
       "#{PumpStationCharge.where(period_id: legacy_period.id, zone_id: zone.id).count} (expect 0)"
end

puts "Demo dataset loaded successfully."
puts "  Demo admin credentials: username=demo_admin  password=Demo@1234"

# frozen_string_literal: true

# Imports real February 2026 data for Sư đoàn bộ (SDB) from the Excel fixture
# shipped with the repository. Used as a one-shot data loader for the 19-20/04
# demo and to seed production on Railway.
#
# Scope: SDB only. 79 contact points from "Sheet1 (2)" sections I-IV plus
# their meter readings (parsed from "Sheet1"), personnel counts,
# other deductions, and 3 pump stations (assigned to SDB).
#
# The imported data is NOT expected to reproduce Excel's 22-column numbers
# verbatim — the engine uses v5 rules (water pump rate 9.45 kW/person,
# loss deducted from standard instead of added to usage, 7 rank groups).
# See docs/BANG_22_COT_ANALYSIS.md for the full divergence analysis.
#
# Idempotent: running twice is a no-op.
#
#   result = ImportFeb2026Service.new.call
#   result.contact_points_count  # => 79
#   result.warnings              # => Array<String>
class ImportFeb2026Service
  PATH_DEFAULT = Rails.root.join("test/fixtures/files/bang_tinh_thang_02.xlsx")
  SHEET_BANG22 = "Sheet1 (2)"
  SHEET_METERS = "Sheet1"
  PERIOD_YEAR  = 2026
  PERIOD_MONTH = 2
  ORG_CODE     = "SDB"
  EXPECTED_CP_COUNT = 79  # Safety net: Sheet1(2) sections I-IV data rows. Diff → Excel structure changed.

  ELECTRICITY_SUPPLY_KW = BigDecimal("41940") # 45,960 − 4,020 TĐ18 no-loss position
  SAVINGS_RATE          = BigDecimal("0.05")
  DIVISION_PUBLIC_RATE  = BigDecimal("0.10")
  UNIT_PUBLIC_RATE      = BigDecimal("0")
  UNIT_PRICE_VND        = BigDecimal("2336.4")

  # Pump-station meters. reading_end is computed as reading_start + Sheet1 col G
  # (already-adjusted consumption), so "Trạm nước cấp 1" reflects the Excel's
  # "sau khi trừ nhà ở trạm nước" value of 2,158 kW instead of the raw 2,677.
  PUMP_STATIONS = [
    { name: "Trạm nước bên sông", sheet_row: 145 },
    { name: "Trạm nước cấp 1",    sheet_row: 146 },
    { name: "Trạm nước cấp 2",    sheet_row: 147 }
  ].freeze

  # Aggregation overrides: Sheet1(2) contact-point name → list of Sheet1 row numbers
  # whose readings should be summed for that contact point. Use this hash for
  # cases where a single contact point corresponds to multiple physical meters,
  # where names diverge across sheets, or where group normalization is lossy
  # (e.g. "B.Q.Khí" vs "Ban Quân khí").
  MANUAL_METER_MATCH = {
    # Section I — Phòng Tham mưu
    "Ban Quân lực — Quỳnh;  Tú"                 => [ 27 ],
    "Ban Trinh sát — TB TS + Ngọc"              => [ 33 ],
    "Ban Công binh — TB + Tùng +Cường"          => [ 35 ],
    "Ban Công binh — Hưng,Phiêu"                => [ 36 ],
    "Ban Phòng không — Nguyên,Đạt"              => [ 40 ],
    "Ban tài chính — TB Thịnh"                  => [ 44 ],
    "Ban tài chính — P4 Vũ;Giang"               => [ 47 ],
    "Trợ lý chính trị"                          => [ 52 ],
    "Tổ xe"                                     => [ 53, 54, 55, 56 ],
    "Bảo đảm (Không tính quân y f bộ)"          => [ 100, 101, 102, 103, 104, 105 ],
    "Phòng cắt tóc"                             => [ 137 ],
    # Section II — Phòng chính trị
    "Ban dân vận"                               => [ 62 ],
    "Ban Bảo vệ — TB + Thịnh"                   => [ 65 ],
    "Ban Bảo vệ — TL Hiếu + Đức"                => [ 66 ],
    "Ban tuyên huấn — TB"                       => [ 70 ],
    "Ban tuyên huấn — Ánh (Hội trường)"         => [ 71, 72 ],
    "TLKH huy, Vũ"                              => [ 75 ],
    # Section III — Phòng HC-KT
    "Phòng ăn tầng 1"                           => [ 80 ],
    "Phòng ăn tầng 2"                           => [ 81 ],
    "Ban Doanh trại — TB"                       => [ 85 ],
    "Ban Doanh trại — TL"                       => [ 86 ],
    "Ban Xăng dầu — TB"                         => [ 91 ],
    "Ban xe máy — TB"                           => [ 94 ],
    "Ban Quân khí — TB"                         => [ 96 ],
    "Ban Quân khí — TL"                         => [ 97 ],
    "TLCT Huy"                                  => [ 98 ],
    # Section IV — Khác
    "Nhà xe dân sự"                             => [ 134 ],
    "Xưởng in Ban tác huấn"                     => [ 135 ],
    "Trạm sửa chữa cổng"                        => [ 138 ],
    "Cây ATM"                                   => [ 142 ],
    "Chuồng lợn bếp fbo"                        => [ 149 ],
    "Máy sục ao (Hưng Hchính)"                  => [ 152 ]
  }.freeze

  # Sheet1 rows to skip entirely in the "unmatched meter" warning list
  # (out-of-scope: other units or shared infrastructure beyond SDB demo).
  SKIPPED_METER_ROWS = [
    *(15..21),                                     # Chỉ huy f (Sư đoàn level)
    106,                                           # Quân y f bộ (not in Bảo đảm for SDB)
    *(107..114),                                   # C20-23
    *(115..133), 136, *(139..144),                 # Điện khác shared
    145, 146, 147,                                 # Pump stations (handled separately)
    148, *(150..151)                               # Cổng gác / Đài phun nước / Vườn bưởi
  ].freeze

  Result = Struct.new(
    :period, :organization, :contact_points_count, :meters_count,
    :readings_count, :personnel_count, :other_deductions_count,
    :pump_stations_count, :warnings, keyword_init: true
  )

  def initialize(path: PATH_DEFAULT)
    @path = path.to_s
    @warnings = []
  end

  def call
    raise ArgumentError, "Excel file not found: #{@path}" unless File.exist?(@path)

    open_workbook!

    # PaperTrail versions are for tracking human edits in the UI. This service
    # is an automated bulk loader — audit trail for it belongs to git / the Rake
    # task invocation, not to a per-row DB log. Suppress version creation so
    # re-running on identical data is truly a no-op.
    PaperTrail.request(enabled: false) do
      ActiveRecord::Base.transaction do
        @period = upsert_monthly_period
        @organization = Organization.find_by!(code: ORG_CODE)
        upsert_unit_config

        cp_specs = parse_contact_points
        assert_unique_contact_point_names!(cp_specs)
        meter_specs = parse_meter_specs
        used_rows = Set.new

        cp_specs.each do |spec|
          cp = upsert_contact_point(spec)
          upsert_personnel(cp, spec)
          upsert_other_deduction(cp, spec)
          upsert_meter_and_reading(cp, spec, meter_specs, used_rows)
        end

        log_unmatched_meter_rows(meter_specs, used_rows)
        upsert_pump_stations
        assert_expected_contact_point_count!
      end
    end

    build_result
  end

  private

  # ===================================================================== I/O
  def open_workbook!
    @book = Roo::Excelx.new(@path)
    unless @book.sheets.include?(SHEET_BANG22) && @book.sheets.include?(SHEET_METERS)
      raise ArgumentError,
            "Excel missing expected sheet '#{SHEET_BANG22}' or '#{SHEET_METERS}'"
    end
  end

  def cell(sheet_name, row, col)
    @book.sheet(sheet_name).cell(row, col)
  end

  # ============================================================= period/org/config
  def upsert_monthly_period
    period = MonthlyPeriod.find_or_initialize_by(year: PERIOD_YEAR, month: PERIOD_MONTH)
    raise "Cannot import into locked period #{period.label}" if period.persisted? && period.locked?

    period.unit_price = UNIT_PRICE_VND
    period.locked = false if period.new_record?
    period.save! if period.new_record? || period.changed?
    period
  end

  def upsert_unit_config
    cfg = UnitConfig.find_or_initialize_by(organization: @organization, monthly_period: @period)
    cfg.savings_rate = SAVINGS_RATE
    cfg.division_public_rate = DIVISION_PUBLIC_RATE
    cfg.unit_public_rate = UNIT_PUBLIC_RATE
    cfg.other_deduction_type = :fixed_kw
    cfg.other_deduction_value = BigDecimal("0")
    cfg.electricity_supply_kw = ELECTRICITY_SUPPLY_KW
    cfg.save! if cfg.new_record? || cfg.changed?
    cfg
  end

  # ============================================================= parse Sheet1(2)
  def parse_contact_points
    specs = []
    section = nil
    group = nil

    (9..91).each do |row|
      b = cell(SHEET_BANG22, row, 2)
      c = cell(SHEET_BANG22, row, 3)
      d = cell(SHEET_BANG22, row, 4)
      e = cell(SHEET_BANG22, row, 5)
      f = cell(SHEET_BANG22, row, 6)
      g = cell(SHEET_BANG22, row, 7)
      h = cell(SHEET_BANG22, row, 8)
      m = cell(SHEET_BANG22, row, 13)

      next if b.nil? && c.nil? && d.nil?

      # Section marker (col B is Roman numeral)
      if b.is_a?(String) && b.match?(/\A(I|II|III|IV)\z/)
        section = "#{b.strip}. #{c.to_s.strip}"
        group = nil
        next
      end

      # Grand total ("Tổng Quân số" row at bottom)
      next if c.to_s.strip.start_with?("Tổng")

      c_str = c.to_s.strip.presence
      d_str = d.to_s.strip.presence

      if d_str && c_str
        group = c_str
        name = "#{c_str} — #{d_str}"
      elsif d_str
        raise ArgumentError, "Row #{row}: sub-row without a preceding group" if group.nil?

        name = "#{group} — #{d_str}"
      elsif c_str
        group = c_str
        name = c_str
      else
        next
      end

      specs << {
        row:         row,
        section:     section,
        group:       group,
        name:        name,
        detail:      d_str,
        rank1_count: to_int(e),
        rank5_count: to_int(f) + to_int(g),
        rank7_count: to_int(h),
        other_value: to_decimal(m)
      }
    end

    specs
  end

  # ============================================================= parse Sheet1 meters
  def parse_meter_specs
    specs = []
    current_group = nil

    (15..152).each do |row|
      b = cell(SHEET_METERS, row, 1)
      c = cell(SHEET_METERS, row, 2)
      cs = cell(SHEET_METERS, row, 3)
      ce = cell(SHEET_METERS, row, 4)
      es = cell(SHEET_METERS, row, 5)
      ee = cell(SHEET_METERS, row, 6)

      current_group = b.to_s.strip if b.is_a?(String) && b.to_s.strip.present?

      detail = c.to_s.strip.presence
      next if detail.nil?

      validate_reading_pair!(row, "Nhà ở", cs, ce)
      validate_reading_pair!(row, "NLV", es, ee)

      has_reading = [ cs, ce, es, ee ].any? { |v| v.is_a?(Numeric) }
      next unless has_reading

      specs << {
        row:           row,
        group:         current_group,
        detail:        detail,
        reading_start: to_decimal(cs) + to_decimal(es),
        reading_end:   to_decimal(ce) + to_decimal(ee)
      }
    end

    specs
  end

  # Nhà ở start/end and NLV start/end must appear as pairs. A single-sided
  # cell silently treats the missing side as 0 → wildly inflated consumption.
  def validate_reading_pair!(row, label, start_val, end_val)
    start_present = start_val.is_a?(Numeric)
    end_present = end_val.is_a?(Numeric)
    return if start_present == end_present

    raise ArgumentError,
          "Sheet1 row #{row} (#{label}): only one side of start/end present " \
          "(start=#{start_val.inspect}, end=#{end_val.inspect})"
  end

  # ============================================================= persistence
  def upsert_contact_point(spec)
    cp = ContactPoint.find_or_initialize_by(organization: @organization, name: spec[:name])
    cp.group_name = spec[:section]
    cp.position = spec[:row]
    cp.save! if cp.new_record? || cp.changed?
    cp
  end

  def upsert_personnel(contact_point, spec)
    p = Personnel.find_or_initialize_by(contact_point: contact_point, monthly_period: @period)
    p.rank1_count = spec[:rank1_count]
    p.rank2_count = 0
    p.rank3_count = 0
    p.rank4_count = 0
    p.rank5_count = spec[:rank5_count]
    p.rank6_count = 0
    p.rank7_count = spec[:rank7_count]
    p.save! if p.new_record? || p.changed?
  end

  def upsert_other_deduction(contact_point, spec)
    value = spec[:other_value]

    ded = ContactPointOtherDeduction.find_by(contact_point: contact_point, monthly_period: @period)

    if value.nil? || value.zero?
      ded&.destroy! # clear stale row when fixture changes a prior non-zero to zero
      return
    end

    ded ||= ContactPointOtherDeduction.new(contact_point: contact_point, monthly_period: @period)
    ded.other_type = :fixed_kw
    ded.other_value = value
    return unless ded.new_record? || ded.changed?

    ded.save!
  end

  def upsert_meter_and_reading(contact_point, spec, meter_specs, used_rows)
    matched = match_meter_rows(spec, meter_specs)

    if matched.empty?
      @warnings << "No meter rows matched for contact point '#{contact_point.name}' " \
                   "(Sheet1(2) row #{spec[:row]}) — contact point saved without meter reading"
      return
    end

    matched.each { |m| used_rows << m[:row] }

    reading_start = matched.sum(BigDecimal("0")) { |m| m[:reading_start] }
    reading_end   = matched.sum(BigDecimal("0")) { |m| m[:reading_end] }
    source_note = "Sheet1 rows #{matched.map { |m| m[:row] }.join(', ')}"

    meter = Meter.find_or_initialize_by(
      organization: @organization,
      contact_point: contact_point,
      name: "#{contact_point.name} — Tổng (Nhà ở + NLV)",
      meter_type: :normal
    )
    meter.position = spec[:row]
    meter.notes = "Aggregated from #{source_note}"
    meter.save! if meter.new_record? || meter.changed?

    reading = MeterReading.find_or_initialize_by(meter: meter, monthly_period: @period)
    reading.reading_start = reading_start
    reading.reading_end = reading_end
    reading.save! if reading.new_record? || reading.changed?
  end

  # Returns Array<meter_spec>. Tries MANUAL_METER_MATCH first, then normalized
  # name matching against Sheet1's detail column, narrowing by group when
  # ambiguous.
  def match_meter_rows(spec, meter_specs)
    if MANUAL_METER_MATCH.key?(spec[:name])
      rows = MANUAL_METER_MATCH[spec[:name]]
      return meter_specs.select { |m| rows.include?(m[:row]) }
    end

    key = spec[:detail] || spec[:name]
    key_norm = normalize(key)
    return [] if key_norm.empty?

    candidates = meter_specs.select { |m| normalize_substring_match?(m[:detail], key_norm) }

    if candidates.size > 1 && spec[:group]
      group_norm = normalize(spec[:group])
      narrowed = candidates.select do |m|
        m[:group] && normalize_substring_match?(m[:group], group_norm, min_len: 4)
      end
      candidates = narrowed if narrowed.any?
    end

    if candidates.size > 1 && spec[:detail].nil?
      exact = candidates.select { |m| normalize(m[:detail]) == key_norm }
      candidates = exact if exact.any?
    end

    candidates
  end

  def log_unmatched_meter_rows(meter_specs, used_rows)
    meter_specs.each do |m|
      next if used_rows.include?(m[:row])
      next if SKIPPED_METER_ROWS.include?(m[:row])

      @warnings << "Unmatched Sheet1 meter row #{m[:row]} (group='#{m[:group]}', " \
                   "detail='#{m[:detail]}') — skipped (name mismatch)"
    end
    @warnings << "no_loss_position chưa support — Tiểu đoàn 18 tại trạm biến áp " \
                 "(Sheet1 row 7, 4,020 kW) bỏ qua, ngoài phạm vi SDB"
    @warnings << "Bảng II bỏ qua — demo chỉ có SDB, engine gán 100% bơm nước " \
                 "(≈ 6,420 kW) cho SDB"
  end

  # ============================================================= pump stations
  def upsert_pump_stations
    PUMP_STATIONS.each do |ps_spec|
      row = ps_spec[:sheet_row]
      cs = to_decimal(cell(SHEET_METERS, row, 3))
      consumption = to_decimal(cell(SHEET_METERS, row, 7))

      ps = PumpStation.find_or_initialize_by(organization: @organization, name: ps_spec[:name])
      ps.save! if ps.new_record? || ps.changed?

      # meter_type included in the lookup so we never accidentally convert a
      # pre-existing :normal meter with the same name.
      meter = Meter.find_or_initialize_by(
        organization: @organization,
        name: "#{ps_spec[:name]} — công tơ",
        meter_type: :pump_station
      )
      meter.contact_point = nil
      meter.pump_station = ps
      meter.position = row
      meter.save! if meter.new_record? || meter.changed?

      # TODO(M6.x): set fixed_pump_percentage 30 cho org "Chỉ huy f + nhà khách"
      # sau khi tạo org đó qua admin UI. Hiện tại tất cả assignments là variable
      # (nil) — engine fallback về behavior 100% theo quân số (giữ Bảng II workaround).
      PumpStationAssignment.find_or_create_by!(pump_station: ps, organization: @organization)

      reading = MeterReading.find_or_initialize_by(meter: meter, monthly_period: @period)
      reading.reading_start = cs
      reading.reading_end = cs + consumption
      reading.save! if reading.new_record? || reading.changed?
    end
  end

  # ============================================================= helpers
  def normalize(str)
    return "" if str.nil?

    I18n.transliterate(str.to_s)
        .downcase
        .gsub(/[^a-z0-9]+/, " ")
        .squeeze(" ")
        .strip
  end

  def normalize_substring_match?(candidate, key_norm, min_len: 3)
    return false if candidate.nil?

    cand_norm = normalize(candidate)
    return false if cand_norm.empty? || key_norm.empty?
    return false if cand_norm.length < min_len || key_norm.length < min_len

    cand_norm.include?(key_norm) || key_norm.include?(cand_norm)
  end

  def to_int(value)
    return 0 if value.nil?

    int_val = value.to_i
    if value.is_a?(Numeric) && value != int_val
      @warnings << "Truncated non-integer count: #{value} → #{int_val}"
    end
    int_val
  end

  def assert_unique_contact_point_names!(cp_specs)
    duplicates = cp_specs.map { |s| s[:name] }.tally.select { |_, count| count > 1 }
    return if duplicates.empty?

    raise ArgumentError,
          "Duplicate contact point names detected (would violate unique index): " \
          "#{duplicates.keys.join(', ')}"
  end

  def assert_expected_contact_point_count!
    count = ContactPoint.where(organization: @organization).count
    return if count == EXPECTED_CP_COUNT

    @warnings << "Expected #{EXPECTED_CP_COUNT} contact points for SDB but found #{count} — " \
                 "Excel structure may have changed; review MANUAL_METER_MATCH and row ranges"
  end

  def to_decimal(value)
    case value
    when BigDecimal then value
    when Numeric then BigDecimal(value.to_s)
    when String then value.strip.empty? ? BigDecimal("0") : BigDecimal(value)
    when nil then BigDecimal("0")
    else raise ArgumentError, "Unexpected #{value.class} for decimal: #{value.inspect}"
    end
  end

  def build_result
    Result.new(
      period:                  @period,
      organization:            @organization,
      contact_points_count:    ContactPoint.where(organization: @organization).count,
      meters_count:            Meter.where(organization: @organization).count,
      readings_count:          MeterReading.joins(:meter)
                                           .where(meters: { organization_id: @organization.id },
                                                  monthly_period_id: @period.id).count,
      personnel_count:         Personnel.joins(:contact_point)
                                        .where(contact_points: { organization_id: @organization.id },
                                               monthly_period_id: @period.id).count,
      other_deductions_count:  ContactPointOtherDeduction
                                 .joins(:contact_point)
                                 .where(contact_points: { organization_id: @organization.id },
                                        monthly_period_id: @period.id).count,
      pump_stations_count:     PumpStation.where(organization: @organization).count,
      warnings:                @warnings
    )
  end
end

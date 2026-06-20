require "ostruct"

module SampleData
  SAMPLE_RANK_KEYS = %i[
    chi_huy_su_doan
    chi_huy_trung_doan
    chi_huy_tieu_doan
    chi_huy_dai_doi
    co_quan
    tieu_doan_dai_doi
    ha_si_quan
  ].freeze

  SAMPLE_PERSONNEL = {
    ban_tac_huan:    { tieu_doan_dai_doi: 2,                          ha_si_quan: 3 },
    van_thu:         {                       co_quan: 1,              ha_si_quan: 1 },
    kho_vat_tu:      {                                   chi_huy_dai_doi: 1, ha_si_quan: 2 },
    dai_doi_1:       {                                   chi_huy_dai_doi: 1, ha_si_quan: 10 },
    chi_huy_khu_vuc: { chi_huy_su_doan: 1 }
  }.freeze

  SAMPLE_METER_READINGS = {
    ct_a1:     { start: 1_000, finish: 1_250, no_loss: false },
    ct_a2:     { start: 500,   finish: 680,   no_loss: false },
    ct_a3:     { start: 200,   finish: 310,   no_loss: true },
    ct_cc_a:   { start: 300,   finish: 520,   no_loss: false },
    ct_b1:     { start: 2_000, finish: 2_350, no_loss: false },
    ct_cc_b:   { start: 100,   finish: 150,   no_loss: false },
    ct_kv1:    { start: 800,   finish: 1_250, no_loss: false },
    ct_cc_kv:  { start: 400,   finish: 530,   no_loss: false },
    ct_bn1:    { start: 600,   finish: 900,   no_loss: false }
  }.freeze

  SAMPLE_PERSONNEL_KV2 = {
    quan_y:            { chi_huy_dai_doi: 1, ha_si_quan: 4 },   # 5 người
    trinh_sat:         { tieu_doan_dai_doi: 2, ha_si_quan: 6 }, # 8 người
    chi_huy_khu_vuc_2: { chi_huy_trung_doan: 1 }                # 1 người
  }.freeze

  SAMPLE_METER_READINGS_KV2 = {
    ct_qy:    { start: 0,     finish: 150,   no_loss: false },
    ct_ts:    { start: 1_000, finish: 1_300, no_loss: false },
    ct_chkv2: { start: 200,   finish: 550,   no_loss: false },
    ct_cc_c:  { start: 0,     finish: 120,   no_loss: false },
    ct_bn2:   { start: 0,     finish: 150,   no_loss: false }
  }.freeze

  # Tạo toàn bộ dữ liệu mẫu mục 1 của V2_KICH_BAN_TEST.md cho kỳ tháng 5/2026.
  # Trả về OpenStruct chứa mọi entity cần cho assertions.
  def setup_zone_one_full_sample(open_period: true)
    zone = create(:zone, name: "Khu vực 1")
    main_meter = create(:main_meter, name: "CT-Tổng-KV1", zone: zone)

    unit_a = create(:unit, name: "Đơn vị A", zone: zone)
    unit_b = create(:unit, name: "Đơn vị B", zone: zone)
    zone.update!(manager_unit: unit_a)

    period = PeriodService.new.open_new_period(year: 2026, month: 5, unit_price: BigDecimal("2336.4")).period
    # Mẫu T02 mô hình phân bổ bơm zone-wide (trước TN2): pump_allocations dùng đối tượng
    # cấp khu vực không gắn trạm bơm. Ép kỳ về legacy để giữ ngữ nghĩa zone-wide.
    period.update!(pump_allocation_per_station: false)

    ranks = build_sample_ranks_lookup(period)

    block_a = create(:block, name: "Phòng Tham mưu", unit: unit_a)
    group_ban_tac_huan = create(:group, name: "Ban Tác huấn", unit: unit_a, block: block_a)

    contact_points = {
      ban_tac_huan: create_residential_with_personnel(
        name: "Ban Tác huấn", unit: unit_a, block: block_a, group: group_ban_tac_huan,
        ranks: ranks, counts_key: :ban_tac_huan
      ),
      van_thu: create_residential_with_personnel(
        name: "Văn thư", unit: unit_a, block: block_a,
        ranks: ranks, counts_key: :van_thu
      ),
      kho_vat_tu: create_residential_with_personnel(
        name: "Kho vật tư", unit: unit_a,
        ranks: ranks, counts_key: :kho_vat_tu
      ),
      dai_doi_1: create_residential_with_personnel(
        name: "Đại đội 1", unit: unit_b,
        ranks: ranks, counts_key: :dai_doi_1
      ),
      chi_huy_khu_vuc: create_zone_residential_with_personnel(
        name: "Chỉ huy khu vực", zone: zone,
        ranks: ranks, counts_key: :chi_huy_khu_vuc
      ),
      nha_an:      create(:contact_point, :public_type, name: "Nhà ăn", unit: unit_a),
      tram_gac:    create(:contact_point, :public_type, name: "Trạm gác", unit: unit_b),
      den_duong:   build_zone_public(name: "Đèn đường", zone: zone),
      tram_bom_1:  create(:contact_point, :water_pump, name: "Trạm bơm 1", zone: zone),
      tho_xay:     create(:contact_point, :non_establishment, name: "Thợ xây", zone: zone, personnel_count: 5)
    }

    meters = {
      ct_a1:    create(:meter, name: "CT-A1",    contact_point: contact_points[:ban_tac_huan],    no_loss: false),
      ct_a2:    create(:meter, name: "CT-A2",    contact_point: contact_points[:van_thu],         no_loss: false),
      ct_a3:    create(:meter, name: "CT-A3",    contact_point: contact_points[:kho_vat_tu],      no_loss: true),
      ct_cc_a:  create(:meter, name: "CT-CC-A",  contact_point: contact_points[:nha_an],          no_loss: false),
      ct_b1:    create(:meter, name: "CT-B1",    contact_point: contact_points[:dai_doi_1],       no_loss: false),
      ct_cc_b:  create(:meter, name: "CT-CC-B",  contact_point: contact_points[:tram_gac],        no_loss: false),
      ct_kv1:   create(:meter, name: "CT-KV1",   contact_point: contact_points[:chi_huy_khu_vuc], no_loss: false),
      ct_cc_kv: create(:meter, name: "CT-CC-KV", contact_point: contact_points[:den_duong],       no_loss: false),
      ct_bn1:   create(:meter, name: "CT-BN1",   contact_point: contact_points[:tram_bom_1],      no_loss: false)
    }

    SAMPLE_METER_READINGS.each do |meter_key, attrs|
      reading = meters[meter_key].meter_readings.find_by!(period: period)
      reading.update!(reading_start: BigDecimal(attrs[:start].to_s),
                      reading_end: BigDecimal(attrs[:finish].to_s),
                      no_loss: attrs[:no_loss])
    end

    main_meter_reading = main_meter.main_meter_readings.create!(period: period, usage: BigDecimal("2100"))

    unit_a.unit_configs.find_by!(period: period).update!(unit_public_rate: BigDecimal("3"))
    unit_b.unit_configs.find_by!(period: period).update!(unit_public_rate: BigDecimal("0"))

    apply_other_deduction(contact_points[:ban_tac_huan],    period, type: "fixed",       value: BigDecimal("5"))
    apply_other_deduction(contact_points[:van_thu],         period, type: "coefficient", value: BigDecimal("-2.5"))
    apply_other_deduction(contact_points[:kho_vat_tu],      period, type: "fixed",       value: BigDecimal("0"))
    apply_other_deduction(contact_points[:dai_doi_1],       period, type: "coefficient", value: BigDecimal("3"))
    apply_other_deduction(contact_points[:chi_huy_khu_vuc], period, type: "fixed",       value: BigDecimal("0"))

    pump_allocations = {
      chi_huy_khu_vuc: create(:pump_allocation,
                              zone: zone, period: period, unit: nil,
                              contact_point: contact_points[:chi_huy_khu_vuc],
                              fixed_percentage: BigDecimal("20"), coefficient: BigDecimal("1")),
      unit_a: create(:pump_allocation,
                     zone: zone, period: period, unit: unit_a, contact_point: nil,
                     fixed_percentage: nil, coefficient: BigDecimal("1")),
      unit_b: create(:pump_allocation,
                     zone: zone, period: period, unit: unit_b, contact_point: nil,
                     fixed_percentage: nil, coefficient: BigDecimal("1")),
      tho_xay: create(:pump_allocation,
                      zone: zone, period: period, unit: nil,
                      contact_point: contact_points[:tho_xay],
                      fixed_percentage: nil, coefficient: BigDecimal("0.5"))
    }

    period.update!(closed: true) unless open_period

    OpenStruct.new(
      zone: zone, main_meter: main_meter, main_meter_reading: main_meter_reading,
      unit_a: unit_a, unit_b: unit_b,
      period: period, ranks: ranks,
      contact_points: contact_points, meters: meters,
      pump_allocations: pump_allocations
    )
  end

  # Build Khu vực 2 vào period đã mở (do setup_zone_one_full_sample tạo).
  # Bổ sung cho dữ liệu mẫu KV1, chỉ thêm các lỗ hổng KV1 chưa có.
  # `period:` BẮT BUỘC là kỳ đang mở (Period.current): các callback per-kỳ
  # (unit_config, meter_reading, snapshot) tạo bản ghi theo Period.current, rồi
  # helper find_by! theo period truyền vào. Truyền kỳ đã đóng sẽ gây RecordNotFound.
  def setup_zone_two_full_sample(period:)
    zone = create(:zone, name: "Khu vực 2")
    main_meter = create(:main_meter, name: "CT-Tổng-KV2", zone: zone)

    unit_c = create(:unit, name: "Đơn vị C", zone: zone)
    unit_d = create(:unit, name: "Đơn vị D", zone: zone)
    zone.update!(manager_unit: unit_c)

    ranks = build_sample_ranks_lookup(period)

    group_quan_y = create(:group, name: "Tổ Quân y", unit: unit_c, block: nil)

    contact_points = {
      quan_y: create_residential_with_personnel_kv2(
        name: "Quân y", unit: unit_c, group: group_quan_y,
        ranks: ranks, counts_key: :quan_y
      ),
      trinh_sat: create_residential_with_personnel_kv2(
        name: "Trinh sát", unit: unit_d,
        ranks: ranks, counts_key: :trinh_sat
      ),
      chi_huy_khu_vuc_2: create_zone_residential_with_personnel_kv2(
        name: "Chỉ huy khu vực 2", zone: zone,
        ranks: ranks, counts_key: :chi_huy_khu_vuc_2
      ),
      nha_an_2:   create(:contact_point, :public_type, name: "Nhà ăn 2", unit: unit_c),
      tram_bom_2: create(:contact_point, :water_pump, name: "Trạm bơm 2", zone: zone)
    }

    meters = {
      ct_qy:    create(:meter, name: "CT-QY",    contact_point: contact_points[:quan_y],            no_loss: false),
      ct_ts:    create(:meter, name: "CT-TS",    contact_point: contact_points[:trinh_sat],         no_loss: false),
      ct_chkv2: create(:meter, name: "CT-CHKV2", contact_point: contact_points[:chi_huy_khu_vuc_2], no_loss: false),
      ct_cc_c:  create(:meter, name: "CT-CC-C",  contact_point: contact_points[:nha_an_2],           no_loss: false),
      ct_bn2:   create(:meter, name: "CT-BN2",   contact_point: contact_points[:tram_bom_2],         no_loss: false)
    }

    SAMPLE_METER_READINGS_KV2.each do |meter_key, attrs|
      reading = meters[meter_key].meter_readings.find_by!(period: period)
      reading.update!(reading_start: BigDecimal(attrs[:start].to_s),
                      reading_end: BigDecimal(attrs[:finish].to_s),
                      no_loss: attrs[:no_loss])
    end

    main_meter_reading = main_meter.main_meter_readings.create!(period: period, usage: BigDecimal("1100"))

    unit_c.unit_configs.find_by!(period: period).update!(unit_public_rate: BigDecimal("5"))
    unit_d.unit_configs.find_by!(period: period).update!(unit_public_rate: BigDecimal("0"))

    apply_other_deduction(contact_points[:quan_y],            period, type: "fixed", value: BigDecimal("0"))
    apply_other_deduction(contact_points[:trinh_sat],         period, type: "fixed", value: BigDecimal("0"))
    apply_other_deduction(contact_points[:chi_huy_khu_vuc_2], period, type: "fixed", value: BigDecimal("0"))

    pump_allocations = {
      unit_c: create(:pump_allocation, zone: zone, period: period, unit: unit_c, contact_point: nil,
                     fixed_percentage: nil, coefficient: BigDecimal("1")),
      unit_d: create(:pump_allocation, zone: zone, period: period, unit: unit_d, contact_point: nil,
                     fixed_percentage: nil, coefficient: BigDecimal("1")),
      chi_huy_khu_vuc_2: create(:pump_allocation, zone: zone, period: period, unit: nil,
                                contact_point: contact_points[:chi_huy_khu_vuc_2],
                                fixed_percentage: nil, coefficient: BigDecimal("1"))
    }

    OpenStruct.new(
      zone: zone, main_meter: main_meter, main_meter_reading: main_meter_reading,
      unit_c: unit_c, unit_d: unit_d,
      period: period, contact_points: contact_points, meters: meters,
      pump_allocations: pump_allocations
    )
  end

  private

  def build_sample_ranks_lookup(period)
    ranks = period.ranks.order(:position)
    SAMPLE_RANK_KEYS.zip(ranks).to_h
  end

  def create_residential_with_personnel(name:, unit:, ranks:, counts_key:, block: nil, group: nil)
    counts = SAMPLE_PERSONNEL.fetch(counts_key)
    initial = counts.transform_keys { |rank_key| ranks.fetch(rank_key).id }
    contact_point = create(:contact_point, :residential,
                           name: name, unit: unit, block: block, group: group,
                           initial_personnel_counts: initial)
    contact_point
  end

  def create_zone_residential_with_personnel(name:, zone:, ranks:, counts_key:)
    counts = SAMPLE_PERSONNEL.fetch(counts_key)
    initial = counts.transform_keys { |rank_key| ranks.fetch(rank_key).id }
    create(:contact_point, :zone_residential,
           name: name, zone: zone,
           initial_personnel_counts: initial)
  end

  def create_residential_with_personnel_kv2(name:, unit:, ranks:, counts_key:, block: nil, group: nil)
    counts = SAMPLE_PERSONNEL_KV2.fetch(counts_key)
    initial = counts.transform_keys { |rank_key| ranks.fetch(rank_key).id }
    create(:contact_point, :residential,
           name: name, unit: unit, block: block, group: group,
           initial_personnel_counts: initial)
  end

  def create_zone_residential_with_personnel_kv2(name:, zone:, ranks:, counts_key:)
    counts = SAMPLE_PERSONNEL_KV2.fetch(counts_key)
    initial = counts.transform_keys { |rank_key| ranks.fetch(rank_key).id }
    create(:contact_point, :zone_residential,
           name: name, zone: zone,
           initial_personnel_counts: initial)
  end

  def build_zone_public(name:, zone:)
    ContactPoint.create!(name: name, contact_point_type: "public", zone: zone, unit: nil)
  end

  def apply_other_deduction(contact_point, period, type:, value:)
    deduction = contact_point.other_deductions.find_by!(period: period)
    deduction.update!(other_type: type, other_value: value)
  end
end

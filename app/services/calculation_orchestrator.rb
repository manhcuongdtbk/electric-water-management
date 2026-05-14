# frozen_string_literal: true

# F08 + F09 + F10 — Orchestrator của engine tính toán bảng 22 cột cho một đơn vị
# (organization) trong một chu kỳ tháng (monthly_period).
#
# Tuân thủ nghiệp vụ v5 (docs/XAC_NHAN_NGHIEP_VU_v5.html):
#
#   * Engine được tách 3:
#       - LossCalculator (zone:, monthly_period:) — tổn hao zone, per-CP + per-pump.
#       - PumpAllocationCalculator (zone:, monthly_period:, loss_calculator:) —
#         phân bổ pump pool (consumption + pump_loss_share) theo mô hình 30/70
#         (M6) cho mọi assignment trong zone, drill xuống tới CP.
#       - SummaryCalculator (organization:, monthly_period:, loss_results:, pump_results:) —
#         per-CP standard + deductions + usage + billing.
#     Khi org chưa được gán Zone, zone = nil → Loss/Pump short-circuit về 0.
#   * Orchestrator chỉ wire 3 service trên + persist. Không còn business
#     logic per-CP nào ở đây.
#   * Mọi phép tính dùng BigDecimal. KHÔNG làm tròn ở bước trung gian.
#
# Interface:
#
#   orchestrator = CalculationOrchestrator.new(organization:, monthly_period:)
#   orchestrator.compute  # → Array<Hash> (full-precision BigDecimal, not persisted)
#   orchestrator.call     # → persists MonthlyCalculation rows (upsert), returns results
#
# Instance là one-shot: caches build on first access. Tạo instance mới nếu dữ
# liệu underlying thay đổi giữa các lần tính.
class CalculationOrchestrator
  attr_reader :organization, :monthly_period

  def initialize(organization:, monthly_period:)
    @organization = organization
    @monthly_period = monthly_period
  end

  # Compute all 22-column values for every contact point in the organization.
  # Returns an Array of Hashes — one per contact point — with full-precision
  # BigDecimal values. Does NOT touch the database.
  def compute
    summary_calculator.compute(contact_points).map do |row|
      row.except(:contact_point)
    end
  end

  # Compute and persist results to monthly_calculations (upsert per contact point).
  # Runs inside a transaction — any validation failure rolls back all rows.
  def call
    results = compute
    ActiveRecord::Base.transaction do
      results.each { |row| persist(row) }
    end
    results
  end

  # Engine-level warnings surfaced to the UI (e.g. clamped negative loss).
  # Sourced from LossCalculator; empty array when nothing to flag.
  def warnings
    loss_results[:warnings] || []
  end

  private

  def contact_points
    @contact_points ||= organization.contact_points.ordered.to_a
  end

  def zone
    @zone ||= organization.zone
  end

  # --- Loss phase (zone-wide tổn hao) — delegated to LossCalculator -------
  def loss_calculator
    @loss_calculator ||= LossCalculator.new(zone: zone, monthly_period: monthly_period)
  end

  def loss_results
    @loss_results ||= loss_calculator.call
  end

  # --- Pump phase (zone-wide bơm nước) — delegated to PumpAllocationCalculator
  def pump_calculator
    @pump_calculator ||= PumpAllocationCalculator.new(
      zone:            zone,
      monthly_period:  monthly_period,
      loss_calculator: loss_calculator
    )
  end

  def pump_results
    @pump_results ||= pump_calculator.call
  end

  # --- Summary phase (per-CP) — delegated to SummaryCalculator ------------
  def summary_calculator
    @summary_calculator ||= SummaryCalculator.new(
      organization:   organization,
      monthly_period: monthly_period,
      loss_results:   loss_results,
      pump_results:   pump_results
    )
  end

  # ===================================================================== persist

  def persist(row)
    calc = MonthlyCalculation.find_or_initialize_by(
      contact_point_id: row[:contact_point_id],
      monthly_period_id: row[:monthly_period_id]
    )
    calc.assign_attributes(row.except(:contact_point_id, :monthly_period_id))
    calc.save!
  end
end

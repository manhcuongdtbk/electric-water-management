module BillingHelper
  def compute_rowspans(calculations, show_zone:, show_unit:)
    Billing::RowspanComputer.compute(calculations, show_zone: show_zone, show_unit: show_unit)
  end

  def billing_filter_params
    params.permit(:period_id, :zone_id, :unit_id, :q, :per_page).to_h.compact_blank
  end

  def billing_column_signature(show_zone:, show_unit:)
    "z#{show_zone ? 1 : 0}-u#{show_unit ? 1 : 0}"
  end
end

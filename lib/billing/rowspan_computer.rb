module Billing
  class RowspanComputer
    COLUMNS = %i[zone unit block group].freeze

    def self.compute(calculations, show_zone:, show_unit:)
      rows = calculations.map do |calc|
        cp = calc.contact_point
        {
          zone_key: cp.effective_zone&.id,
          unit_key: cp.unit_id,
          block_key: cp.block_id,
          group_key: cp.group_id
        }
      end

      result = Array.new(rows.size) { {} }
      COLUMNS.each do |col|
        next if col == :zone && !show_zone
        next if col == :unit && !show_unit
        compute_column_rowspans(rows, col, result)
      end
      result
    end

    def self.compute_column_rowspans(rows, col, result)
      key = "#{col}_key".to_sym
      parents = COLUMNS.take_while { |c| c != col }.map { |c| "#{c}_key".to_sym }
      i = 0
      while i < rows.size
        j = i + 1
        j += 1 while j < rows.size &&
                     rows[j][key] == rows[i][key] &&
                     parents.all? { |p| rows[j][p] == rows[i][p] }
        result[i][col] = j - i
        i = j
      end
    end
    private_class_method :compute_column_rowspans
  end
end

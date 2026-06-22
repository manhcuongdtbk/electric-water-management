class AddUnitCoefficientToOtherDeductionType < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute "ALTER TYPE other_deduction_type ADD VALUE IF NOT EXISTS 'unit_coefficient'"
  end

  def down
    # PostgreSQL không hỗ trợ xóa giá trị enum đã thêm; down để no-op.
  end
end

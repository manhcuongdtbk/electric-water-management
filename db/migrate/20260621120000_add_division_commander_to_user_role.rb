class AddDivisionCommanderToUserRole < ActiveRecord::Migration[8.0]
  def up
    execute "ALTER TYPE user_role ADD VALUE 'division_commander'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "PostgreSQL does not support removing enum values"
  end
end

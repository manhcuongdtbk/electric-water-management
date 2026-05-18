class CreateEnumTypes < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      CREATE TYPE contact_point_type AS ENUM ('residential', 'public', 'water_pump', 'non_establishment');
      CREATE TYPE other_deduction_type AS ENUM ('fixed', 'coefficient');
      CREATE TYPE user_role AS ENUM ('technician', 'system_admin', 'unit_admin', 'commander');
    SQL
  end

  def down
    execute <<~SQL
      DROP TYPE IF EXISTS user_role;
      DROP TYPE IF EXISTS other_deduction_type;
      DROP TYPE IF EXISTS contact_point_type;
    SQL
  end
end

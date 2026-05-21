class AddLockVersionToNonEstablishmentSnapshots < ActiveRecord::Migration[8.1]
  def change
    add_column :non_establishment_snapshots, :lock_version, :integer, default: 0, null: false
  end
end

class DropEffectiveFromFromRankQuotas < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      DELETE FROM rank_quotas
      WHERE id NOT IN (
        SELECT DISTINCT ON (rank_group) id
        FROM rank_quotas
        ORDER BY rank_group, effective_from DESC, id DESC
      )
    SQL

    remove_index :rank_quotas, name: "index_rank_quotas_on_rank_group_and_effective_from"
    remove_column :rank_quotas, :effective_from
    add_index :rank_quotas, :rank_group, unique: true, name: "index_rank_quotas_on_rank_group"
  end

  def down
    add_column :rank_quotas, :effective_from, :date
    execute "UPDATE rank_quotas SET effective_from = '2024-01-01' WHERE effective_from IS NULL"
    change_column_null :rank_quotas, :effective_from, false
    remove_index :rank_quotas, name: "index_rank_quotas_on_rank_group"
    add_index :rank_quotas, %i[rank_group effective_from], unique: true,
              name: "index_rank_quotas_on_rank_group_and_effective_from"
  end
end

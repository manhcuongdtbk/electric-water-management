class CreateBackups < ActiveRecord::Migration[8.0]
  def change
    create_table :backups do |t|
      t.string  :filename,      null: false
      t.bigint  :size_bytes,    null: false, default: 0
      t.string  :status,        null: false, default: "completed"
      t.text    :error_message
      t.bigint  :created_by_id
      t.timestamps
    end

    add_index :backups, :filename, unique: true
    add_index :backups, :created_at
    add_foreign_key :backups, :users, column: :created_by_id, on_delete: :nullify
  end
end

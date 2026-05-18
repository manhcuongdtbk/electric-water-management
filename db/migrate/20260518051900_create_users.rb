class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :username, null: false
      t.string :encrypted_password, null: false, default: ""
      t.string :display_name, null: false
      t.column :role, :user_role, null: false
      t.references :unit, foreign_key: true
      t.boolean :force_password_change, null: false, default: true
      t.boolean :default_account, null: false, default: false
      t.timestamps
    end

    add_index :users, :username, unique: true
  end
end

class RemoveReviewedBooleanFromPersonnel < ActiveRecord::Migration[8.1]
  def change
    remove_column :personnel, :reviewed, :boolean, default: false, null: false
  end
end

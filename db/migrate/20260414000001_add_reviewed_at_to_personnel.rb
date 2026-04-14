class AddReviewedAtToPersonnel < ActiveRecord::Migration[8.1]
  def change
    add_column :personnel, :reviewed_at, :datetime
  end
end

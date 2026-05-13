class ContactPointGroup < ApplicationRecord
  has_paper_trail

  belongs_to :organization
  has_many :contact_point_group_memberships, dependent: :destroy
  has_many :contact_points, through: :contact_point_group_memberships
  has_many :pump_station_assignments, as: :assignable, dependent: :restrict_with_error

  validates :name, presence: true, length: { maximum: 100 },
                   uniqueness: { scope: :organization_id }

  scope :ordered, -> { order(:name) }

  def total_personnel
    sql = Personnel::RANK_COLUMNS.map { |c| "personnel.#{c}" }.join(" + ")
    contact_points.joins(:personnel_records).sum(sql)
  end
end

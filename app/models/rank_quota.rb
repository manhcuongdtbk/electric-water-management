class RankQuota < ApplicationRecord
  self.table_name = "rank_quotas"

  has_paper_trail

  RANK_GROUPS = (1..7).to_a.freeze
  # Rank group => standard quota (kW/person/month)
  STANDARD_QUOTAS = {
    1 => 570,
    2 => 440,
    3 => 305,
    4 => 130,
    5 => 210,
    6 => 110,
    7 => 24
  }.freeze

  # Validations
  validates :rank_group, presence: true,
            inclusion: { in: RANK_GROUPS },
            uniqueness: true
  validates :rank_name, presence: true, length: { maximum: 100 }
  validates :quota_kw, presence: true,
            numericality: { greater_than: 0 }

  # Scopes
  scope :ordered, -> { order(:rank_group) }
  scope :for_rank, ->(group) { where(rank_group: group) }

  def self.current_quotas
    RANK_GROUPS.each_with_object({}) do |group, hash|
      quota = for_rank(group).first
      hash[group] = quota&.quota_kw
    end
  end

  def self.current_names
    RANK_GROUPS.each_with_object({}) do |group, hash|
      quota = for_rank(group).first
      hash[group] = quota&.rank_name || "Nhóm #{group}"
    end
  end
end

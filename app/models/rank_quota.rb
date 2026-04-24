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
            uniqueness: { scope: :effective_from }
  validates :rank_name, presence: true, length: { maximum: 100 }
  validates :quota_kw, presence: true,
            numericality: { greater_than: 0 }
  validates :effective_from, presence: true

  # Scopes
  scope :ordered, -> { order(:rank_group, :effective_from) }
  scope :for_rank, ->(group) { where(rank_group: group) }
  scope :effective_at, ->(date) { where("effective_from <= ?", date).order(effective_from: :desc) }

  def self.current_quotas_for(date = Date.current)
    RANK_GROUPS.each_with_object({}) do |group, hash|
      quota = for_rank(group).effective_at(date).first
      hash[group] = quota&.quota_kw
    end
  end

  def self.current_names(date = Date.current)
    RANK_GROUPS.each_with_object({}) do |group, hash|
      quota = for_rank(group).effective_at(date).first
      hash[group] = quota&.rank_name || "Nhóm #{group}"
    end
  end
end

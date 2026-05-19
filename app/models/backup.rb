class Backup < ApplicationRecord
  include Auditable

  MAX_COUNT = 3
  STATUSES = %w[completed failed].freeze
  FILENAME_FORMAT = /\Abackup_\d{8}_\d{6}\.dump\z/

  belongs_to :created_by, class_name: "User", optional: true

  validates :filename, presence: true, uniqueness: true, format: { with: FILENAME_FORMAT }
  validates :size_bytes, presence: true,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: "completed") }

  def self.at_capacity?
    completed.count >= MAX_COUNT
  end

  def absolute_path
    BackupService.backup_dir.join(filename)
  end

  def file_exists?
    absolute_path.exist?
  end

  def human_size
    ActiveSupport::NumberHelper.number_to_human_size(size_bytes)
  end
end

class MainMeter < ApplicationRecord
  include Discard::Model
  include Auditable

  belongs_to :zone
  has_many :main_meter_readings

  validates :name, presence: true
end

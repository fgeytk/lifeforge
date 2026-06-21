class Run < ApplicationRecord
  has_one :character, dependent: :destroy
  has_many :life_events, dependent: :destroy

  validates :status, inclusion: { in: %w[active dead retired] }
end

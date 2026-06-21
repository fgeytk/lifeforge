class Character < ApplicationRecord
  belongs_to :run

  validates :first_name, :last_name, presence: true
  validates :age, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :health, :happiness, :intelligence, :fitness, :looks, :charisma,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def full_name
    "#{first_name} #{last_name}"
  end
end

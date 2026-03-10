class Subscription < ApplicationRecord
  # Associations
  belongs_to :business

  # Enums
  enum :plan, { basic: 0, pro: 1, premium: 2 }, default: :basic
  enum :status, { active: 0, suspended: 1, cancelled: 2 }, default: :active

  # Validations
  validates :plan, presence: true
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :max_employees, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true

  # Callbacks
  before_validation :set_plan_defaults, on: :create

  # Methods
  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def active_and_valid?
    active? && !expired?
  end

  private

  def set_plan_defaults
    case plan
    when 'basic'
      self.price ||= 25000
      self.max_employees ||= 2
    when 'pro'
      self.price ||= 45000
      self.max_employees ||= 5
    when 'premium'
      self.price ||= 70000
      self.max_employees ||= 999 # Ilimitado
    end
  end
end

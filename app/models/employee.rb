class Employee < ApplicationRecord
  belongs_to :business
  belongs_to :user, optional: true
  
  has_many :employee_services, dependent: :destroy
  has_many :services, through: :employee_services
  
  enum :status, { available: 0, busy: 1, on_break: 2, offline: 3 }
  
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :business_within_employee_limit

  private

  def business_within_employee_limit
    return unless business
    return unless new_record? || business_id_changed?
    
    if business.subscription.nil?
      errors.add(:base, 'Business does not have an active subscription')
      return
    end
    
    unless business.subscription.active_and_valid?
      errors.add(:base, 'Business subscription is not active or has expired')
      return
    end
    
    if business.employees_limit_reached?
      errors.add(:base, "Cannot add more employees. Plan '#{business.subscription.plan}' allows maximum #{business.subscription.max_employees} employees")
    end
  end
end

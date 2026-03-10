class Service < ApplicationRecord
  belongs_to :business
  
  has_many :employee_services, dependent: :destroy
  has_many :employees, through: :employee_services
  
  validates :name, presence: true
  validates :duration, presence: true, numericality: { greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
end

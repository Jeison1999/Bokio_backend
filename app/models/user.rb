class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Roles
  enum :role, { client: 0, employee: 1, admin: 2, super_admin: 3 }, default: :client

  # Validations
  validates :name, presence: true

  # Associations
  has_many :businesses, foreign_key: :owner_id, dependent: :destroy
  has_many :tickets, foreign_key: :client_id, dependent: :destroy
  has_many :employee_records, class_name: 'Employee', foreign_key: :user_id, dependent: :nullify
  has_many :notifications, dependent: :destroy
end

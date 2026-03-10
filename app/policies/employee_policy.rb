# frozen_string_literal: true

class EmployeePolicy < ApplicationPolicy
  # super_admin, admin del negocio, y empleados pueden ver lista
  def index?
    user.super_admin? || user_owns_business? || user_works_in_business?
  end

  # Cualquiera puede ver un empleado (para agendar)
  def show?
    true
  end

  # Solo admin del negocio o super_admin pueden crear empleados
  def create?
    user.super_admin? || user_owns_business?
  end

  # Solo admin del negocio o super_admin pueden actualizar
  def update?
    user.super_admin? || user_owns_business?
  end

  # Solo admin del negocio o super_admin pueden eliminar
  def destroy?
    user.super_admin? || user_owns_business?
  end

  # Asignar servicios a empleado
  def assign_services?
    user.super_admin? || user_owns_business?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      case user.role
      when 'super_admin'
        # Super admin ve todos los empleados
        scope.all
      when 'admin'
        # Admin ve empleados de sus negocios
        business_ids = Business.where(owner_id: user.id).pluck(:id)
        scope.where(business_id: business_ids)
      when 'employee'
        # Employee ve empleados del mismo negocio
        business_ids = user.employee_records.pluck(:business_id)
        scope.where(business_id: business_ids)
      when 'client'
        # Client ve todos los empleados activos (para agendar)
        scope.where(status: :available)
      else
        scope.none
      end
    end
  end

  private

  def user_owns_business?
    return false unless record.business
    record.business.owner_id == user.id
  end

  def user_works_in_business?
    return false unless record.business
    user.employee_records.exists?(business_id: record.business_id)
  end
end

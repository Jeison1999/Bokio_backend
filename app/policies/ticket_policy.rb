# frozen_string_literal: true

class TicketPolicy < ApplicationPolicy
  # Todos pueden ver lista de tickets (filtrado por scope)
  def index?
    true
  end

  # Ver queue (cola) del negocio
  def queue?
    true
  end

  # Todos pueden ver un ticket específico
  def show?
    true
  end

  # Clientes pueden crear tickets
  def create?
    user.client? || user.admin? || user.super_admin?
  end

  # Solo admin o super_admin pueden actualizar tickets directamente
  def update?
    user.super_admin? || user_owns_business?
  end

  # Solo admin o super_admin pueden eliminar tickets
  def destroy?
    user.super_admin? || user_owns_business?
  end

  # Empleado o admin pueden iniciar un ticket
  def start?
    user.super_admin? || user_owns_business? || user_is_employee_in_business?
  end

  # Empleado o admin pueden completar un ticket
  def complete?
    user.super_admin? || user_owns_business? || user_is_employee_in_business?
  end

  # Empleado o admin pueden cancelar un ticket
  def cancel?
    user.super_admin? || user_owns_business? || user_is_employee_in_business?
  end

  # Empleado o admin pueden marcar como no_show (cliente no llegó)
  def no_show?
    user.super_admin? || user_owns_business? || user_is_employee_in_business?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      case user.role
      when 'super_admin'
        # Super admin ve todos los tickets
        scope.all
      when 'admin'
        # Admin ve tickets de sus negocios
        business_ids = Business.where(owner_id: user.id).pluck(:id)
        scope.where(business_id: business_ids)
      when 'employee'
        # Employee ve tickets del negocio donde trabaja
        business_ids = user.employee_records.pluck(:business_id)
        scope.where(business_id: business_ids)
      when 'client'
        # Client solo ve sus propios tickets
        scope.where(client_id: user.id)
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

  def user_is_employee_in_business?
    return false unless record.business
    user.employee_records.exists?(business_id: record.business_id)
  end
end

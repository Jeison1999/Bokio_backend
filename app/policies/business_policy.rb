# frozen_string_literal: true

class BusinessPolicy < ApplicationPolicy
  # super_admin y admin pueden ver lista de negocios
  # client puede ver negocios disponibles
  # employee puede ver el negocio donde trabaja
  def index?
    true # Todos pueden ver la lista (se filtra en el scope)
  end

  # Todos pueden ver un negocio específico
  def show?
    true
  end

  # Solo admin puede crear su negocio
  def create?
    user.admin? || user.super_admin?
  end

  # Solo el owner del negocio o super_admin pueden actualizar
  def update?
    user.super_admin? || (user.admin? && user_owns_business?)
  end

  # Solo el owner del negocio o super_admin pueden eliminar
  def destroy?
    user.super_admin? || (user.admin? && user_owns_business?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      case user.role
      when 'super_admin'
        # Super admin ve todos los negocios
        scope.all
      when 'admin'
        # Admin solo ve sus negocios
        scope.where(owner_id: user.id)
      when 'employee'
        # Employee ve el negocio donde trabaja
        business_ids = user.employee_records.pluck(:business_id)
        scope.where(id: business_ids)
      when 'client'
        # Client ve todos los negocios activos
        scope.where(active: true)
      else
        scope.none
      end
    end
  end

  private

  def user_owns_business?
    record.owner_id == user.id
  end
end

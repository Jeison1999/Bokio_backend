# frozen_string_literal: true

class ServicePolicy < ApplicationPolicy
  # Todos pueden ver lista de servicios
  def index?
    true
  end

  # Todos pueden ver un servicio
  def show?
    true
  end

  # Solo admin del negocio o super_admin pueden crear servicios
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

  class Scope < ApplicationPolicy::Scope
    def resolve
      case user.role
      when 'super_admin'
        # Super admin ve todos los servicios
        scope.all
      when 'admin'
        # Admin ve servicios de sus negocios
        business_ids = Business.where(owner_id: user.id).pluck(:id)
        scope.where(business_id: business_ids)
      when 'employee', 'client'
        # Employee y Client ven todos los servicios activos
        scope.all
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
end

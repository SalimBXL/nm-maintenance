# Journal d'audit (versions PaperTrail) : lecture seule, réservée aux
# administrateurs et aux responsables techniques. À utiliser avec :
#   authorize PaperTrail::Version, policy_class: AuditLogPolicy
class AuditLogPolicy < ApplicationPolicy
  def index? = fleet_manager?
  def show? = fleet_manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? && user.active? && (user.admin? || user.technical_manager?) ? scope.all : scope.none
    end
  end
end

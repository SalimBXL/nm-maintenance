# Parc et référentiels : lecture pour tout utilisateur actif, écriture
# (création, modification, archivage) pour les administrateurs et les
# responsables techniques.
class FleetPolicy < ApplicationPolicy
  def index? = signed_in?
  def show? = signed_in?
  def create? = fleet_manager?
  def update? = fleet_manager?

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? && user.active? ? scope.all : scope.none
    end
  end
end

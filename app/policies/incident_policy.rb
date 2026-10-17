# Incidents.
#
# - Lecture : tout utilisateur actif.
# - Déclaration : administrateur et responsable technique partout ; technicien
#   et déclarant uniquement sur les équipements des départements dont ils sont
#   membres (appartenances). Sans appartenance, pas de déclaration.
# - Modification (qualification, cause racine…) : administrateur et
#   responsable technique, tant que l'incident n'est pas clôturé.
# - Changements de statut : administrateur et responsable technique pour tous ;
#   le technicien auquel l'incident est assigné peut le prendre en charge
#   (en cours) et le résoudre, pas le qualifier ni le clôturer.
class IncidentPolicy < ApplicationPolicy
  def index? = signed_in?
  def show? = signed_in?

  def create?
    return false unless signed_in?
    return true if fleet_manager?
    return false unless user.department_memberships.exists?

    equipment = record.respond_to?(:equipment) ? record.equipment : nil
    equipment.nil? || user.department_memberships.exists?(department_id: equipment.location.department_id)
  end

  def update?
    fleet_manager? && !record.closed?
  end

  def transition?
    allowed_targets.any?
  end

  # Statuts vers lesquels cet utilisateur peut faire passer cet incident.
  def allowed_targets
    return [] unless signed_in?

    targets = record.next_statuses
    return targets if fleet_manager?
    return [] unless user.technician? && record.assigned_to_id == user.id

    targets & %w[in_progress resolved]
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? && user.active? ? scope.all : scope.none
    end
  end
end

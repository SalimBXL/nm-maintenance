# Interventions.
#
# - Lecture : tout utilisateur actif.
# - Création : administrateur et responsable technique (planification) ;
#   technicien pour un incident qui lui est assigné et non clôturé.
# - Modification : administrateur et responsable technique ; technicien sur
#   les interventions dont il est l'intervenant, tant qu'elles sont
#   planifiées ou en cours.
# - Changements de statut : administrateur et responsable technique ;
#   technicien intervenant : démarrer et terminer (pas annuler).
class EventPolicy < ApplicationPolicy
  def index? = signed_in?
  def show? = signed_in?

  def create?
    return false unless signed_in?
    return true if fleet_manager?

    incident = record.respond_to?(:incident) ? record.incident : nil
    user.technician? && incident.present? && incident.assigned_to_id == user.id && !incident.closed?
  end

  def update?
    return false unless signed_in?
    return true if fleet_manager?

    user.technician? && record.performed_by_id == user.id && record.editable?
  end

  def transition?
    allowed_targets.any?
  end

  def allowed_targets
    return [] unless signed_in?

    targets = record.next_statuses
    return targets if fleet_manager?
    return [] unless user.technician? && record.performed_by_id == user.id

    targets & %w[in_progress completed]
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? && user.active? ? scope.all : scope.none
    end
  end
end

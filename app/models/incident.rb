class Incident < ApplicationRecord
  has_paper_trail

  # Workflow : déclaré -> qualifié -> en cours -> résolu -> clôturé.
  # Un incident résolu peut être rouvert (remis en cours) avec un commentaire.
  TRANSITIONS = {
    'declared' => %w[qualified],
    'qualified' => %w[in_progress],
    'in_progress' => %w[resolved],
    'resolved' => %w[closed in_progress]
  }.freeze

  belongs_to :equipment
  belongs_to :reported_by, class_name: 'User'
  belongs_to :assigned_to, class_name: 'User', optional: true
  has_many :status_changes, class_name: 'IncidentStatusChange', inverse_of: :incident, dependent: :restrict_with_error

  enum :severity, { critical: 'critical', major: 'major', minor: 'minor' },
       default: :minor, prefix: true, validate: true

  enum :nature, { technical: 'technical', safety: 'safety', radiation_protection: 'radiation_protection' },
       default: :technical, prefix: true, validate: true

  enum :status, {
    declared: 'declared', qualified: 'qualified', in_progress: 'in_progress',
    resolved: 'resolved', closed: 'closed'
  }, default: :declared, validate: true

  attribute :detected_at, default: -> { Time.current }

  validates :description, :detected_at, presence: true
  validates :assigned_to, presence: { message: 'est obligatoire dès la qualification' }, unless: :declared?
  validates :root_cause, presence: { message: "est obligatoire pour clôturer l'incident" }, if: :closed?
  validate :assignee_can_work
  validate :equipment_not_archived, on: :create

  scope :unclosed, -> { where.not(status: 'closed') }

  def next_statuses
    TRANSITIONS.fetch(status, [])
  end

  # Un incident de sécurité ou de radioprotection peut imposer une
  # déclaration obligatoire (selon la réglementation applicable).
  def may_require_mandatory_declaration?
    nature_safety? || nature_radiation_protection?
  end

  # Fait passer l'incident au statut suivant : enregistre le changement dans
  # l'historique, met à jour les dates et, pour un incident critique qualifié,
  # passe l'équipement « en panne » ; à la résolution, le statut de l'équipement
  # est recalculé (voir Equipment#restore_status_after_incident!). Retourne true ou false (erreurs dans errors).
  def transition(to, user:, comment: nil, attributes: {})
    to = to.to_s
    from = status

    unless next_statuses.include?(to)
      errors.add(:base, "Transition impossible de « #{from} » vers « #{to} ».")
      return false
    end

    if from == 'resolved' && to == 'in_progress' && comment.blank?
      errors.add(:base, 'Un commentaire est obligatoire pour rouvrir un incident.')
      return false
    end

    success = false
    transaction do
      assign_attributes(attributes)
      self.status = to
      self.resolved_at = Time.current if to == 'resolved'
      self.resolved_at = nil if from == 'resolved' && to == 'in_progress'
      self.closed_at = Time.current if to == 'closed'

      raise ActiveRecord::Rollback unless save

      status_changes.create!(from_status: from, to_status: to, user: user, comment: comment.presence)
      mark_equipment_out_of_order if to == 'qualified'
      equipment.restore_status_after_incident!(self) if to == 'resolved'
      mark_equipment_out_of_order if from == 'resolved' && to == 'in_progress'
      success = true
    end

    self.status = from unless success
    success
  end

  private

  def assignee_can_work
    return if assigned_to.nil? || !assigned_to_id_changed?

    return if assigned_to.active? && !assigned_to.reporter?

    errors.add(:assigned_to, 'doit être un utilisateur actif (technicien, responsable technique ou administrateur)')
  end

  def equipment_not_archived
    errors.add(:equipment, "est archivé : on ne peut plus y déclarer d'incident") if equipment&.archived?
  end

  # Un incident critique ouvert peut faire passer l'équipement en panne.
  def mark_equipment_out_of_order
    equipment.update!(status: :out_of_order) if severity_critical? && equipment.in_service?
  end
end

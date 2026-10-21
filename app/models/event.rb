# Intervention (préventive, corrective, contrôle qualité, étalonnage, mise à
# jour logicielle) sur un équipement, éventuellement liée à un incident.
class Event < ApplicationRecord
  has_paper_trail

  # Planifiée -> en cours -> terminée ; une intervention planifiée ou en cours
  # peut aussi être terminée directement ou annulée.
  TRANSITIONS = {
    'planned' => %w[in_progress completed cancelled],
    'in_progress' => %w[completed cancelled]
  }.freeze

  belongs_to :equipment
  belongs_to :incident, optional: true
  belongs_to :performed_by, class_name: 'User', optional: true

  enum :event_type, {
    preventive: 'preventive', corrective: 'corrective', quality_control: 'quality_control',
    calibration: 'calibration', software_update: 'software_update'
  }, default: :corrective, prefix: :type, validate: true

  enum :status, {
    planned: 'planned', in_progress: 'in_progress', completed: 'completed', cancelled: 'cancelled'
  }, default: :planned, validate: true

  validates :title, presence: true
  validates :ended_at, :report, presence: true, if: :completed?
  validates :cost_cents, :downtime_minutes,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :cost_euros_valid
  validate :ended_after_started
  validate :incident_matches_equipment
  validate :performer_can_work
  validate :equipment_not_archived, on: :create

  scope :open_ones, -> { where(status: %w[planned in_progress]) }

  def next_statuses
    TRANSITIONS.fetch(status, [])
  end

  # Planifiée ou en cours : le contenu peut encore évoluer.
  def editable?
    planned? || in_progress?
  end

  # --- Coût saisi en euros (« 125,50 »), stocké en centimes

  def cost_euros
    return @cost_input if @cost_invalid

    cost_cents && format('%.2f', cost_cents / 100.0).tr('.', ',')
  end

  def cost_euros=(value)
    text = value.to_s.strip.tr(',', '.')
    @cost_invalid = false

    if text.empty?
      self.cost_cents = nil
    elsif text.match?(/\A\d+(\.\d{1,2})?\z/)
      self.cost_cents = (BigDecimal(text) * 100).to_i
    else
      @cost_invalid = true
      @cost_input = value
    end
  end

  # Fait passer l'intervention au statut suivant. Retourne true ou false
  # (erreurs dans errors).
  def transition(to, user:, attributes: {})
    to = to.to_s
    from = status

    unless next_statuses.include?(to)
      errors.add(:base, "Transition impossible de « #{from} » vers « #{to} ».")
      return false
    end

    success = false
    transaction do
      assign_attributes(attributes)
      self.status = to

      case to
      when 'in_progress'
        self.started_at ||= Time.current
        self.performed_by ||= user if user && !user.reporter?
      when 'completed'
        self.ended_at ||= Time.current
      end

      raise ActiveRecord::Rollback unless save

      equipment.sync_status_with_events!
      success = true
    end

    self.status = from unless success
    success
  end

  private

  def cost_euros_valid
    errors.add(:cost_euros, "n'est pas un montant valide (exemple : 125,50)") if @cost_invalid
  end

  def ended_after_started
    return unless started_at && ended_at && ended_at < started_at

    errors.add(:ended_at, 'doit être postérieure au début')
  end

  def incident_matches_equipment
    return unless incident && equipment && incident.equipment_id != equipment_id

    errors.add(:incident, 'concerne un autre équipement')
  end

  def performer_can_work
    return if performed_by.nil? || !performed_by_id_changed?

    return if performed_by.active? && !performed_by.reporter?

    errors.add(:performed_by, 'doit être un utilisateur actif (technicien, responsable technique ou administrateur)')
  end

  def equipment_not_archived
    errors.add(:equipment, "est archivé : on ne peut plus y planifier d'intervention") if equipment&.archived?
  end
end

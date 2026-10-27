class Equipment < ApplicationRecord
  include Archivable

  has_paper_trail

  # TYPE-FABRICANT-NN, ex. PETCT-GE-01, SPECT-SIEM-02, ACT-VIK-01
  CODE_FORMAT = /\A[A-Z0-9]{2,8}-[A-Z]{2,5}-\d{2,}\z/

  # Le code est généré à la création, jamais modifié.
  attr_readonly :code

  belongs_to :equipment_model
  belongs_to :location

  has_one :department, through: :location
  has_many :equipment_moves, dependent: :restrict_with_error

  delegate :category, :manufacturer, to: :equipment_model

  enum :status, {
    in_service: 'in_service',             # en service
    out_of_order: 'out_of_order',         # en panne
    under_maintenance: 'under_maintenance', # en maintenance
    decommissioned: 'decommissioned' # hors service
  }, default: :in_service, validate: true

  # Niveaux de criticité : à confirmer.
  enum :criticality, {
    low: 'low',
    medium: 'medium',
    high: 'high'
  }, default: :medium, prefix: true, validate: true

  normalizes :serial_number, with: ->(v) { v.strip.presence }

  validates :code, format: { with: CODE_FORMAT }, allow_nil: true
  validates :serial_number, uniqueness: { scope: :equipment_model_id }, allow_nil: true
  validates :decommissioned_on, presence: true, if: :decommissioned?

  # Attribué dans la transaction de la sauvegarde : si l'insertion échoue,
  # le compteur est annulé et aucun numéro n'est perdu.
  before_create :assign_code
  after_update :record_move, if: :saved_change_to_location_id?

  # Aligne le statut sur les interventions : « en maintenance » tant qu'une
  # intervention est en cours ; au retour, « en service », ou « en panne » si
  # un incident critique qualifié ou en cours n'est pas encore résolu.
  # Un équipement en panne ou hors service n'est jamais modifié au démarrage.
  def sync_status_with_events!
    if Event.exists?(equipment_id: id, status: 'in_progress')
      update!(status: :under_maintenance) if in_service?
    elsif under_maintenance?
      update!(status: critical_incident_unresolved? ? :out_of_order : :in_service)
    end
  end

  # À la résolution d'un incident critique, recalcule le statut sans le forcer :
  # un équipement « en panne » repasse « en maintenance » si une intervention est
  # en cours, « en service » s'il ne reste aucun autre incident critique ouvert,
  # et ne change pas sinon. Les autres statuts (hors service, en maintenance
  # posé à la main) ne sont jamais touchés.
  def restore_status_after_incident!(incident)
    return unless incident.severity_critical? && out_of_order?
    return if critical_incident_unresolved?(except: incident)

    update!(status: Event.exists?(equipment_id: id, status: 'in_progress') ? :under_maintenance : :in_service)
  end

  private

  def critical_incident_unresolved?(except: nil)
    scope = Incident.where(equipment_id: id, severity: 'critical', status: %w[qualified in_progress])
    scope = scope.where.not(id: except.id) if except
    scope.exists?
  end

  def assign_code
    self.code ||= EquipmentCodeCounter.next_code(category: category, manufacturer: manufacturer)
  end

  # Tout changement de local est enregistré dans l'historique des déplacements.
  def record_move
    equipment_moves.create!(
      from_location_id: location_id_before_last_save,
      to_location_id: location_id,
      moved_at: Time.current,
      user: Current.user
    )
  end
end

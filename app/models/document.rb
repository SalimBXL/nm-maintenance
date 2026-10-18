# Document technique (manuel, certificat, rapport…) rattaché à un équipement
# ou à un modèle d'équipement. Une nouvelle version référence la précédente ;
# l'historique reste consultable.
class Document < ApplicationRecord
  include Archivable

  has_paper_trail

  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    image/png
    image/jpeg
    text/plain
    application/zip
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
  ].freeze

  # Un document dont la validité se termine dans ce délai est signalé.
  EXPIRING_DAYS = 60

  class_attribute :max_file_size, instance_accessor: false, default: 25.megabytes

  belongs_to :equipment, optional: true
  belongs_to :equipment_model, optional: true
  belongs_to :uploaded_by, class_name: 'User', optional: true
  belongs_to :supersedes, class_name: 'Document', optional: true
  has_one :superseded_by, class_name: 'Document', foreign_key: :supersedes_id, inverse_of: :supersedes

  has_one_attached :file

  enum :document_type, {
    manual: 'manual', certificate: 'certificate', conformity_declaration: 'conformity_declaration',
    report: 'report', procedure: 'procedure', other: 'other'
  }, default: :other, prefix: :type, validate: true

  validates :title, presence: true
  validates :version_label, length: { maximum: 50 }
  validate :exactly_one_target
  validate :acceptable_file
  validate :consistent_supersedes, if: :supersedes

  before_validation :set_version_number, on: :create

  # Versions les plus récentes uniquement (celles qui n'ont pas été remplacées).
  scope :current, -> { where.not(id: Document.where.not(supersedes_id: nil).select(:supersedes_id)) }

  def current?
    superseded_by.nil?
  end

  def expired?
    valid_until.present? && valid_until < Time.zone.today
  end

  def expiring_soon?
    valid_until.present? && !expired? && valid_until <= Time.zone.today + EXPIRING_DAYS
  end

  # Toutes les versions de ce document, de la plus ancienne à la plus récente.
  def chain
    root = self
    root = root.supersedes while root.supersedes
    versions = [root]
    while (newer = Document.find_by(supersedes_id: versions.last.id))
      versions << newer
    end
    versions
  end

  private

  def set_version_number
    self.version_number = supersedes ? supersedes.version_number + 1 : 1
  end

  def exactly_one_target
    return if equipment_id.present? ^ equipment_model_id.present?

    errors.add(:base, 'Le document doit être rattaché à un équipement ou à un modèle, pas aux deux ni à aucun.')
  end

  def acceptable_file
    unless file.attached?
      errors.add(:file, 'doit être jointe')
      return
    end

    blob = file.blob
    unless ALLOWED_CONTENT_TYPES.include?(blob.content_type)
      errors.add(:file,
                 "n'est pas d'un type accepté (#{blob.content_type})")
    end
    return unless blob.byte_size > self.class.max_file_size

    errors.add(:file, "est trop volumineuse (maximum #{self.class.max_file_size / 1.megabyte} Mo)")
  end

  def consistent_supersedes
    # Requête directe (pas l'association) : elle pourrait être en cache et périmée.
    already_replaced = Document.where(supersedes_id: supersedes_id).where.not(id: id).exists?
    errors.add(:supersedes, 'a déjà une version plus récente') if already_replaced

    return if supersedes.equipment_id == equipment_id && supersedes.equipment_model_id == equipment_model_id

    errors.add(:supersedes, "n'a pas le même rattachement")
  end
end

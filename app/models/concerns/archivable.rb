# Pas de suppression physique des données métier : on archive.
module Archivable
  extend ActiveSupport::Concern

  included do
    scope :kept, -> { where(archived_at: nil) }
    scope :archived, -> { where.not(archived_at: nil) }

    before_destroy :refuse_destroy
  end

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end

  private

  def refuse_destroy
    errors.add(:base, "La suppression est interdite : archivez l'enregistrement.")
    throw :abort
  end
end

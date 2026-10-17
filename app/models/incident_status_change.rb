# Historique des changements de statut d'un incident : un enregistrement
# n'est ni modifiable ni supprimable une fois créé.
class IncidentStatusChange < ApplicationRecord
  belongs_to :incident
  belongs_to :user, optional: true

  validates :to_status, presence: true

  def readonly?
    persisted? || super
  end
end

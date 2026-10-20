# Modèle d'équipement (ex. un type d'appareil d'un fabricant). Séparé des
# équipements pour ne pas répéter fabricant et modèle sur chaque exemplaire
# et pour rattacher un manuel à tous les appareils d'un même modèle.
class EquipmentModel < ApplicationRecord
  include Archivable

  has_paper_trail

  belongs_to :manufacturer
  belongs_to :category, class_name: 'EquipmentCategory'

  has_many :equipments, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: :manufacturer_id }

  def display_name
    "#{manufacturer.name} #{name}"
  end
end

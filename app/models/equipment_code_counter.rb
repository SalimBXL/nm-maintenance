# Compteur séquentiel par couple (catégorie, fabricant). Il ne redescend
# jamais, donc un numéro de code n'est jamais réutilisé, même après archivage
# ou mise hors service d'un équipement.
class EquipmentCodeCounter < ApplicationRecord
  belongs_to :category, class_name: 'EquipmentCategory'
  belongs_to :manufacturer

  def self.next_code(category:, manufacturer:)
    counter = find_or_create_counter(category, manufacturer)
    counter.with_lock do
      counter.increment!(:last_number)
      format('%s-%s-%02d', category.code_prefix, manufacturer.code, counter.last_number)
    end
  end

  def self.find_or_create_counter(category, manufacturer)
    find_or_create_by!(category: category, manufacturer: manufacturer)
  rescue ActiveRecord::RecordNotUnique
    retry
  end
  private_class_method :find_or_create_counter
end

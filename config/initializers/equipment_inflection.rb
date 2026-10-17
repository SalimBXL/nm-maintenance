# "equipment" est incontable par défaut en anglais (equipment -> equipment).
# On force le pluriel "equipments" pour que la table, les routes et l'API
# (/api/v1/equipments) correspondent à la spécification du jalon 1.
ActiveSupport::Inflector.inflections(:en) do |inflect|
  inflect.irregular 'equipment', 'equipments'
end

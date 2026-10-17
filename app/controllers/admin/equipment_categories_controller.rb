module Admin
  class EquipmentCategoriesController < ResourcesController
    private

    def resource_class = EquipmentCategory
    def resource_title = "Catégories d'équipements"

    def fields
      [
        { name: :name, label: 'Nom', type: :text },
        { name: :code_prefix, label: 'Préfixe de type', type: :text, create_only: true,
          hint: '2 à 8 lettres ou chiffres, sans tiret (ex. PETCT). Entre dans le code interne : non modifiable ensuite.' },
        { name: :description, label: 'Description', type: :textarea }
      ]
    end

    def columns
      [
        ['Nom', ->(category) { category.name }],
        ['Préfixe', ->(category) { category.code_prefix }],
        ['Modèles', ->(category) { category.equipment_models.kept.count }]
      ]
    end

    def archive_blocker(category)
      "Cette catégorie a encore des modèles actifs : archivez-les d'abord." if category.equipment_models.kept.exists?
    end
  end
end

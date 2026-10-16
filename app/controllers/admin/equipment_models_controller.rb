module Admin
  class EquipmentModelsController < ResourcesController
    private

    def resource_class = EquipmentModel
    def resource_title = "Modèles d'équipements"
    def includes = %i[manufacturer category]

    def fields
      [
        { name: :manufacturer_id, label: "Fabricant", type: :select, collection: :manufacturers, create_only: true },
        { name: :category_id, label: "Catégorie", type: :select, collection: :categories, create_only: true },
        { name: :name, label: "Nom du modèle", type: :text }
      ]
    end

    def columns
      [
        ["Modèle", ->(model) { model.name }],
        ["Fabricant", ->(model) { model.manufacturer.name }],
        ["Catégorie", ->(model) { model.category.name }],
        ["Équipements", ->(model) { model.equipments.kept.count }]
      ]
    end

    def collections
      {
        manufacturers: Manufacturer.kept.order(:name).map { |manufacturer| [manufacturer.name, manufacturer.id] },
        categories: EquipmentCategory.kept.order(:name).map { |category| [category.name, category.id] }
      }
    end

    def archive_blocker(model)
      "Ce modèle a encore des équipements actifs : archivez-les d'abord." if model.equipments.kept.exists?
    end
  end
end

module Admin
  class ManufacturersController < ResourcesController
    private

    def resource_class = Manufacturer
    def resource_title = "Fabricants"

    def fields
      [
        { name: :name, label: "Nom", type: :text },
        { name: :code, label: "Code court", type: :text, create_only: true,
          hint: "2 à 5 lettres (ex. GE, COME). Entre dans le code interne : non modifiable ensuite." }
      ]
    end

    def columns
      [
        ["Nom", ->(manufacturer) { manufacturer.name }],
        ["Code", ->(manufacturer) { manufacturer.code }],
        ["Modèles", ->(manufacturer) { manufacturer.equipment_models.kept.count }]
      ]
    end

    def archive_blocker(manufacturer)
      "Ce fabricant a encore des modèles actifs : archivez-les d'abord." if manufacturer.equipment_models.kept.exists?
    end
  end
end

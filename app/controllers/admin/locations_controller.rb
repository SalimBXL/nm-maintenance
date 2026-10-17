module Admin
  class LocationsController < ResourcesController
    private

    def resource_class = Location
    def resource_title = 'Locaux'
    def includes = %i[department referent]
    def default_order = :name

    def fields
      [
        { name: :department_id, label: 'Département', type: :select, collection: :departments, create_only: true },
        { name: :name, label: 'Nom', type: :text },
        { name: :code, label: 'Code', type: :text, hint: 'Unique dans le département (ex. CAM1).' },
        { name: :referent_id, label: 'Référent', type: :select, collection: :users, blank: 'Aucun',
          hint: 'Facultatif : référent du local (ex. SPECT ou PET).' }
      ]
    end

    def columns
      [
        ['Nom', ->(location) { location.name }],
        ['Code', ->(location) { location.code }],
        ['Département', ->(location) { location.department.name }],
        ['Référent', ->(location) { location.referent&.name || '—' }]
      ]
    end

    def collections
      {
        departments: Department.kept.order(:name).map { |department| [department.name, department.id] },
        users: User.active.order(:name).map { |user| [user.name, user.id] }
      }
    end

    def archive_blocker(location)
      return unless location.equipments.kept.exists?

      "Ce local contient encore des équipements actifs : déplacez-les ou archivez-les d'abord."
    end
  end
end

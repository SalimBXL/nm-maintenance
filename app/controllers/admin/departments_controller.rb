module Admin
  class DepartmentsController < ResourcesController
    private

    def resource_class = Department
    def resource_title = 'Départements'
    def includes = [:manager]

    def fields
      [
        { name: :name, label: 'Nom', type: :text },
        { name: :code, label: 'Code', type: :text, hint: 'Court et stable (ex. CAM, INJ).' },
        { name: :manager_id, label: 'Responsable', type: :select, collection: :users, blank: 'Aucun' }
      ]
    end

    def columns
      [
        ['Nom', ->(department) { department.name }],
        ['Code', ->(department) { department.code }],
        ['Responsable', ->(department) { department.manager&.name || '—' }],
        ['Locaux', ->(department) { department.locations.kept.count }]
      ]
    end

    def collections
      { users: User.active.order(:name).map { |user| [user.name, user.id] } }
    end

    def archive_blocker(department)
      "Ce département a encore des locaux actifs : archivez-les d'abord." if department.locations.kept.exists?
    end
  end
end

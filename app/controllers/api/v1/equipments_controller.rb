module Api
  module V1
    class EquipmentsController < BaseController
      INCLUDES = [{ equipment_model: %i[manufacturer category] }, { location: :department }].freeze

      # GET /api/v1/equipments
      # Filtres : department_id, location_id, category_id, status, q (code, n° de série,
      # modèle, fabricant), archived=1. Pagination : page, per_page.
      def index
        authorize Equipment
        records, meta = paginate(filtered(policy_scope(Equipment)).includes(*INCLUDES).order(:code))
        render_collection(records, meta) { |equipment| ApiSerializers.equipment(equipment) }
      end

      # GET /api/v1/equipments/:id
      def show
        equipment = Equipment.includes(*INCLUDES).find(params.expect(:id))
        authorize equipment
        render json: { data: ApiSerializers.equipment(equipment) }
      end

      private

      def filtered(scope)
        scope = scope.kept unless params[:archived] == '1'
        scope = scope.where(status: params[:status]) if Equipment.statuses.key?(params[:status])
        scope = scope.where(location_id: Location.where(department_id: params[:department_id])) if params[:department_id].present?
        scope = scope.where(location_id: params[:location_id]) if params[:location_id].present?
        if params[:category_id].present?
          scope = scope.where(equipment_model_id: EquipmentModel.where(category_id: params[:category_id]))
        end
        params[:q].present? ? search(scope, params[:q]) : scope
      end

      def search(scope, term)
        pattern = "%#{Equipment.sanitize_sql_like(term.to_s.strip)}%"
        by_model = EquipmentModel.joins(:manufacturer)
                                 .where('equipment_models.name LIKE :p OR manufacturers.name LIKE :p', p: pattern)
                                 .select(:id)

        scope.where('equipments.code LIKE :p OR equipments.serial_number LIKE :p', p: pattern)
             .or(scope.where(equipment_model_id: by_model))
      end
    end
  end
end

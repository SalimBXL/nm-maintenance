module Api
  module V1
    class IncidentsController < BaseController
      INCLUDES = %i[equipment reported_by assigned_to].freeze

      # GET /api/v1/incidents
      # Filtres : status (par défaut : ouverts ; « all » pour tous), severity,
      # equipment_id, department_id, mine=1. Pagination : page, per_page.
      def index
        authorize Incident
        scope = filtered(policy_scope(Incident)).includes(*INCLUDES).order(id: :desc)
        records, meta = paginate(scope)
        render_collection(records, meta) { |incident| ApiSerializers.incident(incident, user: Current.user) }
      end

      # GET /api/v1/incidents/:id
      def show
        incident = Incident.includes(*INCLUDES).find(params[:id])
        authorize incident
        render json: { data: ApiSerializers.incident(incident, user: Current.user) }
      end

      # POST /api/v1/incidents : { "incident": { equipment_id, description, severity, nature, detected_at } }
      def create
        incident = Incident.new(declaration_params)
        incident.reported_by = Current.user
        authorize incident

        if save_declaration(incident)
          render json: { data: ApiSerializers.incident(incident, user: Current.user) }, status: :created
        else
          render_validation_errors(incident)
        end
      end

      # POST /api/v1/incidents/:id/transition
      # { "to": "qualified", "comment": "...", "incident": { assigned_to_id, severity, ... } }
      def transition
        incident = Incident.find(params[:id])
        authorize incident, :transition?
        target = params[:to].to_s

        unless IncidentPolicy.new(Current.user, incident).allowed_targets.include?(target)
          return render_error(:forbidden, 'forbidden', "Ce changement de statut n'est pas permis.")
        end

        if incident.transition(target, user: Current.user, comment: params[:comment], attributes: transition_attributes)
          render json: { data: ApiSerializers.incident(incident, user: Current.user) }
        else
          render_validation_errors(incident)
        end
      end

      private

      def save_declaration(incident)
        IncidentStatusChange.transaction do
          raise ActiveRecord::Rollback unless incident.save

          incident.status_changes.create!(to_status: 'declared', user: Current.user, comment: 'Déclaration')
          true
        end
      end

      def filtered(scope)
        status = params[:status].to_s
        scope = scope.unclosed if status.blank?
        scope = scope.where(status: status) if Incident.statuses.key?(status)
        scope = scope.where(severity: params[:severity]) if Incident.severities.key?(params[:severity])
        scope = scope.where(equipment_id: params[:equipment_id]) if params[:equipment_id].present?
        if params[:department_id].present?
          scope = scope.where(equipment_id: Equipment.where(location_id: Location.where(department_id: params[:department_id])))
        end
        if params[:mine] == '1'
          scope = scope.where('incidents.assigned_to_id = :id OR incidents.reported_by_id = :id',
                              id: Current.user.id)
        end
        scope
      end

      def declaration_params
        params.require(:incident).permit(:equipment_id, :description, :severity, :nature, :detected_at)
      end

      def transition_attributes
        permitted = if Current.user.admin? || Current.user.technical_manager?
                      %i[severity nature assigned_to_id mandatory_declaration root_cause corrective_action]
                    else
                      %i[corrective_action]
                    end
        params.fetch(:incident, {}).permit(*permitted)
      end
    end
  end
end

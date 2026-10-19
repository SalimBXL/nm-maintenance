module Api
  module V1
    class EventsController < BaseController
      INCLUDES = %i[equipment performed_by].freeze

      # GET /api/v1/events
      # Filtres : status (par défaut : en attente ou en cours ; « all » pour toutes),
      # event_type, equipment_id, incident_id, department_id, mine=1.
      def index
        authorize Event
        scope = filtered(policy_scope(Event)).includes(*INCLUDES).order(id: :desc)
        records, meta = paginate(scope)
        render_collection(records, meta) { |event| ApiSerializers.event(event, user: Current.user) }
      end

      # GET /api/v1/events/:id
      def show
        event = Event.includes(*INCLUDES).find(params[:id])
        authorize event
        render json: { data: ApiSerializers.event(event, user: Current.user) }
      end

      # POST /api/v1/events
      # { "event": { equipment_id, incident_id, event_type, title, scheduled_on, performed_by_id, contractor } }
      # Un technicien ne peut créer d'intervention que sur un incident qui lui est assigné
      # (l'équipement et l'intervenant sont alors déduits).
      def create
        event = Event.new(create_params)
        event.equipment ||= event.incident&.equipment
        event.performed_by = Current.user if technician?
        authorize event

        if event.save
          render json: { data: ApiSerializers.event(event, user: Current.user) }, status: :created
        else
          render_validation_errors(event)
        end
      end

      # POST /api/v1/events/:id/start
      def start
        change_status('in_progress')
      end

      # POST /api/v1/events/:id/complete
      # { "event": { report (obligatoire), ended_at, started_at, downtime_minutes, cost_euros } }
      def complete
        change_status('completed')
      end

      # POST /api/v1/events/:id/cancel
      def cancel
        change_status('cancelled')
      end

      private

      def change_status(target)
        event = Event.find(params[:id])
        authorize event, :transition?

        unless EventPolicy.new(Current.user, event).allowed_targets.include?(target)
          return render_error(:forbidden, 'forbidden', "Ce changement de statut n'est pas permis.")
        end

        if event.transition(target, user: Current.user, attributes: transition_attributes)
          render json: { data: ApiSerializers.event(event, user: Current.user) }
        else
          render_validation_errors(event)
        end
      end

      def manager?
        Current.user.admin? || Current.user.technical_manager?
      end

      def technician?
        !manager? && Current.user.technician?
      end

      def filtered(scope)
        status = params[:status].to_s
        scope = scope.open_ones if status.blank?
        scope = scope.where(status: status) if Event.statuses.key?(status)
        scope = scope.where(event_type: params[:event_type]) if Event.event_types.key?(params[:event_type])
        scope = scope.where(equipment_id: params[:equipment_id]) if params[:equipment_id].present?
        scope = scope.where(incident_id: params[:incident_id]) if params[:incident_id].present?
        if params[:department_id].present?
          scope = scope.where(equipment_id: Equipment.where(location_id: Location.where(department_id: params[:department_id])))
        end
        scope = scope.where(performed_by_id: Current.user.id) if params[:mine] == '1'
        scope
      end

      def create_params
        permitted = if manager?
                      %i[equipment_id incident_id event_type title scheduled_on performed_by_id contractor]
                    else
                      %i[incident_id event_type title scheduled_on contractor]
                    end
        params.require(:event).permit(*permitted)
      end

      def transition_attributes
        params.fetch(:event, {}).permit(:started_at, :ended_at, :report, :downtime_minutes, :cost_euros, :contractor)
      end
    end
  end
end
